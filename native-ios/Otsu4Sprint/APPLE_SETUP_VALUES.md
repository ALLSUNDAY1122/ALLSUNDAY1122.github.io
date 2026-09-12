# 危険物乙4｜Apple Developer / App Store Connect / Codemagic 正本値

更新: 2026-08-10

このファイルの識別情報はユーザー指定の正本を転記したもの。外部検索・既存コード・命名規則から変更または補完しない。

## 1. 固定識別情報
- App: `危険物乙4｜学びスプリント`
- Apple Team ID: `MN3D2ZM44N`
- Bundle ID: `jp.allsunday1122.otsu4`
- App Store Connect App ID: `6799755566`
- Codemagic provisioning profile reference: `otsu4_appstore`
- IAP Product ID: `jp.allsunday1122.otsu4.premium`
- iOS Version: `1.0.0`
- Distribution: `App Store`
- TestFlight: `Internal Testing only`

**App Store本審査への自動提出は禁止。**

## 2. Apple Developer / Xcode
- Platform: iOS
- App target Bundle ID: `jp.allsunday1122.otsu4`
- Development Team: `MN3D2ZM44N`
- XcodeGen `project.yml` でも同じ値を使用する
- Bundle IDを別名へ作り直さない
- App Store配布用の署名を使用する

Apple Developer Portal上の登録状態を確認する場合も、上記値を検索・推測で置換しない。

## 3. App Store Connect
対象レコードの正本値:
- App Store Connect App ID: `6799755566`
- Version: `1.0.0`
- Bundle ID: `jp.allsunday1122.otsu4`
- Primary Category: Education
- Sign-in: 不要
- Support URL: `https://allsunday1122.github.io/kikenbutsu-otsu4-sprint/support.html`
- Privacy Policy URL: `https://allsunday1122.github.io/kikenbutsu-otsu4-sprint/privacy.html`
- Export Compliance: `ITSAppUsesNonExemptEncryption = false`

詳細説明・キーワード・Review Notesは `APP_STORE_METADATA_JA.md` を参照する。

## 4. In-App Purchase
- Type: `Non-Consumable`
- Product ID: `jp.allsunday1122.otsu4.premium`
- Display Name (ja-JP): `乙4 プレミアム`
- 購入後: 全360問、模擬試験3回、全範囲の苦手復習等を解放
- アプリ内価格表示: StoreKit 2 `Product.displayPrice` のみ
- コード・説明文へ固定価格を書かない
- pending / userCancelled / unverified / revocationではPremiumを解放しない
- 復元は利用者の明示操作から `AppStore.sync()` を実行する

価格設定はApp Store Connect側を正とし、アプリ内へ金額をハードコードしない。

## 5. App Privacy実装基準
現行設計:
- 独自アカウントなし
- 広告SDKなし
- 解析SDKなし
- 開発者サーバーへの学習履歴送信なし
- 学習履歴・設定・苦手・中断状態は端末内保存
- JSONバックアップは利用者が明示操作してFilesへ書き出し／読み込み
- 決済はStoreKit / App Store

提出直前に `PrivacyInfo.xcprivacy` と実装を再監査し、追加SDK・外部送信の有無に応じてApp Privacy回答を確定する。

## 6. Codemagic
- Workflow: `otsu4-ios`
- App Store Connect integration: `codemagic`
- Provisioning profile reference: `otsu4_appstore`
- Distribution: App Store
- Bundle ID: `jp.allsunday1122.otsu4`
- App Store Connect App ID: `6799755566`
- Team ID: `MN3D2ZM44N`
- Internal-only export: `testFlightInternalTestingOnly: true`
- `submit_to_testflight: false`
- `submit_to_app_store: false`

`otsu4_appstore` を個別Reference nameで取得する設定を使用する。対応するApple Distribution証明書のReference nameはこの正本に未記載のため、推測して追加しない。署名付きIPA工程でCodemagic上の実在する証明書設定を確認するまでRelease blockerとして扱う。

秘密鍵、API key、Issuer ID、Key ID、証明書パスワード、2FAコードはGitHub / Notion / チャットへ保存しない。

## 7. App Icon
学びスプリント申請手順に従い、採用済み個別PNGを使用する。
- Google Drive正本ファイル: `01_危険物取扱者_乙種4類.png`
- Drive file ID: `10B_svZxlg80KfV61atBj4_sBkMTndFwS`
- 1024 × 1024 / RGB / no alpha
- SHA-256: `d0cb19b237ca3306413c481e4fbc0fb871705b390a1bc37619d9683fff19ff2d`

似たアイコンの自動生成物をApp Store用アイコンとして完成扱いしない。

## 8. TestFlight内部テスト
Internal Testing only。最低限:
- 起動
- 標準8問
- 4 / 8 / 16問切替
- `わからない`
- 苦手登録と3連続正解解除
- 中断／続きから
- 模擬試験3回、35問・120分
- 記録／5週間ヒートマップ
- JSONバックアップ／復元
- Premium購入成功
- 購入キャンセル
- pending
- 復元
- 再インストール後のentitlement
- 大きい文字
- 横スクロールなし
- VoiceOver

## 9. STOP条件
ユーザーの明示承認前に行わない。
- App Store本審査への提出
- `submit_to_app_store: true` への変更
- Bundle ID / App Store Connect App ID / IAP Product ID / Codemagic profileの変更
- Internal Testing以外への勝手な配布変更
