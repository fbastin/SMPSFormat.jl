module SMPSFormatJuMPExt

using JuMP
using SMPSFormat
using SMPSFormat: SMPSProblem, SMPSTree, row_bounds, second_stage
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
        add_row!(model, expression, senses[i], rhs[i], ranges[i])
    end
    return model
end

"""The row `expression ~ rhs` of sense `sense` and range `range`."""
function add_row!(model, expression, sense, rhs, range)
    lower, upper = row_bounds(sense, rhs, range)
    if lower == upper
        @constraint(model, expression == lower)
    elseif isinf(lower)
        @constraint(model, expression <= upper)
    elseif isinf(upper)
        @constraint(model, expression >= lower)
    else
        @constraint(model, lower <= expression <= upper)
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
        y[s] = bounded_variables(model, data.lb, data.ub, smps.integer2, "y_$s")
        add_rows!(model, ((data.T, x), (data.W, y[s])), smps.senses2, data.h, smps.ranges2)
        for (j, qj) in enumerate(data.q)
            qj == 0 || add_to_expression!(objective, p[s] * qj, y[s][j])
        end
    end
    # a maximization is stored as the minimization of the opposite objective
    smps.sense === :max ? @objective(model, Max, -objective) : @objective(model, Min, objective)
    return model, x, y
end

function SMPSFormat.extensive_form(tree::SMPSTree; optimizer = nothing)
    model = optimizer === nothing ? Model() : Model(optimizer)
    periods = eachindex(tree.periods)
    cols = [findall(==(t), tree.colperiod) for t in periods]
    rows = [findall(==(t), tree.rowperiod) for t in periods]
    position = zeros(Int, length(tree.columns))      # a column => its index in its period
    for t in periods, (k, j) in enumerate(cols[t])
        position[j] = k
    end
    At = sparse(tree.A')                            # the rows of A as columns
    N = length(tree.nodeperiod)
    ancestors = Vector{Vector{Int}}(undef, N)       # a node's ancestors by period, itself last
    x = Vector{Vector{VariableRef}}(undef, N)
    objective = AffExpr(tree.constant)
    for n in 1:N                                    # a parent comes before its children
        t = tree.nodeperiod[n]
        ancestors[n] = t == 1 ? [n] : [ancestors[tree.parent[n]]; n]
        J = cols[t]
        random = Dict(tree.elements[e] => v for (e, v) in tree.values[n])
        lb = [get(random, (:lb, j, 0), tree.lb[j]) for j in J]
        ub = [get(random, (:ub, j, 0), tree.ub[j]) for j in J]
        x[n] = bounded_variables(model, lb, ub, tree.integer[J], "x_$n")
        for (k, j) in enumerate(J)
            cj = get(random, (:c, j, 0), tree.c[j])
            cj == 0 || add_to_expression!(objective, tree.probability[n] * cj, x[n][k])
        end
        for i in rows[t]
            expression = AffExpr(0.0)
            for k in nzrange(At, i)
                j = rowvals(At)[k]
                a = get(random, (:A, i, j), nonzeros(At)[k])
                a == 0 || add_to_expression!(expression, a, x[ancestors[n][tree.colperiod[j]]][position[j]])
            end
            add_row!(model, expression, tree.senses[i], get(random, (:rhs, i, 0), tree.rhs[i]),
                     tree.ranges[i])
        end
    end
    tree.sense === :max ? @objective(model, Max, -objective) : @objective(model, Min, objective)
    return model, x
end

end
