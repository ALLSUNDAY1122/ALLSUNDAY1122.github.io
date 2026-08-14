# App Store Connect record values｜保健師国家試験｜学びスプリント

更新: 2026-08-14

Apple側で新規Appレコードを作成するときの固定入力値。

- Platform: iOS
- Name: `保健師国家試験｜学びスプリント`
- Primary Language: Japanese
- Bundle ID: `jp.allsunday1122.hokenshi`
- SKU: `hokenshi-sprint-13-ios`
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
- Price: App Store本審査前の最終承認地点で確定

## 未取得
- App Store Connect App ID: 新規Appレコード作成後にAppleが発行した実値だけを記録する。

数値App IDの仮値は置かない。Apple ID／パスワード／MFAコード／秘密鍵はこのファイルへ保存しない。
