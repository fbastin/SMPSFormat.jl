# Reading the three files of an SMPS instance.

"""
    read_smps(core, time, stoch; sense = nothing, probability_sums = :rounding)
    read_smps(prefix; sense = nothing, probability_sums = :rounding)

Read a two-stage instance in the SMPS format into an [`SMPSProblem`](@ref). `read_smps(prefix)`
looks for `prefix` followed by `.cor` or `.core`, `.tim` or `.time`, and `.sto` or `.stoch`.

**The core file** is in free MPS format: `NAME`, `OBJSENSE`, `ROWS`, `COLUMNS` (with integer
markers), `RHS`, `RANGES` and `BOUNDS` (`UP`, `LO`, `FX`, `FR`, `MI`, `PL`, `BV`, `LI`, `UI`).
Integer variables without bounds lie in `[0, ∞)`. A negative upper bound alone frees the lower
one, as in MPS.

**The time file** gives the periods, implicitly (the first column and row of each, the core file
being in temporal order) or explicitly (`PERIODS EXPLICIT`, then the period of each column and
row). Two periods only, for now.

**The stoch file** gives the law of the random elements, which may be right-hand sides, matrix
coefficients and costs of the second stage:
- `INDEP` sections, `DISCRETE` or continuous: `UNIFORM` (a, b), `NORMAL` (mean, variance),
  `GAMMA` (scale, shape), `BETA` (the two parameters of Beta(n, m), density ∝ x^(n−1)(1−x)^(m−1)),
  `LOGNORM` (mean and variance of the logarithm). A continuous law can be sampled only.
- `BLOCKS DISCRETE`: an element a realization does not list takes its value in the block's first
  realization, as the format says.
- `SCENARIOS DISCRETE` (or `SCEN`) in two stages: each scenario branches from `ROOT`, or from
  another scenario at the second period, and inherits the values it does not list from its
  parent (the core file for `ROOT`).
- The modifiers `REPLACE` (the default), `ADD` and `MULTIPLY` of `INDEP` and `BLOCKS` sections:
  the value given replaces the core value, is added to it, or multiplies it.

Not supported, and refused: more than two periods, `NODES`, `DISTRIB`, `MVNORMAL`, `LINTRAN` and
user-defined distributions, chance constraints (`CHANCE`, `ICC`), `SIMPLE` recourse, random
bounds and ranges, random first-stage data, network core files.

**The names** on the first lines of the three files should be the same; when they are not, as in
several files of SPLIB, a warning.

**`sense`**: `:min` or `:max`, overriding the file's `OBJSENSE` (for a maximization whose files do
not say so, as SAPHIR's); by default, the file's, or `:min`. A maximization is stored as the
minimization of the opposite objective (see [`SMPSProblem`](@ref)).

**`probability_sums`**: probabilities written with a few digits, as 1/6 as 0.16667, sum up to one
only up to their rounding. What to do with those of a block (an `INDEP` element, a `BLOCKS` block,
or the scenarios) that do not sum up to one:
- `:rounding`, the default: normalized when the gap is within the rounding of the digits written
  (the number of outcomes times half a unit of their last digit), with a warning if it is not
  negligible; refused beyond, the file then being taken as wrong.
- `:normalize`: normalized, with a warning if the gap is not negligible.
- `:as_written`: kept as written, with a warning; the probabilities of the scenarios then sum up
  to the product of their totals, and the expected recourse is weighted by them. Zverovich's
  thesis (2011) solved SPLIB's instances so, and its published values are reproduced only this
  way.
"""
function read_smps(prefix::AbstractString; kwargs...)
    find(exts) = (i = findfirst(e -> isfile(prefix * e), exts);
                  i === nothing ? error("no file $prefix$(join(exts, " or "))") : prefix * exts[i])
    return read_smps(find([".cor", ".core", ".COR", ".CORE"]), find([".tim", ".time", ".TIM", ".TIME"]),
                     find([".sto", ".stoch", ".STO", ".STOCH"]); kwargs...)
