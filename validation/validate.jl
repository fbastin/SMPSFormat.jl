"""
Validation of SMPSFormat.jl on the test collections of the literature: each instance of
`instances.toml` is read, its deterministic equivalent solved with HiGHS, and its optimal value
compared with the published one.

    julia --project=validation validation/validate.jl [options]

    --size small|medium|large|huge   the largest instances run (default: small)
    --only REGEX                only the instances whose name matches REGEX
    --data DIRECTORY            where the archives are downloaded (default: validation/data)
    --time-limit SECONDS        the time limit of each solve (default: 3600)
    --output FILE               the table of the results, in Markdown

The exit code is 1 when an instance differs from its published value without a known reason,
or cannot be read or solved.
"""
module Validation

using CodecZlib: GzipDecompressorStream
using Dates
using Downloads
using HiGHS
using JuMP
using Logging
using Printf
using SMPSFormat
using Tar
using TOML

const SIZES = ("small", "medium", "large", "huge")

"""The options of the command line."""
function options(arguments)
    option = Dict("size" => "small", "only" => "", "data" => joinpath(@__DIR__, "data"),
                  "time-limit" => "3600", "output" => "")
    k = 1
    while k <= length(arguments)
        key = replace(arguments[k], r"^--" => "")
        haskey(option, key) && k < length(arguments) || error("unknown option $(arguments[k])\n" *
                                                              "usage: validate.jl [--size small|medium|large|huge] " *
                                                              "[--only REGEX] [--data DIRECTORY] " *
                                                              "[--time-limit SECONDS] [--output FILE]")
        option[key] = arguments[k + 1]
        k += 2
    end
    option["size"] in SIZES || error("--size: one of $(join(SIZES, ", "))")
    return (size = findfirst(==(option["size"]), SIZES), only = Regex(option["only"]),
            data = option["data"], time_limit = parse(Float64, option["time-limit"]),
            output = option["output"])
end

"""The instances of `config`: each instance of each family, the placeholders `{key}` of the
family's name and files replaced by the instance's values, its keys overriding the family's."""
function instances(config)
    list = []
    for family in config["family"], instance in family["instances"]
        fill(text) = foldl((t, (k, v)) -> replace(t, "{$k}" => v), pairs(instance); init = text)
        merged = merge(family, instance)
        push!(list, (name = fill(family["name"]), archive = family["archive"],
                     files = fill.(family["files"]), reference = merged["reference"],
                     value = get(merged, "value", nothing), lower = get(merged, "lower", nothing),
                     upper = get(merged, "upper", nothing), size = merged["size"],
                     known = get(merged, "known", nothing), note = get(merged, "note", nothing),
                     probability_sums = Symbol(get(merged, "probability_sums", "rounding"))))
    end
    return list
end

"""The directory of `archive`, downloaded and extracted in `data` if it is not there yet; its
content checked by its git tree hash."""
function archive_root(archive, data)
    root = joinpath(data, archive["root"])
    isdir(root) && return root
    mkpath(data)
    tarball = joinpath(data, archive["root"] * ".tar.gz")
    println("downloading ", archive["url"])
    Downloads.download(archive["url"], tarball)
    hash = open(io -> Tar.tree_hash(GzipDecompressorStream(io)), tarball)
    hash == archive["tree_hash"] ||
        error("$(archive["url"]): the content's tree hash is $hash, not $(archive["tree_hash"])")
    staging = mktempdir(data)
    open(io -> Tar.extract(GzipDecompressorStream(io), staging), tarball)
    mv(joinpath(staging, archive["root"]), root)
    rm(staging; recursive = true)
    rm(tarball)
    return root
end

"""The deterministic equivalent of `problem` as a JuMP model, its number of scenarios and of
periods."""
function deterministic_equivalent(problem::SMPSProblem)
    (; ξ, p) = enumerate_scenarios(problem.law)
    model, _ = extensive_form(problem, ξ, p)
    return model, length(p), 2
end
function deterministic_equivalent(tree::SMPSTree)
    model, _ = extensive_form(tree)
    return model, length(tree.scenarios), length(tree.periods)
end
deterministic_equivalent(stagewise::SMPSStagewise) = deterministic_equivalent(scenario_tree(stagewise))

