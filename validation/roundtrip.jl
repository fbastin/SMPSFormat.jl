"""
Validation of `write_smps` on the test collections: each instance of `instances.toml` is read,
written in SMPS by `write_smps`, and read back, its probabilities as written (`probability_sums =
:as_written`: those written are those read, in full) and without `sense`, which the written core
file must give. The problem read back must be the one read, every number exactly (`isequal`),
every name the same, but for the names that `write_smps` gives: `SMPS` for a problem without a
name, underscores for the spaces of a name, `RHS` for the right-hand side vector, and `S1`,
`S2`... for the scenarios of a tree.

- A two-stage problem or a law by period is compared field by field, its laws by their
  outcomes completed with the values of the core file for the elements of their block that they
  do not list: `write_smps` lists them all.
- A scenario tree is compared as a stochastic program: the same periods, rows and columns, the
  same scenarios with the same data (`scenario_data`), the same probabilities of their nodes, the
  same bundles in each period (`bundles`). Its representation may change: `write_smps` writes the
  data of the root in the core file, and only the values that differ from those inherited.

The instances only read by `validate.jl` are written too: their laws are written without
enumerating their scenarios.

    julia --project=validation validation/roundtrip.jl [options]

The options are those of `validate.jl`, but for `--time-limit`, which does not apply; `--output`
writes the table of the results in Markdown. The exit code is 1 when a problem read back differs
from the one read, or an instance cannot be written or read back.
"""
module RoundTrip

include("validate.jl")

using .Validation: options, instances, archive_root, SIZES
using Dates
using Logging
using Printf
using SMPSFormat
using SparseArrays
using TOML

"""The first difference between `a` and `b`, as the path of the field where they differ and the
two values, or `nothing` if they are the same: of the same type, the numbers equal (`isequal`, so
that `NaN` equals `NaN`), the strings and symbols the same, recursively."""
function difference(a, b)
    typeof(a) == typeof(b) || return ": a $(typeof(a)) and a $(typeof(b))"
    if a isa Union{Number, AbstractString, Symbol, Char, Nothing}
        return isequal(a, b) ? nothing : ": $(repr(a)) and $(repr(b))"
    elseif a isa SparseMatrixCSC
        size(a) == size(b) || return ": sizes $(size(a)) and $(size(b))"
        for (x, y) in ((a, b), (b, a)), (i, j, _) in zip(findnz(x)...)
            isequal(a[i, j], b[i, j]) || return "[$i, $j]: $(repr(a[i, j])) and $(repr(b[i, j]))"
        end
        return nothing
    elseif a isa Union{AbstractArray, Tuple}
        length(a) == length(b) || return ": lengths $(length(a)) and $(length(b))"
        for (i, (x, y)) in enumerate(zip(a, b))
            d = difference(x, y)
            d === nothing || return "[$i]" * d
        end
        return nothing
    elseif a isa SMPSLaw
        d = fields_difference(a, b; skip = (:outcomes,))
        d === nothing || return d
        d = difference(completed(a), completed(b))
        return d === nothing ? nothing : ".outcomes completed" * d
    elseif a isa AbstractDict
        keys(a) == keys(b) || return ": different keys"
        for k in keys(a)
            d = difference(a[k], b[k])
            d === nothing || return "[$(repr(k))]" * d
        end
        return nothing
    else
        return fields_difference(a, b)
    end
end

"""The outcomes of each block of `law`: the elements of the block, those its outcomes list, and
the values of each outcome, those of the core file (`law.base`) for the elements it does not
list."""
function completed(law)
    return map(law.outcomes) do outcomes
        elements = sort(unique(e for outcome in outcomes for (e, _) in outcome))
        values = [[get(Dict(outcome), e, law.base[e]) for e in elements] for outcome in outcomes]
        return elements, values
    end
end

"""The first difference between the fields of `a` and `b`, but those of `skip`."""
function fields_difference(a, b; skip = ())
    for f in fieldnames(typeof(a))
        f in skip && continue
        d = difference(getfield(a, f), getfield(b, f))
        d === nothing || return ".$f" * d
    end
    return nothing
end

"""The name of the problem `write_smps` writes for a problem named `name`."""
written_name(name) = isempty(name) ? "SMPS" : replace(name, r"\s+" => "_")

"""The names of the random elements of `problem`, but that of the right-hand side vector."""
element_names(problem) = [kind in (:h, :rhs) ? ("", row) : (name, row)
                          for ((kind, _, _), (name, row)) in zip(problem.elements, problem.names)]