end

function read_smps(core::AbstractString, time::AbstractString, stoch::AbstractString;
                   sense::Union{Nothing,Symbol} = nothing, probability_sums::Symbol = :rounding)
    sense in (nothing, :min, :max) || error("sense must be :min or :max, got :$sense")
    probability_sums in (:rounding, :normalize, :as_written) ||
        error("probability_sums must be :rounding, :normalize or :as_written, got :$probability_sums")
    cor = read_core(core)
    sense = something(sense, cor.sense)
    sign = sense === :max ? -1.0 : 1.0
    tim = read_time(time, cor)
    sto = read_stoch(stoch, cor, tim, probability_sums)
    names = (cor.name, tim.name, sto.name)
    allequal(names) || @warn "The SMPS files name different problems: $(names[1]) (core), " *
                             "$(names[2]) (time), $(names[3]) (stoch)"
    return assemble(cor, tim, sto, sign, sense)
end

# ---- the core file

function read_core(path::AbstractString)
    name, objective, sense = "", "", :min
    rows, senses, columns = String[], Char[], String[]
    rowindex, colindex = Dict{String,Int}(), Dict{String,Int}()
    entries = Dict{Tuple{Int,Int},Float64}()        # (row, column) => coefficient
    cost, rhs, ranges = Dict{Int,Float64}(), Dict{Int,Float64}(), Dict{Int,Float64}()
    lower, upper, integer = Dict{Int,Float64}(), Dict{Int,Float64}(), Set{Int}()
    rhsnames, rangenames, boundnames = Set{String}(), Set{String}(), Set{String}()
    constant, section, intmarker = 0.0, "", false
    ignored = Set{String}()                         # the other free rows
    for (header, f) in smps_lines(path)
        if header
            section = uppercase(f[1])
            if section == "NAME"
                name = join(f[2:end], " ")
            elseif section == "OBJSENSE" && length(f) > 1
                sense = objsense(path, f[2])
            elseif !(section in ("OBJSENSE", "ROWS", "COLUMNS", "RHS", "RANGES", "BOUNDS", "ENDATA"))
                error("$path: section $section is not supported")
            end
            continue
        end
        if section == "OBJSENSE"
            sense = objsense(path, f[1])
        elseif section == "ROWS"
            kind, row = uppercase(f[1]), f[2]
            if kind == "N"
                isempty(objective) ? (objective = row) : push!(ignored, row)
            elseif kind in ("L", "G", "E")
                push!(rows, row)
                push!(senses, kind[1])
                rowindex[row] = length(rows)
            else
                error("$path: unknown row type $kind")
            end
        elseif section == "COLUMNS"
            if length(f) >= 3 && f[2] in ("'MARKER'", "MARKER")
                intmarker = f[3] in ("'INTORG'", "INTORG")
                continue
            end
            col = f[1]
            if !haskey(colindex, col)
                push!(columns, col)
                colindex[col] = length(columns)
                intmarker && push!(integer, length(columns))
            end
            j = colindex[col]
            for k in 2:2:(length(f) - 1)
                row, value = f[k], number(f[k+1])
                if row == objective
                    cost[j] = value
                elseif !(row in ignored)
                    haskey(rowindex, row) || error("$path: unknown row $row in column $col")
                    entries[(rowindex[row], j)] = value
                end
            end
        elseif section in ("RHS", "RANGES")
            start = isodd(length(f)) ? 2 : 1        # the name of the vector is optional
            start == 2 && push!(section == "RHS" ? rhsnames : rangenames, f[1])
            for k in start:2:(length(f) - 1)
                row, value = f[k], number(f[k+1])
                if row == objective
                    section == "RHS" ? (constant = -value) :  # MPS: the RHS of the objective is −constant
                    error("$path: a range on the objective row")
                elseif !(row in ignored)
                    haskey(rowindex, row) || error("$path: unknown row $row in section $section")
                    (section == "RHS" ? rhs : ranges)[rowindex[row]] = value
                end
            end
        elseif section == "BOUNDS"
            kind = uppercase(f[1])
            col, value = if kind in ("FR", "MI", "PL", "BV")
                haskey(colindex, f[end]) ? (f[end], NaN) : (f[end-1], number(f[end]))
            else
                length(f) >= 4 ? (f[3], number(f[4])) : (f[2], number(f[3]))
            end
            length(f) >= 3 && !haskey(colindex, f[2]) && push!(boundnames, f[2])
            haskey(colindex, col) || error("$path: unknown column $col in section BOUNDS")
            j = colindex[col]
            kind == "UP" && (upper[j] = value)
            kind == "LO" && (lower[j] = value)
            kind == "FX" && (lower[j] = upper[j] = value)
            kind == "FR" && (lower[j] = -Inf; upper[j] = Inf)
            kind == "MI" && (lower[j] = -Inf)
            kind == "PL" && (upper[j] = Inf)
            kind == "BV" && (lower[j] = 0.0; upper[j] = 1.0; push!(integer, j))
            kind == "LI" && (lower[j] = value; push!(integer, j))
            kind == "UI" && (upper[j] = value; push!(integer, j))
            kind in ("UP", "LO", "FX", "FR", "MI", "PL", "BV", "LI", "UI") ||
                error("$path: bound type $kind is not supported")
        end
    end
    isempty(objective) && error("$path: no objective row (type N)")
    return (; name, objective, sense, rows, senses, columns, rowindex, colindex, entries, cost,
            rhs, ranges, lower, upper, integer, constant, rhsnames, rangenames, boundnames)
