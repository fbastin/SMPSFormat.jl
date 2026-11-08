# SMPSFormat.jl

[![CI](https://github.com/fbastin/SMPSFormat.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/fbastin/SMPSFormat.jl/actions/workflows/CI.yml)

Read and write two-stage stochastic linear programs in the SMPS format (Birge et al., 1987;
Gassmann's description of the format; Gassmann and Kristjánsson, *The SMPS format explained*,
IMA Journal of Management Mathematics, 2007, doi:10.1093/imaman/dpm007).

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
```

## What it reads

- **Core file**: free MPS, with `OBJSENSE`, `RANGES`, integer markers, and the bounds `UP`, `LO`,
  `FX`, `FR`, `MI`, `PL`, `BV`, `LI`, `UI`.
- **Time file**: two periods, implicit or explicit.
- **Stoch file**: `INDEP` (`DISCRETE`, `UNIFORM`, `NORMAL`, `GAMMA`, `BETA`, `LOGNORM`), `BLOCKS
  DISCRETE`, two-stage `SCENARIOS` trees, with the modifiers `REPLACE`, `ADD` and `MULTIPLY`. The
  random data may be the right-hand sides, the matrix coefficients and the costs of the second
  stage.
- **The files as the literature writes them**: comment lines anywhere, headers indented by
  mistake, problem names that differ between the three files (a warning), probabilities rounded
  to the digits written (normalized; see `probability_sums`).

Not yet: more than two periods, `NODES`, `DISTRIB`, `MVNORMAL`, `LINTRAN`, chance constraints,
simple recourse, random bounds and ranges, network core files. They are refused with an error.

## Conventions

- A realization of a `BLOCKS` block lists what changes from the block's first realization; a
  scenario inherits what it does not list from its parent, the core file for `ROOT`.
- `NORMAL` and `LOGNORM` take a variance; `GAMMA` takes its scale, then its shape; `BETA` takes
  the two parameters of Beta(n, m). Gassmann's description gives the last two as formulas whose
  text could not be checked; these are the readings of its table.
- `MULTIPLY` multiplies the core value by the value given; `ADD` adds it.
- A maximization (`OBJSENSE MAX`, or `sense = :max`) is stored as the minimization of the
  opposite objective; `extensive_form` builds it as a maximization.

The reader was checked on SPLIB's 95 instances of Zverovich's thesis (2011, Table 4.3), against
the thesis's optimal values.

## Licence

MIT.
