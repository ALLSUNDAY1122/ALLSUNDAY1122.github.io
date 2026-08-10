# RELEASE STATUS｜薬剤師国家試験｜学びスプリント

更新：2026-08-10 18:12 JST
担当：ChatGPT
GitHub正本：`main`

## 対象アプリ

- 資格名：薬剤師国家試験｜学びスプリント
- Bundle ID：`jp.allsunday1122.yakuzaishi`
- App Store Connect App ID：`6799753724`
- Version：`1.0.0`
- Build番号：`1`（GitHub正本 `pharmacist-manabi-sprint/ios/project.yml` の `CURRENT_PROJECT_VERSION`）。ただし Codemagic 署名ビルド時は `CM_BUILD_NUMBER` に置換するため、**実際にTestFlightへ送るBuild番号はCodemagic未実行の現時点では未確定**。
- Codemagic workflow：`pharmacist-ios`
- Codemagic署名プロファイル正本名：`yakuzaishi_appstore`
- Codemagic App Store Connect integration：`codemagic`
- 本審査：未提出。`submit_to_app_store: false` を維持。

## 実績ステータス

| 項目 | 判定 | 証跡 |
|---|---|---|
| Notion正本照合 | PASS | 標準手順 v2.2 `https://app.notion.com/p/3a909c10697d81e0961bd0fd27a77d39`、申請手順 `https://app.notion.com/p/3b009c10697d81eba325f86d8af55481`、薬剤師正本 `https://app.notion.com/p/3b609c10697d81c6b58dd0935d581b7d` を2026-08-10再取得・照合。 |
| UI要件照合 | PASS | UI Golden Master v2.1 `https://app.notion.com/p/3b609c10697d81f0b3d0f78d160a819f`。実装：`pharmacist-manabi-sprint/ios/Theme.swift`、`RootAndHomeViews.swift`、`QuizViews.swift`、`HistorySettingsViews.swift`。最終再監査：Actions run `31363872501` PASS。 |
| ネイティブ実装 | PASS | `pharmacist-manabi-sprint/ios/App.swift` は `RootView` を直接起動し、学習ランタイムに `WKWebView` / `import WebKit` なし。PR #4128 `https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/pull/4128`、merge commit `97d8a71617f7ace4ad39a23ffbe8c7aef5619600`。 |
| データ監査 | PASS | `pharmacist-manabi-sprint/content/product/final-audit-v2.json`：1,035問、blocked 0、解説1,035/1,035、未解決高類似0、生成水増し0、`finalPass:true`。`scripts/validate_release.py`、Actions run `31363872501` PASS。 |
| StoreKit 2 | PASS | 実装：`pharmacist-manabi-sprint/ios/StoreKitManager.swift`、`MockPaywallViews.swift`。`Transaction.currentEntitlements`、`Transaction.updates`、`AppStore.sync()`、`Product.displayPrice`、月額/買い切り商品IDを `scripts/validate_release.py` で監査。Actions run `31363872501` PASS。※App Store Connect上の商品実体・価格・Subscription Groupは外部確認待ち。 |
| オフライン・途中再開・バックアップ | PASS | `LearningStore.swift` / `LearningStoreResultActions.swift` / `HistorySettingsViews.swift`、問題・図版のアプリ同梱。`ios/Tests/QuestionModelTests.swift` のJSON round-trip・日別回答回帰テストを含むXCTest 5件0失敗。Actions run `31363872501`。 |
| 専門監査 | PASS | `scripts/validate_release.py` でGolden Master設定順、Reduce Motion、StoreKit、Privacy、WebView禁止、問題件数、アイコン、TestFlight-only設定を監査。PR #4128。 |
| 再監査 | PASS | 専門監査修正後のPR head `af29273203f0f20c23b1700a4400053739565506` で Static Gate / XCTest / Release build を再実行。Native Compile run `31363872485` PASS、Native iOS Preflight run `31363872501` PASS。 |
| Releaseビルド | PASS | **署名なしiOS Simulator Release build**。Actions run `31363872485` と `31363872501` のRelease build成功、Release app resource audit成功。これは署名IPAのPASSを意味しない。 |
| 署名IPA | 本人操作待ち | root `codemagic.yaml` に `pharmacist-ios`、Bundle ID、App ID、`yakuzaishi_appstore`、`testFlightInternalTestingOnly`、`submit_to_testflight:true`、`submit_to_app_store:false` を設定済み。ただしCodemagicアカウント内のprofile実体・対応Apple Distribution証明書をこのChatGPTから確認できず、workflow未実行・IPA artifactなし。 |
| App Store Connectアップロード | 未実施 | 現行SwiftUIネイティブ版をApp Store Connectへ送信したBuild ID / upload log / processing recordなし。 |
| Internal TestFlight | 未実施 | 現行SwiftUIネイティブ版のInternal TestFlight build番号・processing完了・内部配布記録なし。 |

