# A multistage problem read from SMPS files: its scenario tree.

"""
    SMPSTree

A problem in more than two periods read by [`read_smps`](@ref), with a discrete scenario tree:

    min  E[ Σ_t c_t(ξ)' x_t ] + constant
    s.t. Σ_{τ ≤ t} A_tτ(ξ) x_τ ~ b_t(ξ)   for each period t   (senses, ranges)
         lb ≤ x ≤ ub,  some of them integer,
         x_t depends only on the history of ξ up to period t (nonanticipativity)

- **The core data**, in the order of the core file: `c`, `A` (rows × columns), `senses`, `rhs`,
  `ranges` (`NaN` for none; see [`row_bounds`](@ref)), `lb`, `ub`, `integer`, `constant`.
  `colperiod[j]` and `rowperiod[i]` give the period of each column and row, among `periods`.
- **Random elements**: `elements` lists them as `(kind, i, j)`: `(:rhs, i, 0)` is the right-hand
  side of row `i`; `(:A, i, j)` the coefficient of column `j` in row `i`; `(:c, j, 0)` the cost of
  column `j`; `(:lb, j, 0)` and `(:ub, j, 0)` its lower and upper bounds. `names` gives, for each,
  the column and row names of the files, or, for a bound, its type (`LO` or `UP`) and the column;
  `elementperiod` its period: that of its row, or of its column for a cost or a bound.
- **The tree**: node `n` lies in period `nodeperiod[n]`, has the parent `parent[n]` (0 for the
  root, node 1) and the probability `probability[n]`, the sum of those of the scenarios through
  it. `values[n]` holds the values its random elements of that period take there (`element =>
  value`); an element it does not list keeps its value in the core file.
- **The scenarios**: `scenarios[s]` is the path of scenario `s`, its node in each period;
  `scenarionames[s]` and `scenarioprobability[s]` its name and probability, as read (see
  `probability_sums` in [`read_smps`](@ref)).
- **Sense**: as for [`SMPSProblem`](@ref), a maximization is stored as the minimization of the
  opposite objective: the costs, random ones included, and the constant are negated.

[`scenario_data`](@ref) gives the data of one scenario, [`bundles`](@ref) the scenarios that share
a node, and, with JuMP loaded, [`extensive_form`](@ref) the deterministic equivalent on the tree.
"""
struct SMPSTree
    name::String
    sense::Symbol
    objective::String
    periods::Vector{String}
    columns::Vector{String}
    rows::Vector{String}
    colperiod::Vector{Int}
    rowperiod::Vector{Int}
    c::Vector{Float64}
    A::SparseMatrixCSC{Float64,Int}
    senses::Vector{Char}
    rhs::Vector{Float64}
    ranges::Vector{Float64}
    lb::Vector{Float64}
    ub::Vector{Float64}
    integer::Vector{Bool}
    constant::Float64
    elements::Vector{Tuple{Symbol,Int,Int}}
    names::Vector{Tuple{String,String}}
    elementperiod::Vector{Int}
    nodeperiod::Vector{Int}
    parent::Vector{Int}
    probability::Vector{Float64}
    values::Vector{Vector{Pair{Int,Float64}}}
    scenarios::Vector{Vector{Int}}
    scenarionames::Vector{String}
    scenarioprobability::Vector{Float64}
end

function Base.show(io::IO, tree::SMPSTree)
    perperiod = [count(==(t), tree.nodeperiod) for t in eachindex(tree.periods)]
    print(io, "SMPS tree ", tree.name, ": ", length(tree.periods), " periods, ",
          length(tree.scenarios), " scenarios, ", length(tree.nodeperiod), " nodes (",
          join(perperiod, ", "), " by period), ", length(tree.columns), " columns and ",
          length(tree.rows), " rows, ", length(tree.elements), " random elements")
end

