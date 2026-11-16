# Writing an instance in StochOptFormat: a policy graph whose nodes solve subproblems written in
# MathOptFormat, the whole in JSON.

"""
    write_sof(filename, smps::SMPSProblem; scenarios = nothing, random_variables = true,
              limit = 100_000, name = smps.name, author = "", description = ...)
    write_sof(filename, tree::SMPSTree; random_variables = true, ...)
    write_sof(filename, s::SMPSStagewise; random_variables = true, limit = 100_000, ...)
    write_sof(io::IO, x; ...)

Write an instance in StochOptFormat 1.0 (Dowson et al., <https://odow.github.io/StochOptFormat>),
the JSON format of SDDP.jl for multistage stochastic programs, and return `filename`; a name that
ends with `.gz` is compressed with gzip. SDDP.jl reads it with `SDDP.read_from_file(filename)`.

StochOptFormat describes a problem as a policy graph: nodes linked, from a root, by the
probabilities of passing from one to the next, each solving a subproblem in MathOptFormat that
receives the values of the state variables from the node before and passes them on. The random
variables of a subproblem take, in each node, the values of one of its realizations.

- **Periods and states.** The subproblem of a period has its columns and rows, named as in the
  core file. A column that a row of a later period involves is a state variable: `COL` in the
  subproblem of its period, which passes it on; in every other subproblem, the pair `COL_in`,
  `COL_out`, with `COL_out == COL_in`, which carries its value, so that every subproblem has
  every state variable, as SDDP.jl requires. The rows of a later period involve `COL_in`. The
  root sets every state to 0, a value no period uses before its own.
- **The objective** is in the sense of the problem read; the constant of the core file is that
  of the first period.
- **Random variables** (`random_variables = true`): the nodes of a period share its subproblem,
  in which each random element of the period is a variable, fixed to its value in each
  realization: `RHS(row)`, a right-hand side, enters its row as `row − RHS(row)`, whose interval
  is then that of a right-hand side of 0, its range included; `LO(col)` and `UP(col)`, bounds,
  are the rows `col − LO(col) ≥ 0` and `col − UP(col) ≤ 0`; `COST(col)`, a cost, the term
  `COST(col) × col` of the objective; `COEF(col,row)`, a coefficient, the term `COEF(col,row) ×
  col` of the row, which is then quadratic. SDDP.jl reads the first three kinds, but not random
  coefficients of the rows (59 of the 208 instances of the validation have some). A random
  variable takes finite values only: a bound infinite in some node calls for the next form.
- **The data of each node** (`random_variables = false`): each node has its own subproblem, the
  random elements set to their values there, without random variables: as many subproblems as
  nodes, each a linear program (or a mixed integer one), whatever its random elements.

The graph:

- **A two-stage problem**: the nodes `PERIOD1` and `PERIOD2`, whose realizations are its
  scenarios: every point of the support of its law (an error beyond `limit` of them), or those
  given, `scenarios = (ξ = ..., p = ...)`, as [`enumerate_scenarios`](@ref) or `rand` give them.
  With `random_variables = false`, a node `PERIOD2_s` for each scenario `s`, which `PERIOD1`
  reaches with its probability.
- **A law by period**: a node per period, named after it, whose realizations are the points of
  the support of the law of that period (an error beyond `limit` of them): stagewise
  independence, as SDDP.jl treats it. With `random_variables = false`, a node `PERIOD_k` for
  each point `k` of that support, which every node of the period before reaches with its
  probability. An element revealed before the period of its data (see [`SMPSStagewise`](@ref))
  cannot be written so: write its scenario tree ([`scenario_tree`](@ref), [`sample_tree`](@ref)).
- **A tree**: a node `PERIOD_n` for each node `n` of the tree, in period `PERIOD`, which its
  parent reaches with its conditional probability, its one realization the values of its random
  elements.

The probabilities are written as read, those of the scenarios kept as written included (see
`probability_sums` in [`read_smps`](@ref)): the root reaches the first node of a tree with the
sum of the probabilities of its scenarios (the constant of the objective divided by it), unless
that sum exceeds one, which StochOptFormat cannot write: the tree is then normalized, with a
warning.

A continuous law has no counterpart in StochOptFormat: sample it (`rand`, [`sample_tree`](@ref))
and write the sample. `name`, `author` and `description` are those of the file.
"""
function write_sof(filename::AbstractString, x::Union{SMPSProblem,SMPSTree,SMPSStagewise}; kwargs...)
    open(filename, "w") do file
        if endswith(filename, ".gz")
            stream = GzipCompressorStream(file)
            try
                write_sof(stream, x; kwargs...)
            finally
                close(stream)
            end
        else
            write_sof(file, x; kwargs...)
        end
    end
    return filename
