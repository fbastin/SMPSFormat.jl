# The law of the random elements.

"""
    SMPSLaw

The law of `ξ`, the vector of the values of the random elements of an [`SMPSProblem`](@ref), in
the order of its `elements`:

- **Discrete blocks**, independent of each other, each taking one of finitely many outcomes,
  which set the values of some elements. An `INDEP DISCRETE` element is a block of its own; a
  `BLOCKS` block sets several elements at once; a two-stage `SCENARIOS` section is a single block
  whose outcomes are the scenarios.
- **Continuous elements**, `INDEP` with a continuous distribution, each independent of the rest.
  Each is `(element, distribution, modifier, sign)`: a draw `v` gives the value `sign ×
  modified(sign × base, v)`, `sign` being −1 for a cost of a maximization (stored negated).

`base` holds the values of the core file; an element no block or distribution sets keeps it. The
outcomes hold the values themselves: `ADD` and `MULTIPLY` are applied when the file is read. A
continuous element keeps its modifier, applied to each draw.

`rand(rng, law)` draws one `ξ`, `rand(rng, law, n)` draws `n` independent ones. A discrete law can
be enumerated, [`enumerate_scenarios`](@ref).
"""
struct SMPSLaw
    base::Vector{Float64}
    probabilities::Vector{Vector{Float64}}             # per block, per outcome
    outcomes::Vector{Vector{Vector{Pair{Int,Float64}}}} # per block, per outcome: element => value
    continuous::Vector{Tuple{Int,UnivariateDistribution,Symbol,Float64}} # element, law, modifier, sign
end

"""Whether the law of `law` is discrete: no continuous element."""
isdiscrete(law::SMPSLaw) = isempty(law.continuous)

"""The value of an element whose core value is `core`, when the file gives `value` with
`modifier` (`:replace`, `:add` or `:multiply`)."""
modified(modifier::Symbol, core::Float64, value::Float64) =
    modifier === :replace ? value : modifier === :add ? core + value : core * value

"""
    support_size(law::SMPSLaw)

The number of points of the support of a discrete `law`, as a `BigInt`: the product of the numbers
of outcomes of its blocks. An error for a law with continuous elements.
"""
function support_size(law::SMPSLaw)
    isdiscrete(law) || error("the law has continuous elements: its support is not finite")
    return prod(BigInt(length(p)) for p in law.probabilities; init = BigInt(1))
end

function Base.rand(rng::AbstractRNG, law::SMPSLaw)
    ξ = copy(law.base)
    for (p, outcomes) in zip(law.probabilities, law.outcomes)
        u, k = rand(rng) * sum(p), 1                # p sums up to one, unless kept as written
        while k < length(p) && u > p[k]
            u -= p[k]
            k += 1
        end
        for (e, v) in outcomes[k]
            ξ[e] = v
        end
    end
    for (e, distribution, modifier, sign) in law.continuous
        ξ[e] = sign * modified(modifier, sign * law.base[e], rand(rng, distribution))
    end
    return ξ
end
Base.rand(law::SMPSLaw) = rand(Random.default_rng(), law)
Base.rand(rng::AbstractRNG, law::SMPSLaw, n::Integer) = [rand(rng, law) for _ in 1:n]
Base.rand(law::SMPSLaw, n::Integer) = rand(Random.default_rng(), law, n)

"""
    enumerate_scenarios(law::SMPSLaw; limit = 100_000)

Every point of the support of a discrete `law` and its probability, as the named tuple
`(ξ = ..., p = ...)`; the last block varies fastest. An error if there are more than `limit` of
them (sample the law instead, `rand(rng, law, n)`), or if the law has continuous elements.
"""
function enumerate_scenarios(law::SMPSLaw; limit::Integer = 100_000)
    size = support_size(law)
    size <= limit || error("the law has $size points, more than the limit of $limit: sample it, " *
                           "or raise `limit`")
    ξ, p = [copy(law.base)], [1.0]
    for (probabilities, outcomes) in zip(law.probabilities, law.outcomes)
        ξ = [(η = copy(point); foreach(((e, v),) -> (η[e] = v), outcome); η)
             for point in ξ for outcome in outcomes]
        p = [w * pk for w in p for pk in probabilities]
    end
    return (ξ = ξ, p = p)
end
