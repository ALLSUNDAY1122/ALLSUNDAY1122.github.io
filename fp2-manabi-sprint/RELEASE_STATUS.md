# FP2 RELEASE STATUS（正本・2026-11-23・Q20第2次独立PASS反映）

**状態: BLOCKED / NOT_SUBMISSION_READY / NOT_SUBMITTED。** 目標期限 2026-11-24 08:00 JST。PR #5717 Draft維持。mainマージ、App Store Connectログイン、Apple審査提出は行わない。

## 監査済み最終コンテンツ状態

| 項目 | 最新値・証拠 |
| --- | --- |
| 回収180問の独立内容監査 | **PASS 180 / FAIL 0 / HOLD 0**（高リスク修正済み5問の再監査完了） |
| 先行独立PASS問題 | 15問 |
| 正規バンク | **195問**（180+15、全問 `publishable=false`） |
| 初回選定 | **120問＝6分野×20問（ID変更なし）** |
| 監査済み予備 | **75問**（Q20は予備のみ） |
| 本番公開承認済み | **0問**（内容PASSと権利・リリース承認は別） |
| Q20最終監査 | `audit/FP2_2025_01_Q20_SECOND_CORRECTION_REAUDIT_PASS_20261123.md`、blob `bccab94170391e9074b021fcee2125b3b5d64bf7`、第2次解説PASS |
| 固定識別子 | App ID `6797228406` / Bundle `com.allsunday1122.fp2manabisprint` / Version `1.0.0` / Build `1` / IAPなし（ASC未照合） |

Q20の登録正答③、原題4肢、修正履歴2件を維持し、下書きの再監査PASSおよび監査証拠SHAと、正規バンクの監査PASS・非公開の予備フラグを一致させた。

## Q0–Q5 現状

| ゲート | 最新判定 | 残る証拠 |
| --- | --- | --- |
| Q0 | **BLOCKED** | 使用主体・出典表示・改変の法的利用条件、2026-04-01制度適用、予備原題PDF対照 |
| Q1 | **CONTENT PASS 180/180、RELEASE QUALITY BLOCKED** | 初回120の難易度・カリキュラムと再現可能な出典点検、バンク及び表示挙動の独立受入 |
| Q2 | **NOT TESTED** | 出題→解答→解説→復習・保存の実操作検証 |
| Q3 | **静的ゲートPASS／実機E2E NOT TESTED** | 4/8/16問目標、5週間ヒートマップ、3/4タブ遷移、PWA/JSON/オフライン、Golden Master実画面 |
| Q4 | **NOT TESTED** | 独立ユーザー受け入れ・障害ケースと復旧テスト |
| Q5 | **BLOCKED** | 最終コミットのiOS Simulator/署名IPAと埋込バンク一致、TestFlight・ASC・プライバシー・公開URL・スクショ |

## ChatGPTがまだ実施できる作業（ユーザーの最終承認を必要としない）

1. 最終ブランチの静的CI・iOS Simulator CIを読戻し、落ちた検査・版固定不整合を修正する。特にcanonical Git Blob SHA/選定120・予備75/オフラインWebバンドルのバイト一致を検証する。
2. Webブラウザ・自動E2E（利用可能な環境範囲）の学習動線、出典/改変表示、バックアップとオフライン復元、エラー処理を検証・修正する。iPhone実機・署名IPAの検証済みと混同しない。
3. 初回120問について公式原典・現行法・学習難易度・出典表示の最終独立品質検査を可能な範囲で追加し、残留する権利判断事項を明文化する。
4. Release Registry、Release Scope、Q0–Q5、PR #5717とCI証拠、署名済みバンドルのSHAが一致するまで記録と自動検査を改善する。公開/提出・mainマージはしない。

## ユーザーによる確認・最終操作（または明示的権限を持つ運用者）

1. **権利・運用主体の最終判断**：日本FP協会等の問題使用条件、問題文・図表・出典・改変の実表示、アプリ提供主体、保険/法律関連解説を2026-04-01基準で採用することを承認。
2. **App Store Connectへログインして実物読戻し**：App ID `6797228406`、Bundle ID、Version 1.0.0、Build 1、IAPなし、App Privacy、サポート/プライバシーURL、公開メタデータ、必要サイズのスクリーンショットを確認。
3. **署名済みビルド/TestFlightの配信・実機受け入れ**：実際にiPhoneへインストールし、120問/6分野・回答/解説/復習・表示・オフライン・データ復旧・設定を確認。結果の画面・端末/ビルド識別子・不具合を証拠化する。署名と配信自体は利用可能な権限/CIの範囲でChatGPTが支援できるが、実機判断は代行できない。
4. **最終承認**：Q0–Q5が証拠付きで通過した後、App ID/Version/Buildと最終差分を特定して明示的に承認する。承認前のApp Review提出をしない。