end

function objsense(path, word)
    w = uppercase(word)
    w in ("MAX", "MAXIMIZE", "MAXIMISE") && return :max
    w in ("MIN", "MINIMIZE", "MINIMISE") && return :min
    error("$path: unknown objective sense $word")
end

# ---- the time file: where the second stage starts

function read_time(path::AbstractString, cor)
    name, starts, periods, section, explicit = "", Tuple{String,String}[], String[], "", false
    colperiod, rowperiod = Dict{String,String}(), Dict{String,String}()
    for (header, f) in smps_lines(path)
        if header
            section = uppercase(f[1])
            section == "TIME" && (name = join(f[2:end], " "))
            section == "PERIODS" && (explicit = length(f) > 1 && uppercase(f[2]) == "EXPLICIT")
            section in ("TIME", "PERIODS", "COLUMNS", "ROWS", "ENDATA") ||
                error("$path: section $section is not supported")
            continue
        end
        if section == "PERIODS" && !explicit
            length(f) >= 3 || error("$path: a period needs a column, a row and a name")
            push!(starts, (f[1], f[2]))
            push!(periods, f[3])
        elseif section == "PERIODS"
            push!(periods, f[1])
        elseif section == "COLUMNS"
            colperiod[f[1]] = f[2]
        elseif section == "ROWS"
            rowperiod[f[1]] = f[2]
        end
    end
    length(periods) == 2 || error("$path: $(length(periods)) periods; only two are supported for now")
    (; rowindex, colindex, rows, columns) = cor
    stage2col, stage2row = if explicit
        for (c, _) in colperiod
            haskey(colindex, c) || error("$path: unknown column $c")
        end
        Set(colindex[c] for (c, t) in colperiod if t == periods[2]),
        Set(rowindex[r] for (r, t) in rowperiod if t == periods[2] && haskey(rowindex, r))
    else
        c, r = starts[2]
        haskey(colindex, c) || error("$path: unknown column $c")
        haskey(rowindex, r) || error("$path: unknown row $r (the first of the second period)")
        Set(colindex[c]:length(columns)), Set(rowindex[r]:length(rows))
    end
    return (; name, periods, stage2col, stage2row)
end

