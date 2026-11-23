# FP2 180問全文回収・出典台帳結合監査（2026-11-23）

## 検索対象
- GitHub: mainのコード検索、search_branchesでfp2/FP2/academicを検索した3つの既存関連ブランチ（codex/fp2-batch-a01-20261108、codex/fp2-official-pastquestions-policy-20261108、feature/fp2-kakomon-coach）。関連ブランチのmain比較で変更ファイルを特定。
- Google Drive: FP2、fp2、学科、過去問、academic等のファイル検索。AUDIT_MATRIX_FP2（2026-05、2025-05、2025-01各60）を確認。
- 既存の公開製品UI fp2-manabi-sprint/index.html（旧8問）と公式出典インデックスを参照。

## 発見
- GitHub branch feature/fp2-kakomon-coach
- fp2-kakomon-coach/questions/question_bank_fp2.json: 180問すべて問題本文、4選択肢、1-based正答、解説を保有。所属試験回 2026-05 60、2025-05 60、2025-01 60。
- fp2-kakomon-coach/AUDIT_MATRIX_FP2.csv: 同ID180行の監査記録。Google Driveの表とも対応。
- 別の codex/fp2-batch-a01-20261108 ブランチで見つかった product-bank-20261107.json は FAIL/PRODUCT_BANK_MISSING の旧監査結果であり、製品bankではない。

## 結合と静的検査（今回実施）
- 回収した全文180件を2026-11-23に直接読み取ったDrive監査表180行とID結合。
- ID一意性180/180、問題本文有180/180、選択肢4肢180/180、解説有180/180、1〜4の正答180/180。
- 照合項目：examDate、domain、sourceQuestionNumber、answer、sourceUrl、legalReferenceDate。180件すべて一致、照合不一致0。
- 旧監査表には転記済・解説確認済フラグ180/180。ただしそのレビューの内容や現行性を再実証するものではない。
- 2026年5月公表の公式PDF（https://www.jafp.or.jp/exam/mohan/files/g2_202605_qa.pdf）第1問と第2問の出題本文・選択肢・正答を視認し、回収データの対応をサンプル確認。**180問すべての公式原文逐語照合はまだ未実施。**
- 資料・図表・「下記」等が本文に含まれる11問をパターン抽出し個別図表検査HOLD。これは候補抽出であり図版依存全件抽出の保証ではない。

## 取込
- 保存: fp2-manabi-sprint/questions/draft/fp2-recovered-180-fulltext-20261123.json
- 完全文構造で回収: 180/180問
- 出典インデックスと結合: 180/180問
- 新規ドラフト登録180、アプリリリース承認0
- 元データを保持し、全設問に団体、出典試験回、問番号、出典URL、権利条件URL、出典表示文字列を付与。
- **modified=null / modification_note=null**: 原文一致・加工有無の判定をしていないため偽の未加工宣言を禁止。解説の独自作成性も旧表の「済」だけでは再証明できない。
- law_target_date=2026-04-01、law_current_recheck=NOT_TESTED、independent_review_status=NOT_TESTED、publishable=false。

## 残るゲート
1. 各設問の公式PDF原題・図表と全文を比較し加工有無を確定、加工時は変更を具体的に表示する。出典を製品画面に表示。
2. 各選択肢の正否と旧模範解答を2026-04-01の適用制度に照らして再判定。2026-05旧基準2025-04-01、2025-05旧基準2024-04-01、2025-01旧基準2024-10-01。法改正影響のある設問を隔離。
3. 解説の独自執筆証拠・内容正確性と第三者コンテンツの混入なしを検証。過去問道場（FP2級ドットコム）の解説・文章・データを転載しない。
4. 特殊図表・外部画像を監査し、欠落なら隔離。独立内容監査、意味重複、canonical統合後の再検査。
5. UI Master v2.1に接続し実機・配布・プライバシー等の全ゲートをPASSするまではSUBMISSION_READY禁止。

**判定**: 構造完全回収 180 PASS / 0 FAIL。個別権利・加工、現行法、独立監査は180 HOLD。Q0 BLOCKED、Q1 BLOCKED。App Review提出なし。
