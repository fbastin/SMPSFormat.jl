"""
    SMPSFormat

Read and write two-stage stochastic linear programs in the SMPS format (Birge et al., 1987;
Gassmann's description of the format; Gassmann and Kristjánsson, 2007): a **core** file, the
deterministic problem in MPS format; a **time** file, which splits it into stages; a **stoch**
file, the law of its random data.

- [`read_smps`](@ref) reads the three files into an [`SMPSProblem`](@ref): the data of each stage
  as matrices and vectors, the random elements, and their law, an [`SMPSLaw`](@ref).
- The law can be enumerated, [`enumerate_scenarios`](@ref), when it is discrete, and sampled,
  `rand(rng, law, n)`; [`second_stage`](@ref) gives the data of the second stage in a scenario.
- [`write_smps`](@ref) writes a problem back, with its law or with given scenarios.
- With JuMP loaded, [`extensive_form`](@ref) builds the deterministic equivalent for given
  scenarios.

The package has a behavior of its own, meant to read the files of the literature as they are
written (SPLIB, POSTS, Felt's test set, SAPHIR): comment lines anywhere, free format, problem names
that differ between the files (a warning), probabilities rounded to the digits written
(normalized), scenario trees given in two stages.
"""
module SMPSFormat

using Distributions: Distributions, UnivariateDistribution, Normal, Uniform, Gamma, Beta, LogNormal
using Printf
using Random
using SparseArrays

export SMPSProblem, SMPSLaw, read_smps, write_smps, support_size, enumerate_scenarios,
       second_stage, row_bounds, extensive_form

include("lines.jl")
include("law.jl")
include("problem.jl")
include("read.jl")
include("write.jl")

"""
    extensive_form(smps::SMPSProblem, ξ, p; optimizer = nothing)

The deterministic equivalent of `smps` for the scenarios `ξ` (vectors of the values of the random
elements, as [`enumerate_scenarios`](@ref) or `rand` give them) and their probabilities `p`, as a
JuMP model: returns `(model, x, y)`, `x` the first-stage variables and `y[s]` the second-stage
variables of scenario `s`. The objective includes the constant of the core file, and is in the
sense of the problem read: a maximization read with `sense = :max` is built as a maximization.

Defined when JuMP is loaded (the package extension `SMPSFormatJuMPExt`).
"""
function extensive_form end

end
