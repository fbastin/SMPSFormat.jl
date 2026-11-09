using SMPSFormat
using Distributions: Normal, Uniform, Gamma, Beta, LogNormal
using HiGHS
using JuMP
using Random
using SparseArrays
using Statistics
using Test

const DATA = joinpath(@__DIR__, "data")

# A small problem: the first stage, X1 and X2 under a capacity; the second, Y1 to Y3 meeting two
# demands and a balance, ranged; Y3 integer. Comment lines and a blank line, as files have them.
const TOY_CORE = """
* a comment line before the name
NAME          TOY
ROWS
 N  COST
 L  CAP
 G  DEM1
 G  DEM2
 E  BAL
COLUMNS
* a comment line among the columns

    X1        COST      2.0            CAP       1.0
    X1        DEM1      1.0
    X2        COST      3.0            CAP       1.0
    X2        DEM2      1.0
    Y1        COST      5.0            DEM1      1.0
    Y1        BAL       1.0
    Y2        COST      6.0            DEM2      1.0
    MARKER                 'MARKER'                 'INTORG'
    Y3        BAL       1.0
    MARKER                 'MARKER'                 'INTEND'
RHS
    RHS       CAP       10.0           DEM1      4.0
    RHS       DEM2      3.0            BAL       8.0
RANGES
    RNG       BAL       -2.0
BOUNDS
 UP BND       X1        8.0
ENDATA
"""

const TOY_TIME = """
TIME          TOY
PERIODS
    X1        CAP                      PERIOD1
    Y1        DEM1                     PERIOD2
ENDATA
"""

# The same in three periods: Y3 and BAL make the third.
const THREE = replace(TOY_TIME, "ENDATA" => "    Y3        BAL                      PERIOD3\nENDATA")

"""The path of the instance made of `core`, `time` and `stoch`, in a new temporary directory."""
function instance(stoch; core = TOY_CORE, time = TOY_TIME)
    dir = mktempdir()
    write(joinpath(dir, "toy.cor"), core)
    write(joinpath(dir, "toy.tim"), time)
    write(joinpath(dir, "toy.sto"), stoch)
    return joinpath(dir, "toy")
end

"""The scenarios of `smps` as a set of (values by element, probability rounded)."""
scenario_set(smps, law = smps.law) = Set((Dict(zip(smps.elements, ξ)), round(p; digits = 12))
                                         for (ξ, p) in zip(enumerate_scenarios(law)...))

"""Whether `a` and `b` are the same problem: the same data, the same elements, the same law."""
function same_problem(a::SMPSProblem, b::SMPSProblem)
    fields = (:sense, :objective, :c, :A, :senses1, :b, :lb1, :ub1, :integer1, :q, :W, :senses2,
              :h, :T, :lb, :ub, :integer2, :constant, :columns1, :columns2, :rows1, :rows2,
              :elements)
    all(f -> getfield(a, f) == getfield(b, f), fields) || return false
    isequal(a.ranges1, b.ranges1) && isequal(a.ranges2, b.ranges2) || return false
    a.law.base == b.law.base || return false
    # the discrete part by its scenarios: a block written may list what it left to the core file
    discrete(law) = SMPSLaw(law.base, law.probabilities, law.outcomes, empty(law.continuous))
    scenario_set(a, discrete(a.law)) == scenario_set(b, discrete(b.law)) || return false
    length(a.law.continuous) == length(b.law.continuous) || return false
    for (x, y) in zip(a.law.continuous, b.law.continuous)
        x[1] == y[1] && typeof(x[2]) == typeof(y[2]) && x[3] == y[3] && x[4] == y[4] || return false
        all(map(≈, Distributions_params(x[2]), Distributions_params(y[2]))) || return false
    end
    return true
end
Distributions_params(d) = SMPSFormat.parameters(d)[2:3]

"""`smps` written and read back."""
function round_trip(smps; kwargs...)
    prefix = joinpath(mktempdir(), "written")
    write_smps(prefix, smps; kwargs...)
    return read_smps(prefix)
