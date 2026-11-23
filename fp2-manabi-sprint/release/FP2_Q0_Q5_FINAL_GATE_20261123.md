# FP2｜Q0〜Q5最終ゲート・統合監査（2026-11-23 JST）

## 結論
**SUBMISSION_READY = NO / PR #5717 Draft / Apple提出なし**。
- 正規bank `questions/canonical/approved-questions-20261123.json` は独立内容監査PASS **122問**（原作12、2024-05の公式加工3、2026/2025公式回収PASS107）。
- 今回指定されたBatch03のPASS **31問（新規29+修正2）** を追加済み。先行65から96へ統合した後、別並行作業によってBatch04のPASS26が追記され122へ増加した。いずれの既存PASSも削除せず保持。
- 追加Batch03は **逐語/実質原文維持27、加工4**（公式2026-05問53、公式2025-05問2、旧FAIL訂正2026-05問14、2025-01問34）。監査証拠: `audit/FP2_RECOVERED_180_INDEPENDENT_BATCH03_30_PLUS_FAIL2_20261123.md`。変更内容は個別`modified`/`modification_note`記録。
- Batch04追加26も公式原文の内容維持と判断し、ソース整形差を注記。**全回収107問の改変状態は boolean + note、正規bank内のnull=0**。残りドラフト73件（うちFAIL/HOLD）まで改変判定したという意味ではない。
- 完全公開許可は **0問**。全問`publishable=false`。
- 別セッションの最新独立監査台帳Batch05/06までの180問カバレッジ：回収 **PASS163 / FAIL4 / HOLD13 / 未監査0**。回収PASSのうち**56問は今回のcanonicalに未統合**。この集計は `audit/FP2_RECOVERED_180_INDEPENDENT_BATCH05_30_20261123.md` と `audit/FP2_RECOVERED_180_INDEPENDENT_BATCH06_FINAL30_20261123.md` に基づく。未統合56問の改変注記を勝手にPASS確定してはいけない。

## Q0–Q5最終判定
| ゲート | 判定 | 根拠・不足 |
|---|---|---|
| Q0 権利・公式出典・法令 | BLOCKED | 日本FP協会＋きんざいの条件付き利用規定を確認。canonical122件の出典リンク・改変注記は存在。利用主体が禁止区分に該当しない証跡、第三者文章/図版の最終検査、適用法令の個別施行履歴・新旧解答全肢の最終独立証拠、アプリ実表示が未確認。 |
| Q1 問題バンク | BLOCKED（内容部分PASS122） | canonical122件は独立内容PASSで、構造・根拠パス・Blob SHA・原典加工字段の機械検査PASS。ただし当初MVPは最大120問、122件で2問超過。さらに回収残分56件のPASS未統合、FAIL4件、HOLD13件、全体意味的重複・リリース選別とビルド後再監査が未完了。 |
| Q2 学習価値 | NOT TESTED | 出題、正答後フィードバック、履歴、苦手復習が実装されているが実際の学習者操作・定着/誤答後復習テスト未実施。 |
| Q3 UI/UX | FAIL（静的移行検査PASS） | 4タブ、4/8/16、82px日次リング、35日ヒートマップ、JSON出入力、出典/加工表示、PWA同一オリジンキャッシュをコードに統合。iPhone/Chromium実動、Golden Masterの画面一致30状態、オフライン復旧、画面安全領域の本検証なし。 |
| Q4 独立受入 | NOT TESTED | 出題内容の独立監査と、製品そのものの別視点・学習者受入は別。実機・E2Eの独立検証未実施。 |
| Q5 最終品質・申請準備 | BLOCKED | iOS専用ビルド、署名IPA、配布バンドルの実SHA、TestFlight、App Store ConnectのVersion/Build/IAP/Privacy、スクリーンショット、公開到達できるサポート/プライバシーURLが未確認。 |

