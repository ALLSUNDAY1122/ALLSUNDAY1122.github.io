# AI引継ぎ帳 v0.6 MacinCloud署名・TestFlight実行手順

作成日：2026年7月24日

## この工程で行うこと

Apple DeveloperのApp IDとApp Store Connectのアプリレコード作成後、MacinCloud上のXcodeで署名付きArchiveを新規作成し、TestFlightへアップロードします。

過去に作成した署名なし`Runner.app`と署名なし`.xcarchive`は検証用です。そのままApp Store Connectへアップロードしません。

## Apple公式手順との対応

- App Store Connectへアップロードするビルドは、事前にアプリレコードを作成しておく必要があります。
- Bundle ID、Version、Buildによってアップロード先のアプリとバージョンが関連付けられます。
- XcodeのAutomatic Signingを使用すると、Xcodeが配布用プロビジョニングプロファイルを管理します。
- Archive後はXcode Organizerの`Validate App`を実行し、`TestFlight & App Store`を選んでアップロードします。
- 初回アップロード後はApple側の処理が完了してからTestFlightへ表示されます。

## 前提条件

1. Apple Developer Programが有効
2. App ID `jp.allsunday.aihandoverlog`を登録済み
3. App Store Connectで「AI引継ぎ帳」のアプリレコードを作成済み
4. MacinCloudへXcode 16以降を導入済み
5. XcodeにApple Accountでサインイン済み
6. Apple Developer Team IDを確認済み
7. v0.6 FlutterプロジェクトをMacinCloudへ配置済み

## Team IDの確認

Apple DeveloperのMembership details、またはXcodeのAccounts画面で10文字のTeam IDを確認します。

Apple ID、パスワード、2ファクタ認証コード、秘密鍵をスクリプトやGitHubへ保存しないでください。

## 実行

ターミナルでFlutterプロジェクトのルートへ移動します。

```bash
chmod +x scripts/macincloud_testflight_archive.sh
DEVELOPMENT_TEAM=ABCDEFGHIJ ./scripts/macincloud_testflight_archive.sh
```

`ABCDEFGHIJ`は実際のApple Developer Team IDへ置き換えます。

別の場所にプロジェクトがある場合：

```bash
DEVELOPMENT_TEAM=ABCDEFGHIJ ./scripts/macincloud_testflight_archive.sh \
  --project-dir "/Users/ユーザー名/Projects/AI_Handover_Log_Flutter_v0.6"
```

環境確認だけを行う場合：

```bash
DEVELOPMENT_TEAM=ABCDEFGHIJ ./scripts/macincloud_testflight_archive.sh --dry-run
```

## スクリプトが自動で確認する内容

- macOSで実行されていること
- Xcode 16以降
- iPhoneOS SDK
- Flutter
- Apple Distribution署名ID
- `pubspec.yaml`
- `ios/Runner.xcworkspace`
- Bundle ID `jp.allsunday.aihandoverlog`
- Version `0.6.0`
- Build `6`
- `flutter analyze`
- `flutter test`
- Swift Package依存解決
- Automatic Signingによる署名付きArchive
- Archive内Info.plist
- code signature
- Entitlements
- arm64バイナリUUID
- 全ログ保存

## Xcode Organizerでの操作

Archive作成後、XcodeがArchiveを開きます。

1. `Validate App`
2. エラーが0件であることを確認
3. `Distribute App`
4. `TestFlight & App Store`
5. 推奨設定を使用
6. Automatic Signingを使用
7. dSYM／symbolsのアップロードを有効
8. `Upload`

内部テスターだけへ先に配る場合でも、初回は通常の`TestFlight & App Store`でアップロードして問題ありません。配布対象はApp Store Connect側で設定します。

## App Store Connectで確認

1. Apps → AI引継ぎ帳
2. TestFlight
3. iOS
4. Build Uploads
5. Version `0.6.0`、Build `6`を確認
6. Processing完了を待つ
7. Export Complianceの質問が出た場合は、現行設定と実装を照合
8. 内部テスターへ追加

## よくある停止原因

### No profiles for bundle ID

- App IDが登録済みか確認
- Bundle IDの完全一致を確認
- XcodeのSigning & CapabilitiesでTeamを選択
- Automatically manage signingを有効化
- Xcode Accountsで証明書を更新
- 古いキャッシュプロファイルが原因の場合、Xcodeで再取得

### Apple Distribution identityがない

Xcode → Settings → Accounts → Team → Manage Certificatesで配布証明書を作成または取得します。

### Bundle IDがApp Store Connectにない

先にApp Store Connectでアプリレコードを作成します。

### Build number already used

Build `6`が既にアップロード済みの場合、`pubspec.yaml`とXcodeのBuildを`7`へ上げて新しいArchiveを作成します。同じBuild番号は再利用できません。

### Agreement update required

App Store ConnectのBusinessでAccount Holderが最新契約へ同意します。

## 成功条件

- Xcode Archive成功
- code signature検証成功
- Validate Appでエラーなし
- Upload成功
- TestFlightのBuild Uploadsへ`0.6.0 (6)`が表示
- Processing完了
