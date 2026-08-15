# App Store Connect record values｜保健師国家試験｜学びスプリント

更新: 2026-08-15

Apple側で新規Appレコードを作成するときの固定入力値。

- Platform: iOS
- Name: `保健師国家試験｜学びスプリント`
- Primary Language: Japanese
- Bundle ID: `jp.allsunday1122.hokenshi`
- SKU: `hokenshi-sprint-13-ios`
- App Store Connect App ID: `6801783499`
- User Access: Full Access
- Version: `1.0.0`
- Distribution: App Store
- TestFlight: Internal Testing only
- App Store本審査自動提出: 禁止

## In-App Purchase
- Type: Non-Consumable
- Reference Name: `保健師国家試験 プレミアム解放`
- Product ID: `jp.allsunday1122.hokenshi.premium`
- Free: 30問（第1回の10分野から各3問）
- Premium: 残り300問と模試機能を解放
- Restore purchases: 必須
- UI price source: StoreKit `Product.displayPrice`
- Price model: 現行標準手順 v2.5 の買い切りモデル（価格標準はv2.4で導入）
- Japan price: `800円`
- 価格文字列をアプリコードへ固定しない。App Store Connectの商品価格を800円基準で設定し、アプリ内はStoreKit取得値だけを表示する。

数値App IDはApple実発行値 `6801783499` を記録済み。Apple ID／パスワード／MFAコード／秘密鍵はこのファイルへ保存しない。
