# 危険物乙4｜実進捗・TestFlight判定

更新: 2026-08-10 18:12 JST

> このファイルはチャット本文ではなく、危険物乙4の実状態を引き継ぐ進捗正本として使用する。証跡がない項目をPASSにしない。

## 対象アプリ

- 資格名: `危険物取扱者 乙種4類｜学びスプリント`
- Bundle ID: `jp.allsunday1122.otsu4`
- App Store Connect App ID: `6799755566`
- Version: `1.0.0`
- Build番号: `1`（Git正本 / 最新Release Simulator build）。Codemagic署名ビルドでは `CM_BUILD_NUMBER` を設定するため、実際にApp Store Connectへ上げるBuild番号はCodemagic実行まで未確定。
- Codemagic workflow: `otsu4-ios`
- Codemagic署名プロファイル: `otsu4_appstore`
- IAP: `jp.allsunday1122.otsu4.premium`
- PR: #4069 `feat/otsu4-360-productization`
- 判定対象製品コードhead: `9481f69ec0c15995ee76f572bab156faa094555e`

## 実績ステータス

| 項目 | 判定 | 証跡 |
|---|---|---|
| Notion正本照合 | **PASS** | 標準手順 v2.2 `https://app.notion.com/p/3a909c10697d81e0961bd0fd27a77d39` / 申請手順 `https://app.notion.com/p/3b009c10697d81eba325f86d8af55481` / UI Golden Master v2.1 `https://app.notion.com/p/3b609c10697d81f0b3d0f78d160a819f` / 乙4開発正本 `https://app.notion.com/p/3b309c10697d812bacb3e0518ded235d` を2026-08-10再取得・照合。 |
| UI要件照合 | **PASS** | `native-ios/Otsu4Sprint/Otsu4GoldenRootView.swift`, `Otsu4DesignSystem.swift`, `Otsu4SprintApp.swift`; Golden Master v2.1の標準8問、4/8/16、4タブ、達成度ドーナツ、朱系5週間ヒートマップ、苦手一覧、必要ペースを反映。PR #4069 / head `9481f69e...`。 |
| ネイティブ実装 | **PASS** | SwiftUI Native。`Otsu4GoldenRootView.swift`, `Otsu4LearningView.swift`, `Otsu4SprintApp.swift`。WebView製品化なし。GitHub Actions `Otsu4 Native Typecheck` run `31362013988` = success（head `9481f69e...`）。 |
| データ監査 | **PASS** | `kikenbutsu-otsu4-sprint/questions.generated.json` / `tools/otsu4-build-content-v2.mjs`。`Otsu4 Content Audit` run `31362013994` = success。360問、法令144 / 物理・化学96 / 性質・消火120、exact duplicate 0、learningObjective duplicate 0、explanation duplicate 0、anti-padding 0。 |
| StoreKit 2 | **PASS** | `native-ios/Otsu4Sprint/Otsu4PurchaseStore.swift`。IAP `jp.allsunday1122.otsu4.premium`、`Product.displayPrice`、verified transaction、`Transaction.currentEntitlements`、`Transaction.updates`、`AppStore.sync()`を実装。最新Native Typecheck run `31362013988` = success。なおSandbox実購入監査は未実施で、専門監査完了とは扱わない。 |
| オフライン・途中再開・バックアップ | **PASS** | `Otsu4LearningStore.swift`, `Otsu4StudySession.swift`, bundle内 `questions.generated.json`。Unit XCTest run `31360071259` で6/6 PASS（JSON往復、弱点3連続解除、誤答リセット、模試startedAt復帰等）。そのテスト後から現製品コードheadまで `Otsu4LearningStore.swift` Git blob SHA `b586fa3a2b1cba30ec7232d5977a0895bf034f52` は不変。最新Release bundleにも360問JSONを内包。 |
| 専門監査 | **FAIL** | データ監査・型監査はPASSだが、最新製品コードheadの小型/大型iPhone UI XCTestとStoreKit Sandbox実購入監査が完了していない。完全な専門監査ゲートとしては未達。 |
| 再監査 | **FAIL** | 最新製品コードheadの `Otsu4 Xcode Build` run `31362014117` は overall failure。Release build / bundle identityはPASSしたが、`Boot selected iPhone simulators` で2台目 `iPhone 17 Pro Max` が5分以内にboot完了せずtimeout。Unit/UI XCTestはこのrunではskipped。 |
| Releaseビルド | **PASS** | 製品コードhead `9481f69e...`、GitHub Actions run `31362014117` step `Build iPhone Simulator app` = success、step `Verify release bundle resources and canonical identifiers` = success。Bundle ID `jp.allsunday1122.otsu4`, Version `1.0.0`, Build `1`, 360問JSON, `PrivacyInfo.xcprivacy`, `Assets.car` を確認。 |
| 署名IPA | **本人操作待ち** | `codemagic.yaml` workflow `otsu4-ios`、profile `otsu4_appstore` は設定済み。ただし対応するApple Distribution証明書Reference nameが正本未記載で、Codemagic上の実在設定確認が必要。署名IPA生成実績なし。 |
| App Store Connectアップロード | **本人操作待ち** | App Store Connect App ID `6799755566` は正本固定。署名IPA未生成のためアップロード未実施。Codemagic/Apple認証設定後に実施。 |
| Internal TestFlight | **未実施** | App Store Connectへのビルドアップロード未実施のため内部配布なし。実機購入/復元/pending/cancel/再インストール entitlement/UI/大文字/VoiceOver監査も未実施。 |