## 今回自力で閉じた項目（ソースとCIの範囲）
1. **Batch03 PASS31をcanonicalへ追加**、監査証拠のパスとSHAを保存、旧FAIL修正2問は独立再PASSを確認。
2. **改変/原典判定**：追加31の27/4を記録。さらに並行Batch04の26について原題を確認して改変なし（PDF体裁正規化）を注記し、canonical回収107件のnullを0にした。
3. UIの`fp2-approved-bank.js`接続を確認し、Web版にPWA `manifest.webmanifest` と `service-worker.js`、登録処理を実装。ただしオフライン実機試験は未了。
4. 古い`content-expansion-contract.json`の固定600問・独自作問限定を廃止。120問上限と122問を明示してスコープ未承認を隔離。
5. 正規bank/UI adapter/HTML/PWA/サポート/プライバシーの**ソースSHAロック** `release/bundle-lock-20261123.json` を記録（実IPAとの一致証明ではない）。
6. `scripts/fp2_release_preflight.py` と `.github/workflows/fp2-release-source-preflight.yml` で、正規問題・証拠SHA・改変注記・WebソースSHA・UI構造・JS構文をCI化。**GitHub Actions 45145368115 はPASS**。従来UI Master静的ゲートも `45145361976` PASS。これらは静的検査に限定する。
7. 製品専用 `support.html` / `privacy.html` を作成、Web実装から条件付きApp Privacy回答・ストア原稿 `release/STORE_AND_APP_PRIVACY_20261123.md` を作成。**外部公開のURLへはHTTP到達確認不可**のためASCにはまだ確定登録しない。

## バンドルとバンクの一致
- **PASS（Webソース）**：`index.html` → `fp2-approved-bank.js` → `questions/canonical/approved-questions-20261123.json` の同一パスを静的検査し、Service Workerも同ファイルをprecache対象に指定。バンクを含む7ファイルのGit Blob SHAがlockと一致（CI PASS）。
- **NOT TESTED（実配布物）**：FP2専用iOSプロジェクトが `fp2-manabi-sprint/` / `ios/fp2` に存在を確認できず、IPA自体のBuild・署名・Manifest・バンクSHAは検証不可。**iOSバンドル一致はPASSではない。**

## HUMAN-REQUIRED（人の操作/判断が不可欠な項目）
- 実際にiPhone/iPadでのインストール/ログイン、出題の正答・誤答・中断復帰・端末向き・Safe Area・VoiceOver・長文、オフライン復帰、JSONの書き出し/読み込みを受け入れ判定し、実機画面・ビルド番号証拠を提供すること（ビルド提供後）。
- 利用主体が日本FP協会/きんざいの利用禁止対象外であること、問題データに第三者コンテンツが混入していないこと、問い合わせ先の運営実体について責任者が最終承認すること。
- アプリのストア掲載表現、IAP有無・料金・App Privacy回答を運営者が確認して最終承認すること。Appleログイン・認証等の手操作が必要になった場合にのみそれを個別依頼する。
- 完了後のApp Review/公開申請を**ユーザーの明示的な最終許可後に**実施すること。現時点では禁止。

## HUMAN-REQUIRED以外のブロッカー（技術・品質・データ作業）
- FP2固有のiOSプロジェクト・署名/ビルド設定と実IPAが未確定。App ID `6797228406` に対するASCのBundle ID、Version、Build、IAPはライブ未照合。Webソース単独では提出不可。
- GitHub Pages上のサポート/プライバシーページはブランチ内のみ新規作成され、外部HTTP200を確認できていない。正式公開状態の確立が必要。
- 学習導線/JSON復元/Service Workerを実ブラウザと実機で検査するE2Eを追加し、UI Master v2.1 Golden Masterと30状態比較すること。
- 122件は計画最大120問を2件超過。全件内容PASSは保持し、リリース対象を最大120に選別するか上限変更を正式決定する必要がある。
- 独立監査PASS56未統合（Batch05/06）を採用する場合、公式原文比較と改変注記、出典・重複監査を完成させる。FAIL4/HOLD13は修正と独立再監査が済むまで除外。
- WebソースSHAの固定と実IPA埋込資産のSHA照合、App Privacyやストア記載と実配布ビルドの照合は実ビルド完成後に実行すること。
- ブラウザやApple側設定を確認できないため、サポート/Privacyの「到達不能」とASCの各項目について架空の確認済み判定は行わない。

## 証拠参照
- Source bank: `fp2-manabi-sprint/questions/canonical/approved-questions-20261123.json`
- Batch03: `fp2-manabi-sprint/audit/FP2_RECOVERED_180_INDEPENDENT_BATCH03_30_PLUS_FAIL2_20261123.md`
- Batch04: `fp2-manabi-sprint/audit/FP2_RECOVERED_180_INDEPENDENT_BATCH04_30_20261123.md`
- QA: `.github/workflows/fp2-release-source-preflight.yml` / `scripts/fp2_release_preflight.py`
- Web source lock: `fp2-manabi-sprint/release/bundle-lock-20261123.json`
- Store/privacy: `fp2-manabi-sprint/release/STORE_AND_APP_PRIVACY_20261123.md`
- CI: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45145368115
- UI static: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45145361976
- PR #5717: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/pull/5717

## 安全制限
SUBMISSION_READY / WAITING_FINAL_APPROVALに昇格禁止。PR Draft維持、mainマージ・App Review/公開申請禁止。
