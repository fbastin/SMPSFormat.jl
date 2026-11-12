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
  Kim and Dandurand (2022); SMKP, with the optimal values of Kim and Dandurand.
- **COIN-OR SMI**'s multistage instances (KandW3R, app0110R, wat_10_C_32), with the values of
  Zehtabian and Bastin (CIRRELT-2016-12, Table 2).
- **WATSON**, the pension fund problems of Consigli and Dempster (1998), in ten periods and 16
  to 2688 scenarios, with the values of their Tables 2 and 3, and of Dempster and Thompson
  (1998) for wati-10-64.
- **The sampling instances** of Linderoth, Shapiro and Wright (2006): gbd, LandS, 20term, ssn
  and storm, of 646,425 to 6×10^81 scenarios, whose optimal values they estimate from samples;
  Bayraksan and Morton (2011) give gbd's.
- **Topaloglu's datasets** (Cornell ORIE): electricity planning, fleet sizing and product
  distribution, of 10^47 to 10^204 scenarios.

The files are those of SPLIB (Zverovich's collection), of COIN-OR's Data-Stochastic and of DSP
(for SMKP), each downloaded at a fixed commit and checked by the hash of its content, and
Topaloglu's zip files, checked by their SHA-256. The instances, their files and their published
values are listed in `validation/instances.toml`, with the reference of each value.

An instance whose optimal value is not published, or whose deterministic equivalent is out of
reach, is only read: 20term, ssn and storm, whose 10^12 to 10^81 scenarios leave only the
estimates of Linderoth, Shapiro and Wright, and Topaloglu's datasets, for which the values of
two approximate policies are published, not optimal values. Reading them checks the files,
not a value. gbd and LandS have deterministic equivalents of tens of millions of nonzeros
(`huge`): gbd's optimum is that of Bayraksan and Morton (2011), who solve it exactly; LandS's,
which is not published, must lie within the confidence intervals of the estimates.

The collections that [the Stochastic Programming Society](https://www.stoprog.org/resources)
lists are all here, but for a few that the reader cannot check:

- the **random right-hand side instances** of Trapp, Prokopyev and Schaefer (2013): their page
  is gone, and the paper reports run times, not optimal values;
- SIPLIB's **VACCINE**, chance-constrained: its time files start both periods at the same
  column, which SMPS cannot express, and the chance constraint is not in the files;
  **MPTSPs**, **PROBPORT** and **EXPUTIL** are not in SMPS (a format of their own, the MPS file
  of a deterministic equivalent, a nonlinear objective);
- SMKP's instances 21 to 30, for which no optimal value is published.

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
  of the instances in 300 scenarios, whose probabilities are written 0.003333. HiGHS does not
  close the gap of SMKP's instances within minutes: their bounds are checked against Kim and
  Dandurand's optima.
- **WATSON's files.** Consigli and Dempster's solvers agree to the digits they print, at least
  two decimals, which is the tolerance of their values. Two of SPLIB's 24 files are not those
  of the published values: watc-10-64.sto is the same file as wati-10-64.sto, and wati-10-1920.sto
  starts with an initial cash balance of 500.63 instead of 300.63 (with 300.63, the published
  value is reproduced). The probabilities of watc-10-1920.sto sum up to 1.2, those of 1536
  equally likely scenarios given to 1536 of its 1920; normalized, they give the published value.
  The difference of watc-10-2304, 0.12, remains unexplained.

The [results](results.md) are those of the last run, with the version of each package and of
HiGHS.

Outside the script, the reader was also checked on the eight multistage instances of Zehtabian
and Bastin (CIRRELT-2016-12, Table 2: KW3R, KW3Rb, app0110R, SGPF3Y3, Asset Mgt, SGPF5Y4,
wat10I16, wat10C32), against the values of the report, two of whose files (KW3Rb, a variant of
KW3R with random technology matrices, and Asset Mgt) are not distributed with SPLIB or
COIN-OR's Data-Stochastic. wat10I16 is SPLIB's WATSON instance wati-10-16, which the script
checks; SMI's original stoch file of wat10I16, with its random bounds, gives the same value.
