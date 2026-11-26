# App Store Connect 作成パケット｜園プリント見落としガード

このパケットは、Apple側の新規Appレコード作成に必要な固定値です。数値App IDはApple発行値のため、作成前に推測・記入しません。

| 項目 | 入力値 |
|---|---|
| App Name | 園プリント見落としガード |
| Platform | iOS |
| Primary Language | Japanese |
| Bundle ID | jp.allsunday1122.enprintguard |
| SKU | enprintguard-ios-20261127-01 |
| Distribution | Internal TestFlight only |
| Marketing Version | 1.0.0 |
| Build | 1 |
| Monthly Product ID | jp.allsunday1122.enprintguard.premium.monthly |
| Annual Product ID | jp.allsunday1122.enprintguard.premium.annual |

## Apple側での作業

1. Apple DeveloperのIdentifiersで、Bundle ID `jp.allsunday1122.enprintguard` が登録済みであることを確認する。未登録なら、PR統合後の専用ワークフローがAPIで登録・read-backする。
2. App Store Connect > Apps > ＋ > New Appを開く。
3. 上表のApp Name、Primary Language、Bundle ID、SKUを入力し、iOSを選択して作成する。
4. 作成後はこのファイルへ数値App IDを手入力せず、Bundle IDからApp Store Connect APIでread-backして正本化する。

## 禁止事項

- App Store Connect App IDを推測しない。
- App Store本審査への提出・公開を行わない。
- TestFlightはInternal Testingのみ。
- Codemagicの `submit_to_app_store` は必ず `false`。
- App Store Connectのアプリレコード作成以外の契約・税務・支払い変更は行わない。
