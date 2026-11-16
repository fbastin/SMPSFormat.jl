"""
Estimates of the optimal values of two-stage instances too large for their deterministic
equivalents, as Linderoth, Shapiro and Wright (2006, Sections 4.1, 4.2 and 9.1) compute them,
with Latin hypercube samples, to compare with theirs (Table 4):

- the lower bound: the mean of the optimal values of `M` sample average approximations (SAA) of
  `N` scenarios each, with its 95% confidence interval;
- the upper bound: the value of the best of their `M` solutions, screened on a common sample of
  five batches of 2000 scenarios, estimated on `T` batches of `N̄` scenarios, with its 95%
  confidence interval; each scenario's second stage is solved on its own, warm started.

    julia --project=validation validation/sampling.jl [options] instance...

`--replications M` (7), `--scenarios N` (5000), `--batches T` (50), `--batch-scenarios N̄`
(20000), `--seed s` (1). The instances are those of `instances.toml`, whose files `validate.jl`
downloads; their random elements must be right-hand sides of the second stage.
"""
module Sampling

using HiGHS, JuMP, LinearAlgebra, Printf, Random, SMPSFormat, SparseArrays, Statistics, TOML

"""Linderoth, Shapiro and Wright's estimates (Table 4, Latin hypercube samples of 5000
scenarios): the lower and upper bounds, each with the half-width of its 95% confidence
interval."""
const LSW = Dict("20term" => ((254298.57, 38.74), (254311.55, 5.56)),
                 "ssn" => ((9.84, 0.10), (9.913, 0.022)),
                 "storm" => ((15498657.8, 73.9), (15498739.41, 19.11)),
                 "gbd" => ((1655.62, 0.00), (1655.628, 0.00)),
                 "LandS" => ((225.62, 0.02), (225.624, 0.005)))

say(args...) = (println(args...); flush(stdout))

"""The files of the instance `name` of `instances.toml`, in the downloaded archives."""
function files(config, name)
    for family in config["family"], instance in family["instances"]
        fill(text) = foldl((t, (k, v)) -> replace(t, "{$k}" => v), pairs(instance); init = text)
        fill(family["name"]) == name || continue
        root = joinpath(@__DIR__, "data", config["archive"][family["archive"]]["root"])
        isdir(root) || error("$root: run validate.jl first, which downloads the files")
        return [joinpath(root, fill(f)) for f in family["files"]]
    end
    error("no instance $name in instances.toml")
end

"""`n` scenarios of the discrete `law`, a Latin hypercube sample: the outcome of each block is
drawn by the inverse of its distribution function at `(π(i) - 1 + u_i) / n`, `π` a random
permutation of `1:n` and `u_i` uniform on [0, 1], each block independently."""
function lhs(rng, law, n)
    isempty(law.continuous) || error("a law with continuous elements")
    ξs = [copy(law.base) for _ in 1:n]
    for (p, outcomes) in zip(law.probabilities, law.outcomes)
        F = cumsum(p) ./ sum(p)
        π = randperm(rng, n)
        for i in 1:n
            k = min(searchsortedfirst(F, (π[i] - 1 + rand(rng)) / n), length(p))
            for (e, v) in outcomes[k]
                ξs[i][e] = v
            end
        end
    end
    return ξs
end

"""The optimal value and first-stage solution of the SAA of the scenarios `ξs`: by HiGHS's
interior point methods, HiPO then IPX, without presolve or crossover, or else by its simplex
method; with `basic`, by its simplex method, whose solution meets the first-stage rows."""
function saa(problem, ξs; basic = false)
    n = length(ξs)
    model, x, _ = extensive_form(problem, ξs, fill(1 / n, n))
    set_optimizer(model, HiGHS.Optimizer)
    set_silent(model)
    simplex = ("simplex", "choose", "on")
    methods = basic ? [simplex] : [("ipm", "off", "off"), ("ipx", "off", "off"), simplex]
    for (solver, presolve, crossover) in methods
        set_attribute(model, "solver", solver)
        set_attribute(model, "presolve", presolve)
        set_attribute(model, "run_crossover", crossover)
        optimize!(model)
        termination_status(model) == MOI.OPTIMAL && return objective_value(model), value.(x)
        say("SAA: ", termination_status(model), " with the solver ", solver)
    end
    error("SAA: not solved")
end