end

function write_sof(io::IO, smps::SMPSProblem; scenarios = nothing, random_variables::Bool = true,
                   limit::Integer = 100_000, kwargs...)
    if scenarios === nothing
        isdiscrete(smps.law) ||
            error("$(smps.name): its law has continuous elements, which StochOptFormat cannot write: ",
                  "pass scenarios drawn from it, `scenarios = (ξ = rand(rng, law, n), p = fill(1 / n, n))`")
        scenarios = enumerate_scenarios(smps.law; limit)
    end
    (; ξ, p) = scenarios
    length(ξ) == length(p) || error("$(length(ξ)) scenarios but $(length(p)) probabilities")
    d = staged(smps)
    E = collect(eachindex(d.elements))
    if random_variables
        subproblems = [("PERIOD1", 1, Int[], Dict{Int,Float64}()), ("PERIOD2", 2, E, Dict{Int,Float64}())]
        nodes = [graph_node("PERIOD1", "PERIOD1"; successors = ["PERIOD2" => 1.0]),
                 graph_node("PERIOD2", "PERIOD2"; random = E,
                            realizations = [(Float64(p[s]), collect(Float64, ξ[s])) for s in eachindex(ξ)])]
    else
        second = ["PERIOD2_$s" for s in eachindex(ξ)]
        subproblems = [("PERIOD1", 1, Int[], Dict{Int,Float64}());
                       [(second[s], 2, Int[], Dict{Int,Float64}(zip(E, ξ[s]))) for s in eachindex(ξ)]]
        nodes = [graph_node("PERIOD1", "PERIOD1"; successors = second .=> Float64.(p));
                 [graph_node(n, n) for n in second]]
    end
    return write_graph(io, d, nodes, subproblems; kwargs...)
end

function write_sof(io::IO, s::SMPSStagewise; random_variables::Bool = true, limit::Integer = 100_000,
                   kwargs...)
    for e in eachindex(s.elements)
        s.revealperiod[e] == s.elementperiod[e] && continue
        error("$(s.name): the element $(elementname(s, e)) of period $(s.periods[s.elementperiod[e]]) is ",
              "revealed in period $(s.periods[s.revealperiod[e]]), before it, which a policy graph cannot ",
              "write: write its scenario tree (scenario_tree, sample_tree)")
    end
    T = length(s.periods)
    supports = map(1:T) do t
        (t == 1 || isempty(s.lawelements[t])) && return nothing
        isdiscrete(s.laws[t]) ||
            error("$(s.name): the law of period $(s.periods[t]) has continuous elements, which StochOptFormat ",
                  "cannot write: write a sampled tree (sample_tree)")
        return enumerate_scenarios(s.laws[t]; limit)
    end
    if random_variables
        subproblems = [(s.periods[t], t, t == 1 ? Int[] : s.lawelements[t], Dict{Int,Float64}()) for t in 1:T]
        nodes = map(1:T) do t
            support = supports[t]
            realizations = support === nothing ? Tuple{Float64,Vector{Float64}}[] :
                           [(p, ξ) for (ξ, p) in zip(support.ξ, support.p)]
            return graph_node(s.periods[t], s.periods[t]; random = subproblems[t][3], realizations,
                              successors = t < T ? [s.periods[t+1] => 1.0] : Pair{String,Float64}[])
        end
    else
        # the nodes of each period: their names, probabilities and values of the random elements
        layers = map(1:T) do t
            support = supports[t]
            support === nothing && return [(s.periods[t], 1.0, Dict{Int,Float64}())]
            return [("$(s.periods[t])_$k", support.p[k], Dict{Int,Float64}(zip(s.lawelements[t], support.ξ[k])))
                    for k in eachindex(support.p)]
        end
        subproblems = [(n, t, Int[], values) for t in 1:T for (n, _, values) in layers[t]]
        nodes = [graph_node(n, n; successors = t < T ? [m => q for (m, q, _) in layers[t+1]] :
                                               Pair{String,Float64}[])
                 for t in 1:T for (n, _, _) in layers[t]]
    end
    return write_graph(io, staged(s), nodes, subproblems; kwargs...)
