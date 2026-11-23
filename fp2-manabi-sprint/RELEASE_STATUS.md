# FP2 RELEASE STATUS（最新正本・2026-11-23）

**Actual: BLOCKED / NOT_SUBMITTED / NOT_SUBMISSION_READY**。初回提出期限目標：2026-11-24 08:00 JST。
最終統合証拠：`audit/FP2_180_FINAL_175PASS_5FAIL_120_SELECTION_20261123.md`。以下に続く過去履歴の古い件数は現行状態ではない。

| Gate | 最新判定 | 根拠・未了 |
| --- | --- | --- |
| Q0 | BLOCKED | 官方公開原題の出典・加工注記は初回候補120に記録済み。権利利用主体の最終確認、現行法/図表/説明の最終証拠、実配布表示の立証未了 |
| Q1 | BLOCKED（内容監査PASS190） | 回収180の最終PASS175/FAIL5/HOLD0、先行15のPASSを含めcanonical190。初回6分野×20=120選定、内容PASS予備70。修正済FAIL5は再監査未了 |
| Q2 | NOT TESTED | 学習者の実練習/定着フローの操作検査未了 |
| Q3 | FAIL（静的検査PASS） | 4タブ・目標・PWA・JSON出入力は実装。ブラウザ/iPhone/Golden Master実画面検証未了 |
| Q4 | NOT TESTED | 製品全体の独立受け入れ/E2E未実施 |
| Q5 | BLOCKED | iOS専用署名IPA/本番バンドル一致/ASC Version Build IAP/Privacy/公開ページ/実スクショ未確定 |

**Canonical**: `questions/canonical/approved-questions-20261123.json` = 190 content-PASS, `release_selected=true` 120 (各分野20), reserve70, release_clear=0。
**変更判定**: 初回候補120は原典内容/改変確認の暫定項目なし。予備61問の modified は暫定分類でPDF全字比較未了。原典の改変は出典と具体的変更説明を記録。
**修正FAIL**: 2025-05 Q36/Q39, 2025-01 Q17/Q20/Q13 の5問を解説修正し独立再監査待ちへ隔離。問題文/4選択肢/正答番号は不変。
**初回選定正本**: `release/release-selection-120-20261123.json`（120 IDs, 70 reserves）。
**ソースSHA**: `release/bundle-lock-20261123.json`。IPA一致は未実証。
**CI**: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45147284570（内容・UI静的・JS構文SUCCESS）。
**PR**: #5717 Draft、mainマージ/Apple審査提出禁止。

---

## 過去履歴（現行判定ではない）

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

## 2026-11-23 canonical content-PASS rebuild from singular audit/ folder
- Independent review files: `audit/FP2_INDEPENDENT_REAUDIT_15_20261123.md` (15 PASS), `audit/FP2_RECOVERED_180_INDEPENDENT_BATCH01_30_20261123.md` (24 PASS/2 FAIL/4 HOLD), `audit/FP2_RECOVERED_180_INDEPENDENT_BATCH02_30_20261123.md` (26 PASS/0 FAIL/4 HOLD). Together: **65 independent CONTENT-PASS**, 10 excluded (2 corrected FAIL awaiting new review, 8 HOLD), 120 unreviewed recovered questions.
- Canonical `questions/canonical/approved-questions-20261123.json` now contains **65 distinct content-PASS records** (15+24+26); each records its audit evidence path and blob SHA. `publishable=false` for all records; content approval does not imply final release approval.
- 50 recovered PASS still require source-vs-PDF `modified`/`modification_note` confirmation (not fabricated), plus legal/rights/attribution/UI/bundle gates. This replaces the earlier zero-question fail-closed placeholder, which was based on the incorrect plural `audits/` location.
- Q0/Q1 final release gate remains BLOCKED, no App Review submission.

## Coordinator integration and provenance finalization (2026-11-23)
- UI branch `feature/fp2-ui-master21-integration-20261123` file-level integrations into this release branch: `index.html`, `fp2-approved-bank.js`, `audit/FP2_UI_INTEGRATION_HANDOFF_20261123.md`. Canonical JSON was already byte-identical between UI and release refs before coordinator modifications; maintain release canonical as only source. UI preview text no longer falsely claims public approval.
- Source comparison for 50 recovered independently content-PASS questions completed against official JAFP PDF and independent review logs: **42 materially verbatim question/choice sets (PDF line wrapping and typography reflow only), 8 adapted exhibit/table/diagram text renderings, 0 provenance null**. Per-item `modified` and `modification_note` in both canonical and recovered draft. Evidence: `audit/FP2_RECOVERED_PASS50_SOURCE_MODIFICATION_AUDIT_20261123.md`.
- Canonical content-review PASS **65**, but individual fully release-approved **0** (`publishable_questions=0`), product status remains `CONTENT_AUDIT_PASS_PROVENANCE_50_VERIFIED_RELEASE_BLOCKED`.
- Q0 final business-rights/license, original-law/current-law cutoffs, user-visible source display screenshot, Q3 mobile E2E and exact UI Master v2.1, offline recovery, Q4/Q5 final gate, CI, Apple Store metadata/IAP/privacy and bundle SHA remain unverified. PR #5717 stays Draft. No App Review submission.

## 2026-11-23 Batch03+Batch04 reconciliation (current)
- Independent audits: Batch03 new 29 PASS / 1 HOLD plus previously corrected 2 PASS; Batch04 26 PASS / 2 FAIL / 2 HOLD. Across recovered 180 **107 content PASS / 2 FAIL (corrected pending independent re-review) / 11 HOLD / 60 NOT TESTED**.
- Canonical `questions/canonical/approved-questions-20261123.json`: **122 content-PASS records = 107 recovered + 15 independently approved originals/previously adapted**, all with individual audit evidence paths, `publishable=false`, `publishable_questions=0`, release_clear_count=0.
- Recovered draft `questions/draft/fp2-recovered-180-fulltext-20261123.json`: 180 records reconciled to PASS107/FAIL2/HOLD11/NOT_TESTED60. Batch04 Q36 and Q39 source explanations corrected, preceding incorrect texts saved in correction_prior. Answers both stay choice 1. **These two remain excluded until a new independent audit PASS.**
- Among recovered canonical 107, original-vs-modified provenance reviewed 81; **26 remain modified=null**, quarantined for individual official PDF comparison. Remaining release blockers Q0 rights/legal/source display, Q1 integration regression, Q3 UI Master v2.1 device/browser/offline, Q4/Q5 real build/screenshot, App Privacy/IAP/ASC, and 60 unreviewed questions.
- Full audit trace: `audit/FP2_BATCH03_04_CANONICAL_RECONCILIATION_20261123.md`. PR #5717 stays Draft and **SUBMISSION_READY=NO**. No App Review submit.
