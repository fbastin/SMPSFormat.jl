using Documenter
using SMPSFormat
using JuMP          # the extension that defines extensive_form

# the results of the validation, a page of the manual
cp(joinpath(@__DIR__, "..", "validation", "results.md"), joinpath(@__DIR__, "src", "results.md"); force = true)

makedocs(sitename = "SMPSFormat.jl",
         authors = "Fabian Bastin",
         modules = [SMPSFormat, Base.get_extension(SMPSFormat, :SMPSFormatJuMPExt)],
         repo = Remotes.GitHub("fbastin", "SMPSFormat.jl"),
         format = Documenter.HTML(prettyurls = get(ENV, "CI", nothing) == "true", edit_link = "main",
                                  size_threshold_ignore = ["results.md"]),
         pages = ["Home" => "index.md",
                  "Guide" => "guide.md",
                  "The format" => "format.md",
                  "Validation" => ["validation.md", "Results" => "results.md"],
                  "Reference" => "api.md"],
         checkdocs = :exports)

deploydocs(repo = "github.com/fbastin/SMPSFormat.jl.git", devbranch = "main", push_preview = false)
