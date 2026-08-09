# 危険物乙4｜Apple Developer / App Store Connect 入力値

更新: 2026-08-10

Notion「申請手順」とユーザー指定の対象アプリ識別情報正本に従う。
外部検索、推測、過去記録でBundle ID / App Store Connect App ID / Codemagic profile / IAPを変更しない。

共通正本:
- Notion: https://app.notion.com/p/3b709c10697d8138a352c422d4dd5c47
- GitHub mirror: `docs/APP_STORE_IDENTIFIERS_CANONICAL.md`

## 0. 固定識別情報
- Apple Team ID: `MN3D2ZM44N`
- App Store Connect App ID: `6799755566`
- Bundle ID: `jp.allsunday1122.otsu4`
- Codemagic profile: `otsu4_appstore`
- IAP Product ID: `jp.allsunday1122.otsu4.premium`
- iOS Version: `1.0.0`
- Distribution: `App Store`
- TestFlight: `Internal Testing only`
- App Store本審査への自動提出は禁止

## 1. Apple Developer｜Explicit App ID
- Description: `危険物乙4 学びスプリント`
- App ID type: `Explicit`
- Bundle ID: `jp.allsunday1122.otsu4`
- Platform: iOS
- In-App Purchase: 利用する

**Bundle IDは変更しない。**

## 2. App Store Connect｜既存アプリ正本
- App Store Connect App ID: `6799755566`
- Platforms: `iOS`
- Name: `危険物乙4｜学びスプリント`
- Primary Language: `Japanese (Japan)`
- Bundle ID: `jp.allsunday1122.otsu4`
- SKU: `otsu4-sprint-ios-001`
- User Access: `Full Access`
- Version: `1.0.0`
- Build: Codemagic側のBuild番号を使用
- Primary Category: `Education`
- App Price: `Free`

App Store Connect App IDは既に正本値があるため、検索や推測で別IDへ置換しない。

## 3. App Store表示
- Subtitle: `8問ずつ、合格力を積み上げる`
- Support URL: `https://allsunday1122.github.io/kikenbutsu-otsu4-sprint/support.html`
- Privacy Policy URL: `https://allsunday1122.github.io/kikenbutsu-otsu4-sprint/privacy.html`
- Copyright: App Store Connect登録時の開発者名義に合わせる
- Sign-in: 不要
- Export Compliance: `ITSAppUsesNonExemptEncryption = false` をInfo.plistへ設定済み

詳細説明・キーワード・Review Notesは `APP_STORE_METADATA_JA.md` を正本とする。

## 4. In-App Purchase
### 商品
- Type: `Non-Consumable`
- Reference Name: `乙4 プレミアム 買い切り`
- Product ID: `jp.allsunday1122.otsu4.premium`
- Display Name (ja-JP): `乙4 プレミアム`
- Description (ja-JP): `独自360問・模擬試験3回・全範囲の苦手復習を解放`
- Availability: 初回はアプリ提供地域と一致させる
- Base Country/Region: `Japan`
- Price: App Store Connectで最終設定し、アプリ内ではStoreKit `displayPrice`のみ表示する
- 開発上の価格候補: `¥980`。本審査前にユーザー最終確認可能。

### App Review Information
- Review Notes:
  `設定タブの「360問・模試3回を解放」から購入画面を表示できます。購入後は全360問、35問×3回の模擬試験、全範囲の苦手復習が利用可能です。「購入を復元」は設定画面と購入画面から実行できます。ログインは不要です。`
- App Review Screenshot: TestFlight実機で購入画面を表示したスクリーンショットを最終登録する

## 5. App Privacy候補
現行実装:
- 独自アカウントなし
- 広告SDKなし
- 解析SDKなし
- 開発者サーバーへの学習履歴送信なし
- 学習履歴・設定・苦手・中断状態は端末内UserDefaults
- JSONバックアップは利用者が明示操作してFilesへ書き出し／読み込み
- 決済はStoreKit / App Store

提出候補: `Data Not Collected`

提出直前に実装と再照合し、第三者SDKや外部通信が追加されていないことを再監査する。

## 6. Codemagic
- Workflow: `otsu4-ios`
- Codemagic署名profile: `otsu4_appstore`
- Distribution: `app_store`
- Bundle ID: `jp.allsunday1122.otsu4`
- Apple Team ID: `MN3D2ZM44N`
- Internal TestFlight export: `testFlightInternalTestingOnly: true`
- Beta App Reviewへの自動提出は禁止
- App Store本審査への自動提出は禁止

`otsu4_appstore` 以外のprofile名へ推測で変更しない。
秘密鍵、API key、Issuer ID、Key ID、Appleパスワード、2FAコードはGitHub / Notion / チャットへ保存しない。

## 7. TestFlight内部テスト
Internal Testing only。
- Group候補: `乙4 内部テスト`
- What to Test:
  `8問スプリント、4/8/16問切替、苦手3連続解除、続きから、模擬試験3回、学習記録、JSONバックアップ、Premium購入・キャンセル・pending・復元・再インストール後の権利復元、文字サイズを確認してください。`

## 8. 人間操作が必要な地点
1. Apple Developer / App Store Connect / Codemagicへの本人ログイン・2FA
2. Paid Apps Agreement・税務・銀行情報の契約確認
3. TestFlightのiPhone実機確認
4. App Store最終提出の承認

それ以外は可能な限り自動検証・CIで完結させる。
