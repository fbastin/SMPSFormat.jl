# A multistage problem whose random data are independent from one period to the next.

"""
    SMPSStagewise

A problem in more than two periods read by [`read_smps`](@ref) from `INDEP` and `BLOCKS` sections:
its random data are revealed period by period, independently from one period to the next
(stagewise independence), and the law of each period is an [`SMPSLaw`](@ref). Its scenario tree,
the product of these laws, is not built: [`scenario_tree`](@ref) builds it when it is small enough,
[`sample_tree`](@ref) samples one, and `rand(rng, s)` draws the data of one scenario.

- **The core data** and **the random elements** are those of an [`SMPSTree`](@ref): `c`, `A`,
  `senses`, `rhs`, `ranges`, `lb`, `ub`, `integer`, `constant`, `colperiod`, `rowperiod`;
  `elements`, `names`, `elementperiod` (the period of the data each element sets).
- **The law**: `laws[t]` is the law of the elements revealed in period `t`, whose values form its
  `ξ` in the order of `lawelements[t]` (indices in `elements`); `laws[1]` has none.
  `revealperiod[e]` is the period element `e` is revealed in: the one its `INDEP` line or its
  block gives, at most the period of its data (a demand of period 3 may be known in period 2).
  `base` holds the values of the elements in the core file.
- **Sense**: a maximization is stored as the minimization of the opposite objective, the costs,
  random ones included, and the constant negated.
"""
struct SMPSStagewise
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
    revealperiod::Vector{Int}
    base::Vector{Float64}
    laws::Vector{SMPSLaw}
    lawelements::Vector{Vector{Int}}
end

function Base.show(io::IO, s::SMPSStagewise)
    sizes = [isdiscrete(l) ? string(support_size(l)) : "continuous" for l in s.laws[2:end]]
    print(io, "SMPS stagewise instance ", s.name, ": ", length(s.periods), " periods (outcomes by ",
          "period: ", join(sizes, ", "), "), ", length(s.columns), " columns and ", length(s.rows),
          " rows, ", length(s.elements), " random elements")
end

"""
    support_size(s::SMPSStagewise)

The number of scenarios of `s`, the product of the support sizes of the laws of its periods, as a
`BigInt`; an error if some period has continuous elements.
"""
support_size(s::SMPSStagewise) = prod(support_size(l) for l in s.laws; init = BigInt(1))

function Base.rand(rng::AbstractRNG, s::SMPSStagewise)
    ξ = copy(s.base)
    for (law, elements) in zip(s.laws, s.lawelements)
        isempty(elements) || (ξ[elements] = rand(rng, law))
    end
    return ξ
end
Base.rand(s::SMPSStagewise) = rand(Random.default_rng(), s)
Base.rand(rng::AbstractRNG, s::SMPSStagewise, n::Integer) = [rand(rng, s) for _ in 1:n]
Base.rand(s::SMPSStagewise, n::Integer) = rand(Random.default_rng(), s, n)

"""
    scenario_data(s::SMPSStagewise, ξ)

The data of the scenario where the random elements of `s` take the values `ξ`, as `rand(rng, s)`
draws them: the named tuple `(c = ..., A = ..., rhs = ..., lb = ..., ub = ...)`, copies of those of
`s` with the random elements set.
"""
function scenario_data(s::SMPSStagewise, ξ::AbstractVector)
    length(ξ) == length(s.elements) ||
        error("ξ has $(length(ξ)) values for $(length(s.elements)) random elements")
    d = (c = copy(s.c), A = copy(s.A), rhs = copy(s.rhs), lb = copy(s.lb), ub = copy(s.ub))
    for (v, (kind, i, j)) in zip(ξ, s.elements)
        set_element!(d, kind, i, j, v)
    end
    return d
end

"""Set the element `(kind, i, j)` to `v` in the data `d` of a tree or a stagewise instance."""
function set_element!(d, kind, i, j, v)
    if kind === :rhs
        d.rhs[i] = v
    elseif kind === :c
        d.c[i] = v
    elseif kind === :A
        d.A[i, j] = v
    elseif kind === :lb
        d.lb[i] = v
    else
        d.ub[i] = v
    end
    return d
end

