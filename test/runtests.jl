using SMPSFormat
using Aqua
using CodecZlib: GzipCompressor, GzipDecompressor
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

"""Whether the trees `a` and `b` are the same: the same nodes, and in each scenario the same data,
the columns and rows matched by name (the core files may order them differently)."""
function same_tree(a::SMPSTree, b::SMPSTree)
    a.nodeperiod == b.nodeperiod && a.parent == b.parent && a.scenarios == b.scenarios || return false
    a.probability ≈ b.probability && a.sense == b.sense && a.periods == b.periods || return false
    Set(a.columns) == Set(b.columns) && Set(a.rows) == Set(b.rows) || return false
    J = [findfirst(==(c), b.columns) for c in a.columns]
    I = [findfirst(==(r), b.rows) for r in a.rows]
    a.colperiod == b.colperiod[J] && a.rowperiod == b.rowperiod[I] || return false
    return all(eachindex(a.scenarios)) do s
        x, y = scenario_data(a, s), scenario_data(b, s)
        x.c == y.c[J] && x.rhs == y.rhs[I] && x.lb == y.lb[J] && x.ub == y.ub[J] && x.A == y.A[I, J]
    end
end

function tree_round_trip(tree; kwargs...)
    prefix = joinpath(mktempdir(), "written")
    write_smps(prefix, tree)
    return read_smps(prefix; kwargs...)
end

"""The scenarios of a law by period: the data of each scenario of its tree, by name, and its
probability."""
function stagewise_scenarios(s)
    tree = scenario_tree(s)
    J, I = sortperm(tree.columns), sortperm(tree.rows)
    return Set(begin
                   d = scenario_data(tree, k)
                   (d.c[J], d.rhs[I], d.lb[J], d.ub[J], Matrix(d.A[I, J]), round(p; digits = 12))
               end for (k, p) in enumerate(tree.scenarioprobability))
end

