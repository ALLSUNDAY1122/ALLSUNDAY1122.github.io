# Splat Lab｜Apple Developer / App Store Connect 登録パケット

更新日: 2026-08-21

## 固定値

- App name: `Splat Lab`
- Platform: iOS
- Primary language: Japanese
- Bundle ID: `jp.allsunday1122.splatlab`
- SKU: `splatlab-ios-2026`
- Version: `1.0.0`
- Team ID: `MN3D2ZM44N`
- Distribution: App Store
- TestFlight: Internal Testing only
- App Store review auto-submit: disabled

## Apple Developer側｜Bundle ID完了

2026-08-21、Apple公式App Store Connect APIで事前検索し、`jp.allsunday1122.splatlab` が0件であることを確認後にBundle IDを1件だけ登録しました。

read-back実値:

- Bundle ID resource ID: `6AWU9TD858`
- Name: `Splat Lab Native`
- Identifier: `jp.allsunday1122.splatlab`
- Platform: `UNIVERSAL`
- Team seed ID: `MN3D2ZM44N`

再実行時は `already_exists` / `changed=false` でread-back PASS。二重登録はありません。

## App Store Connect Appレコード｜完了

2026-08-21、人間Gateで新規Appレコードを作成後、App Store Connect APIで全Appsをread-backし、次の1件がBundle ID / name / SKU / localeまで一致することを確認しました。

- App Store Connect Apple ID: `6803778932`
- Name: `Splat Lab`
- Bundle ID: `jp.allsunday1122.splatlab`
- SKU: `splatlab-ios-2026`
- Primary locale: `ja`

このApple IDはApple実発行値であり、推測値ではありません。

## Apple signing｜profile作成完了

2026-08-21、Apple側の既存Distribution certificateをread-only監査し、秘密鍵がCodemagic secure variableとして管理されている証明書を再利用しました。新規certificate作成・既存certificate失効は行っていません。

- Distribution certificate ID: `K2A3VCP583`
- Codemagic secure group: `app2_010_touhan_signing`
- secure variable: `CERTIFICATE_PRIVATE_KEY`（値は取得・記録しない）
- Splat App Store profile name: `splatlab_appstore`
- Splat App Store profile ID: `P4927U2ZPC`
- Profile type: `IOS_APP_STORE`
- Profile state: `ACTIVE`
- Profile expiration: `2027-08-19T10:50:12.000+00:00`
- Bundle relationship: `6AWU9TD858` / `jp.allsunday1122.splatlab`
- Certificate relationship: `K2A3VCP583`

profileは事前在庫0件を確認後に1件だけ作成し、profile本体・Bundle ID・certificate relationshipをread-backしてPASSしています。

## Appレコード作成後の自動経路｜進行中

`testflight/splat-native-ios-20260820` ブランチを配布候補として使用します。

1. Bundle IDからApp Store Connect App IDをAPI read-back → **PASS (`6803778932`)**
2. `APP_STORE_CONNECT_APP_ID` を実発行Apple IDへ更新 → **PASS**
3. Release入力監査 → **PASS**
4. signing設定・証明書／profile → **PASS (`K2A3VCP583` / `P4927U2ZPC`)**
5. signed IPA生成 → 進行中
6. App Store Connectへupload
7. processing確認
8. Internal TestFlightへ送信
9. Internal TestFlight実機受入
10. App Store本審査には自動送信しない

## Internal TestFlight後に必要な人間判断

実機で中心経路を確認し、次のどれかを判断します。

- PASS: Scaniverse同等化の代表フローと品質Gateを満たす → 残Parity Gateへ進む
- CONDITIONAL: 生成可能だが品質・速度・熱・復旧に課題 → パラメータ／実装を改善し再試験
- FAIL: オンデバイス方式が実用品質に届かない → 方式再設計

Scaniverse同等化が完了する前におもちゃばこ固有MVPへ進めません。また、この判断以前にApp Store本審査へ提出しません。
