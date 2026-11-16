# StochOptFormat: validation results

SMPSFormat 0.9.0, SDDP.jl 1.15.0, JuMP 1.32.1, HiGHS.jl 1.27.0 (HiGHS 1.16.0), Julia 1.12.1, x86_64-linux-gnu; run on 2026-11-15, instances up to the size `medium`, 1800 seconds per solve, run in 8 processes, 52.0 minutes in all.

Each instance is written in StochOptFormat by `write_sof`, read back by `SDDP.read_from_file`, and the deterministic equivalent `SDDP.deterministic_equivalent` builds of it solved with HiGHS: with random variables, unless the instance has random coefficients in its rows, which SDDP.jl does not read (—), and with the data of each node. The files are gzipped.

The instances were split among 8 processes by name (`--only`), their tables merged. rand0-4000 was
then run again alone, the computer otherwise idle: run with the other processes, its solve with
random variables had reached the time limit. The interior point method without presolve that
`instances.toml` sets for the rand instances fails on SDDP.jl's deterministic equivalent of
rand0-4000 with the data of each node (`OTHER_ERROR`), and reaches the time limit on that of
rand0-6000 with random variables: SDDP.jl's deterministic equivalents are larger than
SMPSFormat's, with copies of the state variables and the random variables fixed.

- Random variables: 63 agrees, 13 differs (known), 1 not solved.
- Data by node: 100 agrees, 19 differs (known), 1 not solved.

