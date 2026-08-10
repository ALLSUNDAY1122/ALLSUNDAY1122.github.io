# App Store Connect / TestFlight 接続パケット

## App record（正本固定値）
- Name: `司法書士 学びスプリント`
- Bundle ID: `jp.allsunday1122.shoshi`
- App Store Connect App ID: `6799755748`
- SKU: `shoshi-sprint-ios`
- Version: `1.0.0`
- Platform: iOS
- Availability: Japan first

## In-App Purchase
- Product ID: `jp.allsunday1122.shoshi.premium`
- Type: Non-Consumable
- Reference Name: `司法書士 学びスプリント プレミアム`
- Display Name: `プレミアム解放`
- Price: App Store Connectの正式価格を使用（コードへ固定しない）

## Public URLs
- Support: https://allsunday1122.github.io/learning-sprint/shoshi/support/
- Privacy: https://allsunday1122.github.io/learning-sprint/shoshi/privacy/
- Web prototype: https://allsunday1122.github.io/learning-sprint/shoshi/mvp/

## Native build
- Implementation: `SwiftUI native`（WebView/WKWebView禁止）
- Xcode project: `learning-sprint/shoshi/ios/ShoshiSprint.xcodeproj`
- Scheme: `ShoshiSprint`
- Minimum iOS: 16.0
- Orientation: iPhone portrait
- Signing: App Store distribution
- Codemagic signing profile canonical name: `shoshi_appstore`
- CI build number: `CM_BUILD_NUMBER`
- TestFlight export: `testFlightInternalTestingOnly: true`
- `submit_to_testflight`: true
- `submit_to_app_store`: false

## Internal TestFlight gate
1. 正本AppIcon SHA-256 `c34399358e182a4709f805127fc7244f9763a1f796bb68dfed24b5c4ee815506` をRelease入力として検証する。
2. 210問、ID一意、R7午後33 `all_correct` をRelease前に再検証する。
3. SwiftUI単体テスト、純ネイティブソース監査、Release buildをPASSさせる。
4. CodemagicでApp Store配布署名し、App Store Connect App ID `6799755748` へInternal TestFlightビルドをアップロードする。
5. iPhone実機で起動、4タブ、途中再開、オフライン、JSON、Sandbox購入・キャンセル・保留・復元、購入後解放を確認する。
6. 実機確認PASS後までApp Store本審査へ進めない。

## 禁止
- App Store本審査への自動提出
- 未確認価格の固定表示
- WebView/WKWebViewへ戻すこと
- 仮AppIconでTestFlightへ進むこと
- 実機購入／復元未確認のまま課金を最終PASSとすること