"""Half a unit of the last digit of the number `text`, or of its digit `significant` (counted
from its first) if that one is larger."""
function tolerance(text, significant)
    m = match(r"\.(\d+)", text)
    half = 0.5 * 10.0^(-(m === nothing ? 0 : length(m[1])))
    v = abs(parse(Float64, text))
    significant === nothing || v == 0 ||
        (half = max(half, 0.5 * 10.0^(floor(Int, log10(v)) - significant + 1)))
    return half
end

"""The interval of the published optimal value of `instance`: its value, or its bounds, give or
take the tolerance of the digits printed."""
function published(instance, significant)
    if instance.value !== nothing
        v = parse(Float64, instance.value)
        t = tolerance(instance.value, significant)
        return v - t, v + t
    end
    return parse(Float64, instance.lower) - tolerance(instance.lower, significant),
           parse(Float64, instance.upper) + tolerance(instance.upper, significant)
end

"""The outcome of `instance`, whose published value lies in `[lower, upper]`, given the status
of its solve, the value of its solution, and, for an integer program, the bound on its optimum."""
function verdict(instance, (lower, upper), status, value, bound, mip)
    solved = status == MOI.OPTIMAL
    # a linear program stopped early: its value says nothing of the optimum
    isfinite(value) && (solved || mip) || return "not solved ($status)"
    # the interval in which the solve places the optimum: a point for a linear program
    slack = 1e-9 * max(1.0, abs(value))
    low, high = mip && isfinite(bound) ? minmax(value, bound) : (value, value)
    agrees = low - slack <= upper && high + slack >= lower
    if instance.known !== nothing
        return agrees ? "agrees: the known difference is gone" : "differs (known)"
    end
    return !agrees ? "differs" : solved ? "agrees" : "consistent, not solved ($status)"
end

"""Whether `result` calls for attention: a difference without a known reason, or an error."""
failed(result) = result == "differs" || startswith(result, "error") || startswith(result, "agrees:")

"""Reads and solves `instance`, the files in `root`: a named tuple of the results."""
function run(instance, root, reference, time_limit)
    started = time()
    warnings = IOBuffer()
    outcome = (periods = 0, scenarios = 0, rows = 0, columns = 0, value = NaN, warnings = "")
    try
        problem = with_logger(ConsoleLogger(warnings, Logging.Warn)) do
            return read_smps(joinpath.(root, instance.files)...;
                             probability_sums = instance.probability_sums)
        end
        model, scenarios, periods = deterministic_equivalent(problem)
        mip = num_constraints(model, VariableRef, MOI.Integer) +
              num_constraints(model, VariableRef, MOI.ZeroOne) > 0
        set_optimizer(model, HiGHS.Optimizer)
        set_silent(model)
        set_time_limit_sec(model, time_limit)
        mip && set_attribute(model, "mip_rel_gap", 1e-6)
        optimize!(model)
        status = termination_status(model)
        value = primal_status(model) == MOI.FEASIBLE_POINT ? objective_value(model) : NaN
        bound = mip ? objective_bound(model) : NaN
        interval = published(instance, get(reference, "significant", nothing))
        outcome = (; periods, scenarios, rows = num_constraints(model; count_variable_in_set_constraints = false),
                   columns = num_variables(model), value,
                   warnings = replace(count_warnings(String(take!(warnings))), root * "/" => ""))
        return (; outcome..., result = verdict(instance, interval, status, value, bound, mip),
                seconds = time() - started)
    catch e
        e isa InterruptException && rethrow()
        message = replace(first(split(sprint(showerror, e), '\n')), root * "/" => "")
        return (; outcome..., result = "error: $message", seconds = time() - started)
    end
end

"""The warnings in the log `text`, their first lines, joined."""
count_warnings(text) = join(unique(m[1] for m in eachmatch(r"Warning: ([^\n]*)", text)), "; ")

"""The published value of `instance` as printed."""
printed(instance) = instance.value !== nothing ? instance.value : "[$(instance.lower), $(instance.upper)]"

