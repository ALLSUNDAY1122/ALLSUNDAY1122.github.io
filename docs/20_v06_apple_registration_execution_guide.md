# AI引継ぎ帳 v0.6 Apple登録実行手順

作成日：2026年7月24日

## 目的

Apple Developerで明示的App IDを登録し、App Store Connectで初回アプリレコードを作成するための入力値と操作順です。

現時点では、Apple Accountへのログイン、2ファクタ認証、契約同意が必要な操作は未実施です。公開ページ用PR #1661も未マージです。

## 0. 開始前確認

- Apple Developer Programが有効
- Account Holderが最新契約へ同意済み
- App ID登録者はAccount HolderまたはAdmin
- App Store Connectのアプリ作成者はAccount Holder、Admin、App Managerのいずれか
- Bundle IDは `jp.allsunday.aihandoverlog` から変更しない
- XcodeプロジェクトのBundle IDも同じ値にする

## 1. Apple DeveloperでApp IDを登録

画面：Certificates, Identifiers & Profiles → Identifiers → ＋

| 項目 | 入力値 |
|---|---|
| Identifier Type | App IDs |
| App ID Type | App |
| Description | AI引継ぎ帳 |
| Bundle ID方式 | Explicit |
| Bundle ID | `jp.allsunday.aihandoverlog` |

Capabilities：

- 現行v0.6では追加Capabilityを選択しない
- Sign in with Apple、Push Notifications、iCloud、App Groups、Associated Domainsは使用しない
- アプリ内課金商品は作成しない
- OS共有シートとファイル選択は追加Capabilityを必要としない

Continue → 内容確認 → Register。

## 2. App Store Connectで新規アプリを作成

画面：Apps → ＋ → New App

| 項目 | 入力値 |
|---|---|
| Platforms | iOS |
| Name | AI引継ぎ帳 |
| Primary Language | Japanese |
| Bundle ID | `jp.allsunday.aihandoverlog` |
| SKU | `AIHANDOVERLOG-IOS-001` |
| User Access | Full Access |

作成後の初期状態は「Prepare for Submission」です。

公開検索では同名の完全一致を確認できませんでしたが、名称の最終利用可否はNew App作成画面で確定します。名称が利用不可の場合でも、Bundle IDとSKUは変更せず、アプリ名だけを再検討します。

## 3. App Information

| 項目 | 入力値 |
|---|---|
| Subtitle | 複数AIの進捗と指示を、ひとつに |
| Primary Category | Productivity |
| Secondary Category | Utilities |
| Content Rights | 第三者コンテンツを表示・配信・取得しない |
| Made for Kids | No |
| Copyright | © 2026 Kohei Morita |

## 4. URL

公開予定URL：

- Privacy Policy URL：https://allsunday1122.github.io/ai-handover-log/privacy/
- Support URL：https://allsunday1122.github.io/ai-handover-log/support/

現在はPR #1661が未マージです。App Store Connectへ入力する前に、PRを明示的な指示でmainへマージし、両URLがHTTPSで一般公開され、相互リンクと問い合わせ窓口が正常であることを確認します。

## 5. App Privacy

現行v0.6の回答：

- Data Collection：No, we do not collect data from this app
- Tracking：No
- User Privacy Choices URL：空欄

根拠：

- 開発者サーバーなし
- アカウントなし
- 広告・解析・トラッキングSDKなし
- AI API接続なし
- 入力データは端末内保存
- OS共有は利用者による明示操作
- JSONバックアップは利用者が保存先を選択

広告、解析、クラウド同期、AI API、ログイン、外部サーバー、課金、通知トークンを追加した場合は回答を再確認します。

## 6. バージョン情報

| 項目 | 値 |
|---|---|
| Bundle ID | `jp.allsunday.aihandoverlog` |
| Version | `0.6.0` |
| Build | `6` |
| Minimum iOS | `13.0` |
| Export Compliance | `ITSAppUsesNonExemptEncryption=false` |
| Price | Free |
| Initial Availability | Japan |
| Release Method | Manually release this version |

## 7. Buildアップロード前の順序

1. MacinCloudへv0.6 Flutterプロジェクトを配置
2. XcodeでApple Accountへサインイン
3. Runner targetのSigning & CapabilitiesでTeamを選択
4. Bundle IDを確認
5. Automatically manage signingを有効化
6. Release Archiveを新規作成
7. Validate App
8. Distribute App → App Store Connect → Upload
9. TestFlightでProcessing完了を確認
10. Missing Complianceが表示された場合は暗号化回答を確認

署名なしで作成済みのRunner.appやxcarchiveはそのままアップロードせず、Apple Team設定後に新規Archiveを作成します。

## 8. 提出を止める条件

- Bundle ID不一致
- VersionまたはBuild重複
- Privacy Policy URLまたはSupport URLが404
- スクリーンショット文字化け
- App Privacy回答と実装の不一致
- Xcode Validate Appエラー
- 契約未同意

## 9. 現在の状態

- App ID登録：人間操作待ち
- App Store Connectアプリレコード作成：人間操作待ち
- 公開ページPR #1661：ドラフト・未マージ
- アプリ本体PR #870：ドラフト・未マージ
- App Store入力稿：完成
- スクリーンショット5枚：完成
- 署名なし実機ReleaseとArchive：検証済み
- Apple署名、TestFlightアップロード：未実施