"""The first difference between the problem `a` read and the problem `b` read back."""
function problem_difference(a, b)
    typeof(a) == typeof(b) || return ": a $(nameof(typeof(a))) read back as a $(nameof(typeof(b)))"
    b.name == written_name(a.name) || return ".name: $(repr(a.name)) written $(repr(b.name))"
    if !(a isa SMPSTree)
        d = fields_difference(a, b; skip = (:name, :names))
        d === nothing || return d
        d = difference(element_names(a), element_names(b))
        return d === nothing ? nothing : ".names" * d
    end
    d = fields_difference(a, b; skip = (:name, :c, :A, :rhs, :lb, :ub, :elements, :names,
                                        :elementperiod, :nodeperiod, :parent, :probability,
                                        :values, :scenarios, :scenarionames))
    d === nothing || return d
    length(a.scenarios) == length(b.scenarios) ||
        return ": $(length(a.scenarios)) scenarios and $(length(b.scenarios))"
    for t in eachindex(a.periods)
        d = difference(bundles(a, t), bundles(b, t))
        d === nothing || return ", bundles($t)" * d
    end
    for s in eachindex(a.scenarios)
        d = difference(a.probability[a.scenarios[s]], b.probability[b.scenarios[s]])
        d === nothing || return ", the probabilities of the nodes of scenario $s" * d
        d = difference(scenario_data(a, s), scenario_data(b, s))
        d === nothing || return ", scenario_data($s)" * d
    end
    return nothing
end

"""Reads `instance`, writes it in `directory` and reads it back: the outcome, the kind of the
problem, the seconds and the size of the three files."""
function run(instance, root, directory)
    started = time()
    prefix = joinpath(directory, instance.name)
    try
        problem, again, bytes = with_logger(NullLogger()) do
            problem = read_smps(joinpath.(root, instance.files)...; instance.sense,
                                probability_sums = instance.probability_sums)
            paths = write_smps(prefix, problem)
            again = read_smps(paths...; probability_sums = :as_written)
            bytes = sum(filesize, paths)
            foreach(rm, paths)
            return problem, again, bytes
        end
        d = problem_difference(problem, again)
        result = d === nothing ? "identical" : "differs: $(nameof(typeof(problem)))$d"
        return (; result, kind = string(nameof(typeof(problem))), seconds = time() - started, bytes)
    catch e
        e isa InterruptException && rethrow()
        foreach(ext -> rm(prefix * ext; force = true), (".cor", ".tim", ".sto"))
        message = replace(first(split(sprint(showerror, e), '\n')), root * "/" => "",
                          directory * "/" => "")
        return (result = "error: $message", kind = "", seconds = time() - started, bytes = 0)
    end
end

failed(result) = result != "identical"

"""The table of `results` in Markdown."""
function markdown(io, results, option, elapsed)
    println(io, "# SMPS round trip: validation results\n")
    println(io, "SMPSFormat $(pkgversion(SMPSFormat)), Julia $VERSION, $(Sys.MACHINE); run on ",
            "$(Dates.format(now(), "yyyy-mm-dd")), instances up to the size ",
            "`$(SIZES[option.size])`, $(round(elapsed / 60; digits = 1)) minutes in all.\n")
    println(io, "Each instance is read, written in SMPS by `write_smps` and read back, its ",
            "probabilities as written and without `sense`, which the written core file must give. ",
            "The problem read back must be the one read, every number exactly, every name the ",
            "same but for those `write_smps` gives (the problem's, the right-hand side vector's, ",
            "the scenarios' of a tree), the outcomes of a law completed with the values of the ",
            "core file for the elements of their block they do not list, all of which ",
            "`write_smps` lists; a scenario tree is compared as a stochastic program, by ",
            "its data by scenario (`scenario_data`), the probabilities of its nodes and its ",
            "bundles. The kind is that of the problem read: a two-stage problem (`SMPSProblem`), ",
            "a scenario tree (`SMPSTree`) or a law by period (`SMPSStagewise`).\n")
    counts = Dict{String,Int}()
    for (_, r) in results
        key = startswith(r.result, "error") ? "error" :
              startswith(r.result, "differs") ? "differs" : r.result
        counts[key] = get(counts, key, 0) + 1
    end
    println(io, join(("$v $k" for (k, v) in sort(collect(counts))), ", "), ".\n")
    println(io, "| Instance | Kind | MB written | Seconds | Result |")
    println(io, "|---|---|--:|--:|---|")
    for (instance, r) in results
        println(io, "| ", join((instance.name, r.kind, @sprintf("%.2f", r.bytes / 2^20),
                                @sprintf("%.1f", r.seconds), r.result), " | "), " |")
    end
end

function main(arguments)
    option = options(arguments)
    config = TOML.parsefile(joinpath(@__DIR__, "instances.toml"))
    selected = [i for i in instances(config)
                if findfirst(==(i.size), SIZES) <= option.size && occursin(option.only, i.name)]
    roots = Dict(a => archive_root(config["archive"][a], option.data)
                 for a in unique(i.archive for i in selected))
    directory = mktempdir()
    started = time()
    results = []
    for instance in selected
        r = run(instance, roots[instance.archive], directory)
        push!(results, instance => r)
        @printf("%-18s %-14s %8.2f MB %8.1f s  %s\n", instance.name, r.kind, r.bytes / 2^20,
                r.seconds, r.result)
        flush(stdout)
        GC.gc()
    end
    elapsed = time() - started
    isempty(option.output) || open(io -> markdown(io, results, option, elapsed), option.output, "w")
    bad = [i.name for (i, r) in results if failed(r.result)]
    println("\n", length(results), " instances, ", length(bad), " to look at",
            isempty(bad) ? "" : ": " * join(bad, ", "))
    return isempty(bad) ? 0 : 1
end

end

exit(RoundTrip.main(ARGS))
