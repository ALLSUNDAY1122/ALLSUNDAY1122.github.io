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

## 今回のS1実機候補

- Development branch: `scaniverse/s1-capture`
- TestFlight candidate branch: `testflight/s1-capture`
- Device acceptance: `splat-native-ios/S1_DEVICE_ACCEPTANCE.md`
- Integration branchへのmerge: 実機gate PASSまで禁止

## Apple Developer側

Codemagicの`Splat Lab - Apple Bundle ID Bootstrap` workflowは、Bundle IDが存在しない場合に `jp.allsunday1122.splatlab` のExplicit App IDを作成する構成です。

したがって、手作業で先にBundle IDを作る必要はありません。Codemagicが権限不足等で失敗した場合のみ、その失敗内容に応じて人間操作へ切り替えます。

## App Store Connect側で人間が行う登録

新規AppレコードだけはApple側の認証済みUIで作成し、発行された実値を使用します。

入力値:

- Platforms: iOS
- Name: Splat Lab
- Primary Language: Japanese
- Bundle ID: `jp.allsunday1122.splatlab`
- SKU: `splatlab-ios-2026`
- User Access: Full Access（特別に制限する必要がない場合）

作成後に表示されるApple ID（数値）は推測せず、実値をNotion正本とこのパケットへ記録します。

## Appレコード作成後の自動経路

`testflight/s1-capture` ブランチのCodemagic `Splat Lab S1 - Internal TestFlight` workflow:

1. App Store Connect App IDが実値へ更新済みか確認
2. Release入力監査
3. Explicit Bundle ID確認
4. App Store signing files取得/必要時作成
5. signed IPA生成
6. App Store Connectへupload
7. Internal TestFlightへ送信
8. App Store本審査には送信しない

`APP_STORE_CONNECT_APP_ID=PENDING_HUMAN_APP_RECORD` の間はworkflow冒頭で停止し、誤って署名・uploadへ進まない。

## Internal TestFlight後のS1 human-only gate

`splat-native-ios/S1_DEVICE_ACCEPTANCE.md` に沿い、原則1本の画面録画で次を確認する。

- small object全周は完了できる
- 同じobjectを片側だけ撮っても誤合格しない
- room / outdoor sceneが完了できる
- near / farでcaptureが破綻しない
- pause→resume
- stop→resume/add
- background→return
- tracking loss→relocalization
- 90秒/180秒のlong-scan警告
- soft frame limit後も未撮影coverageだけ救済できる
- LiDAR対応端末がある場合はLiDAR ON/OFF

この判断以前にDraft PR #4158をintegration branchへmergeせず、App Store本審査にも提出しない。
