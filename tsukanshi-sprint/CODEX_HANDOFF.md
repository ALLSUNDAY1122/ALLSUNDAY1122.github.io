# 通関士｜学びスプリント CODEX HANDOFF 正本

更新日: 2026-08-09 22:47 JST

このファイルは、Notion「申請手順」の定義どおり、Codexがこのアプリを引き継ぐ際に最初に読む正本です。

## 0. 正本の優先順位

1. この `CODEX_HANDOFF.md` — 現在地・再開手順・停止点
2. `RELEASE_STATUS.md` / `RELEASE_CHECKLIST.md` — リリース状態と未完了チェック
3. `APP_STORE_METADATA_JA.md` / `APPLE_CONNECT_PACKET.md` / `APP_REVIEW_NOTES_JA.md`
4. `codemagic.yaml` / `ios/project.yml` / `ios/App.swift`
5. GitHub `main` の実装
6. Notion「通関士｜学びスプリント」— アプリ開発台帳の状態・次の作業

共通UI・申請手順・法律対応についてはNotion正本を優先する。

- 通関士開発正本: https://app.notion.com/p/3b609c10697d817588d7ef5e8de23343?pvs=204
- 学びスプリント UI Master v2.1: https://app.notion.com/p/3b609c10697d81f0b3d0f78d160a819f?pvs=204
- 申請手順: https://app.notion.com/p/3b009c10697d81eba325f86d8af55481?pvs=204
- 法律対応: https://app.notion.com/p/3b509c10697d81b58723ca46328f07dc?pvs=204

## 1. リポジトリ

- Repository: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- App folder: `tsukanshi-sprint/`
- Public test URL: https://allsunday1122.github.io/tsukanshi-sprint/
- PR #4101 merged to `main`
- PR #4101 merge SHA: `5df09e2e1fada3a1a0328e8fe551b403cb0c5d02`

引継ぎ開始時に必ず最新 `main` を取得し、このSHA以降に変更がある場合は最新 `RELEASE_STATUS.md` と直近PRを確認してから進める。過去チャットの進捗値をGitHubより優先しない。

## 2. 固定識別子

- App name: `通関士｜学びスプリント`
- Platform: iOS
- Primary language: Japanese
- Bundle ID: `jp.allsunday1122.tsukanshi`
- Version: `1.0.0`
- SKU: `tsukanshi-sprint-ios`
- IAP type: Non-Consumable
- IAP Product ID: `jp.allsunday1122.tsukanshi.premium`
- IAP reference name: `通関士 プレミアム解放`
- IAP display name: `プレミアム解放`
- iOS minimum: 16.0
- Native architecture: SwiftUI + WKWebView + StoreKit 2
- Build route: XcodeGen → Capability正規化 → Codemagic

Bundle ID、SKU、Product IDを独断で変更しない。

## 3. 現在地

**ASC/TestFlightコードゲート完了。現在の最初の外部停止点は、Apple DeveloperでExplicit App IDを登録すること。**

2026-08-09、ユーザーがApp Store Connectの「新規アプリ」画面を開いたところ、Bundle ID欄に選択肢が表示されなかった。

したがって、App Store ConnectのAppレコード作成より前に次を完了する必要がある。

1. Apple Developer → Certificates, Identifiers & Profiles
2. Identifiers → `+`
3. App IDs → App
4. Explicit App ID
5. Description: `通関士 学びスプリント`
6. Bundle ID: `jp.allsunday1122.tsukanshi`
7. Register
8. App Store Connectの新規アプリ画面を開き直す
9. Bundle ID欄に `jp.allsunday1122.tsukanshi` が出ることを確認

もし登録時に「既に使用済み」と出る場合は、新規作成せずIdentifiers一覧で既存IDを検索し、同じBundle IDが自分のTeamに存在するか確認する。

App Store Connectの新規アプリ作成時:

- Platform: iOS
- Name: `通関士｜学びスプリント`
- Primary Language: Japanese
- Bundle ID: `jp.allsunday1122.tsukanshi`
- SKU: `tsukanshi-sprint-ios`
- User Access: アクセス制限なし / Full Access

## 4. App Store Connect App作成後の順番

1. App Store Connect Appレコード作成
2. App Store Connect App IDを `RELEASE_STATUS.md` とNotionへ記録
3. Non-Consumable IAPを作成
   - Product ID: `jp.allsunday1122.tsukanshi.premium`
   - Reference Name: `通関士 プレミアム解放`
   - Display Name: `プレミアム解放`
