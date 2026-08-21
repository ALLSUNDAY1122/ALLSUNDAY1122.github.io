# AI引継ぎ帳 v0.6 Apple配布資格情報の作成・検証手順

作成日：2026年7月24日

## 対象

- Bundle ID：`jp.allsunday.aihandoverlog`
- Version：`0.6.0`
- Build：`6`
- 用途：MacinCloud署名、またはGitHub Actions TestFlight代替経路

## 推奨順序

1. Explicit App IDを登録
2. App Store Connectでアプリレコードを作成
3. Apple Distribution証明書を確認または作成
4. App Store Connect provisioning profileを作成
5. App Store Connect APIへのアクセスを有効化
6. Team API keyを作成
7. `.p12`、`.mobileprovision`、`.p8`を検証
8. 検証合格後にGitHub Environment secretsへ登録

## Apple Distribution証明書

既存の有効なApple Distribution証明書と秘密鍵がXcode／キーチェーンにある場合は再利用する。不要な証明書を増やさない。

新規作成する場合：

1. MacinCloudでKeychain Accessを開く
2. Certificate Assistant → Request a Certificate From a Certificate Authority
3. Apple Developer Programで使用するメールを入力
4. Common Name：`Kohei Morita AI Handover Log`
5. Saved to disk
6. Apple DeveloperのCertificatesで`Apple Distribution`を選択
7. CSRをアップロード
8. `.cer`をダウンロードして同じキーチェーンへ追加
9. My Certificatesで秘密鍵が展開表示されることを確認
10. 証明書と秘密鍵を`.p12`として書き出す
11. 強い`.p12`パスワードを設定する

Apple Distribution証明書の作成権限はAccount HolderまたはAdmin。個人登録では本人がAccount Holder。

## App Store Connect provisioning profile

Apple Developer → Profiles → ＋を開く。

- Distribution：`App Store Connect`
- App ID：`jp.allsunday.aihandoverlog`
- Certificate：上記Apple Distribution証明書
- Profile Name：`AI Handover Log App Store 0.6`

Generate後、`.mobileprovision`をダウンロードする。

検証条件：

- Team IDがApple Developer Team IDと一致
- application-identifierが`TEAMID.jp.allsunday.aihandoverlog`
- `get-task-allow`がtrueではない
- 登録端末一覧を含まない
- Enterprise profileではない
- Apple Distribution証明書を含む

Automatic Signingを使うMacinCloud通常経路ではXcodeに管理を任せられる。手動profileはGitHub Actions代替経路で使用する。

## App Store Connect API key

App Store Connect → Users and Access → Integrations → App Store Connect APIを開く。

初回APIアクセスはAccount Holderがリクエストする。アクセス承認後、Account HolderまたはAdminがTeam API keyを作成する。

推奨入力：

- Name：`AI Handover Log GitHub TestFlight`
- Access：`Developer`

記録する値：

- Key ID：10文字
- Issuer ID：UUID
- `AuthKey_KEYID.p8`

`.p8`は一度しかダウンロードできないため、安全な保管場所へ保存する。不要になったキーや漏えいの疑いがあるキーはRevokeする。

## 検証コマンド

```bash
chmod +x scripts/validate_apple_release_credentials_macos.sh
chmod +x scripts/verify_app_store_connect_api_key.py

./scripts/validate_apple_release_credentials_macos.sh \
  --certificate "/Users/ユーザー名/Secure/AppleDistribution.p12" \
  --profile "/Users/ユーザー名/Secure/AI_Handover_Log_AppStore.mobileprovision" \
  --api-key "/Users/ユーザー名/Secure/AuthKey_XXXXXXXXXX.p8" \
  --team-id "ABCDEFGHIJ" \
  --key-id "KLMNOPQRST" \
  --issuer-id "00000000-0000-0000-0000-000000000000"
```

`.p12`パスワードは画面表示されずに入力する。

APIへ接続しない構造確認：

```bash
./scripts/validate_apple_release_credentials_macos.sh ... --offline-api
```

## 自動検証内容

- `.p12`を開けること
- Apple Distribution証明書であること
- 有効期限
- 秘密鍵が含まれること
- `.mobileprovision`の署名とplist
- Team ID
- Bundle ID
- Development／Ad Hoc／Enterprise profileではないこと
- Profile内証明書と`.p12`が一致すること
- `.p8`秘密鍵形式
- ES256 JWT生成
- App Store Connect API認証
- 各ファイルSHA-256

## 出力

`apple_credential_validation`フォルダ：

- `apple-release-credential-validation.json`
- `app-store-connect-api-validation.json`

出力に含めないもの：

- `.p12`パスワード
- 一時キーチェーンパスワード
- 秘密鍵本文
- JWT
- API秘密鍵
- 証明書・profile本体

## 停止条件

- Apple Distributionではない
- 秘密鍵を含まない
- 証明書が失効または期限切れ
- Team ID不一致
- Bundle ID不一致
- Development／Ad Hoc／Enterprise profile
- Profileに証明書が含まれない
- API認証が401／403

## 合格後

GitHub Actions代替経路を使う場合のみ、`scripts/configure_github_testflight_environment_macos.sh`でEnvironment secretsを登録する。

初回提出は、Privacy ReportとValidate Appを画面で確認しやすいMacinCloud／Xcode Organizer経路を優先する。
