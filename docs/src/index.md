# SMPSFormat.jl

Read and write stochastic programs in the SMPS format: two-stage problems, and multistage ones
given by their scenario tree or by a law for each period. The format is that of Birge et al.
(1987), as Gassmann describes it and as Gassmann and Kristjánsson explain it (*The SMPS format
explained*, IMA Journal of Management Mathematics, 2007, doi:10.1093/imaman/dpm007).

An instance in the SMPS format comes in three files:

- the **core** file, the deterministic problem in MPS format;
- the **time** file, which splits its columns and rows into periods;
- the **stoch** file, the law of its random data: independent elements (`INDEP`), blocks of
  elements (`BLOCKS`), or the scenarios of a tree (`SCENARIOS`).

[`read_smps`](@ref) reads them into one of three types, according to what they describe:

| The instance | The type | What it gives |
|---|---|---|
| two periods | [`SMPSProblem`](@ref) | the matrices of each stage, the random elements and their law, an [`SMPSLaw`](@ref) |
| more periods, `SCENARIOS` | [`SMPSTree`](@ref) | the core data and the scenario tree |
| more periods, `INDEP` and `BLOCKS` | [`SMPSStagewise`](@ref) | the core data and a law for each period, independent from one period to the next |

[`write_smps`](@ref) writes each back, and [`read_smps`](@ref) reads what it writes into the same
problem. With JuMP loaded, [`extensive_form`](@ref) builds the deterministic equivalent.

## Installation

The package is not registered yet; install it from its repository:

```julia
using Pkg
Pkg.add(url = "https://github.com/fbastin/SMPSFormat.jl")
```

## A first example

LandS, the electricity capacity expansion problem of Louveaux and Smeers, in Felt's test set:

```@example first
using SMPSFormat
data = joinpath(pkgdir(SMPSFormat), "test", "data")
smps = read_smps(joinpath(data, "lands"))     # lands.cor, lands.tim, lands.sto
```

Its law is discrete; its three scenarios, and its deterministic equivalent solved with HiGHS:

```@example first
using JuMP, HiGHS
(; ξ, p) = enumerate_scenarios(smps.law)
model, x, y = extensive_form(smps, ξ, p; optimizer = HiGHS.Optimizer)
set_silent(model)
optimize!(model)
objective_value(model)
```

The [Guide](guide.md) goes through the rest: trees, laws by period, sampling, writing. [The
format](format.md) says what the reader accepts and how it reads what the format leaves open, and
[Validation](validation.md) how it was checked against the optimal values published for the test
collections of the literature.
