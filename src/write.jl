# Writing an SMPS instance: the core, time and stoch files.

"""
    write_smps(prefix, smps::SMPSProblem; scenarios = nothing)

Write `smps` in the SMPS format to `prefix.cor`, `prefix.tim` and `prefix.sto`, and return their
paths. [`read_smps`](@ref) reads them back into the same problem.

- **The core file** is in free MPS format, the first stage before the second, so that the time
  file gives each period by its first column and row. A maximization is written as such, with
  an `OBJSENSE MAX` section.
- **The stoch file** gives the law of `smps`: its continuous elements and its discrete blocks of
  one element in `INDEP` sections, its other blocks in a `BLOCKS DISCRETE` section, each
  realization listing every element of its block. With `scenarios = (ξ = ..., p = ...)`, it lists
  those scenarios instead (`SCENARIOS DISCRETE`), each giving the values that differ from the
  core file: an instance whose scenarios were sampled, or generated.

The numbers are written in full, so that they are read back exactly.
"""
function write_smps(prefix::AbstractString, smps::SMPSProblem; scenarios = nothing)
    isempty(smps.columns2) && error("no second-stage variable: not a two-stage problem")
    isempty(smps.rows2) && error("no second-stage row: not a two-stage problem")
    paths = (prefix * ".cor", prefix * ".tim", prefix * ".sto")
    open(io -> write_core(io, smps), paths[1], "w")
    open(io -> write_time(io, smps), paths[2], "w")
    open(io -> write_stoch(io, smps, scenarios), paths[3], "w")
    return paths
end

num(v::Real) = string(Float64(v))
entry(io, a, b, v) = println(io, "    ", rpad(a, 10), "  ", rpad(b, 10), "  ", num(v))
problemname(smps) = isempty(smps.name) ? "SMPS" : smps.name

function write_core(io::IO, smps::SMPSProblem)
    sign = smps.sense === :max ? -1.0 : 1.0         # the costs as the file gives them
    println(io, "NAME          ", problemname(smps))
    smps.sense === :max && println(io, "OBJSENSE\n    MAX")
    println(io, "ROWS")
    println(io, " N  ", smps.objective)
    foreach((r, s) -> println(io, " ", s, "  ", r), smps.rows1, smps.senses1)
    foreach((r, s) -> println(io, " ", s, "  ", r), smps.rows2, smps.senses2)
    println(io, "COLUMNS")
    marked = false
    for (columns, costs, blocks, integer) in
            ((smps.columns1, smps.c, ((smps.A, smps.rows1), (smps.T, smps.rows2)), smps.integer1),
             (smps.columns2, smps.q, ((smps.W, smps.rows2),), smps.integer2))
        for (j, col) in enumerate(columns)
            if integer[j] != marked
                marked = integer[j]
                println(io, "    MARKER                 'MARKER'                 ",
                        marked ? "'INTORG'" : "'INTEND'")
            end
            written = false
            if costs[j] != 0
                entry(io, col, smps.objective, sign * costs[j])
                written = true
            end
            for (M, rows) in blocks, k in nzrange(M, j)
                entry(io, col, rows[rowvals(M)[k]], nonzeros(M)[k])
                written = true
            end
            written || entry(io, col, smps.objective, 0.0)  # a column must appear
        end
    end
    marked && println(io, "    MARKER                 'MARKER'                 'INTEND'")
    println(io, "RHS")
    constant = sign * smps.constant
    constant != 0 && entry(io, "RHS", smps.objective, -constant)  # MPS: the RHS of the objective is −constant
    for (rows, rhs) in ((smps.rows1, smps.b), (smps.rows2, smps.h)), (i, r) in enumerate(rows)
        rhs[i] != 0 && entry(io, "RHS", r, rhs[i])
    end
    if any(!isnan, smps.ranges1) || any(!isnan, smps.ranges2)
        println(io, "RANGES")
        for (rows, ranges) in ((smps.rows1, smps.ranges1), (smps.rows2, smps.ranges2)), (i, r) in enumerate(rows)
            isnan(ranges[i]) || entry(io, "RNG", r, ranges[i])
        end
    end
    println(io, "BOUNDS")
    for (columns, lower, upper) in ((smps.columns1, smps.lb1, smps.ub1), (smps.columns2, smps.lb, smps.ub)),
            (j, col) in enumerate(columns)
        lb, ub = lower[j], upper[j]
        bound(kind, v) = println(io, " ", rpad(kind, 3), rpad("BND", 10), "  ", rpad(col, 10), "  ", num(v))
        if lb == ub
            bound("FX", lb)
        elseif lb == -Inf && ub == Inf
            println(io, " FR BND         ", col)
        else
            if lb == -Inf
                println(io, " MI BND         ", col)
            elseif lb != 0 || ub < 0                 # MPS: a negative upper bound alone frees x
                bound("LO", lb)
            end
            ub == Inf || bound("UP", ub)
        end
    end
    println(io, "ENDATA")
end

