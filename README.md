# SMPSFormat.jl

[![CI](https://github.com/fbastin/SMPSFormat.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/fbastin/SMPSFormat.jl/actions/workflows/CI.yml)

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

## What it reads

- **Core file**: free MPS, with `OBJSENSE`, `OBJNAME`, `RANGES`, integer markers, and the bounds
  `UP`, `LO`, `FX`, `FR`, `MI`, `PL`, `BV`, `LI`, `UI`.
- **Time file**: any number of periods, implicit or explicit.
- **Stoch file**: `INDEP` (`DISCRETE`, `UNIFORM`, `NORMAL`, `GAMMA`, `BETA`, `LOGNORM`), `BLOCKS
  DISCRETE`, two-stage `SCENARIOS` trees, with the modifiers `REPLACE`, `ADD` and `MULTIPLY`. The
  random data may be the right-hand sides, the matrix coefficients, the costs and, in `BLOCKS`
  and `SCENARIOS` sections, the bounds (`UP`, `LO`, `FX`) of the second stage.
- **Stoch file in more periods, `INDEP` and `BLOCKS`**: a law by period, as in two periods, each
  element or block revealed in the period its line gives, at most that of its data; the laws of
  the periods are independent.
- **Stoch file in more periods, `SCENARIOS`**: `SCENARIOS DISCRETE` trees, `REPLACE`. A scenario
  branches from `ROOT` or from a scenario given before it, in the period its `SC` line gives; it
  shares its parent's nodes before, and changes only data of that period or later: right-hand
  sides, matrix coefficients, costs, bounds.
- **The files as the literature writes them**: comment lines anywhere, headers indented by
  mistake, problem names that differ between the three files (a warning), probabilities rounded
  to the digits written (normalized; see `probability_sums`), time and stoch files whose first
  section is `NAME` (as some of SMI's), comment lines with a hash in the first column (as
  CoinMpsIO reads them).

Not yet: `SCENARIOS` mixed with `INDEP` or `BLOCKS` in more than two periods, `NODES`, `DISTRIB`,
`MVNORMAL`, `LINTRAN`, chance constraints, simple recourse, random ranges, random bounds in
`INDEP` sections or of the types `FR`, `MI`, `PL`, `BV`, `LI`, `UI`, network core files. They
are refused with an error.

## What it writes

`write_smps` writes a two-stage problem (its law, or given scenarios), a tree (`SCENARIOS`, each
scenario branching from the first that shares its last common node), or a law by period (`INDEP`
and `BLOCKS`, each line in the period it is revealed in), in free MPS with the columns and rows
in the order of their periods; `read_smps` reads them back into the same problem. A tree's nodes
are numbered scenario by scenario, whether it is read or built, so that a tree written and read
back has the same nodes.

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
- A tree built from a law by period (`scenario_tree`, `sample_tree`) gives each node of period
  `t − 1` its children in period `t`; a period without random data gives one child. Sampled, each
  child has the probability `1 / n` of its parent's; the draws are independent from node to node,
  or common to the nodes of a period (`common = true`).

The reader was checked on SPLIB's 95 instances of Zverovich's thesis (2011, Table 4.3), against
the thesis's optimal values, and on the eight multistage instances of Zehtabian and Bastin
(*Penalty parameter update strategies in progressive hedging algorithm*, CIRRELT-2016-12, Table 2:
KW3R, KW3Rb, app0110R, SGPF3Y3, Asset Mgt, SGPF5Y4, wat10I16, wat10C32), against the optimal values
of the report; app0110R's, whose probabilities sum up to 0.999, with `probability_sums =
:as_written`. SMI's original stoch file of wat10I16, with its random bounds, gives the same value.
In more periods with `INDEP` and `BLOCKS`, it was checked against the optimal values of POSTS
(Post_Results): pltexpA3_6, pltexpA3_16 and pltexpA4_6 are reproduced; fxm3.6, fxm3.16 and
fxm4.6, with their probabilities as written, all exceed them by the same 0.104, as the two-stage
fxm2.16 does, which points to a difference in the data, not in the tree.

## Licence

MIT.
