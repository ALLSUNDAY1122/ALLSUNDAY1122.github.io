# FP2-GATES 公式過去問実数検査ゲート改修
更新: 2026-11-09 JST / owner: MUSE-EXT-GATE
claim_commit: `8f2f12c0821872629e0c5ed23f75b3e3c2e3da0b`

## 変更と対象
- `tools/audit_product_bank.py`: 独自作問600問・分野100問ずつ・学科480/実技120の固定ゲートを廃止。公式原典カタログで定義した実際の公開問番号集合に対し、収録数・監査承認数・原典IDの全件一致を要求する。
- `official-source-catalog.json`: `FP2_OFFICIAL_SOURCE_LEDGER.md` の確認済み公表5セット（202405, 202409, 202501, 202505, 202605）、各学科60＋実技40、合計学科300＋実技200＝500を「原典公表件数」として別保存。500は固定製品ノルマではなく現在の対象原典の集合の大きさであり、原典増減時は出典台帳を先に更新する。
- 一意キー `sourceQuestionId` は `JAFP-FP2-YYYYMM-ACA|PRAC-NN`。未知ID、欠番、重複ID、IDと回次・科目・問番号・公式PDF URL・法令基準日の不一致はFAIL。
- 全件 `auditStatus=approved`、`transcriptionReviewStatus=verified`、`answerReviewStatus=verified`、`explanationReviewStatus=verified`、`rightsReviewStatus=approved`、`thirdPartyRightsStatus=cleared|not_applicable` を要求。不明・未監査はFAIL。
- 各問題の日本FP協会・回次・学科/実技を含む `attributionText`、加工有無、加工ありの場合の `modificationDisclosure` と「加工」の表示、`rightsNoticeDisplayed=true`、公式PDF URLを含むHTTPS `sourceRefs` を必須とする。
- 問題文の完全一致・類似度0.9以上を重複候補としてFAIL。従前の単一選択・数値解答の構造チェックも維持。
- A01独自作問や旧180問は監査承認・原典ID照合前に製品数へ計上しない。
- 製品JSONを変更していない。FP3のロック済みバンクにも変更なし。

## 検証記録
- GitHubから改修ファイル・カタログ・テストファイルを再読込し、ソースに重大な拒否条件7種類の定義があることを確認（静的確認）。
- カタログの回次別宣言を独立計算した結果: 5回次×（学科60＋実技40）＝500、学科300／実技200（静的確認PASS）。
- テスト: `python3 -B -m unittest -v fp2-manabi-sprint/tools/test_audit_product_bank.py`。人工的な完全収録ケースのPASS、欠番、不明原典ID、二重登録、権利未承認、出典表示欠落、加工表示欠落、類似重複、解答監査不足、公式URL不一致の計10ケースを追加。
- CI: `.github/workflows/fp2-official-source-gates.yml` を新設。回帰10ケースと、現行製品データのFAIL閉鎖を検査。**本セッションからCI実行結果・Pythonテスト実行結果を取得できていないため、テスト成功は未確認。**
- 製品リリースゲート: **BLOCKED**。原典の500問は完成・承認を意味せず、旧180問の再利用承認、残り問番号の逐語・回答・権利審査とUI表示の実測が未完。

## 未解決 / 次アクション
1. CIの回帰テスト結果と現行製品BANKのFAIL結果を取得し、失敗があれば修正する。
2. 正式製品統合担当FP2-MERGEで監査済みデータを統合し、sourceQuestionId、表示される出典表記、加工表記を実機上でも照合する。
3. 権利フラグは自己申告フィールドであり、本ゲート単独でライセンスや第三者図版の適法性を実証しない。一次資料・表示画面の人的監査を別途必要とする。
4. 既存の `content-expansion-contract.json` は独自600問の**旧契約**として残している。製品統合時の参照元から外す必要がある。これを現在の正式製品基準として誤用しない。

## 2026-11-09 追加実行検証 / 旧契約参照整理（FP2-GATES解除根拠）

### CI 実行証跡
- 第1回: GitHub Actions Run 42526329561 / job 128870662981。実ジョブログに `Ran 10 tests in 0.007s` / `OK`、10項目すべて `ok`、失敗0、エラー0。現在の未完成製品データの `PRODUCT_BANK_MISSING` によるFAIL-closedも成功。
- 旧契約由来の回帰テストを修正後、第2回: GitHub Actions Run 42527638041 / job 128874678575 / commit `e0afbe6a96c69fb444870d0c5518647cc28a8ade`。専用テスト10/10 PASS、共通回帰エントリポイント（`scripts/tests/test_fp2_product_bank.py`）経由でも10/10 PASS、合計20回の実行で失敗0・エラー0。現行製品のFAIL-closed検査もPASS。
- 証拠URL: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/42527638041

### 旧600問参照の実装調査と修正
1. `fp2-manabi-sprint/tools/audit_product_bank.py` は公式原典問番号の全件対応に切替済み。旧 `content-expansion-contract.json` を参照しない。
2. `scripts/tests/test_fp2_product_bank.py` は旧 `product_bank.target_domain_counts`（600問）を読み込むテストを含んでいた。これを公式原典ゲートの10ケースを呼び出す互換エントリポイントへ改修した（commit `775b1e5044a2e633660ddf2c0a2fc5d049d83d81`）。
3. `scripts/fp2_v21_migration_gate.py` は UIに「600問」という文字列の存在を必須化し、旧600問契約の検査失敗メッセージを出していた。これを旧「別途600問監査後」文言の排除と公式原典ゲート結果の検証に変更。機能ゲートの前提条件は維持（commit `ea662fa7b66ccb513b3b984ddc71bfe472fa9892`）。
4. `fp2-manabi-sprint/content-expansion-contract.json` は旧計画の履歴として保管（600問記述は残る）。`CONTENT_BATCH_PLAN.md`、`PRODUCT_DATA_STATUS.md`、`audits/product-bank-20261107.json` も当時の数値・判断の記録であり現行ゲートの実数には使わない。不要な正本書換を避けるため今回削除・改変しない。
5. `.github/workflows/fp2-official-source-gates.yml` に専用10ケースと共通テスト10ケースの双方を組み入れた（commit `e0afbe6a96c69fb444870d0c5518647cc28a8ade`）。既存の `fp2-v21-migration-gate.yml` は `scripts/fp2_v21_migration_gate.py` を呼び、同スクリプトは新しい公式原典ゲートを呼ぶ。
6. 既知の実行経路について旧契約への実行時参照は解消。リポジトリ全履歴や別ブランチ、未確認の外部実行処理の完全走査は行っていない。

### 完了境界
- **FP2-GATESテーマ: DONE**（コード・10件の回帰テスト・共通経路10件・CI実ログ証拠が揃った）。
- **FP2製品リリース: BLOCKED**（公開原典数500＝完成数ではない）。原文・正答・解説・第三者権利・表示内容の実監査やFP2-MERGE、FP2-E2Eを引き続き必要とする。
