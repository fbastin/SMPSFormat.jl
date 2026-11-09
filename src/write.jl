# Writing an SMPS instance: the core, time and stoch files.

"""
    write_smps(prefix, smps::SMPSProblem; scenarios = nothing)
    write_smps(prefix, tree::SMPSTree)
    write_smps(prefix, s::SMPSStagewise)

Write an instance in the SMPS format to `prefix.cor`, `prefix.tim` and `prefix.sto`, and return
their paths. [`read_smps`](@ref) reads them back into the same problem.

- **The core file** is in free MPS format, the columns and rows in the order of their periods, so
  that the time file gives each period by its first column and row; when a period has none, the
  time file lists the period of each (`PERIODS EXPLICIT`). A maximization is written as such,
  with an `OBJSENSE MAX` section.
- **The stoch file of a two-stage problem or of a law by period** gives the law: its continuous
  elements and its discrete blocks of one element in `INDEP` sections, its other blocks in
  `BLOCKS DISCRETE` sections, each realization listing every element of its block, each line in
  the period it is revealed in. For a two-stage problem, `scenarios = (ξ = ..., p = ...)` lists
  those scenarios instead (`SCENARIOS DISCRETE`), each giving the values that differ from the
  core file: an instance whose scenarios were sampled, or generated.
- **The stoch file of a tree** lists its scenarios (`SCENARIOS DISCRETE`): each branches from
  the first scenario that shares its node in the period before its first node of its own, and
  gives the values that differ from those it inherits. The data of the root are those of the
  core file.

The numbers are written in full, so that they are read back exactly.
"""
function write_smps(prefix::AbstractString, smps::SMPSProblem; scenarios = nothing)
    isempty(smps.columns2) && error("no second-stage variable: not a two-stage problem")
    isempty(smps.rows2) && error("no second-stage row: not a two-stage problem")
    d = written_core(smps)
    return write_files(prefix, d, io -> write_stoch(io, smps, d, scenarios))
end

function write_smps(prefix::AbstractString, tree::SMPSTree)
    d = written_core(tree)
    return write_files(prefix, d, io -> write_tree_stoch(io, tree, d))
end

function write_smps(prefix::AbstractString, s::SMPSStagewise)
    d = written_core(s)
    return write_files(prefix, d, io -> write_stagewise_stoch(io, s, d))
end

function write_files(prefix, d, stoch)
    paths = (prefix * ".cor", prefix * ".tim", prefix * ".sto")
    open(io -> write_core(io, d), paths[1], "w")
    open(io -> write_time(io, d), paths[2], "w")
    open(stoch, paths[3], "w")
    return paths
end

num(v::Real) = string(Float64(v))
entry(io, a, b, v) = println(io, "    ", rpad(a, 10), "  ", rpad(b, 10), "  ", num(v))
problemname(name) = isempty(name) ? "SMPS" : name

# ---- the core data to write

"""The core data of an instance as the core and time files write them: its data with the
indices of the instance, and `colorder` and `roworder`, the order of the periods (stable)."""
function written_core(smps::SMPSProblem)
    d = two_stage_core(smps)
    return (; d..., name = problemname(smps.name), sense = smps.sense, objective = smps.objective,
            periods = ["PERIOD1", "PERIOD2"], constant = smps.constant,
            colorder = collect(eachindex(d.columns)), roworder = collect(eachindex(d.rows)))
end

function written_core(x::Union{SMPSTree,SMPSStagewise})
    d = (c = copy(x.c), A = copy(x.A), rhs = copy(x.rhs), lb = copy(x.lb), ub = copy(x.ub))
    if x isa SMPSTree                                # the data of the root in the core file
        foreach(((e, v),) -> set_element!(d, x.elements[e]..., v), x.values[1])
    end
    return (; d..., name = problemname(x.name), sense = x.sense, objective = x.objective,
            periods = x.periods, columns = x.columns, rows = x.rows, colperiod = x.colperiod,
            rowperiod = x.rowperiod, senses = x.senses, ranges = x.ranges, integer = x.integer,
            constant = x.constant, colorder = sortperm(x.colperiod; alg = MergeSort),
            roworder = sortperm(x.rowperiod; alg = MergeSort))
