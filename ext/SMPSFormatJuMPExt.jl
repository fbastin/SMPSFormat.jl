module SMPSFormatJuMPExt

using JuMP
using SMPSFormat
using SMPSFormat: SMPSProblem, row_bounds, second_stage
using SparseArrays

"""Variables with the bounds `lb`, `ub` and the integrality `integer`, named `name[j]`."""
function bounded_variables(model, lb, ub, integer, name)
    v = @variable(model, [1:length(lb)], base_name = name)
    for j in eachindex(v)
        isfinite(lb[j]) && set_lower_bound(v[j], lb[j])
        isfinite(ub[j]) && set_upper_bound(v[j], ub[j])
        integer[j] && set_integer(v[j])
    end
    return v
end

"""The rows `Σ M x ~ rhs`, `terms` holding the pairs `(M, x)`, with their senses and ranges."""
function add_rows!(model, terms, senses, rhs, ranges)
    expressions = [AffExpr(0.0) for _ in eachindex(senses)]
    for (M, x) in terms, j in axes(M, 2), k in nzrange(M, j)
        add_to_expression!(expressions[rowvals(M)[k]], nonzeros(M)[k], x[j])
    end
    for (i, expression) in enumerate(expressions)
        lower, upper = row_bounds(senses[i], rhs[i], ranges[i])
        if lower == upper
            @constraint(model, expression == lower)
        elseif isinf(lower)
            @constraint(model, expression <= upper)
        elseif isinf(upper)
            @constraint(model, expression >= lower)
        else
            @constraint(model, lower <= expression <= upper)
        end
    end
    return model
end

function SMPSFormat.extensive_form(smps::SMPSProblem, ξ::AbstractVector, p::AbstractVector;
                                   optimizer = nothing)
    length(ξ) == length(p) || error("$(length(ξ)) scenarios but $(length(p)) probabilities")
    model = optimizer === nothing ? Model() : Model(optimizer)
    x = bounded_variables(model, smps.lb1, smps.ub1, smps.integer1, "x")
    add_rows!(model, ((smps.A, x),), smps.senses1, smps.b, smps.ranges1)
    objective = AffExpr(smps.constant)
    add_to_expression!(objective, smps.c' * x)
    y = Vector{Vector{VariableRef}}(undef, length(ξ))
    for s in eachindex(ξ, p)
        data = second_stage(smps, ξ[s])
        y[s] = bounded_variables(model, smps.lb, smps.ub, smps.integer2, "y_$s")
        add_rows!(model, ((data.T, x), (data.W, y[s])), smps.senses2, data.h, smps.ranges2)
        for (j, qj) in enumerate(data.q)
            qj == 0 || add_to_expression!(objective, p[s] * qj, y[s][j])
        end
    end
    # a maximization is stored as the minimization of the opposite objective
    smps.sense === :max ? @objective(model, Max, -objective) : @objective(model, Min, objective)
    return model, x, y
end

end
