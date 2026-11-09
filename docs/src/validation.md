# Validation

The reader is checked against the optimal values published for the test collections of the
literature: each instance is read, its deterministic equivalent solved with HiGHS, and its
optimal value compared with the published one, to the digits published (give or take 1e-9 of the
value, the accuracy of the solve).

## The instances

- **POSTS**, the portable stochastic programming test set of Holmes (1995): pltexp, fxm, storm
  and sgpf, in two to six periods, with the values of its file `Post_Results`.
- **Felt's test set** (Ariyawansa and Felt, 2004): airlift, assets, cargo, chem, LandS (in two
  and three periods), environ, phone, stocfor, with the solutions distributed with it and the
  values of Zverovich's thesis (2011, Table 4.3).
- **GENSLP and SAPHIR** (rand, saphir): the values of Zverovich's thesis.
- **SIPLIB**, the stochastic integer programming test library of Ahmed et al.: SSLP, SIZES,
  DCAP and SEMI, with the optimal values, or the best bounds, of its pages, and for DCAP those of
  Kim and Dandurand (2022).
- **COIN-OR SMI**'s multistage instances (KandW3R, app0110R, wat_10_C_32), with the values of
  Zehtabian and Bastin (CIRRELT-2016-12, Table 2).

The files are those of SPLIB (Zverovich's collection) and of COIN-OR's Data-Stochastic, each
downloaded at a fixed commit and checked by the hash of its content. The instances, their files
and their published values are listed in `validation/instances.toml`, with the reference of each
value.

## Running it

```
julia --project=validation -e 'using Pkg; Pkg.develop(path = "."); Pkg.instantiate()'
julia --project=validation validation/validate.jl --size medium --output results.md
```

`--size` selects the instances by the time their deterministic equivalent takes: `small`
(seconds; the continuous integration runs them), `medium` (minutes), `large` (more, and a few
gigabytes of memory), `huge` (over ten million nonzeros, more memory than most computers have). `--only` selects them by name, `--time-limit` limits each solve. The script
exits with an error when an instance differs from its published value without a known reason, or
cannot be read or solved.

## What it shows

The published values are reproduced, with a few exceptions, each documented in the
[results](results.md) and in `instances.toml`:

- **Probabilities as written.** Some stoch files give probabilities with four digits, 1/6 as
  0.1667, that sum up to 1.0002; the published values of POSTS (pltexpA2_16, pltexpB) and of
  Zverovich's thesis (airlift's randgen) were computed with them as written, without normalizing
  them, and are reproduced with `probability_sums = :as_written`.
- **Values computed on other files.** Post_Results differs from the values computed on SPLIB's
  files of fxm and sgpf by other authors, with other readers (Felt's for fxm, COIN-OR SMI's for
  sgpf5y4), which agree with this one; the difference is the same on the larger instances of the
  family, for which no other value is published. SPLIB's sgpf3y files are not those of POSTS,
  as Felt notes. Post_Results' values of stormG2.8 and stormG2.125 are 3.8 and 1.0 below HiGHS's,
  whatever its tolerances and method. SIPLIB's value of sizes3 is the optimum of the deterministic
  equivalent distributed with the files, whose costs, weighted by the probabilities 1/3, are
  rounded to two decimals. Where a value computed on the same files agrees, it is the reference,
  and the note gives the collection's.
- **Integer programs.** SIPLIB gives the optimal values of SSLP and SIZES, and only bounds for
  DCAP and SEMI: the optimum found must lie within them. When a solve stops at its time limit, its
  bounds must be consistent with the published ones. SIPLIB's bounds of DCAP, those of the DBB
  method of Ahmed, Tawarmalani and Sahinidis (2004), are above the optimal values of four of the
  five instances in 200 and 500 scenarios that Kim and Dandurand (2022) solve; the solve here
  finds solutions of their values. Their values are the reference of those instances; SIPLIB's,
  of the instances in 300 scenarios, whose probabilities are written 0.003333.

The [results](results.md) are those of the last run, with the version of each package and of
HiGHS.

Outside the script, the reader was also checked on the eight multistage instances of Zehtabian
and Bastin (CIRRELT-2016-12, Table 2: KW3R, KW3Rb, app0110R, SGPF3Y3, Asset Mgt, SGPF5Y4,
wat10I16, wat10C32), against the values of the report, three of whose files (KW3Rb, a variant of
KW3R with random technology matrices, Asset Mgt and wat10I16) are not distributed with SPLIB or
COIN-OR's Data-Stochastic; SMI's original stoch file of wat10I16, with its random bounds, gives
the same value.