# ---- the stoch file: the random elements and their law

const DISTRIBUTIONS = ("DISCRETE", "UNIFORM", "NORMAL", "GAMMA", "BETA", "LOGNORM")

"""The continuous distribution `kind` of an `INDEP` element, from its two parameters."""
function distribution(path, kind, p1, p2)
    kind == "UNIFORM" && return Uniform(p1, p2)
    kind == "NORMAL" && return Normal(p1, sqrt(p2))       # mean, variance
    kind == "GAMMA" && return Gamma(p2, p1)               # scale, shape
    kind == "BETA" && return Beta(p1, p2)
    kind == "LOGNORM" && return LogNormal(p1, sqrt(p2))   # mean and variance of the logarithm
    error("$path: distribution $kind is not supported")
end

function read_stoch(path::AbstractString, cor, tim, probability_sums::Symbol)
    (; rowindex, colindex, entries, objective, rhsnames, rangenames, boundnames) = cor
    (; periods, stage2col, stage2row) = tim
    # the random elements: (col, row) names => index; each in one block or distribution only
    elementindex = Dict{Tuple{String,String},Int}()
    elementnames = Tuple{String,String}[]
    owner = Dict{Int,String}()                       # element => the block that sets it
    function element(col, row, block)
        e = get!(elementindex, (col, row)) do
            if haskey(colindex, col)
                j = colindex[col]
                if row == objective
                    j in stage2col || error("$path: random first-stage cost of $col")
                else
                    haskey(rowindex, row) || error("$path: unknown row $row")
                    rowindex[row] in stage2row || error("$path: random entry in the first-stage row $row")
                    haskey(entries, (rowindex[row], j)) ||
                        error("$path: random entry ($row, $col) absent from the core file")
                end
            else
                col in rangenames && error("$path: random range of $row: not supported")
                col in boundnames && error("$path: random bound of $row: not supported")
                row == objective && error("$path: random constant of the objective: not supported")
                haskey(rowindex, row) || error("$path: unknown row $row")
                rowindex[row] in stage2row ||
                    error("$path: random right-hand side of the first-stage row $row")
            end
            push!(elementnames, (col, row))
            return length(elementnames)
        end
        get!(owner, e, block) == block ||
            error("$path: ($col, $row) is random in two blocks, $(owner[e]) and $block")
        return e
    end
    blocks = String[]                                # the names of the discrete blocks
    probabilities, halfunits = Vector{Float64}[], Vector{Float64}[]
    realizations = Vector{Dict{Int,Float64}}[]       # per block, per outcome: element => value as given
    modifiers = Symbol[]                             # per block
    blockindex = Dict{String,Int}()
    continuous = Tuple{Int,String,Float64,Float64,Symbol}[] # element, distribution, parameters, modifier
    scenarioindex = Dict{String,Int}()               # a scenario => its outcome
    name, section, kind, modifier, current = "", "", "DISCRETE", :replace, 0
    newblock(label) = (push!(blocks, label); push!(probabilities, Float64[]); push!(halfunits, Float64[]);
                       push!(realizations, Dict{Int,Float64}[]); push!(modifiers, modifier);
                       blockindex[label] = length(blocks))
    for (header, f) in smps_lines(path)
        if header
            section = uppercase(f[1])
            section == "SCEN" && (section = "SCENARIOS")
            if section == "STOCH"
                name = join(f[2:end], " ")
            elseif section in ("INDEP", "BLOCKS", "SCENARIOS")
                kind = length(f) > 1 ? uppercase(f[2]) : "DISCRETE"
                kind in DISTRIBUTIONS ||
                    error("$path: $section $kind is not supported (distributions: $(join(DISTRIBUTIONS, ", ")))")
                section != "INDEP" && kind != "DISCRETE" &&
                    error("$path: $section $kind is not supported, only DISCRETE")
                word = length(f) > 2 ? uppercase(f[3]) : "REPLACE"
                word in ("REPLACE", "ADD", "MULTIPLY") || error("$path: unknown modifier $word")
                modifier = Symbol(lowercase(word))
                section == "SCENARIOS" && modifier !== :replace &&
                    error("$path: SCENARIOS $word is not supported: scenarios replace the values")
            elseif section != "ENDATA"
                error("$path: section $section is not supported")
            end
            continue
        end
        if section == "INDEP"
            col, row = f[1], f[2]
            length(f) in (4, 5) || error("$path: malformed INDEP line $(join(f, ' '))")
            if kind == "DISCRETE"
                label = "INDEP ($col, $row)"
                e = element(col, row, label)
                haskey(blockindex, label) || newblock(label)
                k = blockindex[label]
                push!(probabilities[k], number(f[end]))
                push!(halfunits[k], half_unit(f[end]))
                push!(realizations[k], Dict(e => number(f[3])))
            else
                e = element(col, row, "INDEP ($col, $row)")
                any(c -> c[1] == e, continuous) && error("$path: two distributions for ($col, $row)")
                push!(continuous, (e, kind, number(f[3]), number(f[end]), modifier))
            end
        elseif section in ("BLOCKS", "SCENARIOS") && f[1] in ("BL", "SC")
            if f[1] == "BL"
                length(f) >= 4 || error("$path: incomplete BL line $(join(f, ' '))")
                label = "BLOCKS " * f[2]
                isnew = !haskey(blockindex, label)
                isnew && newblock(label)
                k = blockindex[label]
                # a realization lists what changes from the block's first one
                push!(realizations[k], isnew ? Dict{Int,Float64}() : copy(realizations[k][1]))
                prob = f[4]
            else
                length(f) >= 4 || error("$path: incomplete SC line $(join(f, ' '))")
                haskey(blockindex, "SCENARIOS") || newblock("SCENARIOS")
                k = blockindex["SCENARIOS"]
                parent = strip(f[3], '\'')
                period = length(f) >= 5 ? strip(f[5], '\'') : periods[2]
                inherited = if parent == "ROOT"
                    Dict{Int,Float64}()
                else
                    # a scenario branching from another at the second period is still two-stage
                    haskey(scenarioindex, parent) && period == periods[2] ||
                        error("$path: scenario $(f[2]) branches from $parent at $period: not two-stage")
                    copy(realizations[k][scenarioindex[parent]])
                end
                push!(realizations[k], inherited)
                scenarioindex[f[2]] = length(realizations[k])
                prob = f[4]
            end
            current = k
            push!(probabilities[k], number(prob))
            push!(halfunits[k], half_unit(prob))
        elseif section in ("BLOCKS", "SCENARIOS")
            current == 0 && error("$path: an entry before the first BL or SC line")
            length(f) in (3, 5) || error("$path: malformed line $(join(f, ' '))")
            for k in 2:2:(length(f) - 1)
                e = element(f[1], f[k], blocks[current])
                realizations[current][end][e] = number(f[k+1])
            end
        end
    end
    # the probabilities of each block
    for (k, p) in enumerate(probabilities)
        total, gap = sum(p), abs(sum(p) - 1)
        if probability_sums === :as_written
            gap > 1e-9 && @warn "$path: the probabilities of $(blocks[k]) sum up to $total; kept as written"
            continue
        end
        slack = sum(halfunits[k])
        probability_sums === :rounding && gap > slack + 1e-12 &&
            error("$path: the probabilities of $(blocks[k]) sum up to $total, beyond the rounding " *
                  "of their digits ($slack); pass probability_sums = :normalize or :as_written to read them")
        gap > 1e-9 && @warn "$path: the probabilities of $(blocks[k]) sum up to $total; normalized"
        probabilities[k] = p ./ total
    end
    return (; path, name, elementnames, blocks, probabilities, realizations, modifiers, continuous)
