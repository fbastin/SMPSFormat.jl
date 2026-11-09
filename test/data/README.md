# Test data

- `lands.cor`, `lands.tim`, `lands.sto`, `lands-blocks.sto`: LandS, the electricity capacity
  expansion problem of Louveaux and Smeers (1988), from Felt's test set as SPLIB distributes it
  (https://github.com/vitaut-archive/splib, `slptestset/electric`). Three scenarios; optimal value
  381.853333 (Zverovich's thesis, 2011, Table 4.3). `lands-blocks.sto` gives the same law in a
  `BLOCKS` section.
- `KandW3R.*`, `app0110R.*`, `wat_10_C_32.*`: multistage instances of the stochastic test data of
  COIN-OR SMI (`Data/Stochastic`, release 1.0.1; Eclipse Public License). KandW3R: 3 periods, 9
  scenarios, optimal value 2613; app0110R: 3 periods, 9 scenarios, time and stoch files whose
  first section is `NAME`, probabilities summing up to 0.999, optimal value 41.958 with them as
  written (42 normalized); wat_10_C_32: 10 periods, 32 scenarios, optimal value −2611.92. The
  values are those of Zehtabian and Bastin (CIRRELT-2016-12, Table 2).
- `pltexpa-3.*` with `pltexpa-3-6.sto`, `fxm.cor` with `fxm-3.tim` and `fxm-3-6.sto`: three-period
  instances of POSTS, the portable stochastic programming test set of Holmes (1995), as SPLIB
  distributes it (`posts/pltexp`, `posts/fxm`), with a law by period: `BLOCKS` for pltexpA3_6
  (36 scenarios, optimal value −13.969368 in Post_Results), `INDEP` for fxm3.6 (36 scenarios,
  18615.932 in Post_Results; 18616.036 read with the probabilities as written, as fxm2.16 exceeds
  its own value by the same 0.104).