end

function write_sof(io::IO, tree::SMPSTree; random_variables::Bool = true, kwargs...)
    total = tree.probability[1]
    total > 1 + 1e-9 && @warn "$(tree.name): the probabilities of the scenarios sum up to $total, more " *
                              "than one, which StochOptFormat cannot write: they are normalized"
    d = staged(tree)
    T, N = length(tree.periods), length(tree.nodeperiod)
    nodename = ["$(tree.periods[tree.nodeperiod[n]])_$n" for n in 1:N]
    children = [Int[] for _ in 1:N]
    foreach(n -> push!(children[tree.parent[n]], n), 2:N)
    p = tree.probability
    successors(n) = [nodename[k] => (p[n] > 0 ? p[k] / p[n] : 0.0) for k in children[n]]
    if random_variables
        random = [t == 1 ? Int[] : findall(==(t), tree.elementperiod) for t in 1:T]
        subproblems = [(tree.periods[t], t, random[t], t == 1 ? Dict{Int,Float64}(tree.values[1]) :
                                                       Dict{Int,Float64}()) for t in 1:T]
        nodes = map(1:N) do n
            t = tree.nodeperiod[n]
            values = Dict(tree.values[n])
            realizations = t == 1 || isempty(random[t]) ? Tuple{Float64,Vector{Float64}}[] :
                           [(1.0, [get(values, e, core_value(d, d.elements[e])) for e in random[t]])]
            return graph_node(nodename[n], tree.periods[t]; random = random[t], realizations,
                              successors = successors(n))
        end
    else
        subproblems = [(nodename[n], tree.nodeperiod[n], Int[], Dict{Int,Float64}(tree.values[n])) for n in 1:N]
        nodes = [graph_node(nodename[n], nodename[n]; successors = successors(n)) for n in 1:N]
    end
    return write_graph(io, d, nodes, subproblems; root = min(total, 1.0), kwargs...)
end

"""A node of the policy graph: its name, its subproblem, the random elements of its subproblem
(`random`), its realizations (each a probability and the values of these elements, in their
order), and its successors (node name => probability)."""
graph_node(name, subproblem; random = Int[], realizations = Tuple{Float64,Vector{Float64}}[],
           successors = Pair{String,Float64}[]) = (; name, subproblem, random, realizations, successors)

"""The data of an instance by period, in the numbering of [`SMPSTree`](@ref)."""
function staged(smps::SMPSProblem)
    d = two_stage_core(smps)
    return (; d..., name = smps.name, sense = smps.sense, periods = ["PERIOD1", "PERIOD2"],
            constant = smps.constant, elements = two_stage_elements(smps),
            elementperiod = fill(2, length(smps.elements)))
end
staged(x::Union{SMPSTree,SMPSStagewise}) =
    (name = x.name, sense = x.sense, periods = x.periods, columns = x.columns, rows = x.rows,
     colperiod = x.colperiod, rowperiod = x.rowperiod, c = x.c, A = x.A, senses = x.senses,
     rhs = x.rhs, ranges = x.ranges, lb = x.lb, ub = x.ub, integer = x.integer, constant = x.constant,
     elements = x.elements, elementperiod = x.elementperiod)

"""The name of the random element `e` of `d`, as a variable of StochOptFormat."""
function elementname(d, e)
    kind, i, j = d.elements[e]
    kind === :rhs && return "RHS($(d.rows[i]))"
    kind === :c && return "COST($(d.columns[i]))"
    kind === :A && return "COEF($(d.columns[j]),$(d.rows[i]))"
    return (kind === :lb ? "LO(" : "UP(") * d.columns[i] * ")"
end