function stagewise_round_trip(s; kwargs...)
    prefix = joinpath(mktempdir(), "written")
    write_smps(prefix, s)
    return read_smps(prefix; kwargs...)
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
               "SC A         ROOT      1.0            PERIOD2\n FR BND       Y1\n",
               "SC A         ROOT      1.0            PERIOD3\n UP BND       Y1        5.0\n",
               "SC A         ROOT      1.0            PERIOD2\n    RNG       BAL       1.0\n",
               "SC A         ROOT      1.0            PERIOD2\n    Y2        DEM1      1.0\n")
        for scenarios in bad
            stoch = "STOCH         TOY\nSCENARIOS     DISCRETE\n " * scenarios * "ENDATA\n"
            @test_throws ErrorException read_smps(instance(stoch; time = THREE))
        end
        @test read_smps(instance(       # INDEP in three periods: a law by period
            "STOCH         TOY\nINDEP         DISCRETE\n    RHS       DEM1      1.0            PERIOD2   1.0\nENDATA\n";
            time = THREE)) isa SMPSStagewise
        @test_throws ErrorException read_smps(instance(
            "STOCH         TOY\nSCENARIOS     DISCRETE                ADD\n SC A         ROOT      1.0            PERIOD2\nENDATA\n";
            time = THREE))
    end

    @testset "The core file: several vectors, OBJNAME, comments with a hash" begin
        several = replace(TOY_CORE,
            "    RHS       DEM2      3.0            BAL       8.0\n" =>
            "    RHS       DEM2      3.0            BAL       8.0\n    RHS2      CAP       99.0\n",
            "    RNG       BAL       -2.0\n" => "    RNG       BAL       -2.0\n    RNG2      BAL       -5.0\n",
            " UP BND       X1        8.0\n" => " UP BND       X1        8.0\n UP BND2      X1        3.0\n")
        smps = @test_logs (:warn, r"several RHS vectors") (:warn, r"several RANGES vectors") (:warn,
                          r"several BOUNDS vectors") read_smps(instance("STOCH         TOY\nENDATA\n"; core = several))
        @test smps.b == [10.0] && smps.h == [4.0, 3.0, 8.0]            # RHS2 left out
        @test smps.ranges2[3] == -2.0 && smps.ub1[1] == 8.0               # RNG2 and BND2 too
        alternative = replace(TOY_CORE, "ROWS\n N  COST\n" => "OBJNAME\n    ALT\nROWS\n N  COST\n N  ALT\n",
                              "    X1        COST      2.0" => "    X1        ALT       7.0\n    X1        COST      2.0")
        smps = read_smps(instance("STOCH         TOY\nENDATA\n"; core = alternative))
        @test smps.objective == "ALT" && smps.c == [7.0, 0.0] && smps.q == zeros(3)
        sameline = replace(alternative, "OBJNAME\n    ALT\n" => "OBJNAME       ALT\n")
        @test read_smps(instance("STOCH         TOY\nENDATA\n"; core = sameline)).objective == "ALT"
        missing = replace(alternative, "OBJNAME\n    ALT\n" => "OBJNAME\n    NONE\n")
        @test_throws ErrorException read_smps(instance("STOCH         TOY\nENDATA\n"; core = missing))
        hashed = replace(TOY_CORE, "COLUMNS\n" => "COLUMNS\n# a comment, as CoinMpsIO reads them\n")
        @test read_smps(instance("STOCH         TOY\nENDATA\n"; core = hashed)).c == [2.0, 3.0]
    end

    @testset "Random bounds in two stages" begin
        stoch = """
            STOCH         TOY
            SCENARIOS     DISCRETE
             SC S1        ROOT      0.5            PERIOD2
             UP BND       Y1        2.0
             SC S2        ROOT      0.5            PERIOD2
             FX BND       Y2        4.0
            ENDATA
            """
        smps = read_smps(instance(stoch))
        @test smps.elements == [(:ub, 1, 0), (:lb, 2, 0), (:ub, 2, 0)]
        @test smps.names == [("UP", "Y1"), ("LO", "Y2"), ("UP", "Y2")]
        (; ξ, p) = enumerate_scenarios(smps.law)
        @test second_stage(smps, ξ[1]).ub == [2.0, Inf, Inf]
        @test second_stage(smps, ξ[2]).lb == [0.0, 4.0, 0.0] && second_stage(smps, ξ[2]).ub[2] == 4.0
        model, _, y = extensive_form(smps, ξ, p)
        @test upper_bound(y[1][1]) == 2.0 && !has_upper_bound(y[2][1])
        @test lower_bound(y[2][2]) == 4.0 && upper_bound(y[2][2]) == 4.0
        @test same_problem(smps, round_trip(smps))                      # written in a BLOCKS section
        @test scenario_set(round_trip(smps; scenarios = (; ξ, p))) == scenario_set(smps)
        for bad in (" UP BND       X1        5.0\n", " FR BND       Y1\n")   # first stage; no value
            @test_throws ErrorException read_smps(instance(
                "STOCH         TOY\nSCENARIOS     DISCRETE\n SC S1        ROOT      1.0            PERIOD2\n" *
                bad * "ENDATA\n"))
        end
        @test_throws ErrorException read_smps(instance(
            "STOCH         TOY\nINDEP         DISCRETE\n UP BND       Y1        2.0            PERIOD2   1.0\nENDATA\n"))
    end

    @testset "Random bounds in a tree" begin
        stoch = """
            STOCH         TOY
            SCENARIOS     DISCRETE                REPLACE
             SC A         ROOT      0.5            PERIOD2
             UP BND       Y1        1.5
             SC B         A         0.5            PERIOD3
             LO BND       Y3        2.0
            ENDATA
            """
        tree = read_smps(instance(stoch; time = THREE))
        @test tree.elements == [(:ub, 3, 0), (:lb, 5, 0)] && tree.elementperiod == [2, 3]
        a, b = scenario_data(tree, 1), scenario_data(tree, 2)
        @test a.ub[3] == 1.5 && a.lb[5] == 0.0                          # B shares A's node in period 2
        @test b.ub[3] == 1.5 && b.lb[5] == 2.0
        model, x = extensive_form(tree)
        @test upper_bound(x[2][1]) == 1.5 && lower_bound(x[3][1]) == 0.0 && lower_bound(x[4][1]) == 2.0
    end

    @testset "A law by period: INDEP in three periods" begin
        stoch = """
            STOCH         TOY
            INDEP         DISCRETE
                RHS       DEM1      4.0            PERIOD2   0.5
                RHS       DEM1      6.0            PERIOD2   0.5
                RHS       DEM2      2.0            PERIOD2   0.5
                RHS       DEM2      3.0            PERIOD2   0.5
                RHS       BAL       8.0            PERIOD3   0.25
                RHS       BAL       9.0            PERIOD3   0.75
            ENDATA
            """
        s = read_smps(instance(stoch; time = THREE))
        @test s isa SMPSStagewise && support_size(s) == 8
        @test s.elementperiod == [2, 2, 3] && s.revealperiod == [2, 2, 3]
        @test s.lawelements == [Int[], [1, 2], [3]] && support_size(s.laws[2]) == 4
        tree = scenario_tree(s)
        @test [count(==(t), tree.nodeperiod) for t in 1:3] == [1, 4, 8]
        @test all(tree.probability[tree.nodeperiod .== 2] .≈ 0.25)
        @test sort(tree.scenarioprobability) ≈ sort(repeat([0.0625, 0.1875], 4))
        @test sum(tree.scenarioprobability) ≈ 1 && length.(bundles(tree, 2)) == fill(2, 4)
        # each scenario's data: a demand pair of period 2, a balance of period 3
        data = [scenario_data(tree, k).rhs for k in eachindex(tree.scenarios)]
        @test Set((d[2], d[3], d[4]) for d in data) ==
              Set((a, b, c) for a in (4.0, 6.0), b in (2.0, 3.0), c in (8.0, 9.0))
        @test_throws ErrorException scenario_tree(s; limit = 7)
        # the data of a draw
        ξ = rand(MersenneTwister(1), s)
        @test length(ξ) == 3 && scenario_data(s, ξ).rhs[2:4] == ξ
        # a balance of period 3 known in period 2: the same for the children of a node
        early = read_smps(instance("STOCH         TOY\nINDEP         DISCRETE\n" *
                                   "    RHS       BAL       8.0            PERIOD2   0.5\n" *
                                   "    RHS       BAL       9.0            PERIOD2   0.5\nENDATA\n"; time = THREE))
        @test early.elementperiod == [3] && early.revealperiod == [2]
        t = scenario_tree(early)
        @test t.nodeperiod == [1, 2, 3, 2, 3] && sort([scenario_data(t, k).rhs[4] for k in 1:2]) == [8.0, 9.0]
        # refused: revealed after its period, in the first period, in an unknown one; mixed with SCENARIOS
        for line in ("    RHS       DEM1      4.0            PERIOD3   1.0\n",
                     "    RHS       DEM1      4.0            PERIOD1   1.0\n",
                     "    RHS       DEM1      4.0            PERIOD7   1.0\n")
            @test_throws ErrorException read_smps(instance("STOCH         TOY\nINDEP         DISCRETE\n" *
                                                           line * "ENDATA\n"; time = THREE))
        end
        @test_throws ErrorException read_smps(instance(
            "STOCH         TOY\nINDEP         DISCRETE\n    RHS       DEM1      4.0            PERIOD2   1.0\n" *
            "SCENARIOS     DISCRETE\n SC A         ROOT      1.0            PERIOD2\nENDATA\n"; time = THREE))
    end

    @testset "A law by period: BLOCKS, sampled trees, continuous laws" begin
        stoch = """
            STOCH         TOY
            BLOCKS        DISCRETE
             BL B1        PERIOD2   0.5
                RHS       DEM1      5.0            DEM2      4.0
             BL B1        PERIOD2   0.5
                RHS       DEM1      7.0
             BL B2        PERIOD3   0.4
                RHS       BAL       9.0
             BL B2        PERIOD3   0.6
                RHS       BAL       7.0
            ENDATA
            """
        s = read_smps(instance(stoch; time = THREE))
        tree = scenario_tree(s)
        @test length(tree.scenarios) == 4
        # the second realization of B1 keeps the first's DEM2
        @test Set((d.rhs[2], d.rhs[3]) for d in scenario_data.(Ref(tree), 1:4)) == Set([(5.0, 4.0), (7.0, 4.0)])
        # sampled: each node draws its own children, or all share the draws of their period
        sampled = sample_tree(MersenneTwister(2), s, [3, 2])
        @test [count(==(t), sampled.nodeperiod) for t in 1:3] == [1, 3, 6]
        @test sampled.probability[end] ≈ 1 / 6 && sum(sampled.scenarioprobability) ≈ 1
        @test sample_tree(MersenneTwister(2), s, 2).values == sample_tree(MersenneTwister(2), s, 2).values
        common = sample_tree(MersenneTwister(3), s, [2, 5]; common = true)
        leaves(n) = [common.values[m] for m in eachindex(common.parent) if common.parent[m] == n]
        a, b = findall(==(2), common.nodeperiod)
        @test leaves(a) == leaves(b)                                     # the same draws in period 3
        # a period without random data: one child per node
        only2 = read_smps(instance("STOCH         TOY\nINDEP         DISCRETE\n" *
                                   "    RHS       DEM1      4.0            PERIOD2   0.5\n" *
                                   "    RHS       DEM1      6.0            PERIOD2   0.5\nENDATA\n"; time = THREE))
        @test [count(==(t), sample_tree(only2, [2, 5]).nodeperiod) for t in 1:3] == [1, 2, 2]
        # a continuous law: sampled, not enumerated
        normal = read_smps(instance("STOCH         TOY\nINDEP         NORMAL\n" *
                                    "    RHS       DEM1      5.0            PERIOD2   1.0\nENDATA\n"; time = THREE))
        @test_throws ErrorException scenario_tree(normal)
        @test length(sample_tree(MersenneTwister(4), normal, 10).scenarios) == 10
    end

    @testset "POSTS in three periods: pltexpA3_6 (BLOCKS), fxm3_6 (INDEP)" begin
        plt = read_smps(joinpath(DATA, "pltexpa-3.cor"), joinpath(DATA, "pltexpa-3.tim"),
                        joinpath(DATA, "pltexpa-3-6.sto"))
        model, _ = extensive_form(scenario_tree(plt); optimizer = HiGHS.Optimizer)
        set_silent(model)
        optimize!(model)
        @test isapprox(objective_value(model), -13.969368; atol = 1e-6)   # Post_Results
        fxm = @test_logs (:warn, r"kept as written") (:warn, r"kept as written") read_smps(
            joinpath(DATA, "fxm.cor"), joinpath(DATA, "fxm-3.tim"), joinpath(DATA, "fxm-3-6.sto");
            probability_sums = :as_written)
        tree = scenario_tree(fxm)
        @test length(tree.scenarios) == 36 && fxm.elementperiod == [2, 3]
        model, _ = extensive_form(tree; optimizer = HiGHS.Optimizer)
        set_silent(model)
        optimize!(model)
        # Post_Results gives 18615.932: 0.104 less, as for fxm2.16, read in two stages
        @test isapprox(objective_value(model), 18616.036; atol = 1e-3)
    end

    @testset "Two-stage problems as trees" begin
        smps = read_smps(joinpath(DATA, "lands.cor"), joinpath(DATA, "lands.tim"), joinpath(DATA, "lands.sto"))
        tree = scenario_tree(smps)
        @test tree isa SMPSTree && tree.periods == ["PERIOD1", "PERIOD2"]
        @test tree.nodeperiod == [1, 2, 2, 2] && bundles(tree, 2) == [[1], [2], [3]]
        model, _ = extensive_form(tree; optimizer = HiGHS.Optimizer)
        set_silent(model)
        optimize!(model)
        @test isapprox(objective_value(model), 381.853333; rtol = 1e-6)
        (; ξ, p) = enumerate_scenarios(smps.law)
        @test scenario_tree(smps, ξ, p).values == tree.values
        # the data of a scenario: the first stage, then the second
        d = scenario_data(tree, 2)
        stage2 = second_stage(smps, ξ[2])
        @test d.rhs == [smps.b; stage2.h] && d.c == [smps.c; stage2.q]
        @test d.A == [smps.A spzeros(length(smps.b), length(smps.q)); stage2.T stage2.W]
        sampled = sample_tree(MersenneTwister(1), smps, 5)
        @test length(sampled.scenarios) == 5 && all(sampled.scenarioprobability .≈ 0.2)
        # written as a tree in two periods, read back as a two-stage problem
        prefix = joinpath(mktempdir(), "tree")
        write_smps(prefix, tree)
        back = read_smps(prefix)
        @test back isa SMPSProblem && scenario_set(back) == scenario_set(smps)
    end

    @testset "Writing trees" begin
        for name in ("KandW3R", "wat_10_C_32")
            tree = read_smps(joinpath(DATA, name))
            @test same_tree(tree, tree_round_trip(tree))
        end
        # random bounds and costs, data of the root, a maximization
        stoch = """
            STOCH         TOY
            SCENARIOS     DISCRETE                REPLACE
             SC A         ROOT      0.5            PERIOD1
                X1        COST      4.0
             UP BND       Y1        1.5
             SC B         A         0.25           PERIOD2
                RHS       DEM1      6.0
             SC C         B         0.25           PERIOD3
             LO BND       Y3        2.0
                Y3        COST      7.0
            ENDATA
            """
        tree = read_smps(instance(stoch; time = THREE))
        @test same_tree(tree, tree_round_trip(tree))
        maxi = read_smps(instance(stoch; time = THREE); sense = :max)
        back = tree_round_trip(maxi)
        @test back.sense === :max && same_tree(maxi, back)
        # a core file out of the order of the periods (an explicit time file): written in order
        explicit = """
            TIME          TOY
            PERIODS       EXPLICIT
                PERIOD1
                PERIOD2
                PERIOD3
            COLUMNS
                X1        PERIOD1
                X2        PERIOD1
                Y1        PERIOD3
                Y2        PERIOD2
                Y3        PERIOD3
            ROWS
                CAP       PERIOD1
                DEM1      PERIOD3
                DEM2      PERIOD2
                BAL       PERIOD3
            ENDATA
            """
        stoch = "STOCH         TOY\nSCENARIOS     DISCRETE\n SC A         ROOT      0.5            PERIOD2\n" *
                "    RHS       DEM2      2.0\n SC B         A         0.5            PERIOD3\n" *
                "    RHS       DEM1      6.0\nENDATA\n"
        tree = read_smps(instance(stoch; time = explicit))
        back = tree_round_trip(tree)
        @test back.columns == ["X1", "X2", "Y2", "Y1", "Y3"] && same_tree(tree, back)
        # a tree built from a law by period, written as a tree
        plt = read_smps(joinpath(DATA, "pltexpa-3.cor"), joinpath(DATA, "pltexpa-3.tim"),
                        joinpath(DATA, "pltexpa-3-6.sto"))
        tree = scenario_tree(plt)
        @test same_tree(tree, tree_round_trip(tree))
    end

    @testset "Writing laws by period" begin
        stoch = """
            STOCH         TOY
            INDEP         DISCRETE
                RHS       DEM1      4.0            PERIOD2   0.5
                RHS       DEM1      6.0            PERIOD2   0.5
                RHS       BAL       8.0            PERIOD2   0.25
                RHS       BAL       9.0            PERIOD2   0.75
                Y3        COST      2.0            PERIOD3   0.5
                Y3        COST      3.0            PERIOD3   0.5
            BLOCKS        DISCRETE
             BL B1        PERIOD3   0.4
             LO BND       Y3        1.0
                Y1        BAL       2.0
             BL B1        PERIOD3   0.6
             LO BND       Y3        2.0
            ENDATA
            """
        s = read_smps(instance(stoch; time = THREE))
        back = stagewise_round_trip(s)
        @test back isa SMPSStagewise && support_size(back) == support_size(s) == 16
        @test Dict(zip(back.names, back.revealperiod)) == Dict(zip(s.names, s.revealperiod))
        @test stagewise_scenarios(back) == stagewise_scenarios(s)
        maxi = read_smps(instance(stoch; time = THREE); sense = :max)
        @test stagewise_scenarios(stagewise_round_trip(maxi)) == stagewise_scenarios(maxi)
        # continuous laws keep their distribution and modifier
        normal = read_smps(instance("STOCH         TOY\nINDEP         NORMAL                  ADD\n" *
                                    "    RHS       DEM1      1.0            PERIOD2   4.0\n" *
                                    "    RHS       BAL       0.0            PERIOD3   1.0\nENDATA\n"; time = THREE))
        back = stagewise_round_trip(normal)
        @test [(t, c[2], c[3]) for t in 2:3 for c in back.laws[t].continuous] ==
              [(t, c[2], c[3]) for t in 2:3 for c in normal.laws[t].continuous]
        # POSTS
        plt = read_smps(joinpath(DATA, "pltexpa-3.cor"), joinpath(DATA, "pltexpa-3.tim"),
                        joinpath(DATA, "pltexpa-3-6.sto"))
        @test stagewise_scenarios(stagewise_round_trip(plt)) == stagewise_scenarios(plt)
        fxm = @test_logs (:warn,) (:warn,) read_smps(joinpath(DATA, "fxm.cor"), joinpath(DATA, "fxm-3.tim"),
                                                    joinpath(DATA, "fxm-3-6.sto"); probability_sums = :as_written)
        back = @test_logs (:warn,) (:warn,) stagewise_round_trip(fxm; probability_sums = :as_written)
        @test stagewise_scenarios(back) == stagewise_scenarios(fxm)
    end

    @testset "Errors name the file and the line" begin
        message(f) = try f(); "" catch e; sprint(showerror, e) end
        # line 5 of the stoch file: a row the core file does not have
        stoch = "STOCH         TOY\nINDEP         DISCRETE\n    RHS       DEM1      4.0            PERIOD2   0.5\n" *
                "* a comment\n    RHS       NONE      6.0            PERIOD2   0.5\nENDATA\n"
        @test occursin(r"toy\.sto:5: unknown row NONE", message(() -> read_smps(instance(stoch))))
        # line 14 of the core file (after two comments and a blank line): an unknown row in a column
        core = replace(TOY_CORE, "    X2        COST      3.0" => "    X2        NONE      3.0")
        @test occursin(r"toy\.cor:14: unknown row NONE", message(() ->
            read_smps(instance("STOCH         TOY\nENDATA\n"; core = core))))
        # line 4 of the time file: the first column of the second period unknown
        time = replace(TOY_TIME, "    Y1        DEM1" => "    NONE      DEM1")
        @test occursin(r"toy\.tim:4: unknown column NONE", message(() ->
            read_smps(instance("STOCH         TOY\nENDATA\n"; time = time))))
        # a tree: line 4, data of a period before the scenario branches
        tree = "STOCH         TOY\nSCENARIOS     DISCRETE\n SC A         ROOT      1.0            PERIOD3\n" *
               "    RHS       DEM1      5.0\nENDATA\n"
        @test occursin(r"toy\.sto:4: scenario A branches", message(() -> read_smps(instance(tree; time = THREE))))
    end

    @testset "Files read through gzip" begin
        prefix = instance("STOCH         TOY\nINDEP         DISCRETE\n" *
                          "    RHS       DEM1      4.0            PERIOD2   0.5\n" *
                          "    RHS       DEM1      6.0            PERIOD2   0.5\nENDATA\n")
        plain = read_smps(prefix)
        for ext in (".cor", ".tim", ".sto")                # all three compressed, the plain ones removed
            write(prefix * ext * ".gz", transcode(GzipCompressor, read(prefix * ext)))
            rm(prefix * ext)
        end
        @test same_problem(read_smps(prefix), plain)
        @test same_problem(read_smps(prefix * ".cor.gz", prefix * ".tim.gz", prefix * ".sto.gz"), plain)
        write(prefix * ".tim", transcode(GzipDecompressor, read(prefix * ".tim.gz")))   # some plain
        rm(prefix * ".tim.gz")
        @test same_problem(read_smps(prefix), plain)
    end

    @testset "Lines ending with a carriage return" begin
        # files written on Windows: each line ends with CR LF
        dir = mktempdir()
        for name in ("lands", "KandW3R"), ext in (".cor", ".tim", ".sto", ".time", ".stoch")
            file = joinpath(DATA, name * ext)
            isfile(file) && write(joinpath(dir, name * ext), replace(read(file, String), r"\r?\n" => "\r\n"))
        end
        lands = read_smps(joinpath(DATA, "lands"))
        @test same_problem(read_smps(joinpath(dir, "lands")), lands)
        tree = read_smps(joinpath(DATA, "KandW3R"))
        @test same_tree(read_smps(joinpath(dir, "KandW3R")), tree)
        @test same_tree(read_smps(joinpath(dir, "KandW3R"); format = :fixed), tree)
    end

    @testset "Fixed MPS: names with blanks" begin
        # the fields in the columns of fixed MPS: 2-3, 5-12, 15-22, 25-36, 40-47, 50-61
        line(f1, f2, f3 = "", f4 = "", f5 = "", f6 = "") =
            " " * rpad(f1, 2) * " " * rpad(f2, 8) * "  " * rpad(f3, 8) * "  " * lpad(f4, 12) * "   " *
            rpad(f5, 8) * "  " * lpad(f6, 12)
        core = join(["NAME          SPACES", "ROWS", " N  COST", " L  CAP A", " G  DEM 1", "COLUMNS",
                     line("", "X 1", "COST", "2.0", "CAP A", "1.0"), line("", "X 1", "DEM 1", "1.0"),
                     line("", "Y 2", "COST", "5.0", "DEM 1", "1.0"), "RHS",
                     line("", "RHS", "CAP A", "10.0"), "ENDATA"], "\n") * "\n"
        time = join(["TIME          SPACES", "PERIODS", line("", "X 1", "CAP A", "", "PERIOD1"),
                     line("", "Y 2", "DEM 1", "", "PERIOD2"), "ENDATA"], "\n") * "\n"
        stoch = join(["STOCH         SPACES", "INDEP         DISCRETE",
                      line("", "RHS", "DEM 1", "4.0", "PERIOD2", "0.5"),
                      line("", "RHS", "DEM 1", "6.0", "PERIOD2", "0.5"), "ENDATA"], "\n") * "\n"
        smps = read_smps(instance(stoch; core = core, time = time); format = :fixed)
        @test smps.columns1 == ["X 1"] && smps.columns2 == ["Y 2"] && smps.rows2 == ["DEM 1"]
        @test smps.names == [("RHS", "DEM 1")] && support_size(smps.law) == 2
        model, _, _ = extensive_form(smps, enumerate_scenarios(smps.law)...; optimizer = HiGHS.Optimizer)
        set_silent(model)
        optimize!(model)
        @test objective_value(model) ≈ 12.0                       # X 1 = 6, Y 2 = 0 or 2
        @test_throws ErrorException write_smps(joinpath(mktempdir(), "spaces"), smps)
        # SMI's files in fixed format: the period of an SC line starts in column 39
        tree = read_smps(joinpath(DATA, "KandW3R"); format = :fixed)
        @test same_tree(tree, read_smps(joinpath(DATA, "KandW3R")))
        @test_throws ErrorException read_smps(instance(stoch; core = core, time = time); format = :other)
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

    @testset "Code quality (Aqua)" begin
        Aqua.test_all(SMPSFormat)
    end
end