## 固定識別情報の証跡

- `pharmacist-manabi-sprint/ios/project.yml`：`MARKETING_VERSION: 1.0.0`、`CURRENT_PROJECT_VERSION: 1`、`PRODUCT_BUNDLE_IDENTIFIER: jp.allsunday1122.yakuzaishi`
- root `codemagic.yaml` / workflow `pharmacist-ios`：`APP_STORE_CONNECT_APP_ID: "6799753724"`、`CODEMAGIC_PROFILE_REF: yakuzaishi_appstore`
- PR #4128：SwiftUIネイティブ化
- merge commit：`97d8a71617f7ace4ad39a23ffbe8c7aef5619600`
- Native Compile Xcode16：Actions run `31363872485` PASS
- Native iOS Preflight：Actions run `31363872501` PASS
- `pharmacist-manabi-sprint/content/product/final-audit-v2.json`：データ最終監査PASS
- `pharmacist-manabi-sprint/ios/Tests/QuestionModelTests.swift`：XCTest回帰テスト

## 未完了項目

### 1. 署名付きIPA
- 未完了内容：CodemagicでApp Store署名したIPAが未生成。
- FAIL理由：アプリコードのFAILではない。Codemagicアカウント内の `yakuzaishi_appstore` provisioning profile実体と対応Apple Distribution証明書を、このChatGPT接続から検証・実行できない。
- ChatGPTで実行可能：GitHub上の `codemagic.yaml`、Bundle ID、App ID、Xcode project/scheme、release audit、TestFlight-only設定の維持・修正。
- 本人操作：Codemagicでprofile/certificate/integrationを確認し `pharmacist-ios` をmainから実行。
- 次の作業：Codemagic署名条件確認 → workflow実行 → build番号・Build ID・IPA artifact・upload logを記録。

### 2. App Store Connect / StoreKit商品実体
- 未完了内容：月額 `jp.allsunday1122.yakuzaishi.monthly`、買い切り `jp.allsunday1122.yakuzaishi.lifetime`、Subscription Group、価格、必要なIntro Offer、Paid Apps Agreement等のApp Store Connect側実体確認。
- FAIL理由：コード側StoreKit 2実装はPASSだが、App Store Connectアカウント内設定の証跡を取得できていない。
- ChatGPTで実行可能：商品ID・UI・購入/復元ロジック・静的監査。
- 本人操作：App Store Connectへログインして商品状態・契約状態を確認。
- 次の作業：Codemagic実行前にIAPと契約状態を確認。

### 3. App Store Connectアップロード / Internal TestFlight
- 未完了内容：現行SwiftUIネイティブ版のアップロード、Apple processing、Internal TestFlight配布、iPhone実機確認。
- FAIL理由：未実施。署名IPA未生成のため後続工程へ未到達。
- ChatGPTで実行可能：アップロード後にBuild番号・ログ・実機結果をGitHub/Notionへ反映し、FAIL箇所の修正ループを継続。
- 本人操作：Apple/Codemagic認証、必要な2FA、Codemagic実行、TestFlightから実機インストール。
- 次の作業：署名IPA生成 → App Store Connectアップロード → Internal TestFlight → 実機監査。

## TestFlight判定

**READY条件未達。TestFlight Ready markerは未付与。**

未達理由：
1. Codemagic署名ビルド未実行のため、実際に配布するBuild番号が未確定。
2. 署名IPAの証跡なし。
3. App Store Connectアップロードの証跡なし。
4. Internal TestFlightの証跡なし。
5. Codemagicアカウント内の `yakuzaishi_appstore` profile実体・対応Distribution証明書の確認証跡なし。

本審査への提出は禁止。`submit_to_app_store: false` を維持する。
