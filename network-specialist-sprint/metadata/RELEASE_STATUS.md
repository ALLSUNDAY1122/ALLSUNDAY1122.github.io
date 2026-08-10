# RELEASE STATUS

更新: 2026-08-10 19:10 JST

## 対象アプリ
- 資格名：ネットワークスペシャリスト試験｜学びスプリント
- Bundle ID：`jp.allsunday1122.networkspecialist`
- App Store Connect App ID：**未記載・推測禁止**
  - 最上位正本：`https://app.notion.com/p/3b709c10697d8138a352c422d4dd5c47`
- Version：`1.0.0`
- Build番号：`1`
- Codemagic workflow：`network-specialist-native-ios`
- Codemagic署名プロファイル：`networkspecialist_appstore`
- Apple Team ID：`MN3D2ZM44N`
- Distribution：App Store
- TestFlight：Internal Testing only
- App Store本審査提出：禁止

## 実績ステータス

| 項目 | 判定 | PASS/FAIL証跡・実状態 |
|---|---|---|
| Notion正本照合 | PASS | 標準手順 v2.2 `https://app.notion.com/p/3a909c10697d81e0961bd0fd27a77d39`、申請手順 `https://app.notion.com/p/3b009c10697d81eba325f86d8af55481`、UI v2.1 Golden Master `https://app.notion.com/p/3b609c10697d81f0b3d0f78d160a819f`、問題監査ループ `https://app.notion.com/p/3b609c10697d8148a0c2db3a8c8d5e63`、#7正本 `https://app.notion.com/p/3b609c10697d813d9433ff34f45a69ba`、識別情報正本 `https://app.notion.com/p/3b709c10697d8138a352c422d4dd5c47` を2026-08-10再取得。 |
| UI要件照合 | PASS | PR #4126 `https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/pull/4126`。Golden Master v2.1の4タブ、標準8問/4・8・16、生成り紙・藍・朱・緑・金、82px進捗リング、明朝/ゴシック、即時正誤、ここだけ覚えるを純SwiftUIへ実装。merge commit `2387b5136e3114d8af694647b2afa44eb3404024`。 |
| ネイティブ実装 | PASS | `network-specialist-sprint/ios/NetworkSpecialist/`。PR #4126でWKWebView/WebKitをアプリターゲットから削除し純SwiftUI化。GitHub Actions run `31360542268` (#36) でXcodeGen/Swift compile、Unit 5/5、UI 3/3、iPhone 17 Pro Max + iPhone SE(3rd) PASS。 |
| データ監査 | PASS | `network-specialist-sprint/audit-status.json`。75出題枠 / 68ユニーク / 公式再出題・variant 7。GitHub Actions run `31360542268` (#36)。問題本文・正答・解説・出典はNative移行時に変更なし。 |
| StoreKit 2 | FAIL | StoreKit 2非消耗型機構自体は `network-specialist-sprint/ios/NetworkSpecialist/PremiumPurchaseStore.swift` で実装済み。`Product.products`、`Product.displayPrice`、verified active transactionのみ解放、`Transaction.currentEntitlements`、`Transaction.updates`、明示復元 `AppStore.sync()` は監査済み。ただし最上位識別情報正本で #7 IAP Product ID が未記載、無料範囲/買い切り解放範囲も未確定。`network-specialist-sprint/audit-status.json` の `PASS_WITH_CANONICAL_BLOCKER` とCodemagic `--require-iap` が証跡。Release受入項目としてはFAIL。 |
| オフライン・途中再開・バックアップ | PASS | `QuestionRepository.swift` / `LearningStore.swift` / `GeneratedQuestionPayload.swift` / JSON backup/restore。監査済payloadを端末内に保持し、途中再開・弱点・履歴を端末保存。GitHub Actions run `31360542268` (#36)。 |
| 専門監査 | PASS | 著作権・問題品質・Privacy・StoreKit 2機構を再監査。`network-specialist-sprint/audit-status.json` の `questionAudit=PASS`、`nativeImplementation=PASS`、専門FAIL→修正履歴を参照。Release課金正本値は別途FAILとして保持。 |
| 再監査 | PASS | FAIL→修正：WKWebView不適合、`questions.native.json missingResource`、Bundle resource layout差、未確認60%閾値、`sourceCheckedAt`誤代入を修正。最終GitHub Actions run `31360542268` (#36)：Ubuntu PASS / Unit 5/5 / UI 3/3 / 2端末PASS。 |
| Releaseビルド | 未実施 | 最新Release Gate PR #4133 `https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/pull/4133`、GitHub Actions run `31374397737` (#43) は `Materialize exact canonical AppIcon` でFAILし、`Unsigned device Release build` はskipped。ログ：`Canonical AppIcon unavailable. Add the approved Base64 transport parts or provide CANONICAL_APPICON_PATH.`。よってReleaseビルドPASS証跡なし。 |
| 署名IPA | 未実施 | Codemagic workflow `network-specialist-native-ios` のSigned IPA実行証跡なし。`network-specialist-sprint/codemagic.yaml` は `networkspecialist_appstore`、`testFlightInternalTestingOnly: true`、App Store本審査自動提出OFFの構成。 |
| App Store Connectアップロード | 未実施 | App Store Connect App IDが正本未記載。Signed IPAなし。アップロードBuild ID/ログなし。 |
| Internal TestFlight | 未実施 | App Store Connectアップロードなし、Internal Testingビルド番号/実機確認ログなし。 |

## 未完了項目

### 1. App Store Connect App ID未記載
- 未完了内容：#7の数値App Store Connect App IDが識別情報正本に存在しない。
- FAIL理由：最上位正本が「未記載・推測禁止」。外部検索・命名規則から補完不可。
- ChatGPTで実行可能：ユーザーが数値IDを明示後、Notion識別情報、#7正本、GitHub metadata、Codemagic関連記録へ同期し再監査。
- 本人操作が必要：App Store Connectへログインし、`jp.allsunday1122.networkspecialist` のAppレコードを作成/確認して数値App IDを確認する。
- 次：数値App IDを正本へ記録。

### 2. IAP Product ID・無料/解放範囲未確定
- 未完了内容：非消耗型Product IDと無料範囲/買い切り解放範囲が正本未確定。
- FAIL理由：StoreKit 2機構は実装済みだが、商品識別子と商品仕様を推測できない。
- ChatGPTで実行可能：正本確定後にProduct ID・解放条件を実装へ接続し、Unit/UI/Release Gateを再実行。
- 本人操作が必要：IAPを採用する場合はApp Store Connectで非消耗型IAPを作成し、採用Product IDと解放範囲を明示する。
- 次：課金正本値を確定。

### 3. 正本AppIconのRelease checkout配置
- 未完了内容：正本PNGがRelease checkout内の `network-specialist-sprint/ios/NetworkSpecialist/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` に存在しない。
- FAIL理由：PR #4133 / Actions run #43でAppIcon materialize GateがFAIL。
- 正本証跡：Google Drive `07_ネットワークスペシャリスト試験.png`、file ID `1V9gAXcE7jSuYn9Y8SFgYWHNfRGsE_Lb8`、1024x1024 RGB、678310 bytes、SHA-256 `5b53032021cea4a3e71e737c1a48e1aa8d6495b3647cb770b0e5d917bb0d8729`。
- ChatGPTで実行可能：同一SHA検証script、Release Gate、CI定義の修正・再実行。
- 本人操作/バイナリpush可能環境：正本PNGを変換せず指定パスへcommit/push。
- 次：正本PNG配置→PR #4133再実行または後継PRでRelease Gate再実行。

### 4. Support / Privacy公開HTTP 200証跡
- 未完了内容：公開HTTPSの独立HTTP 200証跡未取得。
- FAIL理由：リポジトリ内 `support.html` / `privacy.html` は存在するが、今回の証跡体系でHTTP 200を確定できていない。
- ChatGPTで実行可能：外部HTTP取得可能な経路で再監査し記録。
- 次：公開URL 2本のHTTP 200確認。

### 5. Release / 署名 / App Store Connect / Internal TestFlight
- 未完了内容：Release build、Signed IPA、ASC upload、Internal TestFlightが未完了。
- FAIL理由：上記1〜4とApple/Codemagic本人認証が前提。
- ChatGPTで実行可能：GitHub CI/Release Gate、Codemagic設定監査、metadata/Notion同期、実行ログ監査。
- 本人操作が必要：Apple Developer / App Store Connect / Codemagicのログイン、2FA、`networkspecialist_appstore` integration認証。秘密情報はGitHub/Notion/チャットへ保存しない。
- 次：Release Gate PASS後、Codemagic `network-specialist-native-ios` → signed IPA → App Store Connect upload → Internal Testingのみ。

## 次に実行すべき作業
1. App Store Connectで #7 のAppレコードを作成/確認し、数値App IDを正本へ明示する。
2. IAP採用仕様を確定し、Product IDと無料/解放範囲を正本化する。
3. 正本AppIcon PNGを指定Asset Catalogへ同一SHAで配置し、Release Gateを再実行する。
4. Support / Privacyの公開HTTP 200を証跡化する。
5. GitHub Release GateがPASSした後、Codemagic `network-specialist-native-ios` を署名プロファイル `networkspecialist_appstore` で実行する。
6. Signed IPAをApp Store Connectへアップロードし、Internal Testingのみ有効化する。
7. 本審査へは提出しない。

## TestFlight判定
条件未達のため、`[CODEX TESTFLIGHT READY]` は記録しない。

未達条件：StoreKit 2正本商品値、App Store Connect App ID、正本AppIcon配置、ReleaseビルドPASS、署名IPA、App Store Connectアップロード、Internal TestFlight。

本審査へは提出しない。