"""The value of the element `(kind, i, j)` in the core data of `d`."""
core_value(d, (kind, i, j)) = kind === :rhs ? d.rhs[i] : kind === :c ? d.c[i] : kind === :A ? d.A[i, j] :
                              kind === :lb ? d.lb[i] : d.ub[i]

"""The columns whose values a row of a later period involves: the state variables."""
function state_columns(d)
    last = copy(d.colperiod)
    function involve(i, j)
        d.rowperiod[i] < d.colperiod[j] &&
            error("$(d.name): the row $(d.rows[i]) of period $(d.periods[d.rowperiod[i]]) involves the column ",
                  "$(d.columns[j]) of the later period $(d.periods[d.colperiod[j]])")
        last[j] = max(last[j], d.rowperiod[i])
    end
    for j in axes(d.A, 2), k in nzrange(d.A, j)
        nonzeros(d.A)[k] == 0 || involve(rowvals(d.A)[k], j)
    end
    foreach(((kind, i, j),) -> kind === :A && involve(i, j), d.elements)
    return [j for j in eachindex(d.columns) if last[j] > d.colperiod[j]]
end

"""The names of the variables StochOptFormat adds to the columns: `inname` and `outname`, those of the
state variables, and `element`, those of the random elements; each distinct from the others and
from the columns (a prime appended until it is)."""
function sof_names(d, states)
    taken = Set{String}(d.columns)
    fresh(name) = (while name in taken; name *= "'"; end; push!(taken, name); name)
    inname = Dict(j => fresh(d.columns[j] * "_in") for j in states)
    outname = Dict(j => fresh(d.columns[j] * "_out") for j in states)
    element = [fresh(elementname(d, e)) for e in eachindex(d.elements)]
    return (; inname, outname, element)
end

"""The value of the random element `e` as the file writes it: a cost in the sense of the problem
read."""
function written(d, names, e, v)
    w = (d.elements[e][1] === :c && d.sense === :max ? -v : v) + 0.0   # + 0.0: no negative zero
    isfinite(w) || error("$(d.name): the random element $(names.element[e]) takes the value $w, which a ",
                         "random variable cannot take in StochOptFormat: write with random_variables = false")
    return w
end

