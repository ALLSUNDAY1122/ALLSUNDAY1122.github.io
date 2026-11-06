# Apple Connect Packet｜司法試験予備試験・短答式｜学びスプリント

更新: 2026-08-14
状態: `DRAFT / ASC ISSUED VALUES PENDING`

## アプリ

- App名案: `予備試験 短答｜学びスプリント`
- Version: `1.0.0`
- Build: CI配布時に確定
- Bundle ID: `jp.allsunday1122.yobishikentantou`（標準手順v2.4によりChatGPTが確定）
- App Store Connect Apple ID: 実発行値待ち
- SKU: App Store Connect作成時に正本化
- Apple Team ID: 共通正本に登録済みの値を署名工程で再取得する。ここへ複製固定しない。
- Distribution: App Store
- TestFlight: Internal Testing only

## IAP

- Premium方式: Auto-Renewable Subscription（月額）
- 日本向け基準価格: 200円/月
- planned Product ID: `jp.allsunday1122.yobishikentantou.monthly`
- runtime Product ID: App Store Connectへplanned IDを実登録し、商品取得確認するまで空値
- 商品種別: `.autoRenewable` のみ受理
- アプリ内価格表示: StoreKit 2 `displayPrice` のみ
- 無料範囲: 最初の1スプリント最大8問。Subscription Free Trialではない
- Purchase: StoreKit 2
- Restore: `AppStore.sync()`
- Entitlement: verified transaction + product ID一致 + revocationなし + current entitlement

## URL

- Support: `https://allsunday1122.github.io/learning-sprint/yobi-tantou/support/`
- Privacy: `https://allsunday1122.github.io/learning-sprint/yobi-tantou/privacy/`
- 早期試用URLゲート: 本アプリは純SwiftUIネイティブでブラウザ実行可能な初期試作を持たないため、GitHub PagesのSupport/Privacyをアプリ試用URLとは扱わない。実機試用はInternal TestFlightで行う。

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

- 独自模試3回分を現行R8構成で各回139題、合計417題まで完成
- 法律285問は一次法令・正答・基準日・誤答理由を全件監査
- 一般教養132題は独自作問または権利根拠を明示できる素材だけを使用
- 重複・高類似・正答・法令基準日・根拠・権利の全監査PASS
- mock-bank正本からNative正式バンクへ専用統合監査後に反映

現在の正式監査済み総数は84/417。公式年度問題本文の再録は別権利ゲートでロックを維持する。

## Codemagic方針

Bundle IDは確定済み。App Store Connect Apple ID実発行値、IAP実登録一致、署名profileが正本で確認されるまでactive production signing workflowを作成しない。

実値確定後は次を満たす。
- App Store Connect integrationを使用
- distribution type: app_store
- canonical AppIcon SHA検証
- release preflight PASS
- XcodeGenでcanonical Bundle IDを使用
- IAP Product IDはApp Store Connect実登録値と一致
- Internal TestFlight onlyのexport options
- signed IPAを生成
- App Store本審査へ自動提出しない

## 現在のハードゲート

`ios/release-preflight.py` は次が全て揃うまでPASSしない。
1. canonical `YOBI_BUNDLE_ID = jp.allsunday1122.yobishikentantou`
2. App Store Connect Apple IDの実発行値
3. App Store Connectに実登録済みの月額Product ID
4. canonical AppIcon lock
5. 正式3回分完成監査PASS
6. canonical Native release bank

CI用ID、preview ID、`UNSET`、ビルド変数文字列は本番値として拒否する。

## 禁止

- App Store Connect Apple IDを推測しない。
- planned Product IDを実登録確認なしに「登録済み」と扱わない。
- 価格文字列をアプリコードへ固定しない。
- 正式3回分未完成のまま署名IPAを作らない。
- External Beta App Review／App Store本審査をユーザー承認前に実行しない。
