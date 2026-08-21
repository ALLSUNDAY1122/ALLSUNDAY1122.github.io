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

## Apple Developer側｜完了

2026-08-21、Apple公式App Store Connect APIで事前検索し、`jp.allsunday1122.splatlab` が0件であることを確認後にBundle IDを1件だけ登録しました。

read-back実値:

- Bundle ID resource ID: `6AWU9TD858`
- Name: `Splat Lab Native`
- Identifier: `jp.allsunday1122.splatlab`
- Platform: `UNIVERSAL`
- Team seed ID: `MN3D2ZM44N`

再実行時は `already_exists` / `changed=false` でread-back PASS。二重登録はありません。

Codemagic bootstrap build `6a87c9a258fd97265845cf1e` は実行マシン割当前にfailedしたため重複Buildは行わず、Apple公式APIのidempotent ensureへ切り替えました。Bundle ID作成自体は完了しています。

## App Store Connect側で人間が行う登録｜現在の停止点

Appleの現行App Store Connect運用に従い、新規AppレコードだけはWeb UIの `Apps` → `+` → `New App` から1件作成します。

入力値:

- Platforms: iOS
- Name: Splat Lab
- Primary Language: Japanese
- Bundle ID: `jp.allsunday1122.splatlab`
- SKU: `splatlab-ios-2026`
- User Access: Full Access（特別に制限する必要がない場合）

作成後に発行されるApple ID（数値）は推測せず、Bundle IDからAPIで対象Appを再取得し、実値をNotion正本とこのパケットへ記録します。候補が複数で一意に決まらない場合だけ人間確認へ戻します。

## Appレコード作成後の自動経路

`testflight/splat-native-ios-20260820` ブランチを配布候補として使用します。

1. Bundle IDからApp Store Connect App IDをAPI read-back
2. `APP_STORE_CONNECT_APP_ID=PENDING_HUMAN_APP_RECORD` を実発行Apple IDへ更新
3. Release入力監査
4. signing設定・証明書／profile取得または作成
5. signed IPA生成
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
