"""
Validation of `write_sof` on the test collections: each instance of `instances.toml` with a
published optimal value is written in StochOptFormat, read back by SDDP.jl, and the deterministic
equivalent SDDP.jl builds of the policy graph solved with HiGHS, its optimal value compared with
the published one, as `validate.jl` compares that of SMPSFormat's own. Each instance is written
twice: with random variables (`random_variables = true`), unless it has random coefficients in
its rows, which SDDP.jl does not read; and with the data of each node (`random_variables =
false`). A law by period with an element revealed before the period of its data is written as its
scenario tree.

    julia --project=validation validation/sof.jl [options]

The options are those of `validate.jl`; `--output` writes the table of the results in Markdown.
The exit code is 1 when a value differs from the published one without a known reason, or an
instance cannot be written, read or solved.
"""
module SOFValidation

include("validate.jl")

using .Validation: options, instances, archive_root, published, verdict, failed, printed, SIZES
using Dates
using HiGHS
using JuMP
using Logging
using Printf
import SDDP
using SMPSFormat
using TOML

const MODES = ("random variables", "data by node")

"""The problem `instance` is written from: the one read, or the scenario tree of a law by period
whose elements are not all revealed in the periods of their data."""
function written_problem(problem)
    problem isa SMPSStagewise && any(problem.revealperiod .!= problem.elementperiod) || return problem
    return scenario_tree(problem; limit = typemax(Int))
end

"""Writes `problem` in StochOptFormat in `directory`, reads it back with SDDP.jl and solves the
deterministic equivalent SDDP.jl builds: the value, the outcome, the seconds and the size of the
file (gzipped)."""
function solve_sof(instance, problem, directory, reference, time_limit, random_variables)
    started = time()
    path = joinpath(directory, instance.name * ".sof.json.gz")
    try
        limit = problem isa SMPSTree ? (;) : (; limit = typemax(Int))   # a tree has no law to enumerate
        with_logger(NullLogger()) do
            write_sof(path, problem; random_variables, limit...)
        end
        bytes = filesize(path)
        model, _ = SDDP.read_from_file(path)
        rm(path)
        de = SDDP.deterministic_equivalent(model, HiGHS.Optimizer; time_limit)
        mip = num_constraints(de, VariableRef, MOI.Integer) + num_constraints(de, VariableRef, MOI.ZeroOne) > 0
        set_silent(de)
        set_time_limit_sec(de, time_limit)
        mip && set_attribute(de, "mip_rel_gap", 1e-6)
        for (key, value) in instance.highs
            set_attribute(de, key, value)
        end
        optimize!(de)
        status = JuMP.termination_status(de)
        value = primal_status(de) == MOI.FEASIBLE_POINT ? objective_value(de) : NaN
        bound = mip ? objective_bound(de) : NaN
        result = verdict(instance, published(instance, reference), status, value, bound, mip)
        return (; value, result, seconds = time() - started, bytes)
    catch e
        e isa InterruptException && rethrow()
        isfile(path) && rm(path)
        message = first(split(sprint(showerror, e), '\n'))
        return (value = NaN, result = "error: $message", seconds = time() - started, bytes = 0)
    end
end

"""Reads `instance` and solves it written both ways: a vector of the results, `nothing` where
it is not written so."""
function run(instance, root, reference, time_limit, directory)
    problem = with_logger(NullLogger()) do
        return read_smps(joinpath.(root, instance.files)...;
                         probability_sums = instance.probability_sums, sense = instance.sense)
    end
    problem = written_problem(problem)
    coefficients = any(e -> e[1] in (:A, :T, :W), problem.elements)
    return [random_variables && coefficients ? nothing :
            solve_sof(instance, problem, directory, reference, time_limit, random_variables)
            for random_variables in (true, false)]
end

cell(r) = r === nothing ? ("", "—") : (isfinite(r.value) ? @sprintf("%.10g", r.value) : "", r.result)
megabytes(r) = r === nothing ? "" : @sprintf("%.2f", r.bytes / 2^20)

