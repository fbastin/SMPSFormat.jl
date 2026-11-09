# Guide

```@setup guide
using SMPSFormat, JuMP, HiGHS, Random
data = joinpath(pkgdir(SMPSFormat), "test", "data")
```

The examples read the test data of the package, in `test/data`: `data` below is that directory.

## Reading

[`read_smps`](@ref) takes the three files, or their common prefix: `read_smps(prefix)` looks for
`prefix` followed by `.cor` or `.core`, `.tim` or `.time`, `.sto` or `.stoch`, each possibly
compressed with gzip (`.gz`).

```@example guide
smps = read_smps(joinpath(data, "lands.cor"), joinpath(data, "lands.tim"), joinpath(data, "lands.sto"))
```

An error names the file and its line. The options of the reader:

- `sense = :max` reads the objective as a maximization, for files without `OBJSENSE`;
- `probability_sums` says what to do with probabilities that do not sum up to one, as those
  written with a few digits (1/6 as 0.1667): normalize them when the gap is within their rounding
  (`:rounding`, the default), always (`:normalize`), or keep them (`:as_written`), as some of the
  published optimal values were computed;
- `format = :fixed` reads the files in the columns of fixed MPS, so that names may contain blanks.

## Two-stage problems

An [`SMPSProblem`](@ref) holds the data of each stage, `c`, `A`, `b` and `q`, `T`, `W`, `h`, and
the random elements, `elements`, whose values `ξ` follow `law`. [`second_stage`](@ref) gives the
data of the second stage for one `ξ`:

```@example guide
smps.elements
```

```@example guide
(; ξ, p) = enumerate_scenarios(smps.law)
second_stage(smps, ξ[1]).h
```

A discrete law can be enumerated, [`enumerate_scenarios`](@ref); any law can be sampled:

```@example guide
rng = MersenneTwister(1)
ξs = rand(rng, smps.law, 1000)
length(ξs)
```

[`extensive_form`](@ref) builds the deterministic equivalent for given scenarios, those of the
law or a sample:

```@example guide
model, x, y = extensive_form(smps, ξs, fill(1 / 1000, 1000); optimizer = HiGHS.Optimizer)
set_silent(model)
optimize!(model)
objective_value(model)
```

## Scenario trees

An instance in more periods whose stoch file gives its scenarios, `SCENARIOS`, is read into an
[`SMPSTree`](@ref): the core data, and the tree, each node with its period, its parent, its
probability and the values of its random elements.

```@example guide
tree = read_smps(joinpath(data, "KandW3R"))
```

[`scenario_data`](@ref) gives the data of a scenario over all periods, [`bundles`](@ref) the
scenarios that share a node in a period, those whose decisions must be equal:

```@example guide
bundles(tree, 2)
```

```@example guide
scenario_data(tree, 1).rhs == scenario_data(tree, 2).rhs
```

The deterministic equivalent on the tree, in its nodal form, `x[n]` the variables of node `n`:

```@example guide
model, x = extensive_form(tree; optimizer = HiGHS.Optimizer)
set_silent(model)
optimize!(model)
objective_value(model)
```

## Laws by period

An instance in more periods whose stoch file gives `INDEP` and `BLOCKS` sections is read into an
[`SMPSStagewise`](@ref): a law for each period, independent from one period to the next. Its
tree, the product of these laws, is not built when it is read: it may be far too large.

```@example guide
s = read_smps(joinpath(data, "pltexpa-3.cor"), joinpath(data, "pltexpa-3.tim"),
              joinpath(data, "pltexpa-3-6.sto"))
```

```@example guide
support_size(s)
```

[`scenario_tree`](@ref) builds the whole tree when it is small enough; [`sample_tree`](@ref)
samples one, with a number of children for each period after the first:

```@example guide
tree = scenario_tree(s)
length(tree.scenarios)
```

```@example guide
sampled = sample_tree(MersenneTwister(1), s, [4, 3])
length(sampled.scenarios)
```

`rand(rng, s)` draws the values of the random elements in one scenario, and
[`scenario_data`](@ref) gives its data.

A two-stage problem can be turned into a tree in two periods too, so that a code written for
trees treats both:

```@example guide
scenario_tree(smps)
```

## Writing

[`write_smps`](@ref) writes a two-stage problem (its law, or given scenarios), a tree, or a law by
period, and returns the paths of the three files:

```@example guide
dir = mktempdir()
write_smps(joinpath(dir, "lands"), smps)
```

```@example guide
write_smps(joinpath(dir, "sampled"), smps; scenarios = (ξ = ξs, p = fill(1 / 1000, 1000)))
read_smps(joinpath(dir, "sampled"))
```

```@example guide
write_smps(joinpath(dir, "sampled-tree"), sampled)
read_smps(joinpath(dir, "sampled-tree"))
```
