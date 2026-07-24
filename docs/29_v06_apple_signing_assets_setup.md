# AI引継ぎ帳 v0.6 Apple署名資産作成・検証手順

作成日：2026年7月24日

## 目的

MacinCloud/Xcode経路またはGitHub Actions経路で使用するApple署名資産を、取り違えや期限切れを防ぎながら準備します。

## 推奨する初回経路

初回提出は、XcodeのAutomatic Signingを使用するMacinCloud経路を優先します。

GitHub Actionsの手動署名経路を使う場合だけ、以下の3ファイルが必要です。

1. 秘密鍵付きApple Distribution証明書：`.p12`
2. App Store Connect provisioning profile：`.mobileprovision`
3. App Store Connect API秘密鍵：`AuthKey_XXXXXXXXXX.p8`

## Apple Distribution証明書

Apple Distribution証明書は、App Store Connectへの提出に使用するチーム所有の配布証明書です。

作成可能な役割：

- Account Holder
- Admin

個人登録の場合、本人がAccount Holderです。

### 方法A：Xcodeで作成

1. Xcodeを開く
2. Settings
3. Accounts
4. Apple Accountを追加
5. Teamを選択
6. Manage Certificates
7. `+`
8. Apple Distribution

この方法では秘密鍵が同じMacのKeychainへ自動保存されます。

### `.p12`の書き出し

1. Keychain Accessを開く
2. loginキーチェーン
3. My Certificates
4. `Apple Distribution: ...`を展開
5. 証明書の下に秘密鍵があることを確認
6. 証明書と秘密鍵を一緒に選択
7. Export 2 Items
8. `.p12`で保存
9. 強い書き出しパスワードを設定

`.cer`だけではGitHub Actionsで署名できません。秘密鍵と証明書の組を含む`.p12`が必要です。

## App Store Connect provisioning profile

作成可能な役割：

- Account Holder
- Admin

前提：

- Explicit App ID `jp.allsunday.aihandoverlog`
- Apple Distribution証明書
- App Store Connectのアプリレコード

作成値：

- Distribution：App Store Connect
- App ID：`jp.allsunday.aihandoverlog`
- Certificate：今回使用するApple Distribution証明書
- Profile Name：`AIHandoverLog_AppStore_0.6`

App Store Connect provisioning profileには、配布証明書が1つだけ含まれます。

Automatic Signingを使う場合はXcodeが配布用プロファイルを管理するため、手動作成は必須ではありません。

## App Store Connect APIキー

GitHub ActionsからTransporterでアップロードする場合に使用します。MacinCloudのXcode Organizer経路だけなら不要です。

### APIアクセス

最初にAccount HolderがApp Store ConnectのUsers and Access → IntegrationsでAPIアクセスを申請します。Appleによる個別審査が行われる場合があります。

### Team API Key

作成可能な役割：

- Account Holder
- Admin

推奨値：

- Name：`AIHandoverLog-TestFlight`
- Access：Developer

作成後に記録する値：

- Key ID
- Issuer ID
- `.p8`秘密鍵

`.p8`は一度しかダウンロードできません。紛失や漏えいの疑いがある場合はRevokeし、新しいキーを作成します。

## 保存場所

MacinCloudに一時保存する場合：

```text
~/Documents/AIHandoverLog-Signing/
```

推奨ファイル名：

```text
AppleDistribution_AI_Handover_Log.p12
AIHandoverLog_AppStore_0.6.mobileprovision
AuthKey_XXXXXXXXXX.p8
```

作業後はMacinCloudから削除します。共有フォルダ、GitHub、Google Drive、Notion、メール添付へ無保護で保存しません。

## 自動検証

同梱スクリプトをMacinCloudで実行します。

```bash
chmod +x verify_apple_signing_assets_macos.sh

./verify_apple_signing_assets_macos.sh \
  --certificate "$HOME/Documents/AIHandoverLog-Signing/AppleDistribution_AI_Handover_Log.p12" \
  --profile "$HOME/Documents/AIHandoverLog-Signing/AIHandoverLog_AppStore_0.6.mobileprovision" \
  --api-key "$HOME/Documents/AIHandoverLog-Signing/AuthKey_XXXXXXXXXX.p8" \
  --team-id ABCDEFGHIJ \
  --key-id KLMNOPQRST \
  --issuer-id 00000000-0000-0000-0000-000000000000 \
  --report "$HOME/Documents/AIHandoverLog-Signing/verification-report.json"
```

スクリプトは`.p12`パスワードを非表示で尋ねます。

## 自動検証項目

- `.p12`をパスワードで開ける
- Apple Distribution証明書である
- 証明書が期限切れでない
- 秘密鍵との組が成立する
- プロファイルを正常に復号できる
- Team IDが一致する
- Bundle IDが`jp.allsunday.aihandoverlog`
- Development、Ad Hoc、Enterpriseプロファイルではない
- プロファイルが期限切れでない
- プロファイル内の証明書と`.p12`証明書が一致する
- `.p8`が有効な秘密鍵
- Key IDとIssuer IDの形式

レポートには秘密鍵、パスワード、Base64本体を含めません。

## GitHub Environment secretsへの登録

検証に合格した後だけ、既存の次のスクリプトを使用します。

```bash
configure_github_testflight_environment_macos.sh
```

Environment：

```text
testflight-production
```

登録後、GitHubのSettings → EnvironmentsでSecret名が存在することだけを確認します。値は再表示できません。

## 失効・削除

以下の場合は使用を停止します。

- `.p12`またはパスワードが漏えいした
- `.p8`が紛失・漏えいした
- 証明書またはプロファイルが期限切れ
- Team IDまたはBundle IDが一致しない
- 使用者がApple Developer Teamから外れた

APIキーはApp Store ConnectでRevokeします。証明書はApple DeveloperのCertificatesでRevokeします。プロファイルはCertificates, Identifiers & Profilesで削除または再生成します。