| Instance | Published | Random variables | Result | MB | Data by node | Result | MB | Seconds |
|---|--:|--:|---|--:|--:|---|--:|--:|
| pltexpA2_6 | -9.479354 | -9.479354405 | agrees | 0.01 | -9.479354405 | agrees | 0.04 | 6.3 |
| pltexpA2_16 | -9.663308 | -9.663308373 | agrees | 0.01 | -9.663308373 | agrees | 0.09 | 0.2 |
| pltexpA3_6 | -13.969368 | -13.96936764 | agrees | 0.02 | -13.96936764 | agrees | 0.08 | 1.1 |
| pltexpA3_16 | -14.267458 | -14.26745774 | agrees | 0.02 | -14.26745774 | agrees | 0.21 | 5.1 |
| pltexpA4_6 | -19.599417 | -19.59941738 | agrees | 0.03 | -19.59941738 | agrees | 0.13 | 5.0 |
| pltexpA5_6 | -23.214073 | -23.21407133 | differs (known) | 0.04 | -23.21407133 | differs (known) | 0.20 | 250.1 |
| pltexpB3 | -13.643226 | -13.64322619 | agrees | 0.02 | -13.64322619 | agrees | 0.05 | 0.3 |
| pltexpB4 | -17.928191 | -17.92819134 | agrees | 0.03 | -17.92819134 | agrees | 0.08 | 0.6 |
| pltexpB5 | -23.846166 | -23.84339992 | differs (known) | 0.04 | -23.84339992 | differs (known) | 0.10 | 1.8 |
| fxm2.6 | 18417.065572 | 18417.06557 | agrees | 0.02 | 18417.06557 | agrees | 0.09 | 6.5 |
| fxm2.16 | 18416.759028 | 18416.75903 | agrees | 0.02 | 18416.75903 | agrees | 0.23 | 0.5 |
| fxm3.6 | 18615.932 | 18616.03616 | differs (known) | 0.02 | 18616.03616 | differs (known) | 0.11 | 1.3 |
| fxm3.16 | 18438.891 | 18438.99508 | differs (known) | 0.02 | 18438.99508 | differs (known) | 0.27 | 14.2 |
| fxm4.6 | 18616.224 | 18616.32797 | differs (known) | 0.03 | 18616.32797 | differs (known) | 0.13 | 4.3 |
| stormG2.8 | 15535200 | 15535235.73 | agrees | 0.03 | 15535235.73 | agrees | 0.22 | 0.9 |
| stormG2.27 | 15508982.306 | 15508982.31 | agrees | 0.04 | 15508982.31 | agrees | 0.72 | 2.5 |
| stormG2.125 | 15512090.180 | 15512091.18 | differs (known) | 0.04 | 15512091.18 | differs (known) | 3.31 | 18.6 |
| sgpf5y3 | -3027.706 | -3027.6035 | differs (known) | 0.02 | -3027.6035 | differs (known) | 0.13 | 1.3 |
| sgpf5y4 | -4031.3 | -4031.303083 | agrees | 0.03 | -4031.303083 | agrees | 0.85 | 4.3 |
| sgpf5y5 | -5201.282 | -5200.917904 | differs (known) | 0.08 | -5200.917904 | differs (known) | 5.13 | 26.6 |
| sgpf5y6 | -6403.3 | -6467.43021 | differs (known) | 0.25 | -6467.43021 | differs (known) | 30.06 | 329.2 |
| sgpf3y3 | -2967.917 | -2967.910853 | differs (known) | 0.01 | -2967.910853 | differs (known) | 0.09 | 0.3 |
| sgpf3y5 | -5172.165 | -5171.890871 | differs (known) | 0.06 | -5171.890871 | differs (known) | 3.34 | 18.5 |
| sgpf3y6 | -6463.323 | -6452.193393 | differs (known) | 0.20 | -6452.193393 | differs (known) | 19.72 | 187.8 |
| airl-first | 249101.672072 | 249101.6721 | agrees | 0.00 | 249101.6721 | agrees | 0.00 | 0.0 |
| airl-second | 269665.498390 | 269665.4984 | agrees | 0.00 | 269665.4984 | agrees | 0.00 | 0.0 |
| airl-randgen | 250262 | 250262.0498 | agrees | 0.00 | 250262.0498 | agrees | 0.04 | 0.7 |
| assets-small | -723.839 |  | — |  | -723.8386129 | agrees | 0.01 | 0.1 |
| 4node-1 | 413.388 | 413.3875 | agrees | 0.01 | 413.3875 | agrees | 0.01 | 0.0 |
| 4node-2 | 414.013 | 414.0125 | agrees | 0.01 | 414.0125 | agrees | 0.01 | 0.0 |
| 4node-4 | 416.513 | 416.5125 | agrees | 0.01 | 416.5125 | agrees | 0.02 | 0.1 |
| 4node-8 | 418.513 | 418.5125 | agrees | 0.01 | 418.5125 | agrees | 0.04 | 0.1 |
| 4node-16 | 423.013 | 423.0125 | agrees | 0.01 | 423.0125 | agrees | 0.08 | 0.2 |
| 4node-32 | 423.013 | 423.0125 | agrees | 0.01 | 423.0125 | agrees | 0.16 | 0.5 |
| 4node-64 | 423.013 | 423.0125 | agrees | 0.01 | 423.0125 | agrees | 0.31 | 1.5 |
| 4node-128 | 423.013 | 423.0125 | agrees | 0.01 | 423.0125 | agrees | 0.62 | 4.7 |
| 4node-256 | 425.375 | 425.375 | agrees | 0.01 | 425.375 | agrees | 1.23 | 14.4 |
| 4node-512 | 429.963 | 429.9625 | agrees | 0.01 | 429.9625 | agrees | 2.46 | 49.5 |
| 4node-1024 | 434.112 | 434.1125 | agrees | 0.01 | 434.1125 | agrees | 4.91 | 268.7 |
| 4node-base-1 | 413.388 | 413.3875 | agrees | 0.01 | 413.3875 | agrees | 0.01 | 0.0 |
| 4node-base-2 | 414.013 | 414.0125 | agrees | 0.01 | 414.0125 | agrees | 0.01 | 0.1 |
| 4node-base-4 | 414.388 | 414.3875 | agrees | 0.01 | 414.3875 | agrees | 0.02 | 0.1 |
| 4node-base-8 | 414.688 | 414.6875 | agrees | 0.01 | 414.6875 | agrees | 0.04 | 0.2 |
| 4node-base-16 | 414.688 | 414.6875 | agrees | 0.01 | 414.6875 | agrees | 0.08 | 0.3 |
| 4node-base-32 | 416.6 | 416.6 | agrees | 0.01 | 416.6 | agrees | 0.16 | 0.6 |
| 4node-base-64 | 416.6 | 416.6 | agrees | 0.01 | 416.6 | agrees | 0.31 | 1.7 |
| 4node-base-128 | 416.6 | 416.6 | agrees | 0.01 | 416.6 | agrees | 0.62 | 4.8 |
| 4node-base-256 | 417.162 | 417.161875 | agrees | 0.01 | 417.161875 | agrees | 1.23 | 15.1 |
| 4node-base-512 | 420.293 | 420.2925 | agrees | 0.01 | 420.2925 | agrees | 2.46 | 49.8 |
| 4node-base-1024 | 423.05 | 423.05 | agrees | 0.01 | 423.05 | agrees | 4.92 | 270.1 |
| 4node-old | 83094.075275 | 83094.07527 | agrees | 0.01 | 83094.07527 | agrees | 0.16 | 0.7 |
| chem | -13009.166667 | -13009.16667 | agrees | 0.00 | -13009.16667 | agrees | 0.00 | 0.3 |
| chem-base | -13009.2 | -13009.16667 | agrees | 0.00 | -13009.16667 | agrees | 0.00 | 0.0 |
| lands | 381.853333 | 381.8533333 | agrees | 0.00 | 381.8533333 | agrees | 0.00 | 0.0 |
| lands-blocks | 381.853 | 381.8533333 | agrees | 0.00 | 381.8533333 | agrees | 0.00 | 0.0 |
| lands3-indep | 719.2066666667 | 719.2066667 | agrees | 0.00 | 719.2066667 | agrees | 0.00 | 0.0 |
| lands3-dep | 722.5836666667 | 722.5836667 | agrees | 0.00 | 722.5836667 | agrees | 0.00 | 0.0 |
| env-aggr | 20478.7 | 20478.69899 | agrees | 0.00 | 20478.69899 | agrees | 0.01 | 0.3 |
| env-first | 19777.4 | 19777.44472 | agrees | 0.00 | 19777.44472 | agrees | 0.01 | 0.0 |
| env-loose | 19777.4 | 19777.44472 | agrees | 0.00 | 19777.44472 | agrees | 0.01 | 0.0 |
| env-15 | 22265.3 |  | — |  | 22265.25491 | agrees | 0.01 | 0.1 |
| env-1200 | 22428.9 |  | — |  | 22428.90823 | agrees | 0.45 | 9.5 |
| env-1875 | 22447.1 |  | — |  | 22447.11312 | agrees | 0.71 | 18.1 |
| env-3780 | 22441 |  | — |  | 22441.0436 | agrees | 1.42 | 64.5 |
| env-5292 | 22438.4 |  | — |  | 22438.42378 | agrees | 1.99 | 131.9 |
| env-8232 | 22439.1 |  | — |  | 22438.89396 | differs (known) | 3.09 | 341.8 |
| env-diss-aggr | 15963.9 | 15963.9291 | agrees | 0.00 | 15963.9291 | agrees | 0.01 | 0.0 |
| env-diss-first | 14794.6 | 14794.60822 | agrees | 0.00 | 14794.60822 | agrees | 0.01 | 0.0 |
| env-diss-loose | 14794.6 | 14794.60822 | agrees | 0.00 | 14794.60822 | agrees | 0.01 | 0.0 |
| env-diss-15 | 20773.9 |  | — |  | 20773.88852 | agrees | 0.01 | 0.0 |
| env-diss-1200 | 20808.6 |  | — |  | 20808.59319 | agrees | 0.46 | 7.2 |
| env-diss-1875 | 20809.3 |  | — |  | 20809.28824 | agrees | 0.71 | 16.0 |
| env-diss-3780 | 20794.7 |  | — |  | 20794.68302 | agrees | 1.43 | 55.7 |
| env-diss-5292 | 20788.6 |  | — |  | 20788.64505 | agrees | 2.00 | 103.8 |
| env-diss-8232 | 20799.4 |  | — |  | 20799.26507 | differs (known) | 3.11 | 295.0 |
| phone1 | 36.9 | 36.9 | agrees | 0.00 | 36.9 | agrees | 0.00 | 0.0 |
| stocfor1 | -41132 | -41131.98323 | agrees | 0.00 | -41131.98323 | agrees | 0.00 | 0.0 |
| stocfor2 | -39772.4 |  | — |  | -39772.44771 | agrees | 0.19 | 0.4 |
| rand0-2000 | 162.146 | 162.1460246 | agrees | 0.03 | 162.146025 | agrees | 13.19 | 214.5 |
| rand0-4000 | 199.032 | 199.0320874 | agrees | 0.04 | 199.323369 | not solved (OTHER_ERROR) | 26.38 | 2885.2 |
| rand0-6000 | 140.275 |  | not solved (TIME_LIMIT) | 0.09 | 140.2747333 | agrees | 39.56 | 2902.6 |
| rand1-2000 | 244.159 | 244.1587055 | agrees | 0.08 | 244.1587055 | agrees | 39.92 | 902.1 |
| saphir-50 | 129505000 |  | — |  | 129505616.3 | differs (known) | 5.72 | 234.9 |
| sslp_5_25_50 | -121.600 | -121.6 | agrees | 0.00 | -121.6 | agrees | 0.15 | 7.4 |
| sslp_5_25_100 | -127.370 | -127.37 | agrees | 0.01 | -127.37 | agrees | 0.29 | 17.1 |
| sslp_15_45_5 | -262.400 | -262.4 | agrees | 0.02 | -262.4 | agrees | 0.07 | 10.5 |
| sslp_15_45_10 | -260.500 | -260.5 | agrees | 0.02 | -260.5 | agrees | 0.14 | 21.9 |
| sslp_15_45_15 | -253.602 | -253.602333 | agrees | 0.02 | -253.602333 | agrees | 0.22 | 48.5 |
| dcap233_200 | [1834.55, 1834.57] |  | — |  | 1834.565368 | agrees | 0.06 | 31.8 |
| dcap243_200 | [2322.49, 2322.49] |  | — |  | 2322.494874 | agrees | 0.08 | 16.7 |
| dcap243_300 | [2559.297, 2559.545] |  | — |  | 2559.447893 | agrees | 0.12 | 17.9 |
| sizes3 | 224434.32 | 224433.7333 | differs (known) | 0.01 | 224433.7333 | differs (known) | 0.01 | 2.3 |
| sizes5 | 224486 | 224486 | agrees | 0.01 | 224486 | agrees | 0.02 | 4.4 |
| wati-10-16 | -2158.7519 |  | — |  | -2158.751929 | agrees | 0.62 | 7.8 |
| wati-10-32 | -1866.398 |  | — |  | -1866.396931 | agrees | 1.09 | 1.9 |
| wati-10-64 | -2310.53 |  | — |  | -2310.526382 | agrees | 1.87 | 4.1 |
| wati-10-128 | -1637.8125 |  | — |  | -1637.812523 | agrees | 3.10 | 8.5 |
| wati-10-256 | -2000.838 |  | — |  | -2000.838468 | agrees | 4.86 | 16.8 |
| wati-10-512 | -1959.635 |  | — |  | -1959.635803 | agrees | 6.98 | 33.7 |
| wati-10-768 | -1813.105 |  | — |  | -1813.105475 | agrees | 10.46 | 69.7 |
| wati-10-1024 | -1926.787 |  | — |  | -1926.788554 | agrees | 13.95 | 140.8 |
| wati-10-1152 | -1687.92 |  | — |  | -1687.920435 | agrees | 15.68 | 180.9 |
| wati-10-1536 | -1790.276 |  | — |  | -1790.275208 | agrees | 20.91 | 320.8 |
| wati-10-1920 | -1778.954 |  | — |  | -2891.11714 | differs (known) | 26.13 | 437.5 |
| watc-10-16 | -2401.875 |  | — |  | -2401.87525 | agrees | 0.62 | 8.0 |
| watc-10-32 | -2167.624 |  | — |  | -2167.62414 | agrees | 1.09 | 2.0 |
| watc-10-64 | -2027.4293 |  | — |  | -2310.526382 | differs (known) | 1.87 | 4.2 |
| watc-10-128 | -1879.432 |  | — |  | -1879.432526 | agrees | 3.10 | 8.6 |
| watc-10-256 | -1841.2985 |  | — |  | -1841.298568 | agrees | 4.86 | 16.6 |
| watc-10-512 | -1787.1977 |  | — |  | -1787.197732 | agrees | 6.98 | 32.0 |
| watc-10-768 | -1780.126 |  | — |  | -1780.126578 | agrees | 10.46 | 65.7 |
| watc-10-1024 | -1791.176 |  | — |  | -1791.176872 | agrees | 13.95 | 140.4 |
| watc-10-1152 | -1725.53 |  | — |  | -1725.533416 | agrees | 15.69 | 161.0 |
| watc-10-1536 | -1693.474 |  | — |  | -1693.474267 | agrees | 20.91 | 302.7 |
| watc-10-1920 | -1769.45 |  | — |  | -1769.45172 | agrees | 26.14 | 426.7 |
| watc-10-2304 | -1664.66 |  | — |  | -1664.778953 | differs (known) | 31.37 | 587.9 |
| watc-10-2688 | -1679.921 |  | — |  | -1679.920932 | agrees | 36.59 | 371.5 |
| KandW3R | 2613 | 2613 | agrees | 0.00 | 2613 | agrees | 0.00 | 0.0 |
| app0110R | 41.958 | 41.958 | agrees | 0.00 | 41.958 | agrees | 0.01 | 0.0 |
| wat_10_C_32 | -2611.92 |  | — |  | -2611.919384 | agrees | 1.15 | 2.8 |

