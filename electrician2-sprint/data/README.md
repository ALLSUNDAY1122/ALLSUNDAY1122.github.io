# 第二種電気工事士 QUESTION_BANK 受け口

## 置き場所

- 各回の転記成果物（受け入れ・監査前）：\`electrician2-sprint/data/E2-{YEAR}-{U|L}-001-050.json\`
- アプリが読む統合バンク：\`electrician2-sprint/ios/Resources/QUESTION_BANK.json\`
- スキーマ定義・検証コード：\`electrician2-sprint/ios/Sources/QuestionBank.swift\`

6回分（2026上期・下期、2025上期・下期、2024上期・下期）を各50問、合計300問とする。各回の転記JSONは原典転記単位で保持し、統合バンクへマージする。転記ファイルを直接アプリに同梱しない。

## 正式スキーマ（既存 E2-2026-U-001-050.json と同一）

トップレベル：
- \`schemaVersion\`: \`"1.0"\`
- \`dataSet\`: 例 \`"E2-2026-U"\`（統合時は \`"E2-ALL-2024-2026"\`）
- \`sourceFiles\`: \`questionPdf\` / \`answerPdf\`
- \`questionCount\`: questions配列件数と一致
- \`questions\`: 問題レコード配列

問題レコード：
- \`id\`: \`E2-2026-U-001\` 形式
- \`exam\`, \`examDate\`, \`section\`, \`questionNumber\`, \`question\`
- \`choices\`: \`[{ "label":"イ", "text":"..." }, ...]\`。順序はイ・ロ・ハ・ニ
- \`answerOfficial\`: 公式正答の選択肢ラベル（イ／ロ／ハ／ニ）
- \`hereToRemember\`, \`explanation\`: 未作成時はnull
- \`source\`: \`title\`, \`url\`, \`page\`, \`figure\`, 任意の \`figureRefs\`
- \`audit\`: \`transcription\`, \`answer\`, \`figureStatus\`, \`independentReview\`, \`releaseStatus\`

## 監査・権利の扱い

- 転記直後は \`audit.releaseStatus = "PENDING_SOURCE_AND_VISUAL_AUDIT"\` または個別状況に対応するHOLD値とする。
- 「転記済み」は「独立監査PASS」や「公開可能」を意味しない。監査状態を転記担当者の判断でPASSにしない。
- 図版は埋め込まず、\`source.figureRefs\` に論理参照IDを列挙する。図版データ・権利確認・目視監査は別管理。
- 正答は公式正答PDFと照合し、\`answerOfficial\` はラベルで記録する。
- 既存2026上期ファイルの構造を正本とし、他セッションで異なるキー（\`audit_status\`、\`correct_answer\`、\`figure_ref\` 等）を出力した場合は、意味を保持してこの形式へ正規化してから統合する。
- 問題文・選択肢・公式正答を推測補完しない。図版参照のみの選択肢は原ファイルの表現を維持し、図版IDを付ける。

## 受入条件

各回50問、ID重複なし、問番号1〜50、選択肢4つ・順序イロハニ、正答ラベル整合、出典PDF URLとページあり、図版参照保持、監査状態あり。6回合計300問を確認後にQUESTION_BANK.jsonへ統合する。