"""The table of `results` in Markdown."""
function markdown(io, results, option, elapsed)
    println(io, "# StochOptFormat: validation results\n")
    println(io, "SMPSFormat $(pkgversion(SMPSFormat)), SDDP.jl $(pkgversion(SDDP)), JuMP $(pkgversion(JuMP)), ",
            "HiGHS.jl $(pkgversion(HiGHS)) (HiGHS $(HiGHS.Highs_versionMajor()).$(HiGHS.Highs_versionMinor()).",
            "$(HiGHS.Highs_versionPatch())), Julia $VERSION, $(Sys.MACHINE); run on ",
            "$(Dates.format(now(), "yyyy-mm-dd")), instances up to the size `$(SIZES[option.size])`, ",
            "$(round(Int, option.time_limit)) seconds per solve, $(round(elapsed / 60; digits = 1)) minutes in all.\n")
    println(io, "Each instance is written in StochOptFormat by `write_sof`, read back by `SDDP.read_from_file`, ",
            "and the deterministic equivalent `SDDP.deterministic_equivalent` builds of it solved with HiGHS: ",
            "with random variables, unless the instance has random coefficients in its rows, which SDDP.jl ",
            "does not read (—), and with the data of each node. The files are gzipped.\n")
    for (k, mode) in enumerate(MODES)
        counts = Dict{String,Int}()
        for (_, r) in results
            r[k] === nothing && continue
            key = startswith(r[k].result, "error") ? "error" : replace(r[k].result, r" \([A-Z_]+\)" => "")
            counts[key] = get(counts, key, 0) + 1
        end
        println(io, "- ", uppercasefirst(mode), ": ", join(("$v $k" for (k, v) in sort(collect(counts))), ", "), ".")
    end
    println(io, "\n| Instance | Published | Random variables | Result | MB | Data by node | Result | MB | Seconds |")
    println(io, "|---|--:|--:|---|--:|--:|---|--:|--:|")
    for (instance, r) in results
        seconds = sum(x.seconds for x in r if x !== nothing; init = 0.0)
        println(io, "| ", join((instance.name, printed(instance), cell(r[1])..., megabytes(r[1]),
                                cell(r[2])..., megabytes(r[2]), @sprintf("%.1f", seconds)), " | "), " |")
    end
    known = [instance for (instance, _) in results if instance.known !== nothing]
    if !isempty(known)
        println(io, "\n## Known differences\n")
        println(io, "Those of the validation of SMPSFormat (see its results), the same files being read:\n")
        foreach(instance -> println(io, "- $(instance.name): $(instance.known)"), known)
    end
end

function main(arguments)
    option = options(arguments)
    config = TOML.parsefile(joinpath(@__DIR__, "instances.toml"))
    selected = [i for i in instances(config)
                if !i.read_only && findfirst(==(i.size), SIZES) <= option.size && occursin(option.only, i.name)]
    roots = Dict(a => archive_root(config["archive"][a], option.data) for a in unique(i.archive for i in selected))
    directory = mktempdir()
    started = time()
    results = []
    for instance in selected
        r = run(instance, roots[instance.archive], get(config["reference"], instance.reference, Dict()),
                option.time_limit, directory)
        push!(results, instance => r)
        @printf("%-18s %16s", instance.name, printed(instance))
        for x in r
            value, result = cell(x)
            @printf("  %16s %-18s", value, result)
        end
        @printf(" %8.1f s\n", sum(x.seconds for x in r if x !== nothing; init = 0.0))
        flush(stdout)
        GC.gc()
    end
    elapsed = time() - started
    isempty(option.output) || open(io -> markdown(io, results, option, elapsed), option.output, "w")
    bad = [i.name for (i, r) in results if any(x -> x !== nothing && failed(x.result), r)]
    println("\n", length(results), " instances, ", length(bad), " to look at", isempty(bad) ? "" : ": " * join(bad, ", "))
    return isempty(bad) ? 0 : 1
end

end

exit(SOFValidation.main(ARGS))