"""
    scenario_tree(s::SMPSStagewise; limit = 100_000)

The scenario tree of `s`, as an [`SMPSTree`](@ref): each node of period `t − 1` has a child for each
point of the support of the law of period `t`, with the product of the probabilities. An error if
`s` has more than `limit` scenarios (sample a tree instead, [`sample_tree`](@ref)), or continuous
elements. A period without random data adds one child to each node.
"""
function scenario_tree(s::SMPSStagewise; limit::Integer = 100_000)
    size = support_size(s)
    size <= limit || error("$(s.name) has $size scenarios, more than the limit of $limit: sample a " *
                           "tree (sample_tree), or raise `limit`")
    supports = [enumerate_scenarios(law) for law in s.laws]
    return build_tree(s, (t, _) -> zip(supports[t].ξ, supports[t].p))
end

"""
    sample_tree([rng,] s::SMPSStagewise, branching; common = false)

A scenario tree sampled from the law of `s`, as an [`SMPSTree`](@ref): each node of period `t − 1`
has `branching[t − 1]` children (`branching` a vector of length `length(s.periods) − 1`, or an
integer, the same in every period), each drawn from the law of period `t` with probability `1 /
branching[t − 1]` times its parent's. The draws are independent from node to node (conditional
sampling); with `common = true`, the same draws serve every node of a period. A period without
random data adds one child to each node.
"""
function sample_tree(rng::AbstractRNG, s::SMPSStagewise, branching; common::Bool = false)
    T = length(s.periods)
    b = branching isa Integer ? fill(Int(branching), T - 1) : collect(Int, branching)
    length(b) == T - 1 || error("branching gives $(length(b)) numbers for $(T - 1) periods after the first")
    all(>(0), b) || error("branching must be positive")
    random(t) = !isempty(s.laws[t].probabilities) || !isempty(s.laws[t].continuous)
    draws(t) = (n = random(t) ? b[t-1] : 1; [(rand(rng, s.laws[t]), 1 / n) for _ in 1:n])
    shared = common ? [t == 1 ? [] : draws(t) for t in 1:T] : nothing
    return build_tree(s, (t, _) -> common ? shared[t] : draws(t))
end
sample_tree(s::SMPSStagewise, branching; kwargs...) = sample_tree(Random.default_rng(), s, branching; kwargs...)

"""The tree of `s` whose node of period `t` has the children `children(t, node)`: pairs of a
draw of the law of period `t + 1` and its probability, conditional on the node."""
function build_tree(s::SMPSStagewise, children)
    T = length(s.periods)
    # the elements whose data lie in each period, with where they are revealed
    position = Dict{Int,Int}()                       # an element => its index in its law's ξ
    for elements in s.lawelements, (k, e) in enumerate(elements)
        position[e] = k
    end
    ofperiod = [[e for e in eachindex(s.elements) if s.elementperiod[e] == t] for t in 1:T]
    nodeperiod, parent, probability = [1], [0], [1.0]
    draw = Vector{Vector{Float64}}([Float64[]])      # the draw of the law of each node's period
    values = [Pair{Int,Float64}[]]
    ancestors = [[1]]                                 # a node's ancestors by period, itself last
    frontier = [1]
    for t in 2:T
        next = Int[]
        for p in frontier, (ξ, q) in children(t, p)
            push!(nodeperiod, t)
            push!(parent, p)
            push!(probability, probability[p] * q)
            push!(draw, ξ)
            n = length(nodeperiod)
            push!(ancestors, [ancestors[p]; n])
            # the values of the elements of period t, revealed here or at an ancestor
            node = Pair{Int,Float64}[]
            for e in ofperiod[t]
                v = draw[ancestors[n][s.revealperiod[e]]][position[e]]
                v == s.base[e] || push!(node, e => v)
            end
            push!(values, node)
            push!(next, n)
        end
        frontier = next
    end
    paths = [ancestors[n] for n in frontier]
    return SMPSTree(s.name, s.sense, s.objective, s.periods, s.columns, s.rows, s.colperiod,
                    s.rowperiod, s.c, s.A, s.senses, s.rhs, s.ranges, s.lb, s.ub, s.integer,
                    s.constant, s.elements, s.names, s.elementperiod, nodeperiod, parent,
                    probability, values, paths, ["S$k" for k in eachindex(paths)],
                    probability[frontier])
end
