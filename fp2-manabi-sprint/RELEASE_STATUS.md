# FP2 RELEASE STATUS

Updated: 2026-11-23 JST
Target: SUBMISSION_READY / WAITING_FINAL_APPROVAL by 2026-11-24 08:00 JST (not achieved)
Actual status: BLOCKED / NOT_SUBMITTED

Canonical procedures: see RELEASE_SCOPE_20261124.md.

| Quality gate | Status | Blocker |
|---|---|---|
| Q0 | BLOCKED | Official JAFP + Kinzai reuse rules verified CONDITIONAL_PASS; per-item citation, modification disclosure, historical/current law audit and independent signoff remain. See audits/FP2_Q0_OFFICIAL_PAST_EXAM_RIGHTS_20261123.md |
| Q1 | BLOCKED | Recovered 180 complete full-text questions and matched to 180 source-index rows without discrepancy; individual PDF/modification and 2026 law review, independent review and canonical/UI integration remain pending |
| Q2 | NOT TESTED | Real learning cycle not tested |
| Q3 | FAIL | GitHub HTML source retains v1.3 marker, 8-question sample and 600-question placeholder; lacks v2.1 identity, 4/8/16 setting, 5-week heatmap and JSON import evidence. Real-device inspection remains NOT TESTED. |
| Q4 | NOT TESTED | Independent reviewer and learner acceptance evidence missing |
| Q5 | BLOCKED | Q0-Q4 not passed |

Submission preparation: BLOCKED; App Store Connect, signed build, privacy, screenshots and TestFlight real-device acceptance unverified.
App Review actions: NOT PERFORMED.
Branch: feature/fp2-release-scope-20261123; PR #5717 (draft).
This status must not be promoted on the basis of planning documents or historical audit matrix alone.

## 2026-11-23 read-only source inspection
Direct inspection of the current branch's `fp2-manabi-sprint/index.html` confirms obsolete v1.3 description, 8-question UI-only marker, 600-question placeholder, and missing v2.1 markers / 4-8-16 control / heatmap / JSON import. Q3 therefore FAIL, not merely an untested assertion. `scripts/fp2_v21_migration_gate.py` was updated on this branch to remove the obsolete hard-coded 600-question requirement; running the full Python validator in CI is still pending.

## Batch A evidence 2026-11-23
- Draft: `questions/draft/fp2-original-20261123-a.json` (6 domains x 2, 12 questions, not shipped)
- Audit: `audits/FP2_ORIGINAL_BATCH_A_AUDIT_20261123.md`
- Source desk-check provisional 12; rights final review and independent content review pending. No independent workers were launched. Current draft PR #5717 must not be merged as submission ready.

## 2026-11-23 Q0 rights-policy update
Both official entities affirm conditional reuse of publicly released common 2nd-grade academic exam questions, with source attribution, modification disclosure, and exclusions. Remaining batches should prioritize authorized official past questions. Third-party FP2過去問道場 content, explanations, wording and datasets must not be copied. This policy verification does NOT approve any specific new question; current Q0 remains BLOCKED. Source: `audits/FP2_Q0_OFFICIAL_PAST_EXAM_RIGHTS_20261123.md`.

## 2026-11-23 second batch update
- Original draft A 12 records: L02 now cites Japan Pension Service's direct `合算対象期間` explanation; all 12 `source_section` descriptions made specific, including correction of E01's previously inapposite source.
- First official past-exam draft B01 3 records, sourced to JAFP 2024-05-26 second-grade academic examination Q1,Q2,Q6 with original law cutoff 2023-10-01 and target 2026-04-01; question-level source, modification notices and original explanations included.
- New records are only in `questions/draft/fp2-official-202405-b01.json`; audit `audits/FP2_OFFICIAL_BATCH_B01_AUDIT_20261123.md`. No UI integration, no independent review, no release approval. Q0 and Q1 remain BLOCKED.

## 2026-11-23 Drive 180 source-only import
Live Google Sheet `AUDIT_MATRIX_FP2.csv` A1:I181 yielded 180 IDs (2026-05, 2025-05, 2025-01 each 60). All have historical answer/source URLs and legacy transcription/explanation flags, but source sheet lacks question stem, option texts and actual explanations. **180 metadata records imported; 0 complete questions imported; 180 current-law reviews NOT TESTED.** Quarantined `questions/draft/fp2-drive-matrix-180-source-index-20261123.json`, audit `audits/FP2_DRIVE_180_REUSE_EVALUATION_20261123.md`. Never count these 180 source-only entries toward release bank; Q0/Q1 BLOCKED and no submission readiness.

## 2026-11-23 full-text corpus recovered (supersedes source-only import as available draft data)
Actual source: `feature/fp2-kakomon-coach:fp2-kakomon-coach/questions/question_bank_fp2.json`. 180 complete structured questions matched 180 Drive source-index IDs with **zero metadata discrepancies**. Draft import: `questions/draft/fp2-recovered-180-fulltext-20261123.json`. Audit: `audits/FP2_180_FULLTEXT_RECOVERY_AUDIT_20261123.md`. Legacy audit flags are not independently reverified; all `modified` values remain null until official PDF text comparison; all current-law review statuses `NOT_TESTED`; 11 figure/exhibit keywords flagged. **180 recovered / 0 independently approved / 0 in app.** Q0/Q1 BLOCKED, no submission.

## 2026-11-23 2 corrections and fail-closed canonical bank
- 2026-05 Q14: official premium table restored (old general 10万円, old + new individual pension 10万円 each, no nursing medical); correct answer 3=10万円, original bank's erroneous 12万円 rationale removed; modification=true with precise note.
- 2025-01 Q34: original spouse income threshold 48万円 changed to 58万円 per 2025 reform, answer 4 retained; modification=true with precise note.
- Both original errors preserved in `correction_prior` and are `FAIL_CORRECTION_AWAITING_REVIEW`, not approved.
- Specified independent audit `audits/FP2_RECOVERED_180_INDEPENDENT_BATCH01_30_20261123.md`: 404 on target branch. Prior 15 draft questions remain HOLD. No source evidence of the 28 other purported PASS IDs; therefore cannot certify their modified status or release inclusion.
- Canonical approval placeholder: `questions/canonical/approved-questions-20261123.json`: verified count **0**, BLOCKED_INDEPENDENT_EVIDENCE_MISSING. This is not a shipped question bank. Full 180 draft has 2 individually documented modified=true, 178 modification flags still unverified/null, all quarantined.
- Audit record: `audits/FP2_FAIL2_CORRECTION_20261123.md`. Q0/Q1 blocked, SUBMISSION_READY prohibited.
