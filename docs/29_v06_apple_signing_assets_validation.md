# AI引継ぎ帳 v0.6 Apple署名資産の作成・検証手順

作成日：2026年7月24日

## 目的

MacinCloudまたはGitHub Actionsで署名付きBuildを作る前に、次の3資産が正しい組み合わせであることをローカル確認します。

1. Apple Distribution証明書と秘密鍵を含む`.p12`
2. `jp.allsunday.aihandoverlog`用のApp Store Connect provisioning profile
3. App Store Connect APIの`.p8`秘密鍵、Key ID、Issuer ID

秘密情報そのものはGitHub、ChatGPT、Notion、PR、Issueへ貼り付けません。

## 権限

Apple Distribution証明書の作成はAccount HolderまたはAdminが行います。

App Store Connect provisioning profileもAccount HolderまたはAdminが作成します。明示的App IDと配布証明書を選択して生成します。XcodeでAutomatic Signingを使用する通常経路では、Xcodeにプロファイル管理を任せることもできます。

App Store Connect APIは、最初にAccount HolderがAPIアクセスを有効化します。Team API keyの管理はAccount HolderまたはAdminです。API秘密鍵は一度しかダウンロードできません。

## 1. CSRとApple Distribution証明書

MacinCloudのKeychain Accessを開きます。

1. Keychain Access → Certificate Assistant
2. Request a Certificate From a Certificate Authority
3. Apple Developer Programに登録したメールアドレスを入力
4. Common Nameを入力
5. Saved to disk
6. `.certSigningRequest`を保存

Apple DeveloperのCertificatesで：

1. `＋`
2. Software → `Apple Distribution`
3. CSRをアップロード
4. `.cer`をダウンロード
5. `.cer`をダブルクリックしてKeychainへ追加
6. Keychain AccessのMy CertificatesでApple Distribution証明書を展開
7. 直下に秘密鍵が表示されることを確認
8. 証明書と秘密鍵を同時選択
9. Export Items
10. `.p12`として保存し、強い書き出しパスワードを設定

`.p12`とパスワードは別々に保管します。

## 2. App Store Connect provisioning profile

Apple DeveloperのProfilesで：

1. `＋`
2. Distribution → `App Store Connect`
3. App ID `jp.allsunday.aihandoverlog`
4. 作成したApple Distribution証明書
5. Profile Name：`AI引継ぎ帳 App Store v0.6`
6. Generate
7. `.mobileprovision`をダウンロード

開発用、Ad Hoc、Enterpriseのプロファイルは使用しません。

## 3. App Store Connect API key

App Store Connect → Users and Access → Integrations → App Store Connect APIで：

1. 必要ならAccount HolderがAPIアクセスを有効化
2. Team Keys
3. Generate API Key
4. Name：`AI引継ぎ帳 GitHub TestFlight`
5. Role：Developer
6. Generate
7. Key IDとIssuer IDを記録
8. `.p8`を一度だけダウンロード
9. ファイル名を`AuthKey_<Key ID>.p8`のまま保持

Team API keyは全アプリに適用され、アプリ単位に制限できません。必要最小限のRoleを選びます。

## 4. ローカル検証

同梱スクリプトをMacinCloudで実行します。

```bash
chmod +x scripts/validate_apple_signing_assets_macos.sh

scripts/validate_apple_signing_assets_macos.sh \
  --certificate "/Users/ユーザー名/Secure/AppleDistribution.p12" \
  --profile "/Users/ユーザー名/Secure/AI引継ぎ帳_AppStore.mobileprovision" \
  --api-key "/Users/ユーザー名/Secure/AuthKey_XXXXXXXXXX.p8" \
  --team-id "ABCDEFGHIJ" \
  --key-id "XXXXXXXXXX" \
  --issuer-id "00000000-0000-0000-0000-000000000000"
```

`.p12`のパスワードは非表示入力です。

## 検証内容

- `.p12`が読める
- Apple Distribution証明書である
- 証明書が有効期限内
- 証明書と秘密鍵が一致
- provisioning profileが読める
- Team ID一致
- application-identifierが`TeamID.jp.allsunday.aihandoverlog`
- Development profileではない
- Ad Hoc profileではない
- Enterprise profileではない
- Profileが有効期限内
- Profileが指定のDistribution証明書を含む
- `.p8`が有効な秘密鍵構造
- Key IDとIssuer IDの形式
- 秘密情報を含まないJSONだけを出力

## 出力JSONに含まれないもの

- `.p12`本体
- 証明書の秘密鍵
- `.p12`パスワード
- `.mobileprovision`本体
- `.p8`秘密鍵
- GitHub Secret値

証明書の公開情報、指紋、Profile名・UUID・期限、API公開鍵のハッシュだけを記録します。

## GitHub秘密情報スキャン

PR #870にはApple Secret Safety CIを追加します。

禁止対象：

- `.p12`
- `.pfx`
- `.mobileprovision`
- `AuthKey_*.p8`
- `.cer`
- `.key`
- PRIVATE KEYブロック
- 長いBase64秘密値の直接代入

署名WorkflowがEnvironment secretsを参照していること、署名済みIPAやArchiveをArtifactへ保存しないことも検査します。

## 漏えいが疑われる場合

- App Store Connect API key：直ちにRevoke
- Apple Distribution証明書：Developer AccountでRevokeし再発行
- GitHub Secret：削除・再登録
- Workflow Artifactやログ：削除
- 同じパスワードや秘密鍵を再利用しない
