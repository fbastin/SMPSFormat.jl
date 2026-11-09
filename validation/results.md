# Validation results

SMPSFormat 0.7.0, JuMP 1.32.1, HiGHS.jl 1.26.1 (HiGHS 1.15.1), Julia 1.12.5, x86_64-linux-gnu; run on 2026-11-09, instances up to the size `medium`, 600 seconds per solve, 15.3 minutes in all.

73 agrees, 10 differs (known).

| Instance | Periods | Scenarios | Rows | Columns | Published | Reference | Computed | Difference | Seconds | Result |
|---|--:|--:|--:|--:|--:|---|--:|--:|--:|---|
| pltexpA2_6 | 2 | 6 | 686 | 1820 | -9.479354 | posts | -9.479354405 | -4.05e-07 | 6.9 | agrees |
| pltexpA2_16 | 2 | 16 | 1726 | 4540 | -9.663308 | posts | -9.663308373 | -3.73e-07 | 0.8 | agrees |
| pltexpA3_6 | 3 | 36 | 4430 | 11612 | -13.969368 | posts | -13.96936764 | 3.55e-07 | 0.9 | agrees |
| pltexpA3_16 | 3 | 256 | 28350 | 74172 | -14.267458 | posts | -14.26745774 | 2.6e-07 | 1.3 | agrees |
| pltexpA4_6 | 4 | 216 | 26894 | 70364 | -19.599417 | posts | -19.59941738 | -3.82e-07 | 1.1 | agrees |
| pltexpB3 | 3 | 12 | 1934 | 5084 | -13.643226 | posts | -13.64322619 | -1.92e-07 | 0.0 | agrees |
| pltexpB4 | 4 | 24 | 4430 | 11612 | -17.928191 | posts | -17.92819134 | -3.39e-07 | 0.1 | agrees |
| pltexpB5 | 5 | 48 | 9422 | 24668 | -23.846166 | posts | -23.84339992 | 0.00277 | 0.3 | differs (known) |
| fxm2.6 | 2 | 6 | 1520 | 2172 | 18417.065572 | felt | 18417.06557 | 4.93e-07 | 0.1 | agrees |
| fxm2.16 | 2 | 16 | 3900 | 5602 | 18416.759028 | felt | 18416.75903 | 3.49e-07 | 0.2 | agrees |
| fxm3.6 | 3 | 36 | 6200 | 9492 | 18615.932 | posts | 18616.03616 | 0.104 | 0.4 | differs (known) |
| fxm3.16 | 3 | 256 | 41340 | 64162 | 18438.891 | posts | 18438.99508 | 0.104 | 9.6 | differs (known) |
| fxm4.6 | 4 | 216 | 22400 | 30732 | 18616.224 | posts | 18616.32797 | 0.104 | 2.6 | differs (known) |
| stormG2.8 | 2 | 8 | 4409 | 10193 | 15535200 | zverovich | 15535235.73 | 35.7 | 0.2 | agrees |
| stormG2.27 | 2 | 27 | 14441 | 34114 | 15508982.306 | posts | 15508982.31 | -0.000493 | 0.7 | agrees |
| stormG2.125 | 2 | 125 | 66185 | 157496 | 15512090.180 | posts | 15512091.18 | 1 | 6.2 | differs (known) |
| sgpf5y3 | 3 | 25 | 1952 | 2509 | -3027.706 | posts | -3027.6035 | 0.103 | 0.2 | differs (known) |
| sgpf5y4 | 4 | 125 | 9827 | 12384 | -4031.3 | cirrelt | -4031.303083 | -0.00308 | 0.1 | agrees |
| sgpf5y5 | 5 | 625 | 49202 | 61759 | -5201.282 | posts | -5200.848593 | 0.433 | 0.7 | differs (known) |
| sgpf3y3 | 3 | 25 | 1208 | 1617 | -2967.917 | posts | -2967.910853 | 0.00615 | 0.0 | differs (known) |
| sgpf3y5 | 5 | 625 | 30458 | 39867 | -5172.165 | posts | -5171.929007 | 0.236 | 0.4 | differs (known) |
| airl-first | 2 | 25 | 152 | 204 | 249101.672072 | felt | 249101.6721 | 3.31e-07 | 0.0 | agrees |
| airl-second | 2 | 25 | 152 | 204 | 269665.498390 | felt | 269665.4984 | 1.07e-07 | 0.0 | agrees |
| airl-randgen | 2 | 676 | 4058 | 5412 | 250262 | zverovich | 250262.0498 | 0.0498 | 0.1 | agrees |
| assets-small | 2 | 100 | 505 | 1313 | -723.839 | zverovich | -723.8386129 | 0.000387 | 0.0 | agrees |
| 4node-1 | 2 | 1 | 88 | 238 | 413.388 | zverovich | 413.3875 | -0.0005 | 0.0 | agrees |
| 4node-2 | 2 | 2 | 162 | 424 | 414.013 | zverovich | 414.0125 | -0.0005 | 0.0 | agrees |
| 4node-4 | 2 | 4 | 310 | 796 | 416.513 | zverovich | 416.5125 | -0.0005 | 0.0 | agrees |
| 4node-8 | 2 | 8 | 606 | 1540 | 418.513 | zverovich | 418.5125 | -0.0005 | 0.0 | agrees |
| 4node-16 | 2 | 16 | 1198 | 3028 | 423.013 | zverovich | 423.0125 | -0.0005 | 0.1 | agrees |
| 4node-32 | 2 | 32 | 2382 | 6004 | 423.013 | zverovich | 423.0125 | -0.0005 | 0.3 | agrees |
| 4node-64 | 2 | 64 | 4750 | 11956 | 423.013 | zverovich | 423.0125 | -0.0005 | 0.7 | agrees |
| 4node-128 | 2 | 128 | 9486 | 23860 | 423.013 | zverovich | 423.0125 | -0.0005 | 2.6 | agrees |
| 4node-256 | 2 | 256 | 18958 | 47668 | 425.375 | zverovich | 425.375 | 2.79e-11 | 10.2 | agrees |
| 4node-512 | 2 | 512 | 37902 | 95284 | 429.963 | zverovich | 429.9625 | -0.0005 | 32.9 | agrees |
| 4node-1024 | 2 | 1024 | 75790 | 190516 | 434.112 | zverovich | 434.1125 | 0.0005 | 131.7 | agrees |
| 4node-base-1 | 2 | 1 | 90 | 238 | 413.388 | zverovich | 413.3875 | -0.0005 | 0.0 | agrees |
| 4node-base-2 | 2 | 2 | 164 | 424 | 414.013 | zverovich | 414.0125 | -0.0005 | 0.0 | agrees |
| 4node-base-4 | 2 | 4 | 312 | 796 | 414.388 | zverovich | 414.3875 | -0.0005 | 0.0 | agrees |
| 4node-base-8 | 2 | 8 | 608 | 1540 | 414.688 | zverovich | 414.6875 | -0.0005 | 0.0 | agrees |
| 4node-base-16 | 2 | 16 | 1200 | 3028 | 414.688 | zverovich | 414.6875 | -0.0005 | 0.1 | agrees |
| 4node-base-32 | 2 | 32 | 2384 | 6004 | 416.6 | zverovich | 416.6 | -1.71e-13 | 0.2 | agrees |
| 4node-base-64 | 2 | 64 | 4752 | 11956 | 416.6 | zverovich | 416.6 | 3.18e-12 | 0.6 | agrees |
| 4node-base-128 | 2 | 128 | 9488 | 23860 | 416.6 | zverovich | 416.6 | 2.9e-12 | 1.8 | agrees |
| 4node-base-256 | 2 | 256 | 18960 | 47668 | 417.162 | zverovich | 417.161875 | -0.000125 | 6.1 | agrees |
| 4node-base-512 | 2 | 512 | 37904 | 95284 | 420.293 | zverovich | 420.2925 | -0.0005 | 18.9 | agrees |
| 4node-base-1024 | 2 | 1024 | 75792 | 190516 | 423.05 | zverovich | 423.05 | 2.24e-11 | 105.4 | agrees |
| 4node-old | 2 | 32 | 2382 | 6004 | 83094.075275 | felt | 83094.07527 | -2.74e-07 | 0.3 | agrees |
| chem | 2 | 2 | 130 | 121 | -13009.166667 | felt | -13009.16667 | 3.33e-07 | 0.0 | agrees |
| chem-base | 2 | 2 | 118 | 121 | -13009.2 | zverovich | -13009.16667 | 0.0333 | 0.0 | agrees |
| lands | 2 | 3 | 23 | 40 | 381.853333 | felt | 381.8533333 | 3.33e-07 | 0.0 | agrees |
| lands-blocks | 2 | 3 | 23 | 40 | 381.853 | zverovich | 381.8533333 | 0.000333 | 0.0 | agrees |
| lands3-indep | 3 | 9 | 128 | 220 | 719.2066666667 | felt | 719.2066667 | -3.29e-11 | 0.0 | agrees |
| lands3-dep | 3 | 9 | 86 | 148 | 722.5836666667 | felt | 722.5836667 | -3.32e-11 | 0.0 | agrees |
| env-aggr | 2 | 5 | 288 | 294 | 20478.7 | zverovich | 20478.69899 | -0.00101 | 0.0 | agrees |
| env-first | 2 | 5 | 288 | 294 | 19777.4 | zverovich | 19777.44472 | 0.0447 | 0.0 | agrees |
| env-loose | 2 | 5 | 288 | 294 | 19777.4 | zverovich | 19777.44472 | 0.0447 | 0.0 | agrees |
| env-15 | 2 | 15 | 768 | 784 | 22265.3 | zverovich | 22265.25491 | -0.0451 | 0.0 | agrees |
| env-1200 | 2 | 1200 | 57648 | 58849 | 22428.9 | zverovich | 22428.90823 | 0.00823 | 1.4 | agrees |
| env-1875 | 2 | 1875 | 90048 | 91924 | 22447.1 | zverovich | 22447.11312 | 0.0131 | 2.6 | agrees |
| env-3780 | 2 | 3780 | 181488 | 185269 | 22441 | zverovich | 22441.0436 | 0.0436 | 8.0 | agrees |
| env-5292 | 2 | 5292 | 254064 | 259357 | 22438.4 | zverovich | 22438.42378 | 0.0238 | 14.7 | agrees |
| env-diss-aggr | 2 | 5 | 288 | 294 | 15963.9 | zverovich | 15963.9291 | 0.0291 | 0.0 | agrees |
| env-diss-first | 2 | 5 | 288 | 294 | 14794.6 | zverovich | 14794.60822 | 0.00822 | 0.0 | agrees |
| env-diss-loose | 2 | 5 | 288 | 294 | 14794.6 | zverovich | 14794.60822 | 0.00822 | 0.0 | agrees |
| env-diss-15 | 2 | 15 | 768 | 784 | 20773.9 | zverovich | 20773.88852 | -0.0115 | 0.0 | agrees |
| env-diss-1200 | 2 | 1200 | 57648 | 58849 | 20808.6 | zverovich | 20808.59319 | -0.00681 | 1.6 | agrees |
| env-diss-1875 | 2 | 1875 | 90048 | 91924 | 20809.3 | zverovich | 20809.28824 | -0.0118 | 3.5 | agrees |
| env-diss-3780 | 2 | 3780 | 181488 | 185269 | 20794.7 | zverovich | 20794.68302 | -0.017 | 11.9 | agrees |
| env-diss-5292 | 2 | 5292 | 254064 | 259357 | 20788.6 | zverovich | 20788.64505 | 0.045 | 22.3 | agrees |
| phone1 | 2 | 1 | 24 | 93 | 36.9 | zverovich | 36.9 | 7.11e-15 | 0.0 | agrees |
| stocfor1 | 2 | 1 | 117 | 111 | -41132 | zverovich | -41131.98323 | 0.0168 | 0.0 | agrees |
| stocfor2 | 2 | 64 | 6543 | 6159 | -39772.4 | zverovich | -39772.44771 | -0.0477 | 0.1 | agrees |
| sslp_5_25_50 | 2 | 50 | 1501 | 6505 | -121.600 | siplib | -121.6 | -1.42e-14 | 17.8 | agrees |
| sslp_5_25_100 | 2 | 100 | 3001 | 13005 | -127.370 | siplib | -127.37 | 0 | 62.2 | agrees |
| dcap233_200 | 2 | 200 | 3006 | 5412 | [1834.55, 1834.57] | kim | 1834.565368 | 0 | 110.0 | agrees |
| dcap243_200 | 2 | 200 | 3606 | 7212 | [2322.49, 2322.49] | kim | 2322.495735 | 0.00574 | 76.5 | agrees |
| dcap243_300 | 2 | 300 | 5406 | 10812 | [2559.297, 2559.545] | siplib | 2559.447808 | 0 | 195.6 | agrees |
| sizes3 | 2 | 3 | 124 | 300 | 224434.32 | siplib | 224433.7333 | -0.587 | 2.1 | differs (known) |
| sizes5 | 2 | 5 | 186 | 450 | 224486 | siplib | 224486 | -1.46e-10 | 14.6 | agrees |
| KandW3R | 3 | 9 | 25 | 28 | 2613 | cirrelt | 2613 | 2.73e-12 | 0.0 | agrees |
| app0110R | 3 | 9 | 129 | 268 | 41.958 | cirrelt | 41.958 | 1.42e-14 | 0.0 | agrees |
| wat_10_C_32 | 10 | 32 | 8413 | 15553 | -2611.92 | cirrelt | -2611.919384 | 0.000616 | 0.3 | agrees |

