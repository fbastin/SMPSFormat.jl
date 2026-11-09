"""
    SMPSFormat

Read and write stochastic linear programs in the SMPS format (Birge et al., 1987;
Gassmann's description of the format; Gassmann and Kristjánsson, 2007): a **core** file, the
deterministic problem in MPS format; a **time** file, which splits it into stages; a **stoch**
file, the law of its random data.

- [`read_smps`](@ref) reads the three files of a two-stage instance into an [`SMPSProblem`](@ref):
  the data of each stage as matrices and vectors, the random elements, and their law, an
  [`SMPSLaw`](@ref). An instance in more periods is read into an [`SMPSTree`](@ref), its scenario
  tree, or, when its random data are given period by period (`INDEP`, `BLOCKS`), into an
  [`SMPSStagewise`](@ref), from which [`scenario_tree`](@ref) builds the tree and
  [`sample_tree`](@ref) samples one; [`scenario_data`](@ref) gives the data of a scenario,
  [`bundles`](@ref) the scenarios that share a node.
- The law can be enumerated, [`enumerate_scenarios`](@ref), when it is discrete, and sampled,
  `rand(rng, law, n)`; [`second_stage`](@ref) gives the data of the second stage in a scenario.
- [`write_smps`](@ref) writes a problem back: a two-stage problem with its law or with given
  scenarios, a tree, a law by period. [`scenario_tree`](@ref) and [`sample_tree`](@ref) also turn
  a two-stage problem into a tree in two periods, so that a code written for trees treats both.
- With JuMP loaded, [`extensive_form`](@ref) builds the deterministic equivalent: for given
  scenarios of a two-stage instance, or on the tree of a multistage one.

The package has a behavior of its own, meant to read the files of the literature as they are
written (SPLIB, POSTS, Felt's test set, SAPHIR): comment lines anywhere, free format, problem names
that differ between the files (a warning), probabilities rounded to the digits written
(normalized), scenario trees in two stages or more, time and stoch files whose first section is
`NAME`.
"""
module SMPSFormat

using Distributions: Distributions, UnivariateDistribution, Normal, Uniform, Gamma, Beta, LogNormal
using Printf
using Random
using SparseArrays

export SMPSProblem, SMPSLaw, SMPSTree, SMPSStagewise, read_smps, write_smps, support_size,
       enumerate_scenarios, second_stage, scenario_data, bundles, scenario_tree, sample_tree,
       row_bounds, extensive_form

include("lines.jl")
include("law.jl")
include("problem.jl")
include("tree.jl")
include("stagewise.jl")
include("read.jl")
include("write.jl")

"""
    extensive_form(smps::SMPSProblem, ξ, p; optimizer = nothing)
    extensive_form(tree::SMPSTree; optimizer = nothing)

The deterministic equivalent of `smps` for the scenarios `ξ` (vectors of the values of the random
elements, as [`enumerate_scenarios`](@ref) or `rand` give them) and their probabilities `p`, as a
JuMP model: returns `(model, x, y)`, `x` the first-stage variables and `y[s]` the second-stage
variables of scenario `s`. The objective includes the constant of the core file, and is in the
sense of the problem read: a maximization read with `sense = :max` is built as a maximization.

On a tree, the deterministic equivalent in its nodal form: the variables of a period are those of
each node of that period, `x[n]` for node `n` (its columns in the order of the core file, as
`findall(==(nodeperiod[n]), colperiod)` lists them); returns `(model, x)`. Each row of a node
involves the variables of the node and of its ancestors, with the values of the node's random
elements; the objective weighs the costs of each node by its probability.

Defined when JuMP is loaded (the package extension `SMPSFormatJuMPExt`).
"""
function extensive_form end

end