end

@testset "SMPSFormat" begin
    @testset "The core file" begin
        smps = read_smps(instance("STOCH         TOY\nINDEP         DISCRETE\n" *
                                  "    RHS       DEM1      4.0            PERIOD2   0.5\n" *
                                  "    RHS       DEM1      6.0            PERIOD2   0.5\nENDATA\n"))
        @test smps.name == "TOY" && smps.sense === :min && smps.objective == "COST"
        @test smps.c == [2.0, 3.0] && Matrix(smps.A) == [1.0 1.0] && smps.b == [10.0]
        @test smps.senses1 == ['L'] && smps.ub1 == [8.0, Inf] && smps.lb1 == [0.0, 0.0]
        @test smps.q == [5.0, 6.0, 0.0] && smps.h == [4.0, 3.0, 8.0]
        @test Matrix(smps.T) == [1.0 0.0; 0.0 1.0; 0.0 0.0]
        @test Matrix(smps.W) == [1.0 0.0 0.0; 0.0 1.0 0.0; 1.0 0.0 1.0]
        @test smps.senses2 == ['G', 'G', 'E'] && smps.integer2 == [false, false, true]
        @test isequal(smps.ranges2, [NaN, NaN, -2.0])
        @test row_bounds('E', 8.0, -2.0) == (6.0, 8.0) && row_bounds('E', 8.0, 2.0) == (8.0, 10.0)
        @test row_bounds('L', 8.0, -2.0) == (6.0, 8.0) && row_bounds('G', 8.0, -2.0) == (8.0, 10.0)
        @test row_bounds('G', 8.0, NaN) == (8.0, Inf)
        @test smps.columns1 == ["X1", "X2"] && smps.rows2 == ["DEM1", "DEM2", "BAL"]
    end

    @testset "INDEP, ADD" begin
        smps = read_smps(instance("""
            STOCH         TOY
            INDEP         DISCRETE
                RHS       DEM1      4.0            PERIOD2   0.5
                RHS       DEM1      6.0            PERIOD2   0.5
            INDEP         DISCRETE  ADD
                RHS       DEM2      1.0            PERIOD2   0.5
                RHS       DEM2      -1.0           PERIOD2   0.5
            ENDATA
            """))
        @test smps.elements == [(:h, 1, 0), (:h, 2, 0)]
        @test support_size(smps.law) == 4
        @test scenario_set(smps) == Set((Dict((:h, 1, 0) => d1, (:h, 2, 0) => d2), 0.25)
                                        for d1 in (4.0, 6.0) for d2 in (4.0, 2.0))
        @test same_problem(smps, round_trip(smps))
    end

    @testset "BLOCKS: an element left out keeps the first realization's value" begin
        smps = read_smps(instance("""
            STOCH         TOY
            BLOCKS        DISCRETE
             BL B1        PERIOD2   0.5
                Y1        COST      7.0
                Y2        COST      8.0
             BL B1        PERIOD2   0.5
                Y1        COST      9.0
            ENDATA
            """))
        (; ξ, p) = enumerate_scenarios(smps.law)
        @test ξ == [[7.0, 8.0], [9.0, 8.0]] && p == [0.5, 0.5]
        @test second_stage(smps, ξ[2]).q == [9.0, 8.0, 0.0]
        @test same_problem(smps, round_trip(smps))
    end

    @testset "BLOCKS, MULTIPLY, two entries on a line" begin
        smps = read_smps(instance("""
            STOCH         TOY
            BLOCKS        DISCRETE  MULTIPLY
             BL B1        PERIOD2   0.5
                Y1        DEM1      2.0            BAL       3.0
             BL B1        PERIOD2   0.5
                Y1        DEM1      0.5
            ENDATA
            """))
        @test smps.elements == [(:W, 1, 1), (:W, 3, 1)] && smps.law.base == [1.0, 1.0]
        # BAL left out of the second realization: its value in the first, 3
        @test [(W = second_stage(smps, ξ).W; (W[1, 1], W[3, 1])) for ξ in enumerate_scenarios(smps.law).ξ] ==
              [(2.0, 3.0), (0.5, 3.0)]
        @test same_problem(smps, round_trip(smps))
        # X1 is not in DEM2 in the core file
        @test_throws ErrorException read_smps(instance("""
            STOCH         TOY
            BLOCKS        DISCRETE  MULTIPLY
             BL B1        PERIOD2   0.5
                X1        DEM2      2.0
            ENDATA
            """))
    end

    @testset "SCENARIOS: a tree in two stages, values inherited" begin
        smps = read_smps(instance("""
            STOCH         TOY
            SCENARIOS     DISCRETE
             SC S1        'ROOT'    0.5            PERIOD1
                RHS       DEM1      5.0
                RHS       DEM2      6.0
             SC S2        S1        0.25           PERIOD2
                RHS       DEM1      7.0
             SC S3        S2        0.25           PERIOD2
                Y1        COST      1.0
            ENDATA
            """))
        (; ξ, p) = enumerate_scenarios(smps.law)
        @test smps.elements == [(:h, 1, 0), (:h, 2, 0), (:q, 1, 0)]
        @test ξ == [[5.0, 6.0, 5.0], [7.0, 6.0, 5.0], [7.0, 6.0, 1.0]] && p == [0.5, 0.25, 0.25]
        @test same_problem(smps, round_trip(smps))
        @test_throws ErrorException read_smps(instance("""
            STOCH         TOY
            SCENARIOS     DISCRETE
             SC S1        ROOT      0.5            PERIOD1
                RHS       DEM1      5.0
             SC S2        S1        0.5            PERIOD1
                RHS       DEM1      7.0
            ENDATA
            """))
    end

    @testset "Continuous laws" begin
        smps = read_smps(instance("""
            STOCH         TOY
            INDEP         NORMAL
                RHS       DEM1      5.0                      4.0
            INDEP         UNIFORM
                RHS       DEM2      1.0            PERIOD2   3.0
            INDEP         GAMMA
                Y1        COST      2.0            PERIOD2   3.0
            INDEP         BETA
                Y2        COST      2.0            PERIOD2   5.0
            INDEP         LOGNORM   ADD
                X1        DEM1      0.0            PERIOD2   0.25
            ENDATA
            """))
        laws = [c[2] for c in smps.law.continuous]
        @test laws[1] == Normal(5.0, 2.0) && laws[2] == Uniform(1.0, 3.0)
        @test laws[3] == Gamma(3.0, 2.0) && laws[4] == Beta(2.0, 5.0)    # scale 2, shape 3
        @test laws[5] == LogNormal(0.0, 0.5) && smps.law.continuous[5][3] === :add
        @test_throws ErrorException support_size(smps.law)
        @test_throws ErrorException enumerate_scenarios(smps.law)
        draws = rand(Xoshiro(1), smps.law, 20_000)
        @test isapprox(mean(d[1] for d in draws), 5.0; atol = 0.1)
        @test isapprox(var(d[1] for d in draws), 4.0; atol = 0.2)
        @test all(1.0 <= d[2] <= 3.0 for d in draws)
        @test isapprox(mean(d[3] for d in draws), 6.0; atol = 0.1)
        @test all(d[5] > 1.0 for d in draws)          # 1 + a lognormal draw
        @test same_problem(smps, round_trip(smps))
    end

    @testset "Probabilities rounded to the digits written" begin
        sixths = "STOCH         TOY\nINDEP         DISCRETE\n" *
                 join(("    RHS       DEM1      $(k).0            PERIOD2   0.16667\n" for k in 1:6)) *
                 "ENDATA\n"
        smps = @test_logs (:warn, r"normalized") read_smps(instance(sixths))
        @test smps.law.probabilities[1] ≈ fill(1 / 6, 6)
        wrong = "STOCH         TOY\nINDEP         DISCRETE\n" *
                "    RHS       DEM1      1.0            PERIOD2   0.33\n" *
                "    RHS       DEM1      2.0            PERIOD2   0.33\n" *
                "    RHS       DEM1      3.0            PERIOD2   0.30\nENDATA\n"
        @test_throws ErrorException read_smps(instance(wrong))
        smps = @test_logs (:warn, r"normalized") read_smps(instance(wrong); probability_sums = :normalize)
        @test sum(smps.law.probabilities[1]) ≈ 1
        smps = @test_logs (:warn, r"kept as written") read_smps(instance(wrong); probability_sums = :as_written)
        @test sum(enumerate_scenarios(smps.law).p) ≈ 0.96
    end

    @testset "Names that differ, a maximization" begin
        stoch = "STOCH         OTHER\nINDEP         DISCRETE\n" *
                "    RHS       DEM1      4.0            PERIOD2   1.0\nENDATA\n"
        @test_logs (:warn, r"name different problems") read_smps(instance(stoch))
        core = replace(TOY_CORE, "ROWS\n" => "OBJSENSE\n    MAX\nROWS\n")
        smps = read_smps(instance(replace(stoch, "OTHER" => "TOY"); core = core))
        @test smps.sense === :max && smps.c == [-2.0, -3.0] && isequal(smps.q, [-5.0, -6.0, 0.0])
        @test read_smps(instance(replace(stoch, "OTHER" => "TOY"); core = core); sense = :min).c == [2.0, 3.0]
        @test same_problem(smps, round_trip(smps))
    end

    @testset "Refused" begin
        for stoch in ("NODES\n", "BLOCKS        MVNORMAL\n", "INDEP         DISCRETE\n    X1        COST      1.0            PERIOD2   1.0\n",
                      "INDEP         DISCRETE\n    RHS       CAP       1.0            PERIOD2   1.0\n",
                      "INDEP         DISCRETE\n    Y1        DEM2      1.0            PERIOD2   1.0\n",
                      "INDEP         DISCRETE\n    RNG       BAL       1.0            PERIOD2   1.0\n")
            @test_throws ErrorException read_smps(instance("STOCH         TOY\n" * stoch * "ENDATA\n"))
        end
    end

    @testset "A tree in three periods: shared nodes, values inherited" begin
        stoch = """
            STOCH         TOY
            SCENARIOS     DISCRETE                REPLACE
             SC A         ROOT      0.5            PERIOD2
                RHS       DEM1      5.0
             SC B         A         0.25           PERIOD3
                RHS       BAL       9.0
                Y3        COST      7.0
             SC C         ROOT      0.25           PERIOD2
                RHS       DEM1      6.0            DEM2      2.0
            ENDATA
            """
        tree = read_smps(instance(stoch; time = THREE))
        @test tree isa SMPSTree
        @test tree.periods == ["PERIOD1", "PERIOD2", "PERIOD3"]
        @test tree.colperiod == [1, 1, 2, 2, 3] && tree.rowperiod == [1, 2, 2, 3]
        @test tree.nodeperiod == [1, 2, 3, 3, 2, 3] && tree.parent == [0, 1, 2, 2, 1, 5]
        @test tree.scenarios == [[1, 2, 3], [1, 2, 4], [1, 5, 6]]
        @test tree.probability ≈ [1.0, 0.75, 0.5, 0.25, 0.25, 0.25]
        @test bundles(tree, 1) == [[1, 2, 3]] && bundles(tree, 2) == [[1, 2], [3]]
        @test bundles(tree, 3) == [[1], [2], [3]]
        # B shares A's node in the second period, so A's demand; its own balance and cost after
        b = scenario_data(tree, 2)
        @test b.rhs == [10.0, 5.0, 3.0, 9.0] && b.c == [2.0, 3.0, 5.0, 6.0, 7.0]
        a = scenario_data(tree, 1)
        @test a.rhs == [10.0, 5.0, 3.0, 8.0] && a.c == tree.c
        @test scenario_data(tree, 3).rhs == [10.0, 6.0, 2.0, 8.0]
        model, x = extensive_form(tree)
        @test length(x) == 6 && length.(x) == [2, 2, 1, 1, 2, 1]
        @test num_constraints(model, AffExpr, MOI.Interval{Float64}) == 3   # BAL, at each leaf
        @test all(is_integer(x[n][1]) for n in (3, 4, 6))                  # Y3
        # without a scenario: the core problem alone
        single = read_smps(instance("STOCH         TOY\nENDATA\n"; time = THREE))
        @test single.scenarios == [[1, 2, 3]] && single.probability == [1.0, 1.0, 1.0]
        # a maximization: the costs stored negated, the model a maximization
        maxi = read_smps(instance(stoch; time = THREE); sense = :max)
        @test maxi.c == -tree.c
        @test Set(maxi.values[4]) == Set(e => (tree.elements[e][1] === :c ? -v : v) for (e, v) in tree.values[4])
        @test objective_sense(first(extensive_form(maxi))) == MOI.MAX_SENSE
    end

    @testset "A tree: one scenario from ROOT in the first period" begin
        stoch = """
            STOCH         TOY
            SCENARIOS     DISCRETE                REPLACE
             SC A         ROOT      0.5            PERIOD1
                X1        COST      4.0
             SC B         A         0.5            PERIOD2
                RHS       DEM1      6.0
            ENDATA
            """
        tree = read_smps(instance(stoch; time = THREE))
        @test tree.scenarios == [[1, 2, 3], [1, 4, 5]] && tree.probability ≈ [1.0, 0.5, 0.5, 0.5, 0.5]
        @test all(scenario_data(tree, s).c[1] == 4.0 for s in 1:2)        # the first period's data
        @test scenario_data(tree, 2).rhs[2] == 6.0
    end

    @testset "A tree: refused" begin
        bad = ("SC A         ROOT      0.5            PERIOD1\n SC C         ROOT      0.5            PERIOD2\n",
               "SC A         ROOT      1.0            PERIOD3\n    RHS       DEM1      5.0\n",
               "SC B         A         1.0            PERIOD2\n",
               "SC A         ROOT      1.0\n",
               "SC A         ROOT      1.0            PERIOD9\n",
               "SC A         ROOT      1.0            PERIOD2\n UP BND       Y1        5.0\n",
               "SC A         ROOT      1.0            PERIOD2\n    RNG       BAL       1.0\n",
               "SC A         ROOT      1.0            PERIOD2\n    Y2        DEM1      1.0\n")
        for scenarios in bad
            stoch = "STOCH         TOY\nSCENARIOS     DISCRETE\n " * scenarios * "ENDATA\n"
            @test_throws ErrorException read_smps(instance(stoch; time = THREE))
        end
        @test_throws ErrorException read_smps(instance(
            "STOCH         TOY\nINDEP         DISCRETE\n    RHS       DEM1      1.0            PERIOD2   1.0\nENDATA\n";
            time = THREE))
        @test_throws ErrorException read_smps(instance(
            "STOCH         TOY\nSCENARIOS     DISCRETE                ADD\n SC A         ROOT      1.0            PERIOD2\nENDATA\n";
            time = THREE))
    end

    @testset "KandW3R: three periods, nine scenarios" begin
        tree = read_smps(joinpath(DATA, "KandW3R"))
        @test [count(==(t), tree.nodeperiod) for t in 1:3] == [1, 3, 9]
        @test bundles(tree, 2) == [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
        @test tree.probability[tree.scenarios[1][2]] ≈ 0.30 && sum(tree.scenarioprobability) ≈ 1
        model, _ = extensive_form(tree; optimizer = HiGHS.Optimizer)
        set_silent(model)
        optimize!(model)
        @test termination_status(model) == MOI.OPTIMAL
        @test objective_value(model) ≈ 2613.0                     # Zehtabian and Bastin (2016)
    end

    @testset "app0110R: NAME as first section, probabilities as written" begin
        # the probabilities sum up to 0.999, within the rounding of their three decimals
        tree = @test_logs (:warn, r"normalized") read_smps(joinpath(DATA, "app0110R"))
        written = @test_logs (:warn, r"kept as written") read_smps(joinpath(DATA, "app0110R");
                                                                   probability_sums = :as_written)
        @test written.probability[1] ≈ 0.999 && tree.probability[1] ≈ 1.0
        values = map((tree, written)) do t
            model, _ = extensive_form(t; optimizer = HiGHS.Optimizer)
            set_silent(model)
            optimize!(model)
            objective_value(model)
        end
        @test values[1] ≈ 42.0 && values[2] ≈ 41.958             # the second as published
    end

    @testset "wat_10_C_32: ten periods" begin
        tree = read_smps(joinpath(DATA, "wat_10_C_32"))
        @test [count(==(t), tree.nodeperiod) for t in 1:10] == [1, 2, 4, 8, 16, 32, 32, 32, 32, 32]
        model, _ = extensive_form(tree; optimizer = HiGHS.Optimizer)
        set_silent(model)
        optimize!(model)
        @test isapprox(objective_value(model), -2611.92; atol = 0.005)   # Zehtabian and Bastin (2016)
    end

    @testset "LandS" begin
        for stoch in ("lands.sto", "lands-blocks.sto")
            smps = read_smps(joinpath(DATA, "lands.cor"), joinpath(DATA, "lands.tim"), joinpath(DATA, stoch))
            @test support_size(smps.law) == 3
            (; ξ, p) = enumerate_scenarios(smps.law)
            model, x, y = extensive_form(smps, ξ, p; optimizer = HiGHS.Optimizer)
            set_silent(model)
            optimize!(model)
            @test termination_status(model) == MOI.OPTIMAL
            @test isapprox(objective_value(model), 381.853333; rtol = 1e-6)
            @test same_problem(smps, round_trip(smps))
            # the scenarios written instead of the law
            written = round_trip(smps; scenarios = (; ξ, p))
            @test scenario_set(written) == scenario_set(smps)
        end
    end

    @testset "The extensive form: ranges, a maximization" begin
        smps = read_smps(instance("STOCH         TOY\nINDEP         DISCRETE\n" *
                                  "    RHS       DEM1      4.0            PERIOD2   0.5\n" *
                                  "    RHS       DEM1      6.0            PERIOD2   0.5\nENDATA\n"))
        model, _, y = extensive_form(smps, enumerate_scenarios(smps.law)...)
        @test num_constraints(model, AffExpr, MOI.Interval{Float64}) == 2   # BAL, in each scenario
        @test all(is_integer(y[s][3]) for s in 1:2)
        maxi = """
            NAME          MAXI
            OBJSENSE
                MAX
            ROWS
             N  PROFIT
             L  CAP
             L  SELL
            COLUMNS
                X         PROFIT    -1.0           CAP       1.0
                X         SELL      -1.0
                Y         PROFIT    3.0            SELL      1.0
            RHS
                RHS       CAP       5.0
            ENDATA
            """
        time = "TIME          MAXI\nPERIODS\n    X         CAP                      P1\n" *
               "    Y         SELL                     P2\nENDATA\n"
        stoch = "STOCH         MAXI\nINDEP         DISCRETE\n    Y         PROFIT    2.0            P2        0.5\n" *
                "    Y         PROFIT    4.0            P2        0.5\nENDATA\n"
        smps = read_smps(instance(stoch; core = maxi, time = time))
        model, x, _ = extensive_form(smps, enumerate_scenarios(smps.law)...; optimizer = HiGHS.Optimizer)
        set_silent(model)
        optimize!(model)
        @test objective_sense(model) == MOI.MAX_SENSE
        @test objective_value(model) ≈ 10.0 && value(x[1]) ≈ 5.0
    end
end
