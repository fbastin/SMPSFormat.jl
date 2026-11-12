# Validation results

SMPSFormat 0.8.0, JuMP 1.32.1, HiGHS.jl 1.26.1 (HiGHS 1.15.1), Julia 1.12.6, x86_64-linux-gnu; run on 2026-11-11, instances up to the size `medium`, 600 seconds per solve, 40.1 minutes in all.

94 agrees, 13 differs (known), 15 read.

| Instance | Periods | Scenarios | Rows | Columns | Published | Reference | Computed | Difference | Seconds | Result |
|---|--:|--:|--:|--:|--:|---|--:|--:|--:|---|
| pltexpA2_6 | 2 | 6 | 686 | 1820 | -9.479354 | posts | -9.479354405 | -4.05e-07 | 8.5 | agrees |
| pltexpA2_16 | 2 | 16 | 1726 | 4540 | -9.663308 | posts | -9.663308373 | -3.73e-07 | 0.8 | agrees |
| pltexpA3_6 | 3 | 36 | 4430 | 11612 | -13.969368 | posts | -13.96936764 | 3.55e-07 | 0.9 | agrees |
| pltexpA3_16 | 3 | 256 | 28350 | 74172 | -14.267458 | posts | -14.26745774 | 2.6e-07 | 1.2 | agrees |
| pltexpA4_6 | 4 | 216 | 26894 | 70364 | -19.599417 | posts | -19.59941738 | -3.82e-07 | 1.2 | agrees |
| pltexpB3 | 3 | 12 | 1934 | 5084 | -13.643226 | posts | -13.64322619 | -1.92e-07 | 0.1 | agrees |
| pltexpB4 | 4 | 24 | 4430 | 11612 | -17.928191 | posts | -17.92819134 | -3.39e-07 | 0.2 | agrees |
| pltexpB5 | 5 | 48 | 9422 | 24668 | -23.846166 | posts | -23.84339992 | 0.00277 | 0.3 | differs (known) |
| fxm2.6 | 2 | 6 | 1520 | 2172 | 18417.065572 | felt | 18417.06557 | 4.93e-07 | 0.2 | agrees |
| fxm2.16 | 2 | 16 | 3900 | 5602 | 18416.759028 | felt | 18416.75903 | 3.49e-07 | 0.2 | agrees |
| fxm3.6 | 3 | 36 | 6200 | 9492 | 18615.932 | posts | 18616.03616 | 0.104 | 0.4 | differs (known) |
| fxm3.16 | 3 | 256 | 41340 | 64162 | 18438.891 | posts | 18438.99508 | 0.104 | 12.5 | differs (known) |
| fxm4.6 | 4 | 216 | 22400 | 30732 | 18616.224 | posts | 18616.32797 | 0.104 | 4.4 | differs (known) |
| stormG2.8 | 2 | 8 | 4409 | 10193 | 15535200 | zverovich | 15535235.73 | 35.7 | 0.3 | agrees |
| stormG2.27 | 2 | 27 | 14441 | 34114 | 15508982.306 | posts | 15508982.31 | -0.000493 | 0.9 | agrees |
| stormG2.125 | 2 | 125 | 66185 | 157496 | 15512090.180 | posts | 15512091.18 | 1 | 11.3 | differs (known) |
| sgpf5y3 | 3 | 25 | 1952 | 2509 | -3027.706 | posts | -3027.6035 | 0.103 | 0.2 | differs (known) |
| sgpf5y4 | 4 | 125 | 9827 | 12384 | -4031.3 | cirrelt | -4031.303083 | -0.00308 | 0.1 | agrees |
| sgpf5y5 | 5 | 625 | 49202 | 61759 | -5201.282 | posts | -5200.848593 | 0.433 | 0.6 | differs (known) |
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
| 4node-32 | 2 | 32 | 2382 | 6004 | 423.013 | zverovich | 423.0125 | -0.0005 | 0.2 | agrees |
| 4node-64 | 2 | 64 | 4750 | 11956 | 423.013 | zverovich | 423.0125 | -0.0005 | 0.7 | agrees |
| 4node-128 | 2 | 128 | 9486 | 23860 | 423.013 | zverovich | 423.0125 | -0.0005 | 2.7 | agrees |
| 4node-256 | 2 | 256 | 18958 | 47668 | 425.375 | zverovich | 425.375 | 2.79e-11 | 13.5 | agrees |
| 4node-512 | 2 | 512 | 37902 | 95284 | 429.963 | zverovich | 429.9625 | -0.0005 | 44.2 | agrees |
| 4node-1024 | 2 | 1024 | 75790 | 190516 | 434.112 | zverovich | 434.1125 | 0.0005 | 125.4 | agrees |
| 4node-base-1 | 2 | 1 | 90 | 238 | 413.388 | zverovich | 413.3875 | -0.0005 | 0.0 | agrees |
| 4node-base-2 | 2 | 2 | 164 | 424 | 414.013 | zverovich | 414.0125 | -0.0005 | 0.0 | agrees |
| 4node-base-4 | 2 | 4 | 312 | 796 | 414.388 | zverovich | 414.3875 | -0.0005 | 0.0 | agrees |
| 4node-base-8 | 2 | 8 | 608 | 1540 | 414.688 | zverovich | 414.6875 | -0.0005 | 0.0 | agrees |
| 4node-base-16 | 2 | 16 | 1200 | 3028 | 414.688 | zverovich | 414.6875 | -0.0005 | 0.1 | agrees |
| 4node-base-32 | 2 | 32 | 2384 | 6004 | 416.6 | zverovich | 416.6 | -1.71e-13 | 0.2 | agrees |
| 4node-base-64 | 2 | 64 | 4752 | 11956 | 416.6 | zverovich | 416.6 | 3.18e-12 | 0.5 | agrees |
| 4node-base-128 | 2 | 128 | 9488 | 23860 | 416.6 | zverovich | 416.6 | 2.9e-12 | 1.8 | agrees |
| 4node-base-256 | 2 | 256 | 18960 | 47668 | 417.162 | zverovich | 417.161875 | -0.000125 | 5.5 | agrees |
| 4node-base-512 | 2 | 512 | 37904 | 95284 | 420.293 | zverovich | 420.2925 | -0.0005 | 19.2 | agrees |
| 4node-base-1024 | 2 | 1024 | 75792 | 190516 | 423.05 | zverovich | 423.05 | 2.24e-11 | 97.4 | agrees |
| 4node-old | 2 | 32 | 2382 | 6004 | 83094.075275 | felt | 83094.07527 | -2.74e-07 | 0.3 | agrees |
| chem | 2 | 2 | 130 | 121 | -13009.166667 | felt | -13009.16667 | 3.33e-07 | 0.1 | agrees |
| chem-base | 2 | 2 | 118 | 121 | -13009.2 | zverovich | -13009.16667 | 0.0333 | 0.1 | agrees |
| lands | 2 | 3 | 23 | 40 | 381.853333 | felt | 381.8533333 | 3.33e-07 | 0.1 | agrees |
| lands-blocks | 2 | 3 | 23 | 40 | 381.853 | zverovich | 381.8533333 | 0.000333 | 0.0 | agrees |
| lands3-indep | 3 | 9 | 128 | 220 | 719.2066666667 | felt | 719.2066667 | -3.29e-11 | 0.1 | agrees |
| lands3-dep | 3 | 9 | 86 | 148 | 722.5836666667 | felt | 722.5836667 | -3.32e-11 | 0.1 | agrees |
| env-aggr | 2 | 5 | 288 | 294 | 20478.7 | zverovich | 20478.69899 | -0.00101 | 0.0 | agrees |
| env-first | 2 | 5 | 288 | 294 | 19777.4 | zverovich | 19777.44472 | 0.0447 | 0.0 | agrees |
| env-loose | 2 | 5 | 288 | 294 | 19777.4 | zverovich | 19777.44472 | 0.0447 | 0.0 | agrees |
| env-15 | 2 | 15 | 768 | 784 | 22265.3 | zverovich | 22265.25491 | -0.0451 | 0.0 | agrees |
| env-1200 | 2 | 1200 | 57648 | 58849 | 22428.9 | zverovich | 22428.90823 | 0.00823 | 1.1 | agrees |
| env-1875 | 2 | 1875 | 90048 | 91924 | 22447.1 | zverovich | 22447.11312 | 0.0131 | 2.8 | agrees |
| env-3780 | 2 | 3780 | 181488 | 185269 | 22441 | zverovich | 22441.0436 | 0.0436 | 9.0 | agrees |
| env-5292 | 2 | 5292 | 254064 | 259357 | 22438.4 | zverovich | 22438.42378 | 0.0238 | 17.9 | agrees |
| env-diss-aggr | 2 | 5 | 288 | 294 | 15963.9 | zverovich | 15963.9291 | 0.0291 | 0.0 | agrees |
| env-diss-first | 2 | 5 | 288 | 294 | 14794.6 | zverovich | 14794.60822 | 0.00822 | 0.0 | agrees |
| env-diss-loose | 2 | 5 | 288 | 294 | 14794.6 | zverovich | 14794.60822 | 0.00822 | 0.0 | agrees |
| env-diss-15 | 2 | 15 | 768 | 784 | 20773.9 | zverovich | 20773.88852 | -0.0115 | 0.1 | agrees |
| env-diss-1200 | 2 | 1200 | 57648 | 58849 | 20808.6 | zverovich | 20808.59319 | -0.00681 | 1.1 | agrees |
| env-diss-1875 | 2 | 1875 | 90048 | 91924 | 20809.3 | zverovich | 20809.28824 | -0.0118 | 3.3 | agrees |
| env-diss-3780 | 2 | 3780 | 181488 | 185269 | 20794.7 | zverovich | 20794.68302 | -0.017 | 12.9 | agrees |
| env-diss-5292 | 2 | 5292 | 254064 | 259357 | 20788.6 | zverovich | 20788.64505 | 0.045 | 21.6 | agrees |
| phone1 | 2 | 1 | 24 | 93 | 36.9 | zverovich | 36.9 | 7.11e-15 | 0.0 | agrees |
| stocfor1 | 2 | 1 | 117 | 111 | -41132 | zverovich | -41131.98323 | 0.0168 | 0.0 | agrees |
| stocfor2 | 2 | 64 | 6543 | 6159 | -39772.4 | zverovich | -39772.44771 | -0.0477 | 0.1 | agrees |
| sslp_5_25_50 | 2 | 50 | 1501 | 6505 | -121.600 | siplib | -121.6 | -1.42e-14 | 15.8 | agrees |
| sslp_5_25_100 | 2 | 100 | 3001 | 13005 | -127.370 | siplib | -127.37 | 0 | 51.1 | agrees |
| dcap233_200 | 2 | 200 | 3006 | 5412 | [1834.55, 1834.57] | kim | 1834.565368 | 0 | 96.7 | agrees |
| dcap243_200 | 2 | 200 | 3606 | 7212 | [2322.49, 2322.49] | kim | 2322.495735 | 0.00574 | 69.1 | agrees |
| dcap243_300 | 2 | 300 | 5406 | 10812 | [2559.297, 2559.545] | siplib | 2559.447808 | 0 | 184.2 | agrees |
| sizes3 | 2 | 3 | 124 | 300 | 224434.32 | siplib | 224433.7333 | -0.587 | 2.0 | differs (known) |
| sizes5 | 2 | 5 | 186 | 450 | 224486 | siplib | 224486 | -1.46e-10 | 12.9 | agrees |
| wati-10-16 | 10 | 16 | 4573 | 8401 | -2158.7519 | consigli | -2158.751929 | -2.86e-05 | 0.2 | agrees |
| wati-10-32 | 10 | 32 | 8413 | 15553 | -1866.398 | consigli | -1866.396934 | 0.00107 | 0.3 | agrees |
| wati-10-64 | 10 | 64 | 15101 | 28097 | -2310.53 | dempster | -2310.526379 | 0.00362 | 0.8 | agrees |
| wati-10-128 | 10 | 128 | 26237 | 49153 | -1637.8125 | consigli | -1637.81251 | -9.71e-06 | 2.3 | agrees |
| wati-10-256 | 10 | 256 | 43517 | 82177 | -2000.838 | consigli | -2000.838404 | -0.000404 | 7.1 | agrees |
| wati-10-512 | 10 | 512 | 67069 | 128001 | -1959.635 | consigli | -1959.635805 | -0.000805 | 13.7 | agrees |
| wati-10-768 | 10 | 768 | 100598 | 191994 | -1813.105 | consigli | -1813.105476 | -0.000476 | 26.3 | agrees |
| wati-10-1024 | 10 | 1024 | 134127 | 255987 | -1926.787 | consigli | -1926.788547 | -0.00155 | 97.5 | agrees |
| wati-10-1152 | 10 | 1152 | 150869 | 287949 | -1687.92 | consigli | -1687.920427 | -0.000427 | 71.0 | agrees |
| wati-10-1536 | 10 | 1536 | 201155 | 383927 | -1790.276 | consigli | -1790.275201 | 0.000799 | 109.0 | agrees |
| wati-10-1920 | 10 | 1920 | 251441 | 479905 | -1778.954 | consigli | -2891.117099 | -1.11e+03 | 191.1 | differs (known) |
| watc-10-16 | 10 | 16 | 4573 | 8401 | -2401.875 | consigli | -2401.87525 | -0.00025 | 0.2 | agrees |
| watc-10-32 | 10 | 32 | 8413 | 15553 | -2167.624 | consigli | -2167.62414 | -0.00014 | 0.3 | agrees |
| watc-10-64 | 10 | 64 | 15101 | 28097 | -2027.4293 | consigli | -2310.526379 | -283 | 1.5 | differs (known) |
| watc-10-128 | 10 | 128 | 26237 | 49153 | -1879.432 | consigli | -1879.432514 | -0.000514 | 2.6 | agrees |
| watc-10-256 | 10 | 256 | 43517 | 82177 | -1841.2985 | consigli | -1841.298554 | -5.43e-05 | 14.7 | agrees |
| watc-10-512 | 10 | 512 | 67069 | 128001 | -1787.1977 | consigli | -1787.19773 | -3.01e-05 | 26.4 | agrees |
| watc-10-768 | 10 | 768 | 100598 | 191994 | -1780.126 | consigli | -1780.126577 | -0.000577 | 59.6 | agrees |
| watc-10-1024 | 10 | 1024 | 134127 | 255987 | -1791.176 | consigli | -1791.176872 | -0.000872 | 129.5 | agrees |
| watc-10-1152 | 10 | 1152 | 150869 | 287949 | -1725.53 | consigli | -1725.533373 | -0.00337 | 136.8 | agrees |
| watc-10-1536 | 10 | 1536 | 201155 | 383927 | -1693.474 | consigli | -1693.474295 | -0.000295 | 79.0 | agrees |
| watc-10-1920 | 10 | 1920 | 251441 | 479905 | -1769.45 | consigli | -1769.451668 | -0.00167 | 87.3 | agrees |
| watc-10-2304 | 10 | 2304 | 301727 | 575883 | -1664.66 | consigli | -1664.778928 | -0.119 | 129.5 | differs (known) |
| watc-10-2688 | 10 | 2688 | 352013 | 671861 | -1679.921 | consigli | -1679.920925 | 7.52e-05 | 302.6 | agrees |
| 20term | 2 | 1.1e12 |  |  |  | lsw |  |  | 0.1 | read |
| ssn | 2 | 1.0e70 |  |  |  | lsw |  |  | 0.1 | read |
| storm | 2 | 6.0e81 |  |  |  | lsw |  |  | 0.1 | read |
| Electricity-Small | 2 | 3.3e47 |  |  |  |  |  |  | 0.1 | read |
| Electricity-Medium | 2 | 3.3e47 |  |  |  |  |  |  | 0.1 | read |
| Electricity-Large | 2 | 1.3e102 |  |  |  |  |  |  | 0.1 | read |
| Bi-Weekly-Small | 2 | 1.0e77 |  |  |  |  |  |  | 0.1 | read |
| Bi-Weekly-Medium | 2 | 1.2e124 |  |  |  |  |  |  | 0.1 | read |
| Bi-Weekly-Large | 2 | 2.6e67 |  |  |  |  |  |  | 0.2 | read |
| Weekly-Small | 2 | 8.5e113 |  |  |  |  |  |  | 0.1 | read |
| Weekly-Medium | 2 | 1.8e123 |  |  |  |  |  |  | 0.2 | read |
| Weekly-Large | 2 | 4.0e120 |  |  |  |  |  |  | 0.1 | read |
| Product-Small | 2 | 1.2e100 |  |  |  |  |  |  | 0.1 | read |
| Product-Medium | 2 | 1.2e100 |  |  |  |  |  |  | 0.1 | read |
| Product-Large | 2 | 3.3e204 |  |  |  |  |  |  | 0.1 | read |
| KandW3R | 3 | 9 | 25 | 28 | 2613 | cirrelt | 2613 | 2.73e-12 | 0.1 | agrees |
| app0110R | 3 | 9 | 129 | 268 | 41.958 | cirrelt | 41.958 | 1.42e-14 | 0.1 | agrees |
| wat_10_C_32 | 10 | 32 | 8413 | 15553 | -2611.92 | cirrelt | -2611.919384 | 0.000616 | 0.5 | agrees |

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
- wati-10-16: Zehtabian and Bastin's wat10I16: -2158.75 (CIRRELT-2016-12).
- wati-10-64: Consigli and Dempster give 2310.51.
- wati-10-768: Read with warnings: watson/wati-10-768.sto: the probabilities of the scenarios sum up to 0.9999997440000009; normalized.
- wati-10-1024: Read with warnings: watson/wati-10-1024.sto: the probabilities of the scenarios sum up to 0.9999994879999996; normalized.
- wati-10-1152: Read with warnings: watson/wati-10-1152.sto: the probabilities of the scenarios sum up to 1.0000005119999997; normalized.
- wati-10-1536: Read with warnings: watson/wati-10-1536.sto: the probabilities of the scenarios sum up to 1.0000005120000002; normalized.
- wati-10-1920: The root scenario of SPLIB's wati-10-1920.sto sets the right-hand side of CB11, the initial cash balance, to -500.63, against -300.63 in the 23 other WATSON files: with -300.63, the files give -1778.9548, the published value. Read with warnings: watson/wati-10-1920.sto: the probabilities of the scenarios sum up to 0.9999993599999986; normalized.
- watc-10-32: COIN-OR's wat_10_C_32, of the same dimensions, is not the same problem: its optimum is -2611.92 (Zehtabian and Bastin's wat10C32).
- watc-10-64: SPLIB's watc-10-64.sto is the same file as wati-10-64.sto: it gives the optimum of wati-10-64.
- watc-10-768: Read with warnings: watson/watc-10-768.sto: the probabilities of the scenarios sum up to 0.9999997440000009; normalized.
- watc-10-1024: Read with warnings: watson/watc-10-1024.sto: the probabilities of the scenarios sum up to 0.9999994879999996; normalized.
- watc-10-1152: Read with warnings: watson/watc-10-1152.sto: the probabilities of the scenarios sum up to 1.0000005119999997; normalized.
- watc-10-1536: Read with warnings: watson/watc-10-1536.sto: the probabilities of the scenarios sum up to 1.0000005120000002; normalized.
- watc-10-1920: The first 1536 scenarios of the stoch file have the probability 0.000651042 (1/1536), the other 384 0.000520833 (1/1920): they sum up to 1.2. The published value is that of these probabilities normalized; all equal, they give -1762.152. Read with warnings: watson/watc-10-1920.sto: the probabilities of the scenarios sum up to 1.200000384; normalized.
- watc-10-2304: The cause is not known: the other conditional problems give their published values, but watc-10-64, whose file is that of wati-10-64, and the values of this file lie within those of watc-10-1536 and watc-10-2688. Read with warnings: watson/watc-10-2304.sto: the probabilities of the scenarios sum up to 1.0000005119999997; normalized.
- watc-10-2688: Read with warnings: watson/watc-10-2688.sto: the probabilities of the scenarios sum up to 1.0000005120000004; normalized.
- 20term: Estimates: lower bound 254298.57 ± 38.74, upper bound 254311.55 ± 5.56.
- ssn: Estimates: lower bound 9.84 ± 0.10, upper bound 9.913 ± 0.022.
- storm: Estimates: lower bound 15498657.8 ± 73.9, upper bound 15498739.41 ± 19.11. Read with warnings: The SMPS files name different problems: Prob_2 (core), Prob_2 (time),  (stoch).
- Electricity-Small: Policies: DA -1351.00, PL -1460.81.
- Electricity-Medium: Policies: DA -5695.06, PL -5916.40.
- Electricity-Large: Policies: DA -1722.62, PL -1846.08.
- Bi-Weekly-Small: Policies: DA -8071.12, PL -8579.98.
- Bi-Weekly-Medium: Policies: DA -701.46, PL -1481.00.
- Bi-Weekly-Large: Policies: DA -6353.51, PL -7259.32.
- Weekly-Small: Policies: DA -2806.10, PL -3672.28.
- Weekly-Medium: Policies: DA -500.08, PL -968.47.
- Weekly-Large: Policies: DA -1750.31, PL -2535.81.
- Product-Small: Policies: DA -17637.20, PL -18146.60.
- Product-Medium: Policies: DA -27837.41, PL -28479.40.
- Product-Large: Policies: DA -29389.04, PL -30016.40.
- app0110R: Read with warnings: app0110R.stoch: the probabilities of the scenarios sum up to 0.999; kept as written.

