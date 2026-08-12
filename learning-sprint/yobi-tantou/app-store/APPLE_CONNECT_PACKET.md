# Apple Connect Packet｜司法試験予備試験・短答式｜学びスプリント

更新: 2026-08-13
状態: `DRAFT / IDENTIFIERS BLOCKED`

## アプリ

- App名案: `予備試験 短答｜学びスプリント`
- Version: `1.0.0`
- Build: CI配布時に確定
- Bundle ID: `要確認`
- App Store Connect App ID: `要確認`
- SKU: `要確認`
- Apple Team ID: 共通正本に登録済みの値を署名工程で再取得する。ここへ複製固定しない。
- Distribution: App Store
- TestFlight: Internal Testing only

## IAP

- Premium方式: Non-Consumable買い切り予定
- Product ID: `要確認`
- 価格: `要確認` / App Store Connectで設定
- アプリ内価格表示: StoreKit 2 `displayPrice`
- 無料範囲: 最初の1スプリント最大8問
- Purchase: StoreKit 2
- Restore: `AppStore.sync()`
- Entitlement: verified transaction + product ID一致 + revocationなし

## URL

- Support: `https://allsunday1122.github.io/learning-sprint/yobi-tantou/support/`
- Privacy: `https://allsunday1122.github.io/learning-sprint/yobi-tantou/privacy/`

## App Privacy実装正本

- Tracking: false
- Collected Data Types: none
- UserDefaults required-reason API: `CA92.1`
- 広告SDK: なし
- 分析SDK: なし
- アカウント: なし
- 独自クラウド同期: なし

## AppIcon正本

- Drive file: `11_司法試験予備試験_短答式.png`
- Drive file ID: `1EyeJxBN2WPEjEw9TUszhmyhuk3_3Lu6K`
- Size: 1024×1024
- SHA-256: `c56c3f0acf7e05ec6096fdee881081b7b7e8e863ae2933b496550e902b840bf9`
- Releaseビルド時にDriveから取得しSHA一致を必須とする。

## 教材Release条件

- R6-R8正式構成・正答・配点を一次資料PDFで確定
- R7誤記訂正の影響反映
- 一般教養等の第三者権利監査
- canonical問題バンク完成
- 重複・高類似・正答・法令基準日・根拠・権利の全監査PASS
- Native `questions.release.json` 生成

## Codemagic方針

Bundle ID・App Store Connect App ID・IAP Product ID・署名profileが正本で明示されるまでactive workflowを作成しない。

本番値確定後は次を満たす。
- App Store Connect integrationを使用
- distribution type: app_store
- canonical AppIcon SHA検証
- release preflight PASS
- XcodeGenで本番Bundle ID注入
- Internal TestFlight onlyのexport options
- signed IPAを生成
- App Store本審査へ自動提出しない

## 現在のハードゲート

`ios/release-preflight.py` は次が全て揃うまでPASSしない。
1. `YOBI_BUNDLE_ID`
2. `YOBI_APP_STORE_CONNECT_APP_ID`
3. `YOBI_IAP_PRODUCT_ID`
4. canonical AppIcon lock
5. canonical `questions.release.json`

CI用ID、preview ID、`UNSET`、ビルド変数文字列は拒否する。

## 禁止

- 推測したBundle ID / App ID / Product IDでApp Store Connectを作らない。
- 固定価格をコード／審査原稿へ書かない。
- 正式教材未完成のまま署名IPAを作らない。
- External Beta App Review／App Store本審査をユーザー承認前に実行しない。
