# Reading the three files of an SMPS instance.

"""
    read_smps(core, time, stoch; sense = nothing, probability_sums = :rounding)
    read_smps(prefix; sense = nothing, probability_sums = :rounding)

Read an instance in the SMPS format: an instance in two periods into an [`SMPSProblem`](@ref),
one in more periods into an [`SMPSTree`](@ref), its scenario tree. `read_smps(prefix)` looks for
`prefix` followed by `.cor` or `.core`, `.tim` or `.time`, and `.sto` or `.stoch`.

**The core file** is in free MPS format: `NAME`, `OBJSENSE`, `ROWS`, `COLUMNS` (with integer
markers), `RHS`, `RANGES` and `BOUNDS` (`UP`, `LO`, `FX`, `FR`, `MI`, `PL`, `BV`, `LI`, `UI`).
Integer variables without bounds lie in `[0, ∞)`. A negative upper bound alone frees the lower
one, as in MPS.

**The time file** gives the periods, implicitly (the first column and row of each, the core file
being in temporal order) or explicitly (`PERIODS EXPLICIT`, then the period of each column and
row), in any number.

**The stoch file of a two-period instance** gives the law of the random elements, which may be
right-hand sides, matrix coefficients and costs of the second stage:
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

**The stoch file of an instance in more periods** gives its scenario tree, in a `SCENARIOS
DISCRETE` (or `SCEN`) section, `REPLACE`: each scenario branches from `ROOT`, or from a scenario
given before it, in the period its `SC` line gives. Before that period it shares the nodes of its
parent; from that period on it has nodes of its own, and inherits the values it does not list
from its parent (the core file for `ROOT`). It may change only data of its branching period or
later: right-hand sides, matrix coefficients and costs. The tree has one node in the first
period: a scenario branching from `ROOT` in the first period, as in the SGPF files of POSTS, must
be the only child of `ROOT`, and then sets the data of the first period. Without any scenario,
the tree is a single one, the core problem.

Not supported, and refused: `NODES`, `DISTRIB`, `MVNORMAL`, `LINTRAN` and user-defined
distributions, `INDEP` and `BLOCKS` in more than two periods, chance constraints (`CHANCE`, `ICC`),
`SIMPLE` recourse, random bounds and ranges, random first-stage data in two periods, network core
files.

**The names** on the first lines of the three files should be the same; when they are not, as in
several files of SPLIB, a warning. A time or stoch file whose first section is `NAME`, instead of
`TIME` or `STOCH`, as some of SMI's, is read as well.

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
  way. In a tree, each node then has the total probability of its scenarios, the root the sum
  of them all.
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
    twostage = length(tim.periods) == 2
    sto = twostage ? read_stoch(stoch, cor, tim, probability_sums) :
          read_tree(stoch, cor, tim, probability_sums)
    names = (cor.name, tim.name, sto.name)
    allequal(names) || @warn "The SMPS files name different problems: $(names[1]) (core), " *
                             "$(names[2]) (time), $(names[3]) (stoch)"
    return twostage ? assemble(cor, tim, sto, sign, sense) : assemble_tree(cor, tim, sto, sign, sense)
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

# ---- the time file: the period of each column and row

function read_time(path::AbstractString, cor)
    name, starts, periods, section, explicit = "", Tuple{String,String}[], String[], "", false
    colperiod, rowperiod = Dict{String,String}(), Dict{String,String}()
    for (header, f) in smps_lines(path)
        if header
            section = uppercase(f[1])
            section == "NAME" && (section = "TIME")    # as some of SMI's files have it
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
    length(periods) >= 2 || error("$path: $(length(periods)) period(s); at least two are needed")
    allunique(periods) || error("$path: a period is given twice")
    (; rowindex, colindex, rows, columns) = cor
    colstage, rowstage = ones(Int, length(columns)), ones(Int, length(rows))
    if explicit                                     # a column or row not listed is in the first
        periodindex = Dict(p => t for (t, p) in enumerate(periods))
        for (list, index, stage, what) in ((colperiod, colindex, colstage, "column"),
                                           (rowperiod, rowindex, rowstage, "row"))
            for (label, p) in list
                haskey(periodindex, p) || error("$path: unknown period $p of the $what $label")
                if haskey(index, label)
                    stage[index[label]] = periodindex[p]
                elseif what == "column"
                    error("$path: unknown column $label")
                end                                 # a row: the objective or another free row
            end
        end
    else                                            # each period from its first column and row on
        for t in 2:length(periods)
            c, r = starts[t]
            haskey(colindex, c) || error("$path: unknown column $c (the first of period $(periods[t]))")
            haskey(rowindex, r) || error("$path: unknown row $r (the first of period $(periods[t]))")
            t == 2 || (colindex[c] > colindex[starts[t-1][1]] && rowindex[r] > rowindex[starts[t-1][2]]) ||
                error("$path: period $(periods[t]) starts before period $(periods[t-1]) in the core file")
            colstage[colindex[c]:end] .= t
            rowstage[rowindex[r]:end] .= t
        end
    end
    stage2col, stage2row = Set(findall(>=(2), colstage)), Set(findall(>=(2), rowstage))
    return (; name, periods, colstage, rowstage, stage2col, stage2row)
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
            section == "NAME" && (section = "STOCH")    # as some of SMI's files have it
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
        probabilities[k] = checked_probabilities(path, blocks[k], p, halfunits[k], probability_sums)
    end
    return (; path, name, elementnames, blocks, probabilities, realizations, modifiers, continuous)
end

"""The probabilities `p` of the outcomes of `block`, written with the half units `halfunits`, as
`probability_sums` says to take them when they do not sum up to one (see [`read_smps`](@ref))."""
function checked_probabilities(path, block, p, halfunits, probability_sums::Symbol)
    total, gap = sum(p), abs(sum(p) - 1)
    if probability_sums === :as_written
        gap > 1e-9 && @warn "$path: the probabilities of $block sum up to $total; kept as written"
        return p
    end
    slack = sum(halfunits)
    probability_sums === :rounding && gap > slack + 1e-12 &&
        error("$path: the probabilities of $block sum up to $total, beyond the rounding " *
              "of their digits ($slack); pass probability_sums = :normalize or :as_written to read them")
    gap > 1e-9 && @warn "$path: the probabilities of $block sum up to $total; normalized"
    return p ./ total
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
    (; c, lb, ub, b, rg) = core_vectors(cor, sign)
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
            sort!([e => signs[e] * modified(modifier, core[e], v) + 0.0 for (e, v) in realization])
        end
    end
    continuous = [(e, distribution(sto.path, kind, p1, p2), modifier, signs[e])
                  for (e, kind, p1, p2, modifier) in sto.continuous]
    law = SMPSLaw(signs .* core .+ 0.0, sto.probabilities, outcomes, continuous)
    return SMPSProblem(cor.name, sense, objective, c[cols1], A, senses[rows1], b[rows1], rg[rows1],
                       lb[cols1], ub[cols1], [j in integer for j in cols1],
                       c[cols2], W, senses[rows2], b[rows2], rg[rows2], T,
                       lb[cols2], ub[cols2], [j in integer for j in cols2], sign * cor.constant + 0.0,
                       columns[cols1], columns[cols2], rows[rows1], rows[rows2],
                       elements, sto.elementnames, law)
end

"""The costs (those of a maximization negated), the bounds, the right-hand sides and the ranges
of the core file `cor`, as vectors in its order."""
function core_vectors(cor, sign::Float64)
    (; rows, columns, cost, rhs, ranges, lower, upper) = cor
    c = [sign * get(cost, j, 0.0) + 0.0 for j in eachindex(columns)]   # + 0.0: no negative zero
    lb = [get(lower, j, 0.0) for j in eachindex(columns)]
    ub = [get(upper, j, Inf) for j in eachindex(columns)]
    for j in eachindex(columns)                     # MPS: a negative upper bound alone frees x
        !haskey(lower, j) && ub[j] < 0 && (lb[j] = -Inf)
    end
    b = [get(rhs, i, 0.0) for i in eachindex(rows)]
    rg = [get(ranges, i, NaN) for i in eachindex(rows)]
    return (; c, lb, ub, b, rg)
end

# ---- the stoch file of an instance in more than two periods: its scenario tree

const BOUND_TYPES = ("UP", "LO", "FX", "FR", "MI", "PL", "BV", "LI", "UI")

function read_tree(path::AbstractString, cor, tim, probability_sums::Symbol)
    (; rowindex, colindex, entries, objective, rangenames, boundnames) = cor
    (; periods, colstage, rowstage) = tim
    periodindex = Dict(p => t for (t, p) in enumerate(periods))
    # the random elements: (col, row) names => index, and their periods
    elementindex = Dict{Tuple{String,String},Int}()
    elementnames, elementperiod = Tuple{String,String}[], Int[]
    function element(col, row)
        get!(elementindex, (col, row)) do
            t = if haskey(colindex, col)
                j = colindex[col]
                if row == objective
                    colstage[j]
                else
                    haskey(rowindex, row) || error("$path: unknown row $row")
                    haskey(entries, (rowindex[row], j)) ||
                        error("$path: random entry ($row, $col) absent from the core file")
                    rowstage[rowindex[row]]
                end
            else
                col in rangenames && error("$path: random range of $row: not supported")
                col in boundnames && error("$path: random bound of $row: not supported")
                row == objective && error("$path: random constant of the objective: not supported")
                haskey(rowindex, row) || error("$path: unknown row $row")
                rowstage[rowindex[row]]
            end
            push!(elementnames, (col, row))
            push!(elementperiod, t)
            return length(elementnames)
        end
    end
    # the scenarios, as given
    names, parents, branch = String[], String[], Int[]
    probabilities, halfunits = Float64[], Float64[]
    given = Dict{Int,Float64}[]                     # per scenario: element => value
    scenarioindex = Dict{String,Int}()
    name, section = "", ""
    for (header, f) in smps_lines(path)
        if header
            section = uppercase(f[1])
            section == "SCEN" && (section = "SCENARIOS")
            section == "NAME" && (section = "STOCH")
            if section == "STOCH"
                name = join(f[2:end], " ")
            elseif section == "SCENARIOS"
                kind = length(f) > 1 ? uppercase(f[2]) : "DISCRETE"
                kind == "DISCRETE" || error("$path: SCENARIOS $kind is not supported, only DISCRETE")
                word = length(f) > 2 ? uppercase(f[3]) : "REPLACE"
                word == "REPLACE" ||
                    error("$path: SCENARIOS $word is not supported: scenarios replace the values")
            elseif section in ("INDEP", "BLOCKS")
                error("$path: $section in $(length(periods)) periods is not supported, only SCENARIOS")
            elseif section != "ENDATA"
                error("$path: section $section is not supported")
            end
            continue
        end
        section == "SCENARIOS" || error("$path: data outside a SCENARIOS section: $(join(f, ' '))")
        if f[1] == "SC"
            length(f) >= 5 || error("$path: incomplete SC line $(join(f, ' ')): a scenario needs " *
                                    "a name, a parent, a probability and a period")
            scenario, parent, period = f[2], strip(f[3], '\''), strip(f[5], '\'')
            haskey(scenarioindex, scenario) && error("$path: scenario $scenario given twice")
            parent == "ROOT" || haskey(scenarioindex, parent) ||
                error("$path: scenario $scenario branches from $parent, not given before it")
            haskey(periodindex, period) || error("$path: unknown period $period of scenario $scenario")
            push!(names, scenario)
            push!(parents, parent)
            push!(branch, periodindex[period])
            push!(probabilities, number(f[4]))
            push!(halfunits, half_unit(f[4]))
            push!(given, Dict{Int,Float64}())
            scenarioindex[scenario] = length(names)
        else
            isempty(names) && error("$path: an entry before the first SC line")
            length(f) == 4 && uppercase(f[1]) in BOUND_TYPES &&
                error("$path: random bound of $(f[3]): not supported")
            length(f) in (3, 5) || error("$path: malformed line $(join(f, ' '))")
            s = length(names)
            for k in 2:2:(length(f) - 1)
                e = element(f[1], f[k])
                elementperiod[e] >= branch[s] ||
                    error("$path: scenario $(names[s]) branches in period $(periods[branch[s]]), but " *
                          "changes ($(f[1]), $(f[k])), of period $(periods[elementperiod[e]])")
                given[s][e] = number(f[k+1])
            end
        end
    end
    if isempty(names)                               # no scenario: the core problem alone
        push!(names, "")
        push!(parents, "ROOT")
        push!(branch, 1)
        push!(probabilities, 1.0)
        push!(halfunits, 0.0)
        push!(given, Dict{Int,Float64}())
    end
    probabilities = checked_probabilities(path, "the scenarios", probabilities, halfunits,
                                          probability_sums)
    # the values of each scenario: its parent's, and those it gives
    values = Vector{Dict{Int,Float64}}(undef, length(names))
    for s in eachindex(names)
        values[s] = parents[s] == "ROOT" ? copy(given[s]) :
                    merge(values[scenarioindex[parents[s]]], given[s])
    end
    # the nodes: a scenario shares its parent's before its branching period, has its own after
    T = length(periods)
    nodeperiod, parentnode, owner = Int[], Int[], Int[]    # owner: whose values, 0 for the core
    rootnodes = Dict{Int,Int}()                     # the nodes of ROOT, by period
    newnode(t, p, o) = (push!(nodeperiod, t); push!(parentnode, p); push!(owner, o); length(owner))
    paths = [zeros(Int, T) for _ in names]
    for s in eachindex(names)
        parent = parents[s] == "ROOT" ? 0 : scenarioindex[parents[s]]
        for t in 1:T
            previous = t == 1 ? 0 : paths[s][t-1]
            paths[s][t] = if t >= branch[s]
                newnode(t, previous, s)
            elseif parent == 0
                get!(() -> newnode(t, previous, 0), rootnodes, t)
            else
                paths[parent][t]
            end
        end
    end
    roots = count(==(1), nodeperiod)
    roots == 1 || error("$path: $roots nodes in the first period, $(periods[1]): only one scenario " *
                        "may branch from ROOT in the first period, and then no other from ROOT")
    nodeprobability = zeros(length(nodeperiod))
    for (s, nodes) in enumerate(paths), n in nodes
        nodeprobability[n] += probabilities[s]
    end
    nodevalues = map(eachindex(owner)) do n
        o = owner[n]
        o == 0 ? Pair{Int,Float64}[] :
        sort!([e => v for (e, v) in values[o] if elementperiod[e] == nodeperiod[n]])
    end
    return (; path, name, elementnames, elementperiod, nodeperiod, parentnode, nodeprobability,
            nodevalues, paths, names, probabilities)
end

function assemble_tree(cor, tim, tr, sign::Float64, sense::Symbol)
    (; rows, senses, columns, rowindex, colindex, entries, integer, objective) = cor
    (; periods, colstage, rowstage) = tim
    I, J, V = Int[], Int[], Float64[]
    for ((i, j), v) in entries
        colstage[j] <= rowstage[i] ||
            error("the variable $(columns[j]) of period $(periods[colstage[j]]) in the row " *
                  "$(rows[i]) of period $(periods[rowstage[i]])")
        push!(I, i); push!(J, j); push!(V, v)
    end
    A = sparse(I, J, V, length(rows), length(columns))  # the zeros written kept as entries
    (; c, lb, ub, b, rg) = core_vectors(cor, sign)
    elements = map(tr.elementnames) do (col, row)
        haskey(colindex, col) || return (:rhs, rowindex[row], 0)
        row == objective && return (:c, colindex[col], 0)
        return (:A, rowindex[row], colindex[col])
    end
    signs = [kind === :c ? sign : 1.0 for (kind, _, _) in elements]
    values = [[e => signs[e] * v + 0.0 for (e, v) in node] for node in tr.nodevalues]
    return SMPSTree(cor.name, sense, objective, periods, columns, rows, colstage, rowstage, c, A,
                    senses, b, rg, lb, ub, [j in integer for j in eachindex(columns)],
                    sign * cor.constant + 0.0, elements, tr.elementnames, tr.elementperiod,
                    tr.nodeperiod, tr.parentnode, tr.nodeprobability, values, tr.paths, tr.names,
                    tr.probabilities)
end
