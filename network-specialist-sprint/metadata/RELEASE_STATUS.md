# RELEASE STATUS

更新: 2026-08-10 18:09 JST

## 対象アプリ
- 資格名：ネットワークスペシャリスト試験｜学びスプリント
- Bundle ID：`jp.allsunday1122.networkspecialist`
- App Store Connect App ID：**未記載・推測禁止**（最上位正本「対象アプリ識別情報｜App Store Connect / Codemagic」）
- Version：`1.0.0`
- Build番号：`1`
- Codemagic workflow：`network-specialist-native-ios`
- Codemagic署名プロファイル：`networkspecialist_appstore`
- Apple Team ID：`MN3D2ZM44N`
- Distribution：App Store
- TestFlight：Internal Testing only
- App Store本審査自動提出：禁止

## 実績ステータス

| 項目 | 判定 | 証跡 |
|---|---|---|
| Notion正本照合 | PASS | Notion 標準手順 v2.2 / 申請手順 / UI v2.1 Golden Master / #7正本を2026-08-10再取得。対象正本: `https://app.notion.com/p/3b609c10697d813d9433ff34f45a69ba` |
| UI要件照合 | PASS | UI正本 v2.1 Golden Master。GitHub PR #4126で純SwiftUI実装を統合。PR: `https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/pull/4126` / merge commit `2387b5136e3114d8af694647b2afa44eb3404024` |
| ネイティブ実装 | PASS | `network-specialist-sprint/ios/NetworkSpecialist/`。WKWebView/WebKitをアプリターゲットから削除。main merge commit `2387b5136e3114d8af694647b2afa44eb3404024` |
| データ監査 | PASS | 75出題枠 / 68ユニーク / 各年度25問。`network-specialist-sprint/audit-status.json`、GitHub Actions run `31360542268` (#36) |
| StoreKit 2 | PASS | 非消耗型購入機構・`Product.displayPrice`・`currentEntitlements`・`Transaction.updates`・復元・未検証/pending/cancel/revocation非解放を実装。`network-specialist-sprint/ios/NetworkSpecialist/PremiumPurchaseStore.swift`。ただし #7 Product ID と無料/解放範囲は正本未確定のため Release課金Gateは未達 |
| オフライン・途中再開・バックアップ | PASS | `QuestionRepository.swift` / `LearningStore.swift` / JSON backup/restore。監査済payloadをJSON＋`GeneratedQuestionPayload.swift`でオフライン保持。GitHub Actions run `31360542268` (#36) |
| 専門監査 | PASS | 著作権・問題監査・課金監査・Privacy再監査を実施。`network-specialist-sprint/audit-status.json` |
| 再監査 | PASS | FAIL→修正：WKWebView不適合、`questions.native.json missingResource`、未確認60%閾値、sourceCheckedAt誤代入を修正。最終 GitHub Actions run `31360542268` (#36): Ubuntu PASS / Unit 5/5 / UI 3/3 / iPhone 17 Pro Max + iPhone SE(3rd) PASS |
| Releaseビルド | 未実施 | `network-specialist-sprint/codemagic.yaml` は署名Release構成済みだが、正本未確定値・AppIcon配置・Apple/Codemagic認証が未完了のため署名Releaseは未実行 |
| 署名IPA | 未実施 | Codemagic `network-specialist-native-ios` の `Build signed IPA` 未実行。IPA証跡なし |
| App Store Connectアップロード | 未実施 | App Store Connect App IDが正本未記載。アップロード証跡なし |
| Internal TestFlight | 未実施 | App Store Connect upload / Internal Testing実機確認の証跡なし |

## 未完了項目
1. **#7 App Store Connect App ID未記載**
   - FAIL理由：最上位識別情報正本が「未記載・推測禁止」。
   - ChatGPTで可能：正本値がユーザーから明示された後、Notion/GitHub/Codemagic metadataへ反映しRelease監査を再実行。
   - 本人操作：App Store Connectで対象Appレコードを確認し、表示されるApp IDをユーザーが明示する。

2. **#7 IAP Product ID・無料体験/買い切り解放範囲未確定**
   - FAIL理由：StoreKit 2機構は実装済みだが商品IDと解放仕様が正本未確定。
   - ChatGPTで可能：正本値確定後、`PremiumProductID` と解放条件を接続しUnit/UI/Release Gateを再実行。
   - 本人操作：App Store Connectで非消耗型IAPの商品IDを決定・作成する場合は、その正本値を明示する。

3. **正本AppIcon PNGのRelease checkout配置未完了**
   - FAIL理由：正本Driveファイルは取得済みだがGitHubコネクタはバイナリContents uploadを直接扱えず、mainの `AppIcon-1024.png` は未配置。
   - 正本証跡：Drive file ID `1V9gAXcE7jSuYn9Y8SFgYWHNfRGsE_Lb8` / 1024x1024 RGB / 678310 bytes / SHA-256 `5b53032021cea4a3e71e737c1a48e1aa8d6495b3647cb770b0e5d917bb0d8729`。
   - ChatGPTで可能：Release script・SHA検証・配置先は確定済み。
   - 本人操作/別実行環境：正本PNGを `network-specialist-sprint/ios/NetworkSpecialist/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` にそのまま配置しcommit/push。

4. **Support / Privacy公開HTTP 200の独立確認**
   - FAIL理由：リポジトリ内ファイルは存在するが、今回の実行環境から公開HTTP 200を証跡化できていない。
   - ChatGPTで可能：公開URL確認可能なブラウザ/CI経路があれば再監査。

5. **Codemagic / Apple認証と署名Release**
   - FAIL理由：Apple Developer / App Store Connect / Codemagicの本人認証・2FA・secretが必要。
   - ChatGPTで可能：`codemagic.yaml`、XcodeGen、Release validator、署名手順は準備済み。
   - 本人操作：Codemagic `networkspecialist_appstore` integrationを認証し、workflow `network-specialist-native-ios` を実行。

## 次に実行すべき作業
1. App Store Connectで #7 App IDを確認し正本値として明示する。
2. IAPを採用する場合は Product ID と無料/買い切り解放範囲を正本確定する。
3. 正本AppIcon PNGを指定パスへ同一SHAでcommitする。
4. Release Gateを再実行する。
5. Codemagic `network-specialist-native-ios` を `networkspecialist_appstore` で実行しSigned IPAを作成する。
6. App Store ConnectへアップロードしInternal Testingのみで配布する。
7. TestFlight実機で起動・8問・25問模試・中断復帰・JSON・機内モード・VoiceOver・購入/復元を確認する。

## TestFlight判定
**条件未達。`[CODEX TESTFLIGHT READY]` は記録しない。**

未達条件：App Store Connect App ID未確定、IAP正本値未確定、正本AppIcon未配置、Releaseビルド未実施、署名IPAなし、App Store Connectアップロードなし、Internal TestFlight未実施。

本審査へは提出しない。