## Known differences

Those of the validation of SMPSFormat (see its results), the same files being read:

- pltexpA5_6: Post_Results is 1.7e-6 lower, within the accuracy of the solvers on the pltexp problems, which are ill-conditioned: on the deterministic equivalents of COIN-OR SMI, which reads the same problems from these files (their blocks rewritten as scenarios), HiGHS and Clp differ by 2e-6 to 1e-5 on pltexpB3 to pltexpB5. HiGHS gives -23.2140713288 by the simplex method, with tighter tolerances, without scaling or presolve, and by interior points, with the probabilities normalized too; the other pltexpA instances agree to the digits published.
- pltexpB5: The cause is not known: the same files, read the same way, give pltexpB3 and pltexpB4 to the digits published; with the probabilities normalized, -23.839595. COIN-OR SMI reads the same problem from these files (their blocks rewritten as scenarios): Clp gives -23.839595, SMI normalizing the probabilities.
- fxm3.6: Post_Results is 0.104 lower, as for fxm2.16, whose value computed by Felt on the same files agrees with ours (and Zverovich's, to six digits): Post_Results was probably computed on another version of the files.
- fxm3.16: Post_Results is 0.104 lower, as for fxm2.16, whose value computed by Felt on the same files agrees with ours (and Zverovich's, to six digits): Post_Results was probably computed on another version of the files.
- fxm4.6: Post_Results is 0.104 lower, as for fxm2.16, whose value computed by Felt on the same files agrees with ours (and Zverovich's, to six digits): Post_Results was probably computed on another version of the files.
- stormG2.125: Post_Results' value is 1.005 lower; HiGHS gives 15512091.184793 by the simplex method, with tighter tolerances, and by interior points, as it gives stormG2.8 a value 3.8 above Post_Results'.
- sgpf5y3: Post_Results is about 0.1 lower; it is 0.088 lower for sgpf5y4 too, whose value computed by Zehtabian and Bastin on the same files, with COIN-OR SMI, agrees with ours.
- sgpf5y5: Post_Results is about 0.1 lower; it is 0.088 lower for sgpf5y4 too, whose value computed by Zehtabian and Bastin on the same files, with COIN-OR SMI, agrees with ours.
- sgpf5y6: Post_Results is about 0.1 lower; it is 0.088 lower for sgpf5y4 too, whose value computed by Zehtabian and Bastin on the same files, with COIN-OR SMI, agrees with ours.
- sgpf3y3: SPLIB's sgpf3y files are not those of POSTS: Felt took them from Frauendorfer's directory (slptestset/sg/README.local). Zehtabian and Bastin's copy of sgpf3y3 gives -2967.91 (CIRRELT-2016-12), as these files do.
- sgpf3y5: SPLIB's sgpf3y files are not those of POSTS: Felt took them from Frauendorfer's directory (slptestset/sg/README.local). Zehtabian and Bastin's copy of sgpf3y3 gives -2967.91 (CIRRELT-2016-12), as these files do.
- sgpf3y6: SPLIB's sgpf3y files are not those of POSTS: Felt took them from Frauendorfer's directory (slptestset/sg/README.local). Zehtabian and Bastin's copy of sgpf3y3 gives -2967.91 (CIRRELT-2016-12), as these files do.
- env-8232: Zverovich's value is 0.206 above, 9.2e-6 of it: within the relative stopping tolerance 1e-5 of his decomposition methods, as for env-32928, env-diss-8232 and env-diss-32928, all above. HiGHS gives 22438.893958 by the simplex method, with tighter tolerances, and by interior points, its probabilities exact.
- env-diss-8232: Zverovich's value is 0.135 above, 6.5e-6 of it: within the relative stopping tolerance 1e-5 of his decomposition methods, as for env-8232.
- saphir-50: Zverovich's value is 616 below, 4.8e-6 of it: within the relative stopping tolerance 1e-5 of his decomposition methods, whose stopping point, in a maximization, is a lower bound, as for env-8232. It is also the optimum truncated to six digits, as for saphir-100, while his other values are rounded. HiGHS gives 129505616.309 by the simplex method and by interior points with crossover.
- sizes3: SIPLIB's value is the optimum of the deterministic equivalent distributed with the files (siplib/sizes/sizes-3.mps), whose costs, weighted by the probabilities 1/3, are rounded to two decimals (8/3 written 2.67): HiGHS gives it 224434.32. The probabilities of sizes5 and sizes10 are exact.
- wati-10-1920: The root scenario of SPLIB's wati-10-1920.sto sets the right-hand side of CB11, the initial cash balance, to -500.63, against -300.63 in the 23 other WATSON files: with -300.63, the files give -1778.9548, the published value.
- watc-10-64: SPLIB's watc-10-64.sto is the same file as wati-10-64.sto: it gives the optimum of wati-10-64.
- watc-10-2304: The cause is not known: the other conditional problems give their published values, but watc-10-64, whose file is that of wati-10-64, and the values of this file lie within those of watc-10-1536 and watc-10-2688.
