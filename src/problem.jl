# A two-stage problem read from SMPS files.

"""
    SMPSProblem

A two-stage problem read by [`read_smps`](@ref):

    min  c'x + E[ q(ξ)'y ] + constant
    s.t. A x  ~ b                 (senses1, ranges1)
         T(ξ) x + W(ξ) y ~ h(ξ)   (senses2, ranges2)
         lb1 ≤ x ≤ ub1,  lb ≤ y ≤ ub,  some of them integer

- **Rows**: each has a sense, `'L'`, `'G'` or `'E'`, a right-hand side, and a range, `NaN` when
  it has none (the `RANGES` section of MPS); [`row_bounds`](@ref) gives the interval it imposes.
- **Random elements**: `elements` lists them as `(kind, i, j)`. `(:h, i, 0)` is the right-hand
  side of the second-stage row `i`; `(:T, i, j)` the coefficient of the first-stage variable `j`
  in that row; `(:W, i, j)` that of the second-stage variable `j`; `(:q, j, 0)` the cost of the
  second-stage variable `j`. `names` gives, for each, the column and row names of the files.
  `law` is their law; [`second_stage`](@ref) gives the data of the second stage for one `ξ`.
- **Sense**: `sense` is `:min` or `:max`. A maximization is stored as the minimization of the
  opposite objective: every cost, random ones included, and the constant, are negated.
- **Names**: `columns1`, `columns2`, `rows1` and `rows2` are those of the files; `objective` is the
  name of the objective row.
"""
struct SMPSProblem
    name::String
    sense::Symbol
    objective::String
    c::Vector{Float64}
    A::SparseMatrixCSC{Float64,Int}
    senses1::Vector{Char}
    b::Vector{Float64}
    ranges1::Vector{Float64}
    lb1::Vector{Float64}
    ub1::Vector{Float64}
    integer1::Vector{Bool}
    q::Vector{Float64}
    W::SparseMatrixCSC{Float64,Int}
    senses2::Vector{Char}
    h::Vector{Float64}
    ranges2::Vector{Float64}
    T::SparseMatrixCSC{Float64,Int}
    lb::Vector{Float64}
    ub::Vector{Float64}
    integer2::Vector{Bool}
    constant::Float64
    columns1::Vector{String}
    columns2::Vector{String}
    rows1::Vector{String}
    rows2::Vector{String}
    elements::Vector{Tuple{Symbol,Int,Int}}
    names::Vector{Tuple{String,String}}
    law::SMPSLaw
end

function Base.show(io::IO, smps::SMPSProblem)
    size = isdiscrete(smps.law) ? string(support_size(smps.law), " scenarios") :
           string(length(smps.law.continuous), " continuous")
    print(io, "SMPS instance ", smps.name, ": ", length(smps.c), " first-stage variables and ",
          length(smps.b), " rows, ", length(smps.q), " second-stage variables and ",
          length(smps.h), " rows, ", length(smps.elements), " random elements (",
          length(smps.law.probabilities), " discrete blocks, ", size, ")")
end

"""
    row_bounds(sense, rhs, range)

The interval `(lower, upper)` a row of sense `sense` (`'L'`, `'G'` or `'E'`), right-hand side
`rhs` and range `range` (`NaN` for none) imposes on its activity, as MPS defines ranges: `[rhs −
|range|, rhs]` for `'L'`, `[rhs, rhs + |range|]` for `'G'`, and for `'E'`, `[rhs, rhs + range]`
or `[rhs + range, rhs]` by the sign of the range.
"""
function row_bounds(sense::Char, rhs::Real, range::Real)
    if isnan(range)
        return sense == 'L' ? (-Inf, Float64(rhs)) : sense == 'G' ? (Float64(rhs), Inf) :
               (Float64(rhs), Float64(rhs))
    end
    sense == 'L' && return (rhs - abs(range), Float64(rhs))
    sense == 'G' && return (Float64(rhs), rhs + abs(range))
    return range >= 0 ? (Float64(rhs), rhs + range) : (rhs + range, Float64(rhs))
end

"""
    second_stage(smps::SMPSProblem, ξ)

The data of the second stage when the random elements take the values `ξ`: the named tuple
`(q = ..., T = ..., W = ..., h = ...)`, copies of those of `smps` with the random elements set.
"""
function second_stage(smps::SMPSProblem, ξ::AbstractVector)
    length(ξ) == length(smps.elements) ||
        error("ξ has $(length(ξ)) values for $(length(smps.elements)) random elements")
    q, h, T, W = copy(smps.q), copy(smps.h), copy(smps.T), copy(smps.W)
    for (k, (kind, i, j)) in enumerate(smps.elements)
        if kind === :h
            h[i] = ξ[k]
        elseif kind === :q
            q[i] = ξ[k]
        elseif kind === :T
            T[i, j] = ξ[k]
        else
            W[i, j] = ξ[k]
        end
    end
    return (q = q, T = T, W = W, h = h)
end
