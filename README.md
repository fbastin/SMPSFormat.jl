# SMPSFormat.jl

[![CI](https://github.com/fbastin/SMPSFormat.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/fbastin/SMPSFormat.jl/actions/workflows/CI.yml)
[![Validation](https://github.com/fbastin/SMPSFormat.jl/actions/workflows/Validation.yml/badge.svg)](https://github.com/fbastin/SMPSFormat.jl/actions/workflows/Validation.yml)
[![Documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://fbastin.github.io/SMPSFormat.jl/dev/)

Read and write stochastic linear programs in the SMPS format, two-stage ones and multistage ones,
given by their scenario tree or by a law for each period (Birge et al., 1987;
Gassmann's description of the format; Gassmann and Kristjánsson, *The SMPS format explained*,
IMA Journal of Management Mathematics, 2007, doi:10.1093/imaman/dpm007).

Not registered yet; install it from this repository:

```julia
using Pkg
Pkg.add(url = "https://github.com/fbastin/SMPSFormat.jl")
```

```julia
using SMPSFormat
smps = read_smps("lands")                     # lands.cor, lands.tim, lands.sto
(; ξ, p) = enumerate_scenarios(smps.law)      # a discrete law: every scenario
ξs = rand(smps.law, 1000)                     # or a sample
second_stage(smps, ξ[1])                      # (q, T, W, h) in the first scenario

using JuMP, HiGHS
model, x, y = extensive_form(smps, ξ, p; optimizer = HiGHS.Optimizer)

write_smps("copy", smps)                      # the law
write_smps("sampled", smps; scenarios = (ξ = ξs, p = fill(1 / 1000, 1000)))

tree = read_smps("KandW3R")                   # three periods, SCENARIOS: an SMPSTree
scenario_data(tree, 1)                        # (c, A, rhs) of the first scenario
bundles(tree, 2)                              # the scenarios sharing a node in period 2
model, x = extensive_form(tree; optimizer = HiGHS.Optimizer)   # x[n]: the variables of node n

s = read_smps("pltexpa-3.cor", "pltexpa-3.tim", "pltexpa-3-6.sto")  # BLOCKS: an SMPSStagewise
support_size(s)                               # 36 scenarios
tree = scenario_tree(s)                       # the whole tree, when it is small enough
tree = sample_tree(rng, s, [10, 5])           # or a sampled one: 10 children, then 5
write_smps("sampled-tree", tree)              # a tree, written as SCENARIOS
write_smps("copy", s)                         # a law by period, INDEP and BLOCKS with periods

tree = scenario_tree(smps)                    # a two-stage problem as a tree in two periods
tree = sample_tree(rng, smps, 100)            # or with 100 scenarios drawn
```

## What it reads and writes

- **Core files** in free or fixed MPS, with `OBJSENSE`, `OBJNAME`, `RANGES`, integer markers and
  all the bound types; **time files** in any number of periods, implicit or explicit.
- **Stoch files**: `INDEP` (discrete and continuous laws), `BLOCKS` and `SCENARIOS`, with
  `REPLACE`, `ADD` and `MULTIPLY`; random right-hand sides, matrix coefficients, costs and bounds.
  In more periods, a scenario tree (`SCENARIOS`) or a law by period (`INDEP`, `BLOCKS`).
- **The files as the literature writes them**: comments anywhere, problem names that differ,
  probabilities rounded to the digits written, `NAME` as first section, carriage returns, gzip.
- **Writing**: a two-stage problem (its law or given scenarios), a tree, a law by period; read
  back into the same problem.

What is refused, and how the reader settles what the format leaves open, is in [the
documentation](https://fbastin.github.io/SMPSFormat.jl/dev/format/).

## Validation

The reader is checked against the optimal values published for the test collections of the
literature: POSTS, Felt's test set, GENSLP and SAPHIR, WATSON and the sampling instances of
Linderoth, Shapiro and Wright (as SPLIB distributes them), SIPLIB, COIN-OR SMI's multistage
instances, and Topaloglu's datasets. [`validation/validate.jl`](validation/validate.jl) downloads
the files at fixed commits, reads each instance of
[`validation/instances.toml`](validation/instances.toml), solves its deterministic equivalent
with HiGHS, and compares its optimal value with the published one; an instance with no
published optimum, or too many scenarios, is only read. The continuous integration runs the
small instances. The [results](validation/results.md) list each instance, its reference, and
the few differences that remain, with what is known of their causes.

## Licence

MIT.