**重要**：全問題の `publishable=false` を保ち、内容監査180/180 PASSだけで `SUBMISSION_READY` と宣言しない。

---

## 過去の履歴（以下は旧判定・旧件数であり現行状態を上書きしない）

## CI evidence after corrected PASS4 integration (2026-11-23 JST)

For commit `313d0614bb0640d71afe0abbc3fae68f04c81c3e` (bank and source-lock final), GitHub PR checks read-back:
- FP2 canonical bank and web source preflight **SUCCESS**: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45149246610. Log: content 194, selected 120, reserve 74, six domains x 20, seven pinned assets; `errors=[]`, `status=PASS`; JS syntax / v2.1 migration static check PASS.
- FP2 Golden Master v2.1 migration gate **SUCCESS**: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45149246573.
- App Release Registry Audit **SUCCESS**: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45149246631.
- iOS-native simulator push CI on this latest head, signed IPA and distributed payload **NOT VERIFIED**. Source static bundle-pin equality is verified; iOS executable bundle SHA and TestFlight remain **NOT TESTED**. This is not SUBMISSION_READY.

## Corrected FAIL5 follow-up / canonical 194 (2026-11-23 JST)

Independent re-audit: `audit/FP2_FAIL5_CORRECTED_INDEPENDENT_REAUDIT_20261123.md` (blob `26f92519480b8c32f44d246440b556a176b472af`). Recovered 180: **PASS179 / FAIL1 / HOLD0**. Four corrected PASS (2025-05 Q36/Q39, 2025-01 Q17/Q13) are admitted to the **content-reviewed reserve only**, not the 120-question release selection. Canonical **194** = 120 selected + 74 reserve; all `publishable=false`. Original 120 IDs unchanged.

2025-01 Q20 (`fp2-2025-01-gakka-020`) still **FAIL**. Explanation re-corrected to distinguish covered lightning loss and covered specified boiler explosion/rupture from excluded fire and fire-caused explosion/rupture; old text preserved in draft `correction_prior`; answer ③ unchanged. **Re-audit pending and excluded from canonical, release selection and bundle.** Prior PASS4 evidence must not be treated as Q20 PASS.

Q0 BLOCKED (operator rights, final provenance); Q1 BLOCKED FOR FINAL RELEASE (Q20 quarantined; release 120 content PASS, integrated CI verification pending); Q2 NOT TESTED; Q3 FAIL/DEVICE E2E NOT TESTED; Q4 NOT TESTED; Q5 BLOCKED (signed IPA, TestFlight/ASC and device evidence missing). CI workflow updated to assert 194/120/74, exact offline bank bytes and SHA256, but passing run after latest head must be independently read back. **NOT_SUBMISSION_READY / NOT_SUBMITTED.**


## Coordinator handoff / post-native integration (2026-11-23 18:34 JST)

**Actual: BLOCKED / NOT_SUBMITTED / NOT_SUBMISSION_READY.** Target: SUBMISSION_READY / WAITING_FINAL_APPROVAL by 2026-11-24 08:00 JST; target is not achieved or asserted.

- Native SwiftUI/WKWebView wrapper merged into release branch via PR #5718, merge commit `e27238a8f20f4d1f2377c67c1a46ae0eaa6b9a6b`. PR #5717 remains the only main-target release PR and must remain Draft.
- App ID 6797228406; bundle `com.allsunday1122.fp2manabisprint`; planned version 1.0.0/build 1; IAP none. Simulator CI success applies to the earlier native branch, **not** an attestation of the integrated commit, signed IPA or App Store Connect state.
- Canonical content PASS 190, release selected 120 (six domains x 20), reserve 70, publishable 0. Five corrected FAIL explanations remain isolated and pending independent re-audit. No unreviewed corrected question may enter the 120.
- Q0 **BLOCKED**: business rights holder/operator authorization, legal-currentness, visible source and modification disclosures not finally accepted.
- Q1 **BLOCKED**: five corrected FAIL re-audit pending; exact integrated release bank and offline payload consistency not yet revalidated.
- Q2 **NOT TESTED**: real learner answer/explanation/review loop not verified.
- Q3 **FAIL / DEVICE E2E NOT TESTED**: static UI success is not browser/iPhone Golden Master, 4/8/16, backup, or offline/PWA recovery verification.
- Q4 **NOT TESTED**: independent acceptance and actual-device evidence missing.
- Q5 **BLOCKED**: post-merge native CI, signed IPA/payload hash, ASC App ID/Version/Build/IAP/Privacy read-back, screenshots, live public URLs, TestFlight evidence missing.
- User-only final steps: (1) ASC login and App ID, bundle, version/build, IAP/privacy and public URLs verification; (2) signed build/TestFlight installation and iPhone acceptance with screenshots and evidence; (3) confirm reuse rights, source/modified notices and operating entity; (4) explicit final approval after Q0–Q5 pass. No ASC login, App Review submission, or main merge performed.


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