## References

- `bayraksan`: Bayraksan and Morton, A sequential sampling procedure for stochastic programming (Operations Research, 2011), Table 2: the optimal value, the problem solved exactly.
- `cirrelt`: Zehtabian and Bastin, Penalty parameter update strategies in progressive hedging algorithm (CIRRELT-2016-12), Table 2.
- `consigli`: Consigli and Dempster, Dynamic stochastic programming for asset-liability management (Annals of Operations Research, 1998), Table 2 (independent scenarios, wati) and Table 3 (conditional scenarios, watc): the terminal wealth maximized, whose opposite the files minimize, with the digits on which their solvers agree, at least two decimals.
- `dempster`: Dempster and Thompson, Parallelization and aggregation of nested Benders decomposition (Annals of Operations Research, 1998), Table 3.
- `felt`: Ariyawansa and Felt, On a new collection of stochastic linear programming test problems (INFORMS Journal on Computing, 2004): the solutions of the test set in SPLIB's slptestset (solution.txt, solutions_cpa0.1, solutions_3stage).
- `kim`: Kim and Dandurand, Scalable branching on dual decomposition of stochastic mixed-integer programming problems (Mathematical Programming Computation, 2022), Table 2 (DCAP) and Table 5 (SMKP): the bounds of the method CS+DW, optimal within 0.01%.
- `lsw`: Linderoth, Shapiro and Wright, The empirical behavior of sampling methods for stochastic programming (Annals of Operations Research, 2006; Optimization Technical Report 02-01, University of Wisconsin-Madison, 2002), Table 4: the estimates of the lower and upper bounds, with their 95% confidence intervals, from Latin hypercube samples of 5000 scenarios.
- `posts`: Holmes, POSTS, a portable stochastic programming test set (1995): the file posts/Post_Results of SPLIB.
- `siplib`: Ahmed et al., SIPLIB, a stochastic integer programming test problem library (https://www2.isye.gatech.edu/~sahmed/siplib/, 2015): the optimal values (SSLP, SIZES) or the best bounds (DCAP, SEMI) of its pages.
- `zverovich`: Zverovich, Modelling and solution methods for stochastic optimisation (PhD thesis, Brunel University, 2011), Table 4.3, rounded to six significant digits.

## Files

- `coin`: COIN-OR's stochastic test data, release 1.1.7 (https://github.com/coin-or-tools/Data-Stochastic), https://codeload.github.com/coin-or-tools/Data-Stochastic/tar.gz/097e43a14777e8f13706a44088e7b495d6258e34.
- `cornell`: Topaloglu's stochastic programming datasets, Cornell ORIE (https://people.orie.cornell.edu/huseyin/research/sp_datasets/sp_datasets.html), https://people.orie.cornell.edu/huseyin/research/sp_datasets/.
- `dsp`: DSP, the dual decomposition solver of Kim and Zavala, whose examples hold SIPLIB's SMKP instances, the same files as SIPLIB's smkp.zip (https://github.com/Argonne-National-Laboratory/DSP, branch release), https://codeload.github.com/Argonne-National-Laboratory/DSP/tar.gz/8ceedb43bd7c81aeecfe2ad26030d630ab458261.
- `splib`: SPLIB, Victor Zverovich's collection of stochastic programming test problems (https://github.com/vitaut-archive/splib), https://codeload.github.com/vitaut-archive/splib/tar.gz/2578558868ee62451117dbd0ee03250cc3203c3b.
