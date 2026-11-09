# SMPSFormat.jl

[![CI](https://github.com/fbastin/SMPSFormat.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/fbastin/SMPSFormat.jl/actions/workflows/CI.yml)

Read stochastic linear programs in the SMPS format, two-stage ones and multistage ones with their
scenario tree, and write two-stage ones (Birge et al., 1987;
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

tree = read_smps("KandW3R")                   # three periods: an SMPSTree
scenario_data(tree, 1)                        # (c, A, rhs) of the first scenario
bundles(tree, 2)                              # the scenarios sharing a node in period 2
model, x = extensive_form(tree; optimizer = HiGHS.Optimizer)   # x[n]: the variables of node n
```

## What it reads

- **Core file**: free MPS, with `OBJSENSE`, `OBJNAME`, `RANGES`, integer markers, and the bounds
  `UP`, `LO`, `FX`, `FR`, `MI`, `PL`, `BV`, `LI`, `UI`.
- **Time file**: any number of periods, implicit or explicit.
- **Stoch file**: `INDEP` (`DISCRETE`, `UNIFORM`, `NORMAL`, `GAMMA`, `BETA`, `LOGNORM`), `BLOCKS
  DISCRETE`, two-stage `SCENARIOS` trees, with the modifiers `REPLACE`, `ADD` and `MULTIPLY`. The
  random data may be the right-hand sides, the matrix coefficients, the costs and, in `BLOCKS`
  and `SCENARIOS` sections, the bounds (`UP`, `LO`, `FX`) of the second stage.
- **Stoch file in more periods**: `SCENARIOS DISCRETE` trees, `REPLACE`. A scenario branches from
  `ROOT` or from a scenario given before it, in the period its `SC` line gives; it shares its
  parent's nodes before, and changes only data of that period or later: right-hand sides,
  matrix coefficients, costs, bounds.
- **The files as the literature writes them**: comment lines anywhere, headers indented by
  mistake, problem names that differ between the three files (a warning), probabilities rounded
  to the digits written (normalized; see `probability_sums`), time and stoch files whose first
  section is `NAME` (as some of SMI's), comment lines with a hash in the first column (as
  CoinMpsIO reads them).

Not yet: `INDEP` and `BLOCKS` in more than two periods, writing a multistage instance, `NODES`,
`DISTRIB`, `MVNORMAL`, `LINTRAN`, chance constraints, simple recourse, random ranges, random
bounds in `INDEP` sections or of the types `FR`, `MI`, `PL`, `BV`, `LI`, `UI`, network core
files. They are refused with an error.

## Conventions

- A realization of a `BLOCKS` block lists what changes from the block's first realization; a
  scenario inherits what it does not list from its parent, the core file for `ROOT`.
- `NORMAL` and `LOGNORM` take a variance; `GAMMA` takes its scale, then its shape; `BETA` takes
  the two parameters of Beta(n, m). Gassmann's description gives the last two as formulas whose
  text could not be checked; these are the readings of its table.
- `MULTIPLY` multiplies the core value by the value given; `ADD` adds it.
- A maximization (`OBJSENSE MAX`, or `sense = :max`) is stored as the minimization of the
  opposite objective; `extensive_form` builds it as a maximization.
- As in MPS and CoinMpsIO: the objective is the first row of type `N`, or the one `OBJNAME`
  names; of several `RHS`, `RANGES` or `BOUNDS` vectors in the core file, only the first is used
  (a warning).
- A random bound line is written as in the core file's `BOUNDS` section, ` UP BND X1 5.0`: `UP`
  sets the upper bound, `LO` the lower one, `FX` both; a negative random upper bound does not
  free the lower bound.
- A tree has one node in the first period. A scenario branching from `ROOT` in the first period,
  as in the SGPF files of POSTS, must be the only child of `ROOT`; it then sets the data of the
  first period. A node's probability is the sum of those of its scenarios.

The reader was checked on SPLIB's 95 instances of Zverovich's thesis (2011, Table 4.3), against
the thesis's optimal values, and on the eight multistage instances of Zehtabian and Bastin
(*Penalty parameter update strategies in progressive hedging algorithm*, CIRRELT-2016-12, Table 2:
KW3R, KW3Rb, app0110R, SGPF3Y3, Asset Mgt, SGPF5Y4, wat10I16, wat10C32), against the optimal values
of the report; app0110R's, whose probabilities sum up to 0.999, with `probability_sums =
:as_written`. SMI's original stoch file of wat10I16, with its random bounds, gives the same value.

## Licence

MIT.