"""
    scenario_data(tree::SMPSTree, s)

The data of scenario `s` over all periods, the random elements of each period set to their
values at the node of `s` in that period: the named tuple `(c = ..., A = ..., rhs = ..., lb = ...,
ub = ...)`, copies of those of `tree`. The senses and ranges are those of `tree`.
"""
function scenario_data(tree::SMPSTree, s::Integer)
    d = (c = copy(tree.c), A = copy(tree.A), rhs = copy(tree.rhs), lb = copy(tree.lb), ub = copy(tree.ub))
    for n in tree.scenarios[s], (e, v) in tree.values[n]
        set_element!(d, tree.elements[e]..., v)
    end
    return d
end

"""
    bundles(tree::SMPSTree, t)

The scenarios that share a node in period `t`, as a vector of vectors of scenario indices, one per
node of period `t`: those whose decisions of period `t` must be equal (nonanticipativity).
"""
function bundles(tree::SMPSTree, t::Integer)
    1 <= t <= length(tree.periods) || error("period $t of a tree with $(length(tree.periods)) periods")
    groups = Dict{Int,Vector{Int}}()
    for (s, path) in enumerate(tree.scenarios)
        push!(get!(groups, path[t], Int[]), s)
    end
    return [groups[n] for n in sort!(collect(keys(groups)))]
end

"""
    scenario_tree(smps::SMPSProblem; limit = 100_000)
    scenario_tree(smps::SMPSProblem, ξ, p)
    sample_tree([rng,] smps::SMPSProblem, n)

The two-stage problem `smps` as an [`SMPSTree`](@ref) in two periods, `PERIOD1` and `PERIOD2`: the
root and a node per scenario, the first stage before the second. The scenarios are every point of
the support of its law (an error beyond `limit`), those given (`ξ`, as
[`enumerate_scenarios`](@ref) or `rand` give them, with the probabilities `p`), or `n` draws of its
law, each with probability `1 / n`. What applies to trees then applies to it:
[`scenario_data`](@ref), [`bundles`](@ref), [`extensive_form`](@ref), [`write_smps`](@ref).
"""
function scenario_tree(smps::SMPSProblem, ξ::AbstractVector, p::AbstractVector)
    length(ξ) == length(p) || error("$(length(ξ)) scenarios but $(length(p)) probabilities")
    d = two_stage_core(smps)
    n1, m1 = length(smps.columns1), length(smps.rows1)
    elements = map(smps.elements) do (kind, i, j)
        kind === :h && return (:rhs, m1 + i, 0)
        kind === :q && return (:c, n1 + i, 0)
        kind === :T && return (:A, m1 + i, j)
        kind === :W && return (:A, m1 + i, n1 + j)
        return (kind, n1 + i, 0)                    # a bound
    end
    base, S = smps.law.base, length(ξ)
    values = [[Pair{Int,Float64}[]];
              [[e => v for (e, v) in enumerate(point) if v != base[e]] for point in ξ]]
    return SMPSTree(smps.name, smps.sense, smps.objective, ["PERIOD1", "PERIOD2"], d.columns, d.rows,
                    d.colperiod, d.rowperiod, d.c, d.A, d.senses, d.rhs, d.ranges, d.lb, d.ub,
                    d.integer, smps.constant, elements, smps.names, fill(2, length(elements)),
                    [1; fill(2, S)], [0; fill(1, S)], [sum(p); collect(Float64, p)], values,
                    [[1, 1 + s] for s in 1:S], ["S$s" for s in 1:S], collect(Float64, p))
end

scenario_tree(smps::SMPSProblem; limit::Integer = 100_000) =
    scenario_tree(smps, enumerate_scenarios(smps.law; limit)...)
sample_tree(rng::AbstractRNG, smps::SMPSProblem, n::Integer) =
    scenario_tree(smps, rand(rng, smps.law, n), fill(1 / n, n))
sample_tree(smps::SMPSProblem, n::Integer) = sample_tree(Random.default_rng(), smps, n)
