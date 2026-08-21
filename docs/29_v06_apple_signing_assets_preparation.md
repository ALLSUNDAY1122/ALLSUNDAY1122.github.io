# AI引継ぎ帳 v0.6 Apple署名資産作成・検証手順

作成日：2026年7月24日

## 目的

次の3点を本人のApple Accountで作成し、Bundle IDとTeamの不一致をTestFlightアップロード前に検出します。

1. Apple Distribution証明書と秘密鍵を含む`.p12`
2. App Store Connect用`.mobileprovision`
3. App Store Connect APIキー`.p8`

初回提出をXcode Organizerだけで行う場合、APIキーは不要です。GitHub Actions代替経路を使う場合だけAPIキーを作成します。

## 重要な分岐

### 推奨：MacinCloud／Xcode Automatic Signing

初回提出ではこちらを優先します。

- XcodeへApple Accountを追加
- RunnerのTeamを選択
- Automatically manage signingを有効化
- Xcodeが配布プロビジョニングプロファイルを管理
- Product → Archive
- Organizer → Generate Privacy Report
- Validate App
- TestFlight & App Store → Upload

この経路では手動の`.mobileprovision`作成やGitHubへの署名Secret登録は不要です。

### 代替：GitHub Actions Manual Signing

継続的なBuildアップロードに使用します。

- Apple Distribution `.p12`
- App Store Connect `.mobileprovision`
- App Store Connect API `.p8`
- GitHub Environment secrets

が必要です。

## 1. CSRを作成

MacinCloudのMacでKeychain Accessを開きます。

1. `/Applications/Utilities/Keychain Access`
2. Keychain Access → Certificate Assistant
3. Request a Certificate from a Certificate Authority
4. User Email AddressへApple Accountのメールアドレス
5. Common Nameへ`Kohei Morita AI Handover Distribution`
6. CA Email Addressは空欄
7. Saved to disk
8. `AI_Handover_Distribution.certSigningRequest`として保存

CSRを作成したMacの秘密鍵は削除しないでください。別のMacで証明書をダウンロードしても、元の秘密鍵がなければ`.p12`へ書き出せません。

## 2. Apple Distribution証明書を作成

Apple Developer → Certificates, Identifiers & Profiles → Certificates → ＋

- Software
- Apple Distribution
- CSRをアップロード
- 証明書をダウンロード
- `.cer`をダブルクリックしてKeychainへ追加

配布証明書を作成できるのはAccount HolderまたはAdminです。

Keychain Access → My Certificatesで、Apple Distribution証明書の下に秘密鍵が表示されることを確認します。

証明書と秘密鍵を選択してExportし、次の名前で保存します。

`AI_Handover_Apple_Distribution.p12`

ランダムで長い書き出しパスワードを設定し、パスワード管理アプリへ保存してください。

## 3. App Store Connectプロファイルを作成

この工程はGitHub Actions代替経路を使う場合に実施します。

Apple Developer → Profiles → ＋

- Distribution
- App Store Connect
- App ID：`AI引継ぎ帳` / `jp.allsunday.aihandoverlog`
- Distribution Certificate：直前に作成したApple Distribution証明書
- Profile Name：`AI Handover Log App Store Build 6`
- Generate
- Download

ファイル名例：

`AI_Handover_Log_AppStore_Build6.mobileprovision`

App Store Connect用プロファイルは1つの配布証明書を含みます。Account HolderまたはAdminが作成できます。

## 4. App Store Connect APIを有効化

GitHub Actions代替経路を使わない場合は不要です。

App Store Connect → Users and Access → Integrations

API利用が未承認の場合：

- Account HolderでRequest Access
- 規約へ同意
- Submit
- Appleの承認完了を確認

## 5. Team API Keyを作成

API利用承認後：

1. Users and Access
2. Integrations
3. Team Keys
4. Generate API Key
5. Name：`AI Handover TestFlight Upload`
6. Access：`Developer`
7. Generate
8. Key IDとIssuer IDを記録
9. `.p8`を即時ダウンロード

秘密鍵は一度しかダウンロードできません。ファイル名を変更せず、`AuthKey_<Key ID>.p8`として保管します。

Team API Keyは全アプリへ適用され、特定アプリだけに制限できません。不要になった場合はRevokeします。

## 6. ローカル検証

MacinCloudで既存の検証スクリプトを実行します。

```bash
chmod +x scripts/validate_apple_release_credentials_macos.sh

scripts/validate_apple_release_credentials_macos.sh \
  --certificate "/安全な保存先/AI_Handover_Apple_Distribution.p12" \
  --profile "/安全な保存先/AI_Handover_Log_AppStore_Build6.mobileprovision" \
  --api-key "/安全な保存先/AuthKey_XXXXXXXXXX.p8" \
  --team-id "ABCDEFGHIJ" \
  --key-id "XXXXXXXXXX" \
  --issuer-id "00000000-0000-0000-0000-000000000000"
```

`.p12`パスワードは画面に表示されない入力欄で求められます。

検証対象：

- Apple Distribution証明書
- `.p12`内の秘密鍵
- 証明書のTeam ID
- 証明書期限
- プロファイルに対象証明書が含まれること
- プロファイルのTeam ID
- `application-identifier`
- Bundle ID
- `get-task-allow=false`
- 端末UDIDが入っていないこと
- Enterprise profileではないこと
- プロファイル期限
- `.p8`からのES256 JWT生成
- Key IDとIssuer ID
- 通常実行時のApp Store Connect API認証

出力JSONにはパスワードや秘密鍵の内容を保存しません。ネットワーク接続なしでJWT生成だけを検査する場合は、末尾に`--offline-api`を追加します。

## 7. 保管

推奨する保管先：

- MacinCloudの暗号化された一時保存領域
- 個人のパスワード管理アプリ
- 暗号化した外部保管

避ける場所：

- GitHubの通常ファイル
- PR、Issue、Actions Artifact
- ChatGPT
- Notion
- Google Driveの共有フォルダ
- メール添付
- WindowsのDownloadsへ平文で長期保存

GitHub Actionsへ登録する場合は、Environment `testflight-production`のSecretsだけを使います。

## 8. 漏えい・紛失時

- `.p8`を紛失または漏えい：App Store Connectで即時Revoke
- `.p12`または秘密鍵が漏えい：Apple Developerで証明書をRevokeし、新しい証明書とプロファイルを作成
- GitHub Actionsログへ秘密が出た：ログを削除し、関係する全Secretをローテーション
- 不要になったAPIキーと証明書：削除またはRevoke

## 現在の状態

この手順を既存のCI検証済みツールへ統合しました。

- 実際の証明書：未作成
- 実際のプロファイル：未作成
- 実際のAPIキー：未作成
- GitHub Environment secrets：未登録
- Apple署名：未実施
- TestFlightアップロード：未実施