"""The second stage of `problem` at the first-stage decision `x`, as a HiGHS model whose rows'
bounds are set scenario by scenario: returns the function of `ξ` that gives `q'y` at its
optimum."""
function recourse(problem, x)
    all(kind === :h for (kind, _, _) in problem.elements) || error("random elements other than h")
    model = direct_model(HiGHS.Optimizer())
    set_silent(model)
    set_attribute(model, "presolve", "off")     # keeps the basis from one scenario to the next
    y = @variable(model, problem.lb[j] <= y[j = 1:length(problem.q)] <= problem.ub[j])
    @objective(model, Min, problem.q' * y)
    Tx = problem.T * x
    Wt = sparse(problem.W')
    bounds(i, h) = row_bounds(problem.senses2[i], h, problem.ranges2[i]) .- Tx[i]
    rows = map(1:length(problem.h)) do i
        terms = zip(rowvals(Wt)[nzrange(Wt, i)], nonzeros(Wt)[nzrange(Wt, i)])
        return @constraint(model, sum(v * y[j] for (j, v) in terms; init = AffExpr(0.0)) in
                                  MOI.Interval(bounds(i, problem.h[i])...))
    end
    random = [(k, i) for (k, (_, i, _)) in enumerate(problem.elements)]
    return function (ξ)
        for (k, i) in random
            MOI.set(model, MOI.ConstraintSet(), rows[i], MOI.Interval(bounds(i, ξ[k])...))
        end
        optimize!(model)
        termination_status(model) == MOI.OPTIMAL ||
            error("second stage: ", termination_status(model))
        return objective_value(model)
    end
end

"""The estimates of `f(x)`, the objective at the first-stage decision `x`, on each batch of
scenarios of `batches`."""
function evaluate(problem, x, batches)
    Q = recourse(problem, x)
    fixed = dot(problem.c, x) + problem.constant
    return [fixed + mean(Q, ξs) for ξs in batches]
end

"""The mean of `v` and the half-width of its 95% confidence interval."""
interval(v) = (mean(v), 1.96 * std(v) / sqrt(length(v)))
show_interval((m, h)) = @sprintf("%.10g ± %.4g", m, h)

"""The estimates for the instance `name`, printed, compared with Linderoth, Shapiro and
Wright's."""
function estimate(config, name, M, N, T, N̄, seed)
    started = time()
    rng = Xoshiro(seed)
    problem = read_smps(files(config, name)...)
    say(name, ": ", problem)
    problem.sense === :min || error("a maximization")

    # The evaluation, checked against the deterministic equivalent of 20 scenarios, x fixed.
    ξs = lhs(rng, problem.law, 20)
    _, x0 = saa(problem, ξs; basic = true)
    model, x, _ = extensive_form(problem, ξs, fill(1 / 20, 20))
    set_optimizer(model, HiGHS.Optimizer)
    set_silent(model)
    fix.(x, x0; force = true)
    optimize!(model)
    termination_status(model) == MOI.OPTIMAL || error("check: ", termination_status(model))
    check = only(evaluate(problem, x0, [ξs]))
    isapprox(objective_value(model), check; rtol = 1e-7) ||
        error("the evaluation gives $check, the deterministic equivalent $(objective_value(model))")

    optima, solutions = Float64[], Vector{Float64}[]
    for j in 1:M
        t = time()
        v, x = saa(problem, lhs(rng, problem.law, N))
        push!(optima, v)
        push!(solutions, x)
        say(@sprintf("SAA %d of %d scenarios: %.10g (%.0f s)", j, N, v, time() - t))
    end
    lower = interval(optima)
    say("lower bound: ", show_interval(lower))

    screen = [lhs(rng, problem.law, 2000) for _ in 1:5]
    scores = [mean(evaluate(problem, x, screen)) for x in solutions]
    best = argmin(scores)
    say("screening: ", join((@sprintf("%.10g", s) for s in scores), ", "), "; best: SAA ", best)
    t = time()
    upper = interval(evaluate(problem, solutions[best], (lhs(rng, problem.law, N̄) for _ in 1:T)))
    say(@sprintf("upper bound: %s (%d batches of %d scenarios, %.0f s)", show_interval(upper), T,
                 N̄, time() - t))

    if haskey(LSW, name)
        (ll, lh), (ul, uh) = LSW[name]
        say(@sprintf("Linderoth, Shapiro and Wright: lower bound %s, upper bound %s",
                     show_interval((ll, lh)), show_interval((ul, uh))))
        # two estimates of the same quantity differ by less than the half-width of the interval
        # of their difference, sqrt(h1² + h2²), 95 times in 100
        say(@sprintf("differences: lower bounds %.4g, half-width %.4g; upper bounds %.4g, %s %.4g",
                     lower[1] - ll, hypot(lower[2], lh), upper[1] - ul, "half-width",
                     hypot(upper[2], uh)))
    end
    say(@sprintf("%s: lower bound %s, upper bound %s, %.0f s", name, show_interval(lower),
                 show_interval(upper), time() - started))
end

function main(arguments)
    option = Dict("--replications" => 7, "--scenarios" => 5000, "--batches" => 50,
                  "--batch-scenarios" => 20000, "--seed" => 1)
    names, k = String[], 1
    while k <= length(arguments)
        if haskey(option, arguments[k])
            k < length(arguments) || error("$(arguments[k]) needs a value")
            option[arguments[k]] = parse(Int, arguments[k + 1])
            k += 2
        else
            push!(names, arguments[k])
            k += 1
        end
    end
    isempty(names) && error("no instance: give the names of instances of instances.toml")
    config = TOML.parsefile(joinpath(@__DIR__, "instances.toml"))
    for name in names
        estimate(config, name, option["--replications"], option["--scenarios"],
                 option["--batches"], option["--batch-scenarios"], option["--seed"])
    end
    return 0
end

end

exit(Sampling.main(ARGS))