"""The difference between `value` and the published value or interval of `instance`."""
function difference(instance, value)
    isfinite(value) || return ""
    if instance.value !== nothing
        d = value - parse(Float64, instance.value)
    else
        lower, upper = parse(Float64, instance.lower), parse(Float64, instance.upper)
        d = value < lower ? value - lower : value > upper ? value - upper : 0.0
    end
    return @sprintf("%.3g", d)
end

"""The table of `results` in Markdown."""
function markdown(io, results, config, option, elapsed)
    println(io, "# Validation results\n")
    println(io, "SMPSFormat $(pkgversion(SMPSFormat)), JuMP $(pkgversion(JuMP)), HiGHS.jl $(pkgversion(HiGHS)) ",
            "(HiGHS $(HiGHS.Highs_versionMajor()).$(HiGHS.Highs_versionMinor()).$(HiGHS.Highs_versionPatch())), ",
            "Julia $VERSION, $(Sys.MACHINE); run on $(Dates.format(now(), "yyyy-mm-dd")), instances up to ",
            "the size `$(SIZES[option.size])`, $(round(Int, option.time_limit)) seconds per solve, ",
            "$(round(elapsed / 60; digits = 1)) minutes in all.\n")
    counts = Dict{String, Int}()
    for (_, r) in results
        key = startswith(r.result, "error") ? "error" : replace(r.result, r" \([A-Z_]+\)" => "")
        counts[key] = get(counts, key, 0) + 1
    end
    println(io, join(("$(v) $(k)" for (k, v) in sort(collect(counts))), ", "), ".\n")
    println(io, "| Instance | Periods | Scenarios | Rows | Columns | Published | Reference | Computed | Difference | Seconds | Result |")
    println(io, "|---|--:|--:|--:|--:|--:|---|--:|--:|--:|---|")
    for (instance, r) in results
        computed = isfinite(r.value) ? @sprintf("%.10g", r.value) : ""
        println(io, "| ", join((instance.name, r.periods, r.scenarios, r.rows, r.columns, printed(instance),
                                instance.reference, computed, difference(instance, r.value),
                                @sprintf("%.1f", r.seconds), r.result), " | "), " |")
    end
    notes = [(instance, r) for (instance, r) in results
             if instance.known !== nothing || instance.note !== nothing || !isempty(r.warnings)]
    if !isempty(notes)
        println(io, "\n## Notes\n")
        for (instance, r) in notes
            text = filter(!isnothing, [instance.known, instance.note,
                                       isempty(r.warnings) ? nothing : "Read with warnings: $(r.warnings)."])
            println(io, "- $(instance.name): ", join(text, " "))
        end
    end
    println(io, "\n## References\n")
    for (key, reference) in sort(collect(config["reference"]); by = first)
        println(io, "- `$key`: $(reference["cite"]).")
    end
    println(io, "\n## Files\n")
    for (key, archive) in sort(collect(config["archive"]); by = first)
        println(io, "- `$key`: $(archive["description"]), $(archive["url"]).")
    end
end

function main(arguments)
    option = options(arguments)
    config = TOML.parsefile(joinpath(@__DIR__, "instances.toml"))
    selected = [i for i in instances(config)
                if findfirst(==(i.size), SIZES) <= option.size && occursin(option.only, i.name)]
    roots = Dict(a => archive_root(config["archive"][a], option.data) for a in unique(i.archive for i in selected))
    started = time()
    results = []
    for instance in selected
        r = run(instance, roots[instance.archive], config["reference"][instance.reference], option.time_limit)
        push!(results, instance => r)
        @printf("%-18s %-10s %16s %16s %8.1f s  %s\n", instance.name, instance.reference, printed(instance),
                isfinite(r.value) ? @sprintf("%.10g", r.value) : "-", r.seconds, r.result)
        flush(stdout)
        GC.gc()
    end
    elapsed = time() - started
    isempty(option.output) || open(io -> markdown(io, results, config, option, elapsed), option.output, "w")
    bad = [i.name for (i, r) in results if failed(r.result)]
    println("\n", length(results), " instances, ", length(bad), " to look at", isempty(bad) ? "" : ": " * join(bad, ", "))
    return isempty(bad) ? 0 : 1
end

end

exit(Validation.main(ARGS))
