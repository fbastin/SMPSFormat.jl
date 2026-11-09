# The format

What the reader accepts, what it refuses, and how it reads what the format leaves open.

## What it reads

- **Core file**: free MPS, with `OBJSENSE`, `OBJNAME`, `RANGES`, integer markers, and the bounds
  `UP`, `LO`, `FX`, `FR`, `MI`, `PL`, `BV`, `LI`, `UI`.
- **Time file**: any number of periods, implicit (the first column and row of each period) or
  explicit (`PERIODS EXPLICIT`, the period of each column and row).
- **Stoch file in two periods**: `INDEP` (`DISCRETE`, `UNIFORM`, `NORMAL`, `GAMMA`, `BETA`,
  `LOGNORM`), `BLOCKS DISCRETE`, `SCENARIOS DISCRETE`, with the modifiers `REPLACE`, `ADD` and
  `MULTIPLY`. The random data may be the right-hand sides, the matrix coefficients, the costs
  and, in `BLOCKS` and `SCENARIOS` sections, the bounds (`UP`, `LO`, `FX`) of the second stage.
- **Stoch file in more periods, `INDEP` and `BLOCKS`**: a law by period, as in two periods, each
  element or block revealed in the period its line gives, at most that of its data; the laws of
  the periods are independent.
- **Stoch file in more periods, `SCENARIOS`**: `SCENARIOS DISCRETE` trees, `REPLACE`. A scenario
  branches from `ROOT` or from a scenario given before it, in the period its `SC` line gives; it
  shares its parent's nodes before, and changes only data of that period or later: right-hand
  sides, matrix coefficients, costs, bounds.
- **The files as the literature writes them**: comment lines anywhere, headers indented by
  mistake, problem names that differ between the three files (a warning), probabilities rounded
  to the digits written (see `probability_sums` in [`read_smps`](@ref)), time and stoch files
  whose first section is `NAME` (as some of SMI's), comment lines with a hash in the first column
  (as CoinMpsIO reads them), lines ending with a carriage return, files compressed with gzip
  (`.gz`).
- **Fixed MPS**, with `format = :fixed`: the fields in the columns of fixed MPS, so that names may
  contain blanks; tolerant of a field shifted by a column, as in SMI's `SC` lines. Only for files
  that are in fixed format: a compact layout (as SMI's `Asset.cor`) is read in free format, the
  default, which reads most fixed files too.
- **Errors** name the file and the line read.

Not yet: `SCENARIOS` mixed with `INDEP` or `BLOCKS` in more than two periods, `NODES`,
`DISTRIB`, `MVNORMAL`, `LINTRAN`, chance constraints, simple recourse, random ranges, random
bounds in `INDEP` sections or of the types `FR`, `MI`, `PL`, `BV`, `LI`, `UI`, network core
files. They are refused with an error.

## What it writes

[`write_smps`](@ref) writes a two-stage problem (its law, or given scenarios), a tree
(`SCENARIOS`, each scenario branching from the first that shares its last common node), or a law
by period (`INDEP` and `BLOCKS`, each line in the period it is revealed in), in free MPS with the
columns and rows in the order of their periods (a name with a blank is refused);
[`read_smps`](@ref) reads them back into the same problem. A tree's nodes are numbered scenario by
scenario, whether it is read or built, so that a tree written and read back has the same nodes.

## Conventions

- A realization of a `BLOCKS` block lists what changes from the block's first realization; a
  scenario inherits what it does not list from its parent, the core file for `ROOT`.
- `NORMAL` and `LOGNORM` take a variance; `GAMMA` takes its scale, then its shape; `BETA` takes
  the two parameters of Beta(n, m). Gassmann's description gives the last two as formulas whose
  text could not be checked; these are the readings of its table.
- `MULTIPLY` multiplies the core value by the value given; `ADD` adds it.
- A maximization (`OBJSENSE MAX`, or `sense = :max`) is stored as the minimization of the
  opposite objective; [`extensive_form`](@ref) builds it as a maximization.
- As in MPS and CoinMpsIO: the objective is the first row of type `N`, or the one `OBJNAME`
  names; of several `RHS`, `RANGES` or `BOUNDS` vectors in the core file, only the first is used
  (a warning).
- A random bound line is written as in the core file's `BOUNDS` section, ` UP BND X1 5.0`: `UP`
  sets the upper bound, `LO` the lower one, `FX` both; a negative random upper bound does not
  free the lower bound.
- A tree has one node in the first period. A scenario branching from `ROOT` in the first period,
  as in the SGPF files of POSTS, must be the only child of `ROOT`; it then sets the data of the
  first period. A node's probability is the sum of those of its scenarios.
- A tree built from a law by period ([`scenario_tree`](@ref), [`sample_tree`](@ref)) gives each
  node of period `t − 1` its children in period `t`; a period without random data gives one
  child. Sampled, each child has the probability `1 / n` of its parent's; the draws are
  independent from node to node, or common to the nodes of a period (`common = true`).
