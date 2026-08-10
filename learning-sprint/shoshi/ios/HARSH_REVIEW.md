# 司法書士 学びスプリント｜純SwiftUI iOS 辛口レビュー 3回

実施日: 2026-08-10
対象: iOS 1.0.0 / SwiftUI Native / StoreKit 2

旧 `SwiftUI + WKWebView` を対象にした2026-08-09のレビュー結果は、純SwiftUI移行開始時に実装/UI/Release PASSとともに失効した。本記録を現行レビュー正本とする。

## 第1回｜「無料枠がJSONやリセットで何度でも復活しないか」

### FAIL
初期純SwiftUI実装では、最初の1スプリントを消費した状態を `LearningState` に含めていた。`LearningState` はJSONバックアップ対象であり、学習データのリセット対象でもあるため、古いJSONの読み戻しやリセットによって無料枠を再取得できる設計だった。

### 修正
- 無料枠消費状態を学習バックアップから分離。
- 専用UserDefaultsキー `shoshi-native-trial-completed-v2` で保持。
- 学習データのJSON export/importとリセットでは変更しない。
- XCTestでJSON内に `trialCompleted` / `trialConsumed` が含まれないことを検証。
- 静的専門監査で、無料枠状態が `LearningState` に存在しないことと専用端末保存を必須化。

### 再監査
- 学習履歴リセットによる無料枠復活: 防止。
- JSON差替えによる無料枠復活: 防止。
- StoreKitのpremium entitlementとは独立し、購入状態をJSONで変更できない。

## 第2回｜「壊れたJSONを読み込むと学習履歴やUIが壊れないか」

### FAIL
初期実装はCodableとしてデコードできれば受け入れていたため、4/8/16以外のdailyGoal、正答数が解答数を超える履歴、異常に大きいファイル、現在存在しない問題IDを含むバックアップを取り込めた。

### 修正
- JSON入力を5MiB以下に制限。
- version範囲、dailyGoal=4/8/16、文字サイズsmall/medium/largeを検証。
- 問題別のanswered/correct/correctStreak、日別answered/correct、完答回数の論理整合を検証。
- 現在の210問に存在しない問題IDの履歴はインポート時に除外。
- resumeは現在の問題IDがすべて存在するときだけ復元。
- 不正dailyGoal、不可能な正答数、過大ファイルのXCTestを追加。

### 再監査
不正バックアップはエラーとして拒否し、既存学習状態を破壊しない設計へ変更。

## 第3回｜「ネイティブ化したつもりでWebViewが残っていないか／課金情報を偽表示しないか」

### FAIL条件
旧実装はSwiftUIの外側にWKWebViewを配置していたため、今回の純ネイティブ要件では旧PASSを全面失効。さらに、価格固定・未検証entitlement・Privacy Manifest不整合があればRelease不可とした。

### 修正・再構成
- App本体から `WebKit` / `WKWebView` / `UIViewRepresentable` / `loadFileURL` を排除。
- 問題210問はBundle Resourceとして直接読み込む。
- 状態管理・4タブ・問題画面・記録・設定・PaywallをSwiftUIで実装。
- StoreKit 2は `Product.products`、`Product.displayPrice`、`Transaction.currentEntitlements`、`Transaction.updates`、revocation、`AppStore.sync()` を使用。
- 金額をコード固定しない。商品が取得できない間は購入不可。
- Privacy Manifestは端末内UserDefaults利用理由 `CA92.1` を宣言し、tracking=false、収集データなし。
- GitHub ActionsでSwiftソース内のWebKit系token 0件、Xcode projectのWeb bundle不在を機械監査。

### 再監査
- 純SwiftUIソース契約: PASS。
- 210問回帰 / R7午後33 all_correct: PASS。
- StoreKit 2契約 / Privacy Manifest: PASS。
- XCTest / Release Simulator build: macOS CI実行結果をRelease Gateで確定するまで未PASS扱い。

# Golden Master照合
- 4タブ: ホーム／模試／記録／設定。
- 標準8問、4/8/16設定。
- 生成り紙＋藍＋朱＋緑＋金。
- 28px方眼、82px進捗リング。
- 明朝タイトル/問題文/結果＋ゴシック操作系。
- 即時○×、解説、黄背景＋金左線の `ここだけ覚える`。
- 全体正答率ドーナツ、11科目バー、5週間ヒートマップ、苦手復習。
- 試験日残日数＋必要ペース。
- 問題途中および回答後解説状態からの再開。
- オフライン210問、JSONバックアップ。

# Releaseハードゲート
- App: `司法書士 学びスプリント`
- Bundle ID: `jp.allsunday1122.shoshi`
- App Store Connect App ID: `6799755748`
- Codemagic署名プロファイル正本名: `shoshi_appstore`
- IAP: `jp.allsunday1122.shoshi.premium` / Non-Consumable
- canonical AppIcon SHA-256: `c34399358e182a4709f805127fc7244f9763a1f796bb68dfed24b5c4ee815506`
- `submit_to_testflight: true`
- `submit_to_app_store: false`

正本AppIcon、macOS XCTest/Release build、signed IPA、Internal TestFlight uploadが完了するまでRelease全体をPASSにしない。本審査への提出は禁止する。
