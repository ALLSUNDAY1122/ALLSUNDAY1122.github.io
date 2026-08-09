# 危険物乙4｜Apple Developer / App Store Connect 入力値

更新: 2026-08-09

Notion「申請手順」に従い、本人ログイン・2FA・契約確認以外の判断を事前固定する。

## 1. Apple Developer｜Explicit App ID
- Description: `危険物乙4 学びスプリント`
- App ID type: `Explicit`
- Bundle ID: `jp.allsunday1122.otsu4`
- Platform: iOS
- In-App Purchase: Explicit App IDでは利用する。Xcode側Bundle IDと完全一致させる。

**Bundle IDは登録後にアプリ側都合で変更しない。**

## 2. App Store Connect｜New App
- Platforms: `iOS`
- Name: `危険物乙4｜学びスプリント`
- Primary Language: `Japanese (Japan)`
- Bundle ID: `jp.allsunday1122.otsu4`
- SKU: `otsu4-sprint-ios-001`
- User Access: `Full Access`
- Version: `1.0.0`
- Build: Codemagic側のBuild番号を使用。初回は1以上。
- Primary Category: `Education`
- App Price: `Free`

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

**初回のNon-Consumable IAPは、App version 1.0.0と同じApp Review submissionへ追加する。**

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
- App Store Connect integration name: `codemagic`
- Distribution: `app_store`
- Bundle ID: `jp.allsunday1122.otsu4`
- Internal TestFlight export: `testFlightInternalTestingOnly: true`
- `submit_to_testflight: false`（外部Beta Reviewへ自動提出しない）
- `submit_to_app_store: false`（本審査へ自動提出しない）

秘密鍵、API key、Issuer ID、Key ID、Appleパスワード、2FAコードはGitHub / Notion / チャットへ保存しない。

## 7. TestFlight内部テスト
App Store Connectで内部テストグループを作り、内部用Buildを追加する。
- Group候補: `乙4 内部テスト`
- What to Test:
  `8問スプリント、4/8/16問切替、苦手3連続解除、続きから、模擬試験3回、学習記録、JSONバックアップ、Premium購入・キャンセル・pending・復元・再インストール後の権利復元、文字サイズを確認してください。`

## 8. 人間操作が必要な地点
1. Apple Developer / App Store Connect / Codemagicへの本人ログイン・2FA
2. Paid Apps Agreement・税務・銀行情報の契約確認
3. TestFlightのiPhone実機確認
4. App Store最終提出の承認

それ以外は可能な限り自動検証・CIで完結させる。