## 最新CI証跡

- PR: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/pull/4069
- 製品コードHead: `9481f69ec0c15995ee76f572bab156faa094555e`
- Native Typecheck: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/31362013988 — **PASS**
- Content Audit: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/31362013994 — **PASS**
- Release Foundation Lint: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/31362014087 — **PASS**
- Xcode Release + XCTest gate: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/31362014117 — **FAIL**
  - Release Simulator Build: PASS
  - Bundle ID / Version / Build / JSON / Privacy / Assets: PASS
  - Simulator selection: PASS (`iPhone 16e`, `iPhone 17 Pro Max`)
  - Simulator boot: FAIL — 2台目iPhone 17 Pro Maxが5分timeout
  - Unit XCTest: skipped in this run
  - UI XCTest: skipped in this run
  - canonical AppIcon SHA final step: skipped in this run（prepare段階では正本SHA `d0cb19b237ca3306413c481e4fbc0fb871705b390a1bc37619d9683fff19ff2d` を検証済み）

## 未完了項目

### 1. 最新製品コードheadの専門監査・再監査
- 未完了内容: Unit/UI XCTestを最後まで通す。
- FAIL理由: アプリのcompile/buildではなくGitHub Actions上の2台目Simulator boot timeout。
- ChatGPTで実行可能: `.github/workflows/otsu4-xcode-build.yml` のSimulator起動方式を安定化し、同一品質条件で再実行・FAIL修正を継続できる。
- 本人操作: 不要。
- 次: CIのSimulator boot処理を修正し、Unit/UI XCTest + AppIcon SHAまでPASSさせる。

### 2. StoreKit Sandbox監査
- 未完了内容: 購入成功 / cancel / pending / restore / 再インストール後entitlementの実挙動。
- FAIL理由: signed TestFlight buildがまだないため実機Sandboxを実行できない。
- ChatGPTで実行可能: コード・UI・StoreKit状態遷移の静的監査、TestFlightチェックリスト整備。
- 本人操作: Internal TestFlight到達後、iPhone実機で購入系挙動を確認して結果を報告。
- 次: 署名IPA→アップロード後に実施。

### 3. Codemagic署名IPA
- 未完了内容: App Store Distribution signed IPA生成。
- FAIL理由: `otsu4_appstore` に対応するApple Distribution証明書Reference nameをGitHub/Notionから確定できない。
- ChatGPTで実行可能: `codemagic.yaml`の正本値・署名ロジックの修正、ビルドログ解析。
- 本人操作: CodemagicのCode signing identitiesで `otsu4_appstore` と組になるApple Distribution証明書の実在Referenceを確認・接続。Apple/Codemagicログインや2FA等は本人実施。
- 次: 証明書が確定したらworkflowへ安全に反映し `otsu4-ios` を実行。

### 4. App Store Connect / Internal TestFlight
- 未完了内容: signed build upload、Internal Testing配布、実機監査。
- FAIL理由: signed IPAが未生成。
- ChatGPTで実行可能: upload後のログ監査、TestFlightチェックリスト・不具合修正。
- 本人操作: Apple/Codemagic認証、必要な契約/2FA、Internal TestFlightでのiPhone実機確認。
- 次: signed IPA生成後にApp Store Connect App ID `6799755566`へアップロードしInternal Testingへ追加。

### 5. Build番号
- 未完了内容: Git正本はBuild `1`だが、Codemagicは署名時に `CM_BUILD_NUMBER` へ置換する。
- FAIL理由: 実際のCodemagic buildをまだ開始していないため、App Store Connectへ上げるBuild番号が未確定。
- ChatGPTで実行可能: Codemagic実行後にbuild番号をGitHub/Notionへ記録。
- 本人操作: Codemagic実行条件の認証・署名設定。

## TestFlight判定

**現在: NOT READY / Release Gate FAIL**

READYマーカーは未記録。

未達条件:
- 専門監査・再監査がPASSしていない
- 最新製品コードheadのXcode XCTest gateがFAIL
- StoreKit Sandbox監査未実施
- Codemagic署名条件のApple Distribution証明書Reference未確定
- 署名IPA未生成
- App Store Connect upload未実施
- 実際にuploadするCodemagic Build番号未確定

本審査は**未提出**であり、`submit_to_app_store: false`を維持する。