4. 正式価格をユーザーと確定しApp Store Connectへ設定
5. Paid Apps Agreement / 税務 / 銀行情報の状態確認
6. Codemagic App Store Connect integrationを確認
7. signed IPA生成
8. App Store Connectへアップロード
9. 内部TestFlightへ配布
10. iPhone実機で主要導線＋Sandbox購入・復元を確認
11. スクリーンショット、App Privacy、年齢、Content Rights、Review情報を完成
12. ユーザーの最終確認後のみApp Store本審査へ提出

## 5. 絶対に再実行しない作業

変更がない限り、以下は完了済みなので最初からやり直さない。

- 通常学習480問の二次編集監査
- 申告書12セットの二次編集監査
- 第59〜57回の過去問権利監査
- UI Master v2.1移行
- Privacy Manifest作成
- App Store原稿作成
- StoreKit 2購入・復元実装
- `Transaction.currentEntitlements`
- `Transaction.updates`
- `AppStore.sync()`
- Web試用版で未確定価格を表示しないガード
- iPhone Simulator Release build
- 実`.app`資産検査
- 教材CI 480＋12
- Apple preflight CI
- ASC/TestFlightコードゲート

コード・教材を変更した場合のみ対応する品質ループを再実行する。

## 6. 重要な実装上の注意

XcodeGen 2.46.0では、ネストした`TargetAttributes/SystemCapabilities`指定が文字列として生成される問題を実CIで検出済み。

そのため、`xcodegen generate` 後に必ず:

`tsukanshi-sprint/ios/apply-xcode-capabilities.py`

を実行し、生成された `TsukanshiSprint.xcodeproj/project.pbxproj` に `com.apple.InAppPurchase` / `enabled = 1;` が正規形で存在することを確認する。

GitHub ActionsとCodemagicにはこの工程を組み込み済み。削除しない。

課金価格はコードへ固定しない。ネイティブ版はStoreKitの`displayPrice`を正本とする。正式価格未取得時に仮価格を表示しない。

## 7. Codemagic安全ルール

workflow: `tsukanshi-ios`

- distribution type: `app_store`
- bundle identifier: `jp.allsunday1122.tsukanshi`
- `testFlightInternalTestingOnly` を維持
- `submit_to_app_store: false` を必ず維持
- Apple側Appレコード・署名連携が確認できるまでは配布設定を不用意に変えない
- App Store本審査を自動提出しない

Appleのパスワード、2FAコード、API Key、Issuer ID、Key ID、`.p8`、証明書秘密鍵等をGitHub・Notion・チャットへ保存しない。

## 8. コンテンツ・権利

- 通常学習: 480問
- 申告書演習: 12セット
- 合計: 492
- 法令基準日: 2026-07-01
- 公式過去問本文はアプリへ同梱しない
- 税関公式問題は外部リンク
- WCO由来の説明資料・Explanatory Notes等を転載しない
- 税関ロゴ・カスタム君を使用しない

既存問題を水増し目的で複製・言い換え追加しない。

## 9. 実機で未確認の項目

以下はまだ完了扱いにしない。

- Apple Developer Explicit App ID登録
- App Store Connect Appレコード
- App Store Connect App ID記録
- IAP正式商品作成・価格
- Codemagic signed IPA
- App Store ConnectへのBuild upload
- 内部TestFlight処理
- iPhone TestFlight版起動
- StoreKit正式価格取得
- Sandbox購入
- 再起動後Premium維持
- 購入復元
- App Store用iPhoneスクリーンショット
- App Privacy / 年齢 / Content Rights最終回答
- `Add for Review` / `Submit for Review`

## 10. 人の操作が必要な箇所

ユーザーに依頼してよいのは主に次だけ。

- Appleログイン / 2FA
- Apple DeveloperのExplicit App ID登録画面での最終Register
- App Store Connectの新規App作成
- IAP正式価格決定
- Paid Apps Agreement / 税務 / 銀行情報
- Codemagicの秘密情報・Apple接続
- TestFlight実機確認
- 本審査提出直前の最終承認

それ以外は可能な限りCodex側で進める。

## 11. 再開指示

Codexはこのファイルを読んだ後、`RELEASE_STATUS.md`、`RELEASE_CHECKLIST.md`、`APPLE_CONNECT_PACKET.md`、`APP_STORE_METADATA_JA.md`、`APP_REVIEW_NOTES_JA.md`、`codemagic.yaml` を確認する。

そのうえで、ユーザーがExplicit App ID登録を終えていなければ、Apple Developer画面で `jp.allsunday1122.tsukanshi` を登録する最短操作だけ案内する。登録済みならApp Store ConnectのAppレコード作成確認から続行する。

**過去工程を最初からやり直さず、現在の停止点から継続すること。**
