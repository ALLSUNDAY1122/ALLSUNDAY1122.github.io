# 保健師｜学びスプリント（iOS）

保健師国家試験 第108〜112回・全546問（厚生労働省公式PDFと照合済み）を収録した学習アプリ。学びスプリントシリーズ標準仕様（看護師アプリと同一基盤）に準拠。

## 構成
- タブ構成：ホーム／模試／記録／設定
- ホーム：今日の学習リング、今日のスプリント（既定8問・未学習優先）、無料お試し30問（第112回 午前15問＋午後15問）、苦手をつぶす（3回連続正解で卒業）、分野から解く（大分類→科目、科目分類は問題文からの自動分類）
- 模試：第112〜108回 × 午前・午後を本番順で出題（プレミアム）
- クイズ：単一選択はタップで即採点、2つ選べは「採点する」、数値問題は数値入力（±許容誤差）、「わからない（答えを見る）」、解説は「ここだけ覚える」＋「もう少し詳しく」、図表36問は画像表示、出典バッジ（第◯回・午前/午後・第◯問）
- 課金：買い切り ¥800（`jp.allsunday1122.hokenshisprint.premium.lifetime`）＋月額 ¥200（`jp.allsunday1122.hokenshisprint.premium.monthly`）。無料は30問、プレミアムで全問・模試・分野別・詳細記録を解放
- アイコン：シリーズ版（番号13・公衆衛生）を使用

## データ
- `ios/GeneratedResources/questions.generated.json`：シリーズ共通バンドル形式（546問、科目分類・無料30問IDつき）
- 図表：`data/figures-1.json` / `figures-2.json`（Base64、計36問分）。ビルド時に `prepare-ios.sh` が GeneratedResources へコピー
- 元データ：`data/questions-546.json`（検証済みマスター）

## ビルド
Codemagic ワークフロー `hokenshi-sprint-ios`（ルート `codemagic.yaml`）。XcodeGen + 共有パッケージ `native-ios/LearningSprintCore` を使用。