end

# ---- the problem

function assemble(cor, tim, sto, sign::Float64, sense::Symbol)
    (; rows, senses, columns, rowindex, colindex, entries, cost, rhs, ranges, lower, upper,
       integer, objective) = cor
    (; stage2col, stage2row) = tim
    cols1 = [j for j in eachindex(columns) if !(j in stage2col)]
    cols2 = [j for j in eachindex(columns) if j in stage2col]
    rows1 = [i for i in eachindex(rows) if !(i in stage2row)]
    rows2 = [i for i in eachindex(rows) if i in stage2row]
    position = Dict{Int,Int}()                      # an index of the core => its index in its stage
    foreach(((k, j),) -> position[j] = k, enumerate(cols1))
    foreach(((k, j),) -> position[j] = k, enumerate(cols2))
    rowposition = Dict{Int,Int}()
    foreach(((k, i),) -> rowposition[i] = k, enumerate(rows1))
    foreach(((k, i),) -> rowposition[i] = k, enumerate(rows2))
    for ((i, j), v) in entries
        i in stage2row || !(j in stage2col) ||
            error("second-stage variable $(columns[j]) in the first-stage row $(rows[i])")
    end
    function matrix(rowlist, collist)
        rowset, colset = Set(rowlist), Set(collist)
        I, J, V = Int[], Int[], Float64[]
        for ((i, j), v) in entries
            (i in rowset && j in colset) || continue
            push!(I, rowposition[i]); push!(J, position[j]); push!(V, v)
        end
        return sparse(I, J, V, length(rowlist), length(collist))
    end
    A, T, W = matrix(rows1, cols1), matrix(rows2, cols1), matrix(rows2, cols2)
    c = [sign * get(cost, j, 0.0) for j in eachindex(columns)]
    lb = [get(lower, j, 0.0) for j in eachindex(columns)]
    ub = [get(upper, j, Inf) for j in eachindex(columns)]
    for j in eachindex(columns)                     # MPS: a negative upper bound alone frees x
        !haskey(lower, j) && ub[j] < 0 && (lb[j] = -Inf)
    end
    b = [get(rhs, i, 0.0) for i in eachindex(rows)]
    rg = [get(ranges, i, NaN) for i in eachindex(rows)]
    # the random elements: where they are, their values in the core file (unsigned)
    elements = map(sto.elementnames) do (col, row)
        if haskey(colindex, col)
            j = colindex[col]
            row == objective && return (:q, position[j], 0)
            return (j in stage2col ? :W : :T, rowposition[rowindex[row]], position[j])
        end
        return (:h, rowposition[rowindex[row]], 0)
    end
    core = map(sto.elementnames) do (col, row)
        haskey(colindex, col) || return b[rowindex[row]]
        j = colindex[col]
        return row == objective ? get(cost, j, 0.0) : entries[(rowindex[row], j)]
    end
    signs = [kind === :q ? sign : 1.0 for (kind, _, _) in elements]
    # the outcomes: the modifiers applied, sorted by element, costs signed
    outcomes = map(zip(sto.realizations, sto.modifiers)) do (realizations, modifier)
        map(realizations) do realization
            sort!([e => signs[e] * modified(modifier, core[e], v) for (e, v) in realization])
        end
    end
    continuous = [(e, distribution(sto.path, kind, p1, p2), modifier, signs[e])
                  for (e, kind, p1, p2, modifier) in sto.continuous]
    law = SMPSLaw(signs .* core, sto.probabilities, outcomes, continuous)
    return SMPSProblem(cor.name, sense, objective, c[cols1], A, senses[rows1], b[rows1], rg[rows1],
                       lb[cols1], ub[cols1], [j in integer for j in cols1],
                       c[cols2], W, senses[rows2], b[rows2], rg[rows2], T,
                       lb[cols2], ub[cols2], [j in integer for j in cols2], sign * cor.constant,
                       columns[cols1], columns[cols2], rows[rows1], rows[rows2],
                       elements, sto.elementnames, law)
end
