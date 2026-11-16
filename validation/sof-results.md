# StochOptFormat: validation results

SMPSFormat 0.9.0, SDDP.jl 1.15.0, JuMP 1.32.1, HiGHS.jl 1.27.0 (HiGHS 1.16.0), Julia 1.12.1, x86_64-linux-gnu; run on 2026-11-15, instances up to the size `small`, 1800 seconds per solve, 1.1 minutes in all.

Each instance is written in StochOptFormat by `write_sof`, read back by `SDDP.read_from_file`, and the deterministic equivalent `SDDP.deterministic_equivalent` builds of it solved with HiGHS: with random variables, unless the instance has random coefficients in its rows, which SDDP.jl does not read (—), and with the data of each node. The files are gzipped.

- Random variables: 45 agrees, 4 differs (known).
- Data by node: 55 agrees, 5 differs (known).

| Instance | Published | Random variables | Result | MB | Data by node | Result | MB | Seconds |
|---|--:|--:|---|--:|--:|---|--:|--:|
| pltexpA2_6 | -9.479354 | -9.479354405 | agrees | 0.01 | -9.479354405 | agrees | 0.04 | 6.2 |
| pltexpA2_16 | -9.663308 | -9.663308373 | agrees | 0.01 | -9.663308373 | agrees | 0.09 | 0.1 |
| pltexpA3_6 | -13.969368 | -13.96936764 | agrees | 0.02 | -13.96936764 | agrees | 0.08 | 1.0 |
| pltexpB3 | -13.643226 | -13.64322619 | agrees | 0.02 | -13.64322619 | agrees | 0.05 | 0.2 |
| pltexpB4 | -17.928191 | -17.92819134 | agrees | 0.03 | -17.92819134 | agrees | 0.08 | 0.4 |
| pltexpB5 | -23.846166 | -23.84339992 | differs (known) | 0.04 | -23.84339992 | differs (known) | 0.10 | 1.3 |
| fxm2.6 | 18417.065572 | 18417.06557 | agrees | 0.02 | 18417.06557 | agrees | 0.09 | 0.4 |
| fxm2.16 | 18416.759028 | 18416.75903 | agrees | 0.02 | 18416.75903 | agrees | 0.23 | 0.4 |
| fxm3.6 | 18615.932 | 18616.03616 | differs (known) | 0.02 | 18616.03616 | differs (known) | 0.11 | 0.6 |
| stormG2.8 | 15535200 | 15535235.73 | agrees | 0.03 | 15535235.73 | agrees | 0.22 | 0.6 |
| stormG2.27 | 15508982.306 | 15508982.31 | agrees | 0.04 | 15508982.31 | agrees | 0.72 | 1.9 |
| sgpf5y3 | -3027.706 | -3027.6035 | differs (known) | 0.02 | -3027.6035 | differs (known) | 0.13 | 0.5 |
| sgpf5y4 | -4031.3 | -4031.303083 | agrees | 0.03 | -4031.303083 | agrees | 0.85 | 2.0 |
| sgpf3y3 | -2967.917 | -2967.910853 | differs (known) | 0.01 | -2967.910853 | differs (known) | 0.09 | 0.1 |
| airl-first | 249101.672072 | 249101.6721 | agrees | 0.00 | 249101.6721 | agrees | 0.00 | 0.0 |
| airl-second | 269665.498390 | 269665.4984 | agrees | 0.00 | 269665.4984 | agrees | 0.00 | 0.0 |
| airl-randgen | 250262 | 250262.0498 | agrees | 0.00 | 250262.0498 | agrees | 0.04 | 0.6 |
| assets-small | -723.839 |  | — |  | -723.8386129 | agrees | 0.01 | 0.0 |
| 4node-1 | 413.388 | 413.3875 | agrees | 0.01 | 413.3875 | agrees | 0.01 | 0.0 |
| 4node-2 | 414.013 | 414.0125 | agrees | 0.01 | 414.0125 | agrees | 0.01 | 0.0 |
| 4node-4 | 416.513 | 416.5125 | agrees | 0.01 | 416.5125 | agrees | 0.02 | 0.0 |
| 4node-8 | 418.513 | 418.5125 | agrees | 0.01 | 418.5125 | agrees | 0.04 | 0.1 |
| 4node-16 | 423.013 | 423.0125 | agrees | 0.01 | 423.0125 | agrees | 0.08 | 0.2 |
| 4node-32 | 423.013 | 423.0125 | agrees | 0.01 | 423.0125 | agrees | 0.16 | 0.4 |
| 4node-64 | 423.013 | 423.0125 | agrees | 0.01 | 423.0125 | agrees | 0.31 | 1.1 |
| 4node-base-1 | 413.388 | 413.3875 | agrees | 0.01 | 413.3875 | agrees | 0.01 | 0.0 |
| 4node-base-2 | 414.013 | 414.0125 | agrees | 0.01 | 414.0125 | agrees | 0.01 | 0.0 |
| 4node-base-4 | 414.388 | 414.3875 | agrees | 0.01 | 414.3875 | agrees | 0.02 | 0.0 |
| 4node-base-8 | 414.688 | 414.6875 | agrees | 0.01 | 414.6875 | agrees | 0.04 | 0.1 |
| 4node-base-16 | 414.688 | 414.6875 | agrees | 0.01 | 414.6875 | agrees | 0.08 | 0.1 |
| 4node-base-32 | 416.6 | 416.6 | agrees | 0.01 | 416.6 | agrees | 0.16 | 0.3 |
| 4node-base-64 | 416.6 | 416.6 | agrees | 0.01 | 416.6 | agrees | 0.31 | 1.0 |
| 4node-old | 83094.075275 | 83094.07527 | agrees | 0.01 | 83094.07527 | agrees | 0.16 | 0.5 |
| chem | -13009.166667 | -13009.16667 | agrees | 0.00 | -13009.16667 | agrees | 0.00 | 0.0 |
| chem-base | -13009.2 | -13009.16667 | agrees | 0.00 | -13009.16667 | agrees | 0.00 | 0.0 |
| lands | 381.853333 | 381.8533333 | agrees | 0.00 | 381.8533333 | agrees | 0.00 | 0.0 |
| lands-blocks | 381.853 | 381.8533333 | agrees | 0.00 | 381.8533333 | agrees | 0.00 | 0.0 |
| lands3-indep | 719.2066666667 | 719.2066667 | agrees | 0.00 | 719.2066667 | agrees | 0.00 | 0.0 |
| lands3-dep | 722.5836666667 | 722.5836667 | agrees | 0.00 | 722.5836667 | agrees | 0.00 | 0.0 |
| env-aggr | 20478.7 | 20478.69899 | agrees | 0.00 | 20478.69899 | agrees | 0.01 | 0.0 |
| env-first | 19777.4 | 19777.44472 | agrees | 0.00 | 19777.44472 | agrees | 0.01 | 0.0 |
| env-loose | 19777.4 | 19777.44472 | agrees | 0.00 | 19777.44472 | agrees | 0.01 | 0.0 |
| env-15 | 22265.3 |  | — |  | 22265.25491 | agrees | 0.01 | 0.0 |
| env-diss-aggr | 15963.9 | 15963.9291 | agrees | 0.00 | 15963.9291 | agrees | 0.01 | 0.0 |
| env-diss-first | 14794.6 | 14794.60822 | agrees | 0.00 | 14794.60822 | agrees | 0.01 | 0.0 |
| env-diss-loose | 14794.6 | 14794.60822 | agrees | 0.00 | 14794.60822 | agrees | 0.01 | 0.0 |
| env-diss-15 | 20773.9 |  | — |  | 20773.88852 | agrees | 0.01 | 0.0 |
| phone1 | 36.9 | 36.9 | agrees | 0.00 | 36.9 | agrees | 0.00 | 0.0 |
| stocfor1 | -41132 | -41131.98323 | agrees | 0.00 | -41131.98323 | agrees | 0.00 | 0.0 |
| stocfor2 | -39772.4 |  | — |  | -39772.44771 | agrees | 0.19 | 0.2 |
| sslp_5_25_50 | -121.600 | -121.6 | agrees | 0.00 | -121.6 | agrees | 0.15 | 6.4 |
| wati-10-16 | -2158.7519 |  | — |  | -2158.751929 | agrees | 0.62 | 0.8 |
| wati-10-32 | -1866.398 |  | — |  | -1866.396931 | agrees | 1.09 | 1.6 |
| wati-10-64 | -2310.53 |  | — |  | -2310.526382 | agrees | 1.87 | 3.5 |
| watc-10-16 | -2401.875 |  | — |  | -2401.87525 | agrees | 0.62 | 0.8 |
| watc-10-32 | -2167.624 |  | — |  | -2167.62414 | agrees | 1.09 | 1.6 |
| watc-10-64 | -2027.4293 |  | — |  | -2310.526382 | differs (known) | 1.87 | 3.1 |
| KandW3R | 2613 | 2613 | agrees | 0.00 | 2613 | agrees | 0.00 | 0.0 |
| app0110R | 41.958 | 41.958 | agrees | 0.00 | 41.958 | agrees | 0.01 | 0.0 |
| wat_10_C_32 | -2611.92 |  | — |  | -2611.919384 | agrees | 1.15 | 1.5 |

## Known differences

Those of the validation of SMPSFormat (see its results), the same files being read:

- pltexpB5: The cause is not known: the same files, read the same way, give pltexpB3 and pltexpB4 to the digits published; with the probabilities normalized, -23.839595. COIN-OR SMI reads the same problem from these files (their blocks rewritten as scenarios): Clp gives -23.839595, SMI normalizing the probabilities.
- fxm3.6: Post_Results is 0.104 lower, as for fxm2.16, whose value computed by Felt on the same files agrees with ours (and Zverovich's, to six digits): Post_Results was probably computed on another version of the files.
- sgpf5y3: Post_Results is about 0.1 lower; it is 0.088 lower for sgpf5y4 too, whose value computed by Zehtabian and Bastin on the same files, with COIN-OR SMI, agrees with ours.
- sgpf3y3: SPLIB's sgpf3y files are not those of POSTS: Felt took them from Frauendorfer's directory (slptestset/sg/README.local). Zehtabian and Bastin's copy of sgpf3y3 gives -2967.91 (CIRRELT-2016-12), as these files do.
- watc-10-64: SPLIB's watc-10-64.sto is the same file as wati-10-64.sto: it gives the optimum of wati-10-64.
