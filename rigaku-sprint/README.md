# 理学療法士国家試験｜学びスプリント #15

SwiftUIネイティブ実装。WKWebView/UIWebViewを主UIに使用しません。学びスプリント UI Golden Master v2.1 と `native-ios/LearningSprintCore` を基準にします。

## 現在地
- ブランチ: `feat/15-rigaku-sprint-native`
- Draft PR: #4139
- 公式構造: 第60・59・58回 各200枠、合計600枠
- リリース問題: 600/600
- 内容監査: 600/600
- 第60・59・58回: 各200問、午前100＋午後100
- 公式採点調整: 20件（採点除外6、複数正答14）
- 権利未解決の公式/第三者図版: 66枠。原図は収録せず独自文章問題へ再構成
- 重複・高類似ゲート: PASS（検出した5組は独立設問へ再構成）
- 最終根拠URL: 検索結果ページを禁止し、特定論文・診療ガイドライン・公的資料へ固定
- Privacy Manifest: 実装済み。tracking=false、開発者収集データ0、Required Reason API宣言0
- Support / Privacy / Termsページ: ブランチ上に作成済み。main統合後に公開確認
- StoreKit2: 共通コアのverified transaction検証を#15へ接続済み。正本IAP Product IDが外部注入された場合だけ有効化
- AppIcon: Drive正本を特定・ハッシュ固定済みだが、正本PNGバイナリのGitHub投入のみ未完

## 模試の扱い
「第58〜60回ベース模試」と表示します。厚生労働省の各回200枠の構成・公式配点を基準にしますが、問題文・選択肢・図版は権利と内容を監査した独自問題へ再構成しているため、公式試験問題の完全な再現とは表示しません。公式採点除外枠は0点として集計します。

## 品質ゲート
- `rigaku-sprint/ios/static_audit.py`
- `rigaku-sprint/ios/privacy_audit.py`
- `rigaku-sprint/product-content/validate_exam_structure.py`
- `rigaku-sprint/product-content/validate_official_answers.py`
- `rigaku-sprint/product-content/validate_question_batches.py`
- `rigaku-sprint/product-content/validate_evidence_quality.py`
- `rigaku-sprint/release_preflight.py`
- GitHub Actions: `Rigaku Fast Quality Gate`
- GitHub Actions: `Rigaku Native iOS Quality Gate`
- `native-ios/LearningSprintCore` SwiftPM tests
- iOS Simulator build-for-testing / XCTest

## 正本値として未確定（推測禁止）
- App Store Connect Apple ID
- Bundle ID (`RIGAKU_BUNDLE_ID` 外部注入)
- SKU
- Copyright owner
- 課金を採用するか
- IAPを採用する場合の商品種別 / Product ID / 価格方針 / 無料・有料範囲 (`RIGAKU_IAP_PRODUCT_ID` 外部注入)
- 公開してよいサポート問い合わせ先

## AppIcon正本
- Google Drive: `AppIcon 採用版 2026-08-09 / 15_理学療法士国家試験.png`
- Drive file id: `1RvSyvCapkoon09U4HbYNM1e4v5V29LVY`
- 1024×1024 PNG
- 663,589 bytes
- SHA-256: `5ffc2de874d6f22b0fd6ee121e7c691ae7a7caee30844fad059439846dfefca9`
- 再生成・トリミング・描き直し禁止。正本バイナリそのものをAppIconへ投入する

## 公開前ルール
- PRはDraftのまま保持し、ユーザー確認前にmainへマージしない
- Internal TestFlightまで。外部テスト/App Store最終提出はユーザー承認なしに実行しない
- `release_preflight.py --phase internal-testflight` がPASSするまでTestFlight作成へ進まない
- `release_preflight.py --phase app-store` がPASSし、さらにユーザーの最終提出承認を得るまでApp Storeへ提出しない
