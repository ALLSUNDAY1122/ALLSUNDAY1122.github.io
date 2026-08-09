# App Store Connect / TestFlight 接続パケット

## App record
- Name: `司法書士 学びスプリント`
- Bundle ID: `jp.allsunday1122.shoshi`
- SKU: `shoshi-sprint-ios`
- Version: `1.0.0`
- Platform: iOS
- Availability: Japan first

## In-App Purchase
- Product ID: `jp.allsunday1122.shoshi.premium`
- Type: Non-Consumable
- Reference Name: `司法書士 学びスプリント プレミアム`
- Display Name: `プレミアム解放`
- Price: App Store Connectで正式価格を設定（コードへ固定しない）

## Public URLs
- Support: https://allsunday1122.github.io/learning-sprint/shoshi/support/
- Privacy: https://allsunday1122.github.io/learning-sprint/shoshi/privacy/
- Web prototype: https://allsunday1122.github.io/learning-sprint/shoshi/mvp/

## Build
- Xcode project: `learning-sprint/shoshi/ios/ShoshiSprint.xcodeproj`
- Scheme: `ShoshiSprint`
- Minimum iOS: 16.0
- Orientation: iPhone portrait
- Signing: Automatic / App Store distribution
- CI build number: `CM_BUILD_NUMBER`
- TestFlight export: `testFlightInternalTestingOnly: true`
- `submit_to_testflight`: false
- `submit_to_app_store`: false

## Human-only external gates
1. App Store Connectで新規Appレコードを作成する。
2. Non-Consumable IAPを作成し正式価格を設定する。
3. CodemagicのApp Store Connect integrationでBundle IDの証明書・プロファイルを取得できることを確認する。
4. 署名済みIPAをApp Store Connectへアップロードし、処理完了を確認する。
5. 内部TestFlightでiPhoneへインストールする。
6. Sandboxで購入成功、購入キャンセル、購入保留、復元を実機確認する。
7. 実機確認PASS後のみApp Store提出準備へ進む。

## 禁止
- App Storeへの自動提出
- Beta App Reviewへの自動提出
- 未確認価格の固定表示
- 実機購入／復元未確認のまま「課金PASS」とすること