end

"""The value of the random element `(kind, i, j)` in the core data `d`."""
function core_value(d, kind, i, j)
    kind === :rhs && return d.rhs[i]
    kind === :c && return d.c[i]
    kind === :A && return d.A[i, j]
    return kind === :lb ? d.lb[i] : d.ub[i]
end

function write_core(io::IO, d)
    sign = d.sense === :max ? -1.0 : 1.0             # the costs as the file gives them
    println(io, "NAME          ", d.name)
    d.sense === :max && println(io, "OBJSENSE\n    MAX")
    println(io, "ROWS")
    println(io, " N  ", d.objective)
    foreach(i -> println(io, " ", d.senses[i], "  ", d.rows[i]), d.roworder)
    println(io, "COLUMNS")
    marked = false
    for j in d.colorder
        col = d.columns[j]
        if d.integer[j] != marked
            marked = d.integer[j]
            println(io, "    MARKER                 'MARKER'                 ",
                    marked ? "'INTORG'" : "'INTEND'")
        end
        written = false
        if d.c[j] != 0
            entry(io, col, d.objective, sign * d.c[j])
            written = true
        end
        for k in nzrange(d.A, j)                     # the zeros stored too: they may be random
            entry(io, col, d.rows[rowvals(d.A)[k]], nonzeros(d.A)[k])
            written = true
        end
        written || entry(io, col, d.objective, 0.0)  # a column must appear
    end
    marked && println(io, "    MARKER                 'MARKER'                 'INTEND'")
    println(io, "RHS")
    constant = sign * d.constant
    constant != 0 && entry(io, "RHS", d.objective, -constant)  # MPS: the RHS of the objective is −constant
    for i in d.roworder
        d.rhs[i] != 0 && entry(io, "RHS", d.rows[i], d.rhs[i])
    end
    if any(!isnan, d.ranges)
        println(io, "RANGES")
        for i in d.roworder
            isnan(d.ranges[i]) || entry(io, "RNG", d.rows[i], d.ranges[i])
        end
    end
    println(io, "BOUNDS")
    for j in d.colorder
        col, lb, ub = d.columns[j], d.lb[j], d.ub[j]
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

function write_time(io::IO, d)
    println(io, "TIME          ", d.name)
    T = length(d.periods)
    cols = [filter(j -> d.colperiod[j] == t, d.colorder) for t in 1:T]
    rows = [filter(i -> d.rowperiod[i] == t, d.roworder) for t in 1:T]
    if !isempty(cols[1]) && all(t -> !isempty(cols[t]) && !isempty(rows[t]), 2:T)
        println(io, "PERIODS")                       # implicit: the first column and row of each
        for t in 1:T
            row = isempty(rows[t]) ? d.objective : d.rows[rows[t][1]]
            println(io, "    ", rpad(d.columns[cols[t][1]], 10), "  ", rpad(row, 10), "  ", d.periods[t])
        end
    else
        println(io, "PERIODS       EXPLICIT")
        foreach(p -> println(io, "    ", p), d.periods)
        println(io, "COLUMNS")
        foreach(j -> println(io, "    ", rpad(d.columns[j], 10), "  ", d.periods[d.colperiod[j]]), d.colorder)
        println(io, "ROWS")
        foreach(i -> println(io, "    ", rpad(d.rows[i], 10), "  ", d.periods[d.rowperiod[i]]), d.roworder)
    end
    println(io, "ENDATA")
end

# ---- the stoch file

"""The column and row names of the random element `(kind, i, j)` of a tree or a law by period, as
the core file written gives them: for a bound, its type and the column."""
function multistage_names(x, kind, i, j)
    kind === :rhs && return ("RHS", x.rows[i])
    kind === :c && return (x.columns[i], x.objective)
    kind === :A && return (x.columns[j], x.rows[i])
    return (kind === :lb ? "LO" : "UP", x.columns[i])
