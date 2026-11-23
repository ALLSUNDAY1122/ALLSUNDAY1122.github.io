# FP2 ORIGINAL BATCH A — Q0/Q1 AUDIT RECORD
Date: 2026-11-23 JST
Batch: fp2-manabi-sprint/questions/draft/fp2-original-20261123-a.json
Purpose: First 12 original questions, isolated from production.

## Audit stages
- Mechanical structural audit (author/coordinator in-memory check): PASS 12 / FAIL 0. Verified unique IDs, four options, answer range, four distractor/choice reasons, and presence of source_url, explanation, applicability date and copyright basis.
- Primary-source desk check (author/coordinator, NOT independent): provisional match 12 / substantive mismatch detected 0; this is not a final Q0 or Q1 signoff. Legal applicability and source-rights must be rechecked for each item with an independent reviewer.
- Independent content audit: PASS 0 / FAIL 0 / HOLD 12 (not performed).
- Canonical integration: 0 / 12. UI integration: 0 / 12.

## Per-item primary sources and provisional desk assessment
| ID suffix | Source | Provisional self-check | Independent gate |
| --- | --- | --- | --- |
| L01 | https://www.nenkin.go.jp/service/jukyu/seido/roureinenkin/jukyu-yoken/20150401-02.html | 10-year qualifying period consistent | HOLD |
| L02 | https://www.nenkin.go.jp/service/yougo/sagyo/jukyushikaku.html | qualifying credit period versus pension amount | HOLD |
| R01 | https://www.sonpo.or.jp/insurance/jishin/index.html | earthquake insurance requires fire insurance | HOLD |
| R02 | https://www.sonpo.or.jp/insurance/jishin/index.html | 30–50% range, contract ceilings excluded in question | HOLD |
| F01 | https://www.fsa.go.jp/policy/payoff/index.html | deposit protection ¥10m per depositor/institution | HOLD |
| F02 | https://www.fsa.go.jp/policy/nisa2/know/index.html | adult NISA annual ¥3.6m combined | HOLD |
| T01 | https://www.nta.go.jp/taxes/shiraberu/taxanswer/shotoku/1120.htm | medical expense deduction threshold under explicit income condition | HOLD |
| T02 | https://www.nta.go.jp/taxes/shiraberu/taxanswer/shotoku/1180.htm | dependent relative age 16+ with other conditions assumed | HOLD |
| E01 | https://www.thr.mlit.go.jp/bumon/b00093/k00490/eizen/hozen/word/w_02ka.html | building coverage ratio 80/200 = 40% | HOLD |
| E02 | https://www.mlit.go.jp/common/001205298.pdf | floor area ratio 300/150 = 200% | HOLD |
| S01 | https://www.nta.go.jp/taxes/shiraberu/taxanswer/sozoku/4102.htm | inheritance deduction 3000+600×3 = 4800 (¥10k units) | HOLD |
| S02 | https://www.nta.go.jp/taxes/shiraberu/taxanswer/zoyo/4410.htm | calendar-year gift deduction ¥1.1m | HOLD |

## Rights handling
The stems, options and explanations were newly drafted from institutional facts; no official examination question was copied deliberately. This is a provenance assertion, not a comprehensive infringement or near-duplicate finding. A separate compare-against-official and product corpus check is still required for Q0 PASS.

## Quality risks
- L01/L02 share a pension qualifying-period theme; independent substantive-similarity assessment required.
- R01/R02 share earthquake insurance but test distinct contract and amount rules; verify not artificial padding.
- 2026-04-01 applicability is tagged but individual legal-history/2026 examination validity has not been independently verified.
- Tests were performed in orchestration logic and NOT executed by GitHub Actions / installed test harness.
- Do not copy this draft file into shipped bank, generate app bundle, or mark SUBMISSION_READY until independent PASS and production regression.

Conclusion: 12 mechanical PASS / 0 mechanical FAIL / 12 independent HOLD. Q0=BLOCKED (rights/legal per-item signoff missing), Q1=BLOCKED (independent content signoff missing).
