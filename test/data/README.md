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