end

"""The column and row names of the random element `e` of a two-stage problem, as the core file
written gives them."""
function element_names(smps::SMPSProblem, e::Integer)
    kind, i, j = smps.elements[e]
    kind in (:lb, :ub) && return (kind === :lb ? "LO" : "UP", smps.columns2[i])
    kind === :h && return ("RHS", smps.rows2[i])
    kind === :q && return (smps.columns2[i], smps.objective)
    return (kind === :T ? smps.columns1[j] : smps.columns2[j], smps.rows2[i])
end

"""The line of the stoch file giving the value `v` to an element named `(a, b)`: a bound as the
core file's BOUNDS section writes it, the others by their column and row."""
stoch_line(io::IO, (a, b), bound::Bool, v) =
    bound ? println(io, " ", rpad(a, 3), rpad("BND", 10), "  ", rpad(b, 10), "  ", num(v)) : entry(io, a, b, v)

"""The keyword and the two parameters of a continuous distribution, as the stoch file gives them."""
function parameters(d::UnivariateDistribution)
    d isa Normal && return ("NORMAL", d.μ, d.σ^2)
    d isa Uniform && return ("UNIFORM", d.a, d.b)
    d isa Gamma && return ("GAMMA", d.θ, d.α)        # scale, shape
    d isa Beta && return ("BETA", d.α, d.β)
    d isa LogNormal && return ("LOGNORM", d.μ, d.σ^2)
    error("no SMPS keyword for the distribution $d")
end

"""Write laws in `INDEP` and `BLOCKS` sections. `parts` lists them as `(law, elements, period)`:
the law, on the elements `elements` (the indices of the instance), revealed in the period named
`period`. For an element `e` of the instance, `names(e)` gives its names, `bound(e)` whether it is
a bound, `sign(e)` the sign of its value as the file gives it. The blocks and continuous elements
are written in the order of their first element, so that the elements are read back in the same
order."""
function write_laws(io::IO, parts, names, bound, sign)
    items = Tuple{Int,Symbol,Int,Int}[]              # (first element, kind, part, index)
    for (p, (law, elements, _)) in enumerate(parts)
        for (k, outcomes) in enumerate(law.outcomes)
            members = unique(elements[e] for outcome in outcomes for (e, _) in outcome)
            # a block that changes nothing still counts its outcomes: last, in BLOCKS
            isempty(members) && (push!(items, (typemax(Int), :blocks, p, k)); continue)
            # a block of one element, the same in every outcome, in INDEP; but not a bound
            single = all(o -> length(o) == 1, outcomes) && length(members) == 1 && !bound(members[1])
            push!(items, (minimum(members), single ? :indep : :blocks, p, k))
        end
        foreach(((k, c),) -> push!(items, (elements[c[1]], :continuous, p, k)), enumerate(law.continuous))
    end
    sort!(items)
    header, nblocks = "", 0
    function section(h)
        h == header || println(io, h)
        header = h
    end
    for (_, kind, p, k) in items
        law, elements, period = parts[p]
        if kind === :indep
            section("INDEP         DISCRETE")
            for (outcome, pk) in zip(law.outcomes[k], law.probabilities[k])
                e, v = outcome[1]
                col, row = names(elements[e])
                println(io, "    ", rpad(col, 10), "  ", rpad(row, 10), "  ", num(sign(elements[e]) * v),
                        "  ", period, "  ", num(pk))
            end
        elseif kind === :continuous
            e, d, modifier, _ = law.continuous[k]
            keyword, p1, p2 = parameters(d)
            section("INDEP         " * rpad(keyword, 10) * "  " * uppercase(string(modifier)))
            col, row = names(elements[e])
            println(io, "    ", rpad(col, 10), "  ", rpad(row, 10), "  ", num(p1), "  ", period, "  ", num(p2))
        else
            section("BLOCKS        DISCRETE")
            nblocks += 1
            members = sort!(unique(e for outcome in law.outcomes[k] for (e, _) in outcome))
            for (outcome, pk) in zip(law.outcomes[k], law.probabilities[k])
                println(io, " BL ", rpad("B$nblocks", 10), "  ", period, "  ", num(pk))
                values = Dict(outcome)
                for e in members                     # every element, explicitly
                    g = elements[e]
                    stoch_line(io, names(g), bound(g), sign(g) * get(values, e, law.base[e]))
                end
            end
        end
    end
