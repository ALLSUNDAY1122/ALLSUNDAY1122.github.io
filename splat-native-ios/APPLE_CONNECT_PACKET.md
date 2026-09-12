# Splat Lab｜Apple Developer / App Store Connect 登録パケット

更新日: 2026-08-15

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

## Apple Developer側

CodemagicのTestFlight workflowは、Bundle IDが存在しない場合に `jp.allsunday1122.splatlab` のExplicit App IDを作成し、App Store配布用の署名ファイルを取得・生成する構成です。

したがって、手作業で先にBundle IDを作る必要はありません。Codemagicが権限不足等で失敗した場合のみ、その失敗内容に応じて人間操作へ切り替えます。

## App Store Connect側で人間が行う登録

App Store Connect APIでは新規Appレコードを作成できないため、新規AppレコードだけはWeb UIで作成します。

入力値:

- Platforms: iOS
- Name: Splat Lab
- Primary Language: Japanese
- Bundle ID: `jp.allsunday1122.splatlab`
- SKU: `splatlab-ios-2026`
- User Access: Full Access（特別に制限する必要がない場合）

作成後に発行されるApple ID（数値）は推測せず、実値をNotion正本とこのパケットへ記録します。

## Appレコード作成後の自動経路

`testflight/splat-native-ios` ブランチのCodemagic workflow:

1. Release入力監査
2. Explicit Bundle ID確認/必要時作成
3. App Store signing files取得/必要時作成
4. signed IPA生成
5. App Store Connectへupload
6. Internal TestFlightへ送信
7. App Store本審査には送信しない

## Internal TestFlight後に必要な人間判断

実機で中心経路を確認し、次のどれかを判断します。

- PASS: 立体の思い出として十分識別できる → おもちゃばこMVPへ進む
- CONDITIONAL: 生成可能だが品質・速度・熱に課題 → パラメータ/撮影方法を改善し再試験
- FAIL: オンデバイス方式が実用品質に届かない → 方式再設計

この判断以前にApp Store本審査へ提出しません。