"""Write the policy graph of `nodes`, the first reached from the root with the probability
`root`, whose subproblems are `subproblems`: each its name, its period, its random elements and
the values it sets."""
function write_graph(io::IO, d, nodes, subproblems; root::Float64 = 1.0, name::AbstractString = d.name,
                     author::AbstractString = "",
                     description::AbstractString = "The SMPS instance $(d.name), written by SMPSFormat.jl.")
    states = state_columns(d)
    names = sof_names(d, states)
    rowelements = Dict{Int,Vector{Int}}()            # a row => the random coefficients in it
    for (e, (kind, i, _)) in enumerate(d.elements)
        kind === :A && push!(get!(rowelements, i, Int[]), e)
    end
    context = (; d, states, names, At = sparse(d.A'), rowelements, root)
    members = Pair{String,Any}["name" => name]
    isempty(author) || push!(members, "author" => author)
    push!(members, "description" => description,
          "version" => object("major" => 1, "minor" => 0),
          "root" => object("state_variables" => JSONObject([d.columns[j] => 0.0 for j in states]),
                           "successors" => object(nodes[1].name => root)),
          "nodes" => JSONObject(node.name => node_json(d, names, node) for node in nodes),
          "subproblems" => JSONObject(n => subproblem_json(context, t, random, values)
                                      for (n, t, random, values) in subproblems))
    json(io, JSONObject(members))
    println(io)
    return io
end

function node_json(d, names, node)
    members = Pair{String,Any}["subproblem" => node.subproblem]
    isempty(node.realizations) ||
        push!(members, "realizations" => [object("probability" => p,
                                                 "support" => JSONObject([names.element[e] => written(d, names, e, v)
                                                                          for (e, v) in zip(node.random, values)]);
                                                 inline = true)
                                          for (p, values) in node.realizations])
    isempty(node.successors) || push!(members, "successors" => JSONObject(node.successors))
    return JSONObject(members)
end

"""The subproblem of period `t` in StochOptFormat: its state variables, its random variables, the
random elements `random`, and its problem in MathOptFormat, the elements of `values` set to
their values there."""
function subproblem_json((; d, states, names, At, rowelements, root), t, random, values)
    sign = d.sense === :max ? -1.0 : 1.0
    randomvar = Dict(d.elements[e] => names.element[e] for e in random)   # an element => its variable
    setvalue = Dict(d.elements[e] => v for (e, v) in values)
    value(element, core) = get(setvalue, element, core)
    columns = findall(==(t), d.colperiod)
    variables = [d.columns[j] for j in columns]
    var = Dict(j => d.columns[j] for j in columns)     # the variable of each column the rows involve
    constraints = JSONObject[]
    statevariables = Pair{String,Any}[]
    for j in states
        xin, xout = names.inname[j], d.colperiod[j] == t ? d.columns[j] : names.outname[j]
        push!(variables, xin)
        if d.colperiod[j] != t                       # carried: out == in
            push!(variables, xout)
            push!(constraints, object("function" => affine([xout => 1.0, xin => -1.0]),
                                      "set" => interval_set(0.0, 0.0); inline = true))
            d.colperiod[j] < t && (var[j] = xin)
        end
        push!(statevariables, d.columns[j] => object("in" => xin, "out" => xout))
    end
    append!(variables, names.element[e] for e in random)
    for i in findall(==(t), d.rowperiod)
        terms, products = Pair{String,Float64}[], Tuple{String,String,Float64}[]
        entries = Dict(rowvals(At)[k] => nonzeros(At)[k] for k in nzrange(At, i))
        order = [rowvals(At)[k] for k in nzrange(At, i)]
        for e in get(rowelements, i, Int[])          # a random coefficient the core file does not have
            j = d.elements[e][3]
            haskey(entries, j) || (entries[j] = 0.0; push!(order, j))
        end
        for j in order
            element = (:A, i, j)
            if haskey(randomvar, element)
                push!(products, (randomvar[element], var[j], 1.0))
            else
                a = value(element, entries[j])
                a == 0 || push!(terms, var[j] => a)
            end
        end
        element = (:rhs, i, 0)
        if haskey(randomvar, element)
            push!(terms, randomvar[element] => -1.0)
            set = interval_set(row_bounds(d.senses[i], 0.0, d.ranges[i])...)
        else
            set = interval_set(row_bounds(d.senses[i], value(element, d.rhs[i]), d.ranges[i])...)
        end
        set === nothing && continue                  # a free row
        f = isempty(products) ? affine(terms) : quadratic(terms, products)
        push!(constraints, object("name" => d.rows[i], "function" => f, "set" => set; inline = true))
    end
    objective, products = Pair{String,Float64}[], Tuple{String,String,Float64}[]
    for j in columns
        x = d.columns[j]
        lower, upper = -Inf, Inf
        if haskey(randomvar, (:lb, j, 0))
            push!(constraints, object("function" => affine([x => 1.0, randomvar[(:lb, j, 0)] => -1.0]),
                                      "set" => interval_set(0.0, Inf); inline = true))
        else
            lower = value((:lb, j, 0), d.lb[j])
        end
        if haskey(randomvar, (:ub, j, 0))
            push!(constraints, object("function" => affine([x => 1.0, randomvar[(:ub, j, 0)] => -1.0]),
                                      "set" => interval_set(-Inf, 0.0); inline = true))
        else
            upper = value((:ub, j, 0), d.ub[j])
        end
        set = interval_set(lower, upper)
        set === nothing || push!(constraints, object("function" => variable(x), "set" => set; inline = true))
        d.integer[j] && push!(constraints, object("function" => variable(x), "set" => object("type" => "Integer");
                                                  inline = true))
        if haskey(randomvar, (:c, j, 0))
            push!(products, (randomvar[(:c, j, 0)], x, 1.0))
        else
            cj = sign * value((:c, j, 0), d.c[j]) + 0.0
            cj == 0 || push!(objective, x => cj)
        end
    end
    constant = t == 1 ? sign * d.constant / root + 0.0 : 0.0  # the root's probability weighs it
    f = isempty(products) ? affine(objective, constant) : quadratic(objective, products, constant)
    mof = object("version" => object("major" => 1, "minor" => 0),
                 "variables" => [object("name" => v) for v in variables],
                 "objective" => object("sense" => d.sense === :max ? "max" : "min", "function" => f),
                 "constraints" => constraints)
    members = Pair{String,Any}["state_variables" => JSONObject(statevariables)]
    isempty(random) || push!(members, "random_variables" => names.element[random])
    push!(members, "subproblem" => mof)
    return JSONObject(members)
end

# ---- MathOptFormat

affine(terms, constant = 0.0) =
    object("type" => "ScalarAffineFunction", "terms" => [object("variable" => v, "coefficient" => a) for (v, a) in terms],
           "constant" => constant; inline = true)
quadratic(terms, products, constant = 0.0) =
    object("type" => "ScalarQuadraticFunction",
           "affine_terms" => [object("variable" => v, "coefficient" => a) for (v, a) in terms],
           "quadratic_terms" => [object("variable_1" => u, "variable_2" => v, "coefficient" => a)
                                 for (u, v, a) in products],
           "constant" => constant; inline = true)
variable(x) = object("type" => "Variable", "name" => x)

"""The set of MathOptFormat of the interval `[lower, upper]`; `nothing` for the real line."""
function interval_set(lower, upper)
    lower == upper && return object("type" => "EqualTo", "value" => lower)
    isinf(lower) && isinf(upper) && return nothing
    isinf(lower) && return object("type" => "LessThan", "upper" => upper)
    isinf(upper) && return object("type" => "GreaterThan", "lower" => lower)
    return object("type" => "Interval", "lower" => lower, "upper" => upper)
end

# ---- JSON

"""An object of JSON: its members (pairs of a name and a value), in order, a vector or an
iterator, whose values are then built as the object is written; written on one line if
`inline`."""
struct JSONObject
    members::Any
    inline::Bool
end
JSONObject(members) = JSONObject(members, false)
object(members::Pair...; inline::Bool = false) = JSONObject(collect(Pair{String,Any}, members), inline)

"""Whether `x` is written on one line: an object written so, or one whose values, or an array
whose items, are numbers or strings."""
oneline(x::JSONObject) = x.inline || x.members isa AbstractVector && all(m -> !iscontainer(last(m)), x.members)
oneline(x::AbstractVector) = !any(iscontainer, x)
iscontainer(x) = x isa JSONObject || x isa AbstractVector

"""Write `x` in JSON, indented by `indent` levels, or on one line if `indent` is `nothing`."""
function json(io::IO, x::Union{JSONObject,AbstractVector}, indent = 0)
    isobject = x isa JSONObject
    indent = indent === nothing || oneline(x) ? nothing : indent
    print(io, isobject ? '{' : '[')
    first = true
    for item in (isobject ? x.members : x)
        first || print(io, indent === nothing ? ", " : ",")
        first = false
        indent === nothing || print(io, '\n', ' '^(2indent + 2))
        if isobject
            json(io, item.first)
            print(io, ": ")
            item = item.second
        end
        json(io, item, indent === nothing ? nothing : indent + 1)
    end
    indent === nothing || first || print(io, '\n', ' '^(2indent))
    print(io, isobject ? '}' : ']')
    return
end
json(io::IO, x::Integer, _ = nothing) = print(io, x)
function json(io::IO, x::AbstractFloat, _ = nothing)
    isfinite(x) || error("$x: JSON has no infinite numbers")
    print(io, Float64(x))                            # the shortest digits that read back exactly
end
function json(io::IO, s::AbstractString, _ = nothing)
    isvalid(s) || error("$(repr(s)): not valid UTF-8, which JSON requires")
    escaped(c) = c == '"' || c == '\\' || c < ' '
    print(io, '"')
    if any(escaped, s)
        for c in s
            c == '"' ? print(io, "\\\"") : c == '\\' ? print(io, "\\\\") :
            c < ' ' ? print(io, "\\u", string(UInt32(c); base = 16, pad = 4)) : print(io, c)
        end
    else
        print(io, s)                                 # names as they mostly are: nothing to escape
    end
    print(io, '"')
    return
end