end

function write_stoch(io::IO, smps::SMPSProblem, d, scenarios)
    law = smps.law
    # the values as the file gives them: the costs of a maximization unsigned
    signs = [kind === :q && smps.sense === :max ? -1.0 : 1.0 for (kind, _, _) in smps.elements]
    isbound(e) = smps.elements[e][1] in (:lb, :ub)
    println(io, "STOCH         ", d.name)
    if scenarios !== nothing
        (; ξ, p) = scenarios
        length(ξ) == length(p) || error("$(length(ξ)) scenarios but $(length(p)) probabilities")
        println(io, "SCENARIOS     DISCRETE")
        for (s, (point, ps)) in enumerate(zip(ξ, p))
            println(io, " SC ", rpad("S$s", 10), "  ROOT        ", num(ps), "  PERIOD2")
            for e in eachindex(point)
                point[e] == law.base[e] && continue    # inherited from the core file
                stoch_line(io, element_names(smps, e), isbound(e), signs[e] * point[e])
            end
        end
    else
        write_laws(io, [(law, collect(eachindex(smps.elements)), "PERIOD2")],
                   e -> element_names(smps, e), isbound, e -> signs[e])
    end
    println(io, "ENDATA")
end

function write_stagewise_stoch(io::IO, s::SMPSStagewise, d)
    println(io, "STOCH         ", d.name)
    parts = [(s.laws[t], s.lawelements[t], s.periods[t]) for t in eachindex(s.periods)
             if !isempty(s.lawelements[t]) || !isempty(s.laws[t].probabilities)]
    write_laws(io, parts, e -> multistage_names(s, s.elements[e]...),
               e -> s.elements[e][1] in (:lb, :ub),
               e -> s.elements[e][1] === :c && s.sense === :max ? -1.0 : 1.0)
    println(io, "ENDATA")
end

function write_tree_stoch(io::IO, tree::SMPSTree, d)
    T = length(tree.periods)
    sign(e) = tree.elements[e][1] === :c && tree.sense === :max ? -1.0 : 1.0
    isbound(e) = tree.elements[e][1] in (:lb, :ub)
    ofperiod = [findall(==(t), tree.elementperiod) for t in 1:T]
    nodevalues = [Dict(v) for v in tree.values]
    base(e) = core_value(d, tree.elements[e]...)
    value(n, e) = get(nodevalues[n], e, base(e))
    println(io, "STOCH         ", d.name)
    println(io, "SCENARIOS     DISCRETE                REPLACE")
    seen = Dict{Int,Int}()                           # a node => the first scenario through it
    for (s, path) in enumerate(tree.scenarios)
        # its first node of its own, from the second period on; the scenario it branches from
        first = something(findfirst(n -> !haskey(seen, n), path[2:end]), T - 1) + 1
        parent = first == 2 ? 0 : seen[path[first-1]]
        println(io, " SC ", rpad("S$s", 10), "  ", rpad(parent == 0 ? "ROOT" : "S$parent", 10), "  ",
                num(tree.scenarioprobability[s]), "  ", tree.periods[first])
        for t in first:T, e in ofperiod[t]
            v = value(path[t], e)
            inherited = parent == 0 ? base(e) : value(tree.scenarios[parent][t], e)
            v == inherited || stoch_line(io, multistage_names(tree, tree.elements[e]...), isbound(e),
                                         sign(e) * v)
        end
        foreach(n -> get!(seen, n, s), path)
    end
    println(io, "ENDATA")
end