## Notes

- pltexpA2_16: Read with warnings: posts/pltexp/pltexpa-2-16.sto: the probabilities of BLOCKS BLOCK001 sum up to 1.0002; kept as written.
- pltexpB3: Read with warnings: posts/pltexp/pltexpb-3-6.sto: the probabilities of BLOCKS BLOCK001 sum up to 1.0002; kept as written.
- pltexpB4: Read with warnings: posts/pltexp/pltexpb-4-6.sto: the probabilities of BLOCKS BLOCK001 sum up to 1.0002; kept as written.
- pltexpB5: The cause is not known: the same files, read the same way, give pltexpB3 and pltexpB4 to the digits published; with the probabilities normalized, -23.839595. Read with warnings: posts/pltexp/pltexpb-5-6.sto: the probabilities of BLOCKS BLOCK001 sum up to 1.0002; kept as written.
- fxm2.6: Post_Results gives 18416.686; Zverovich, 18417.1. Read with warnings: posts/fxm/fxm-2-6.sto: the probabilities of INDEP (RHS, 1MS037) sum up to 1.0000200000000001; kept as written.
- fxm2.16: Post_Results gives 18416.655; Zverovich, 18416.8.
- fxm3.6: Post_Results is 0.104 lower, as for fxm2.16, whose value computed by Felt on the same files agrees with ours (and Zverovich's, to six digits): Post_Results was probably computed on another version of the files. Read with warnings: posts/fxm/fxm-3-6.sto: the probabilities of INDEP (RHS, 1MS037) sum up to 1.0000200000000001; kept as written; posts/fxm/fxm-3-6.sto: the probabilities of INDEP (RHS, 1PD068) sum up to 1.0000200000000001; kept as written.
- fxm3.16: Post_Results is 0.104 lower, as for fxm2.16, whose value computed by Felt on the same files agrees with ours (and Zverovich's, to six digits): Post_Results was probably computed on another version of the files.
- fxm4.6: Post_Results is 0.104 lower, as for fxm2.16, whose value computed by Felt on the same files agrees with ours (and Zverovich's, to six digits): Post_Results was probably computed on another version of the files. Read with warnings: posts/fxm/fxm-4-6.sto: the probabilities of INDEP (RHS, 1MS037) sum up to 1.0000200000000001; kept as written; posts/fxm/fxm-4-6.sto: the probabilities of INDEP (RHS, 1PD068) sum up to 1.0000200000000001; kept as written; posts/fxm/fxm-4-6.sto: the probabilities of INDEP (RHS, 1RB089) sum up to 1.0000200000000001; kept as written.
- stormG2.8: Post_Results gives 15535231.897, 3.8 lower; HiGHS gives the same value as here with tighter tolerances, by interior points and without scaling. The stoch file is not that of the other storm instances (no problem name). Read with warnings: The SMPS files name different problems: Prob_2 (core), Prob_2 (time),  (stoch).
- stormG2.27: Read with warnings: The SMPS files name different problems: Prob_2 (core), Prob_2 (time), storm (stoch).
- stormG2.125: Post_Results' value is 1.005 lower; HiGHS gives 15512091.184793 by the simplex method, with tighter tolerances, and by interior points, as it gives stormG2.8 a value 3.8 above Post_Results'. Read with warnings: The SMPS files name different problems: Prob_2 (core), Prob_2 (time), storm (stoch).
- sgpf5y3: Post_Results is about 0.1 lower; it is 0.088 lower for sgpf5y4 too, whose value computed by Zehtabian and Bastin on the same files, with COIN-OR SMI, agrees with ours.
- sgpf5y4: Post_Results gives -4031.391. Read with warnings: posts/sg/sgpf5y-4.sto: the probabilities of the scenarios sum up to 1.000000001; normalized.
- sgpf5y5: Post_Results is about 0.1 lower; it is 0.088 lower for sgpf5y4 too, whose value computed by Zehtabian and Bastin on the same files, with COIN-OR SMI, agrees with ours. Read with warnings: posts/sg/sgpf5y-5.sto: the probabilities of the scenarios sum up to 1.000000025; normalized.
- sgpf3y3: SPLIB's sgpf3y files are not those of POSTS: Felt took them from Frauendorfer's directory (slptestset/sg/README.local). Zehtabian and Bastin's copy of sgpf3y3 gives -2967.91 (CIRRELT-2016-12), as these files do. Read with warnings: The SMPS files name different problems: SGPF (core), SGPF (time),  (stoch).
- sgpf3y5: SPLIB's sgpf3y files are not those of POSTS: Felt took them from Frauendorfer's directory (slptestset/sg/README.local). Zehtabian and Bastin's copy of sgpf3y3 gives -2967.91 (CIRRELT-2016-12), as these files do. Read with warnings: slptestset/sg/sgpf3y-5.sto: the probabilities of the scenarios sum up to 1.000000025; normalized; The SMPS files name different problems: SGPF (core), SGPF (time),  (stoch).
- airl-randgen: Read with warnings: slptestset/airlift/old/randgen.sto: the probabilities of INDEP (RIGHT, DEMAND1) sum up to 0.9880000000000002; kept as written; slptestset/airlift/old/randgen.sto: the probabilities of INDEP (RIGHT, DEMAND2) sum up to 0.9880000000000002; kept as written.
- assets-small: Felt's solution.txt gives -720.472240.
- 4node-1: Read with warnings: The SMPS files name different problems: 4NODECARGO (core), 4NODECARGO (time), 4NODECAR (stoch).
- 4node-2: Read with warnings: The SMPS files name different problems: 4NODECARGO (core), 4NODECARGO (time), 4NODECAR (stoch).
- 4node-4: Read with warnings: The SMPS files name different problems: 4NODECARGO (core), 4NODECARGO (time), 4NODECAR (stoch).
- 4node-8: Read with warnings: The SMPS files name different problems: 4NODECARGO (core), 4NODECARGO (time), 4NODECAR (stoch).
- 4node-16: Read with warnings: The SMPS files name different problems: 4NODECARGO (core), 4NODECARGO (time), 4NODECAR (stoch).
- 4node-32: Read with warnings: The SMPS files name different problems: 4NODECARGO (core), 4NODECARGO (time), 4NODECAR (stoch).
- 4node-64: Read with warnings: The SMPS files name different problems: 4NODECARGO (core), 4NODECARGO (time), 4NODECAR (stoch).
- 4node-128: Read with warnings: The SMPS files name different problems: 4NODECARGO (core), 4NODECARGO (time), 4NODECAR (stoch).
- 4node-256: Read with warnings: The SMPS files name different problems: 4NODECARGO (core), 4NODECARGO (time), 4NODECAR (stoch).
- 4node-512: Read with warnings: The SMPS files name different problems: 4NODECARGO (core), 4NODECARGO (time), 4NODECAR (stoch).
- 4node-1024: Read with warnings: The SMPS files name different problems: 4NODECARGO (core), 4NODECARGO (time), 4NODECAR (stoch).
- 4node-base-1: Read with warnings: The SMPS files name different problems: 4NODECARGO (core), 4NODECARGO (time), 4NODECAR (stoch).
- 4node-base-2: Read with warnings: The SMPS files name different problems: 4NODECARGO (core), 4NODECARGO (time), 4NODECAR (stoch).
- 4node-base-4: Read with warnings: The SMPS files name different problems: 4NODECARGO (core), 4NODECARGO (time), 4NODECAR (stoch).
- 4node-base-8: Read with warnings: The SMPS files name different problems: 4NODECARGO (core), 4NODECARGO (time), 4NODECAR (stoch).
- 4node-base-16: Read with warnings: The SMPS files name different problems: 4NODECARGO (core), 4NODECARGO (time), 4NODECAR (stoch).
- 4node-base-32: Read with warnings: The SMPS files name different problems: 4NODECARGO (core), 4NODECARGO (time), 4NODECAR (stoch).
- 4node-base-64: Read with warnings: The SMPS files name different problems: 4NODECARGO (core), 4NODECARGO (time), 4NODECAR (stoch).
- 4node-base-128: Read with warnings: The SMPS files name different problems: 4NODECARGO (core), 4NODECARGO (time), 4NODECAR (stoch).
- 4node-base-256: Read with warnings: The SMPS files name different problems: 4NODECARGO (core), 4NODECARGO (time), 4NODECAR (stoch).
- 4node-base-512: Read with warnings: The SMPS files name different problems: 4NODECARGO (core), 4NODECARGO (time), 4NODECAR (stoch).
- 4node-base-1024: Read with warnings: The SMPS files name different problems: 4NODECARGO (core), 4NODECARGO (time), 4NODECAR (stoch).
- 4node-old: Read with warnings: The SMPS files name different problems: 4NODECARGO (core), 4NODECARGO (time), 4NODECAR (stoch).
- sslp_5_25_50: Read with warnings: The SMPS files name different problems: sslp_5_1_25 (core), sslp_5_1_25 (time), sslp_25_5 (stoch).
- sslp_5_25_100: Read with warnings: The SMPS files name different problems: sslp_5_1_25 (core), sslp_5_1_25 (time), sslp_25_5 (stoch).
- dcap233_200: SIPLIB: [1834.868, 1834.893]. Read with warnings: The SMPS files name different problems: dcap233_200 (core),  (time),  (stoch).
- dcap243_200: SIPLIB: [2322.721, 2322.721]. Read with warnings: The SMPS files name different problems: dcap243_200 (core),  (time),  (stoch).
- dcap243_300: Kim and Dandurand: [2559.19, 2559.19], below the optimum found here with the probabilities normalized (2559.4478) or as written (2559.2128). Read with warnings: siplib/dcap243/dcap243-300.sto: the probabilities of SCENARIOS sum up to 0.9999000000000007; normalized; The SMPS files name different problems: dcap243_300 (core),  (time),  (stoch).
- sizes3: SIPLIB's value is the optimum of the deterministic equivalent distributed with the files (siplib/sizes/sizes-3.mps), whose costs, weighted by the probabilities 1/3, are rounded to two decimals (8/3 written 2.67): HiGHS gives it 224434.32. The probabilities of sizes5 and sizes10 are exact. Read with warnings: siplib/sizes/sizes-3.sto: the probabilities of SCENARIOS sum up to 0.999999; normalized; The SMPS files name different problems: SIZES FREE (core), SIZES (time), SIZES (stoch).
- sizes5: Read with warnings: The SMPS files name different problems: SIZES FREE (core), SIZES (time), SIZES (stoch).
- app0110R: Read with warnings: app0110R.stoch: the probabilities of the scenarios sum up to 0.999; kept as written.

## References

- `cirrelt`: Zehtabian and Bastin, Penalty parameter update strategies in progressive hedging algorithm (CIRRELT-2016-12), Table 2.
- `felt`: Ariyawansa and Felt, On a new collection of stochastic linear programming test problems (INFORMS Journal on Computing, 2004): the solutions of the test set in SPLIB's slptestset (solution.txt, solutions_cpa0.1, solutions_3stage).
- `kim`: Kim and Dandurand, Scalable branching on dual decomposition of stochastic mixed-integer programming problems (Mathematical Programming Computation, 2022), Table 2: the bounds of the method CS+DW, optimal within 0.01%.
- `posts`: Holmes, POSTS, a portable stochastic programming test set (1995): the file posts/Post_Results of SPLIB.
- `siplib`: Ahmed et al., SIPLIB, a stochastic integer programming test problem library (https://www2.isye.gatech.edu/~sahmed/siplib/, 2015): the optimal values (SSLP, SIZES) or the best bounds (DCAP, SEMI) of its pages.
- `zverovich`: Zverovich, Modelling and solution methods for stochastic optimisation (PhD thesis, Brunel University, 2011), Table 4.3, rounded to six significant digits.

## Files

- `coin`: COIN-OR's stochastic test data, release 1.1.7 (https://github.com/coin-or-tools/Data-Stochastic), https://codeload.github.com/coin-or-tools/Data-Stochastic/tar.gz/097e43a14777e8f13706a44088e7b495d6258e34.
- `splib`: SPLIB, Victor Zverovich's collection of stochastic programming test problems (https://github.com/vitaut-archive/splib), https://codeload.github.com/vitaut-archive/splib/tar.gz/2578558868ee62451117dbd0ee03250cc3203c3b.
