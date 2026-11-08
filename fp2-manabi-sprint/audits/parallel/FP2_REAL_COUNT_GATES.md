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
