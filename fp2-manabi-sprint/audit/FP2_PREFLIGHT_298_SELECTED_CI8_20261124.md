# FP2｜逐語PASS298選抜・最新ヘッドCI8/8・4分類（2026-11-24 JST）

## 結論
- 評価対象の固定SHA：`0b1dc287b5a6f2f8d39c1b4560e30411f730cf0c`（`feature/fp2-release-scope-20261123` の読み戻し時点HEAD）
- 正規バンク **310**（5回分の逐語独立監査PASS **298**＋内容監査済オリジナル予備**12**）。リリース選抜は **298** のみ。オリジナル・言い換えによる300への補充は禁止。
- 5回の内訳 **2024-05:59／2024-09:59／2025-01:60／2025-05:60／2026-05:60**。6分野 **48/50/50/50/50/50**。2024-09 Q07、2024-05 Q08はFAILのままquarantine（正規・選抜外）、HOLD 0。図版Q53、Q55は内容PASS。公開許可0、全正規問publishable=false。
- GitHub Actions check-runs APIの独立読み戻し：**8件すべてcompleted/success、未完了0、失敗0**。他アプリのfailed workflowは含めない。

| チェックジョブ | 実際の状態 | Actions run |
|---|---|---|
| static-content-and-web-shell | completed/success | https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45195987493 |
| chromium-e2e | completed/success | https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45195987396 |
| static-and-native-simulator | completed/success | https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45195987237 |
| migration-gate | completed/success | https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45195983521 |
| audit | completed/success | https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45195983438 |
| static-and-native-simulator | completed/success | https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45195983176 |
| static-content-and-web-shell | completed/success | https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45195983083 |
| chromium-e2e | completed/success | https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45195982759 |

## 4分類
| 区分 | 状態と担当 |
|---|---|
| **AUTO-FIX** | **CI側はPASS、失敗修正の追加要求なし。** 過去の312/300/12、309/300/9、300問固定やFAIL2補充の陳腐化した記録/表示が再発した場合は298固定の正本に追従する。正答・選抜IDを勝手に変更しない |
| **BUILD-REQUIRED** | **署名なしSimulator成功（本コミットで確認）**。署名済みIPA生成、298問バンドルの実SHA検証、TestFlight配信と実機試験用ビルド、サポート/Privacy URLのHTTP到達確認は未完了 |
| **HUMAN-REQUIRED** | **継続**：App Store Connectに登録されたApp ID `6797228406`、Bundle ID `com.allsunday1122.fp2manabisprint`、Version `1.0.0`、Build `1`、IAPなし、App Privacy、AppIconのApple側一致、スクショ、ストア情報とURLの実物readback。実機での学習・オフライン・図版・アクセシビリティの受入、原題逐語照合/利用主体/権利・出典/法令基準と運営責任者判断も残る |
| **FINAL-APPROVAL** | **未承認**。Q0–Q5を全通過後、ユーザーの明示的App Review提出許可が必要。PR #5717 Draft、mainマージ禁止、提出禁止 |

## Q0〜Q5
- **Q0 BLOCKED**：公式PDF全字照合、二次利用・原図・出典/加工・現行法適用と主体の最終承認。
- **Q1 CONTENT-AUDIT PASS298／PUBLICATION BLOCKED**：正規310の内容PASS、独自12は予備のみ。FAIL2隔離、HOLD0。
- **Q2 CHROMIUM E2E PASS／DEVICE USER ACCEPTANCE PENDING**。
- **Q3 GOLDEN MASTER MIGRATION + WEB E2E PASS／PHYSICAL DEVICE UI PENDING**。
- **Q4 NOT COMPLETED**：独立実機ユーザー受入の証拠なし。
- **Q5 UNSIGNED SIMULATOR PASS／SIGNED IPA・TESTFLIGHT・ASC HUMAN READBACK BLOCKED**。

**最終：CI 8/8 SUCCESS、CONTENT SELECTED 298、PUBLICATION CLEAR 0、NOT_SUBMISSION_READY、NOT_SUBMITTED。** CI成功をApple側の登録・署名・実機・提出承認に読み替えない。

## 2026-11-24 02:08 JST｜7358ea043577 HEAD時点・差分CIと未起動理由の追記

- **検査対象コミットを固定**：`7358ea043577b52a758e0924fd8150db24365d97`。本監査追記時にはブランチ先端が別の新しいコミットへ進んでいたため、このSHAを現在の永続的HEADとは表記しない。
- 対象commitの変更ファイルは **`fp2-manabi-sprint/release/STORE_AND_APP_PRIVACY_20261123.md` のみ**。
- GitHub Check-runs API `/repos/ALLSUNDAY1122/ALLSUNDAY1122.github.io/commits/7358ea043577b52a758e0924fd8150db24365d97/check-runs` を実読戻し。**total_count=3、全件completed/success、失敗0、未完了0**。

| 実行された検査 | 状態 | Actions run |
|---|---|---|
| static-content-and-web-shell | completed/success | https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45219122908 |
| static-and-native-simulator | completed/success | https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45219123054 |
| chromium-e2e | completed/success | https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45219123061 |

### migration-gate／Registry auditを今回の3件に含めない理由

1. **Golden Master migration-gate**：`.github/workflows/fp2-v21-migration-gate.yml`の`push.branches: [main]`であり、今回のpush先`feature/fp2-release-scope-20261123`は対象外。なお`pull_request.paths: fp2-manabi-sprint/**`と`workflow_dispatch`も存在し、別イベントによる実行はこのコミットのpushチェックからは判定しない。Preflightワークフロー `fp2-release-source-preflight.yml`のジョブ内には`python3 scripts/fp2_v21_migration_gate.py`が含まれ、今回の`static-content-and-web-shell`ジョブがSUCCESSであるため、**移行ゲートのスクリプト自体はpreflight内で成功**。独立`migration-gate`ジョブの今回の実行とは区別する。
2. **App Release Registry Audit**：`.github/workflows/app-release-registry-audit.yml`の`push.paths`は`automation/app-release-registry.json`などRegistry関連の定義・スクリプトとそのworkflowのみ。変更ファイル`fp2-manabi-sprint/release/STORE_AND_APP_PRIVACY_20261123.md`は対象外で、**パスフィルタが不一致**。手動`workflow_dispatch`または別のpull_requestイベントは別扱い。

### 今回のプリフライト解釈

- **対象選抜は298問のまま**：正規310問（公式逐語298＋オリジナル予備12）、FAIL2隔離、HOLD0、公開許可0。旧312/300/12や309/300/9に戻さない。
- **AUTO-FIX**：今回の3実行で修正対象のCI失敗なし。Registry auditが起動しなかったことをエラーとみなしてworkflow改変しない。
- **BUILD-REQUIRED**：unsigned Simulatorの今回のSUCCESSは確認。署名済みIPA・298問配布実バイトSHA・TestFlight・公開URL実確認は未了。
- **HUMAN-REQUIRED**：App Store ConnectのApp ID/Bundle/Version/Build/IAP/App Privacy/AppIcon/スクショ/URL読戻し、実機受入、原典・二次利用・運営責任承認は未了。
- **FINAL-APPROVAL**：ユーザーによる明示的なApp Review提出許可は未取得。
- **最終判定は継続：NOT_SUBMISSION_READY／NOT_SUBMITTED**。PR #5717 Draft、mainマージ・Apple提出なし。

**重要な区別**：このSHAで「3/3 SUCCESS」であることと、以前の`0b1dc28`で「8/8 SUCCESS」であることは両立する。今回の未起動2種類をFAIL/QUEUEDとは記録しない。独立Registry auditの今回PASSも捏造しない。