function write_time(io::IO, smps::SMPSProblem)
    println(io, "TIME          ", problemname(smps))
    println(io, "PERIODS")
    first1 = isempty(smps.columns1) ? smps.columns2[1] : smps.columns1[1]
    println(io, "    ", rpad(first1, 10), "  ", rpad(isempty(smps.rows1) ? smps.objective : smps.rows1[1], 10),
            "  PERIOD1")
    println(io, "    ", rpad(smps.columns2[1], 10), "  ", rpad(smps.rows2[1], 10), "  PERIOD2")
    println(io, "ENDATA")
end

"""The column and row names of the random element `e` as the core file written gives them."""
function element_names(smps::SMPSProblem, e::Integer)
    kind, i, j = smps.elements[e]
    kind in (:lb, :ub) && return (kind === :lb ? "LO" : "UP", smps.columns2[i])
    kind === :h && return ("RHS", smps.rows2[i])
    kind === :q && return (smps.columns2[i], smps.objective)
    return (kind === :T ? smps.columns1[j] : smps.columns2[j], smps.rows2[i])
end

"""The line of the stoch file giving the value `v` to the random element `e`: a bound as the core
file's BOUNDS section writes it, the others by their column and row."""
function element_line(io::IO, smps::SMPSProblem, e::Integer, v)
    a, b = element_names(smps, e)
    if smps.elements[e][1] in (:lb, :ub)
        println(io, " ", rpad(a, 3), rpad("BND", 10), "  ", rpad(b, 10), "  ", num(v))
    else
        entry(io, a, b, v)
    end
end

"""The keyword and the two parameters of a continuous distribution, as the stoch file gives them."""
function parameters(d::UnivariateDistribution)
    d isa Normal && return ("NORMAL", d.μ, d.σ^2)
    d isa Uniform && return ("UNIFORM", d.a, d.b)
    d isa Gamma && return ("GAMMA", d.θ, d.α)        # scale, shape
    d isa Beta && return ("BETA", d.α, d.β)
    d isa LogNormal && return ("LOGNORM", d.μ, d.σ^2)
    error("no SMPS keyword for the distribution $d")
end

function write_stoch(io::IO, smps::SMPSProblem, scenarios)
    law = smps.law
    # the values as the file gives them: the costs of a maximization unsigned
    signs = [kind === :q && smps.sense === :max ? -1.0 : 1.0 for (kind, _, _) in smps.elements]
    println(io, "STOCH         ", problemname(smps))
    if scenarios !== nothing
        (; ξ, p) = scenarios
        length(ξ) == length(p) || error("$(length(ξ)) scenarios but $(length(p)) probabilities")
        println(io, "SCENARIOS     DISCRETE")
        for (s, (point, ps)) in enumerate(zip(ξ, p))
            println(io, " SC ", rpad("S$s", 10), "  ROOT        ", num(ps), "  PERIOD2")
            for e in eachindex(point)
                point[e] == law.base[e] && continue    # inherited from the core file
                element_line(io, smps, e, signs[e] * point[e])
            end
        end
        println(io, "ENDATA")
        return
    end
    # the discrete blocks and the continuous elements, in the order of their first element, so
    # that the elements are read back in the same order: a block of one element, the same in
    # every outcome, in an INDEP section, the others in a BLOCKS section
    items = Tuple{Int,Symbol,Int}[]                  # (first element, kind, index)
    for (k, outcomes) in enumerate(law.outcomes)
        members = unique(e for outcome in outcomes for (e, _) in outcome)
        # a block that changes nothing still counts its outcomes: last, in BLOCKS
        isempty(members) && (push!(items, (typemax(Int), :blocks, k)); continue)
        # a bound may not be random in an INDEP section
        single = all(o -> length(o) == 1, outcomes) && length(members) == 1 &&
                 !(smps.elements[members[1]][1] in (:lb, :ub))
        push!(items, (minimum(members), single ? :indep : :blocks, k))
    end
    foreach(((k, c),) -> push!(items, (c[1], :continuous, k)), enumerate(law.continuous))
    sort!(items)
    header = ""
    function section(h)
        h == header || println(io, h)
        header = h
    end
    for (_, kind, k) in items
        if kind === :indep
            section("INDEP         DISCRETE")
            for (outcome, pk) in zip(law.outcomes[k], law.probabilities[k])
                e, v = outcome[1]
                col, row = element_names(smps, e)
                println(io, "    ", rpad(col, 10), "  ", rpad(row, 10), "  ", num(signs[e] * v),
                        "  PERIOD2  ", num(pk))
            end
        elseif kind === :continuous
            e, d, modifier, _ = law.continuous[k]
            keyword, p1, p2 = parameters(d)
            section("INDEP         " * rpad(keyword, 10) * "  " * uppercase(string(modifier)))
            col, row = element_names(smps, e)
            println(io, "    ", rpad(col, 10), "  ", rpad(row, 10), "  ", num(p1), "  PERIOD2  ", num(p2))
        else
            section("BLOCKS        DISCRETE")
            members = sort!(unique(e for outcome in law.outcomes[k] for (e, _) in outcome))
            for (outcome, pk) in zip(law.outcomes[k], law.probabilities[k])
                println(io, " BL ", rpad("B$k", 10), "  PERIOD2  ", num(pk))
                values = Dict(outcome)
                for e in members                     # every element, explicitly
                    element_line(io, smps, e, signs[e] * get(values, e, law.base[e]))
                end
            end
        end
    end
    println(io, "ENDATA")
end
