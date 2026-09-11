# AI引継ぎ帳 v0.6 Apple Distribution CSR・P12作成手順

作成日：2026年7月24日

## 目的

Apple Distribution証明書用のCSRをMacinCloud上で作成し、Appleからダウンロードした`.cer`と秘密鍵の一致を確認して、GitHub Actions署名経路で使う`.p12`を作成します。

対象：

- Bundle ID：`jp.allsunday.aihandoverlog`
- Version：`0.6.0`
- Build：`6`

## 推奨経路

初回提出のMacinCloud／Xcode Organizer経路では、XcodeのAutomatically manage signingを優先します。Xcodeが有効なApple Distribution証明書と配布プロファイルを管理できる場合、手動`.p12`作成は不要です。

次の場合だけ本手順を使用します。

- GitHub Actions TestFlight代替経路を設定する
- Xcodeの自動署名で証明書を取得できない
- 署名資産を明示的に管理する必要がある

## Apple公式GUI経路

Appleが案内するCSR作成方法はKeychain Accessです。

1. MacinCloudでKeychain Accessを開く
2. Certificate Assistant
3. Request a Certificate from a Certificate Authority
4. Apple Developerで使用するメールを入力
5. Common Name：`Kohei Morita AI Handover Log`
6. CA Email Addressは空欄
7. Saved to disk
8. `.certSigningRequest`をApple Developerへアップロード

この経路では秘密鍵がキーチェーンに保存されます。Appleから取得した`.cer`を同じMacへインストールし、My Certificatesで証明書の下に秘密鍵が表示されることを確認して`.p12`へ書き出します。

## コマンド補助経路

同梱スクリプトは暗号化されたRSA 2048ビット秘密鍵とPKCS#10 CSRを作成します。

```bash
chmod +x scripts/generate_apple_distribution_csr_macos.sh

./scripts/generate_apple_distribution_csr_macos.sh \
  --email "Apple Developerで使用するメール" \
  --common-name "Kohei Morita AI Handover Log" \
  --output "$HOME/Secure/AIHandoverSigning"
```

生成物：

- `AppleDistribution.key.pem`
- `AppleDistribution.certSigningRequest`
- `AppleDistribution.csr-report.json`

Appleへアップロードするのは`.certSigningRequest`だけです。`AppleDistribution.key.pem`はアップロードしません。

## Apple Distribution証明書の発行

1. Apple Developer → Certificates, Identifiers & Profiles
2. Certificates → ＋
3. Apple Distribution
4. CSRをアップロード
5. Continue
6. `.cer`をダウンロード

Apple Distribution証明書はApp Store Connectへの提出に使用します。作成権限はAccount HolderまたはAdminです。

## `.p12`作成

Appleから取得した`.cer`と、CSR生成時の暗号化秘密鍵を指定します。

```bash
chmod +x scripts/build_apple_distribution_p12_macos.sh

./scripts/build_apple_distribution_p12_macos.sh \
  --private-key "$HOME/Secure/AIHandoverSigning/AppleDistribution.key.pem" \
  --certificate "$HOME/Downloads/distribution.cer" \
  --output "$HOME/Secure/AIHandoverSigning/AppleDistribution.p12"
```

自動確認：

- `.cer`がX.509として読める
- SubjectにApple Distributionを含む
- 7日以内に期限切れにならない
- 証明書の公開鍵とCSR秘密鍵が一致
- `.p12`に秘密鍵が含まれる
- `.p12`がパスワード保護されている
- 秘密情報を含まない監査JSONを作成

## App Store Connect provisioning profile

Apple Developer → Profiles → ＋で次を選びます。

- Distribution：App Store Connect
- App ID：`jp.allsunday.aihandoverlog`
- Certificate：上記Apple Distribution証明書
- Profile Name：`AI Handover Log App Store 0.6`

Apple公式では、App Store Connect用profileには明示的App IDと1つのdistribution certificateが必要です。Automatic Signingの場合はXcodeがprofileを管理します。

## App Store Connect API key

GitHub Actions代替経路だけで使用します。

1. App Store Connect → Users and Access
2. Integrations
3. App Store Connect API
4. 初回はAccount Holderがアクセスをリクエスト
5. Team Keys → Generate API Key
6. Name：`AI Handover Log GitHub TestFlight`
7. Role：Developer
8. Key IDとIssuer IDを記録
9. `.p8`を1回だけダウンロード

秘密鍵は一度しかダウンロードできません。紛失または漏えいの疑いがある場合はRevokeします。

## 3資産の最終検証

```bash
./scripts/validate_apple_release_credentials_macos.sh \
  --certificate "$HOME/Secure/AIHandoverSigning/AppleDistribution.p12" \
  --profile "$HOME/Secure/AIHandoverSigning/AI_Handover_Log_AppStore.mobileprovision" \
  --api-key "$HOME/Secure/AIHandoverSigning/AuthKey_XXXXXXXXXX.p8" \
  --team-id "ABCDEFGHIJ" \
  --key-id "KLMNOPQRST" \
  --issuer-id "00000000-0000-0000-0000-000000000000"
```

合格表示：

`APPLE_RELEASE_CREDENTIALS_VALID`

## 秘密資産の保管

秘密情報：

- `AppleDistribution.key.pem`
- `AppleDistribution.p12`
- `.p12`パスワード
- `AuthKey_XXXXXXXXXX.p8`
- GitHub Environment secretの値

これらはGitHubリポジトリ、PR、Issue、ChatGPT、Notion、メールへ貼り付けません。

`AppleDistribution.certSigningRequest`、`.cer`、`.mobileprovision`も公開しません。秘密鍵そのものではありませんが、署名体制の情報を含むため、公開リポジトリへ置かない方針です。

## 停止条件

- Apple DeveloperのApp IDが未登録
- 証明書SubjectがApple Distributionではない
- `.cer`と秘密鍵が一致しない
- 証明書の期限切れ
- ProfileのTeam IDまたはBundle IDが不一致
- Development、Ad Hoc、Enterprise profile
- API認証が401または403
