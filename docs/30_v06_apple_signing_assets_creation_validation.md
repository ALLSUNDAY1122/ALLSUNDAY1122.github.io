# AI引継ぎ帳 v0.6 Apple署名資産作成・検証手順

作成日：2026年7月24日

## 重要

初回提出をMacinCloudのXcode Organizerから行う場合、App Store Connect APIキーは不要です。XcodeへApple Accountでサインインし、Automatically manage signingを有効にする通常経路を優先します。

この資料はGitHub Actions代替経路を使用するときのためのものです。

## 必要な資産

1. Apple Distribution証明書と秘密鍵を含む`.p12`
2. Bundle ID `jp.allsunday.aihandoverlog`用のApp Store Connect provisioning profile
3. App Store Connect API Keyの`.p8`
4. 10文字のTeam ID
5. 10文字のAPI Key ID
6. Issuer ID

## 1. Apple Distribution証明書

Apple Distribution証明書はApp Storeへの提出に使用します。Apple公式ではAccount HolderまたはAdminが作成できます。

### 推奨方法：Xcode

1. MacinCloudでXcodeを起動
2. Xcode → Settings → Accounts
3. Apple Accountを追加
4. Teamを選択
5. Manage Certificates
6. 左下の`+`
7. Apple Distribution

既存の有効なApple Distribution証明書が表示される場合、むやみに追加・失効しないでください。Distribution証明書はチーム資産です。

### `.p12`の書き出し

1. Keychain Accessを開く
2. `login`キーチェーン
3. My Certificates
4. `Apple Distribution: ...`の左側を展開
5. 配下に秘密鍵があることを確認
6. 証明書と秘密鍵を選択
7. Export 2 items
8. Personal Information Exchange `.p12`
9. 強い書き出しパスワードを設定

証明書だけを選択して書き出すと秘密鍵が含まれず、GitHub Actionsでは署名できません。

## 2. App Store Connect provisioning profile

手動署名用プロファイルはAccount HolderまたはAdminが作成します。

1. Apple Developer → Certificates, Identifiers & Profiles
2. Profiles
3. `+`
4. Distribution → App Store Connect
5. App ID `jp.allsunday.aihandoverlog`
6. 使用するApple Distribution証明書
7. Profile Name：`AI Handover Log App Store Build 6`
8. Generate
9. Download

プロファイルは単一の配布用証明書を含みます。後から証明書を変更・失効した場合は、プロファイルも再生成します。

## 3. App Store Connect APIキー

APIアクセスの初回申請はAccount Holderが行います。Team API keyの作成はAccount HolderまたはAdminです。

1. App Store Connect
2. Users and Access
3. Integrations
4. 初回だけRequest Access
5. Team Keys
6. Generate API Key
7. Name：`GitHub TestFlight AI Handover Log`
8. Access：Developer
9. Generate
10. `.p8`を1回だけダウンロード
11. Key IDとIssuer IDを記録

`.p8`は再ダウンロードできません。紛失・漏えい時はRevokeし、新しいキーを作成します。

個人APIキーも作成できますが、継続運用では役割と管理者による失効管理が明確なTeam API keyを使用する方針です。

## 4. 検証

同梱ファイルを同じフォルダへ配置します。

- `verify_apple_signing_assets_macos.sh`
- `verify_apple_provisioning_profile.py`

実行例：

```bash
chmod +x verify_apple_signing_assets_macos.sh
chmod +x verify_apple_provisioning_profile.py

./verify_apple_signing_assets_macos.sh \
  --p12 "/Users/ユーザー名/Desktop/AppleDistribution.p12" \
  --profile "/Users/ユーザー名/Desktop/AI_Handover_Log_App_Store.mobileprovision" \
  --api-key "/Users/ユーザー名/Desktop/AuthKey_XXXXXXXXXX.p8" \
  --team-id "ABCDEFGHIJ" \
  --key-id "XXXXXXXXXX" \
  --issuer-id "00000000-0000-0000-0000-000000000000"
```

`.p12`パスワードは画面へ表示されずに入力します。

## 自動検査内容

### 証明書

- `.p12`が開ける
- Apple Distribution証明書
- Team ID一致
- 有効期限内
- 秘密鍵あり
- 証明書と秘密鍵が一致

### プロビジョニングプロファイル

- Team ID一致
- application-identifierが`TEAMID.jp.allsunday.aihandoverlog`
- `.p12`の証明書を含む
- 有効期限内
- `get-task-allow=false`
- 登録端末リストなし
- Enterprise用ではない
- `beta-reports-active=true`

### APIキー

- PKCS#8 `.p8`
- EC P-256秘密鍵
- Key IDとファイル名の対応
- Issuer IDの形式

## レポート

検証結果として次だけを保存します。

- 証明書のSubject、期限、指紋
- Team ID
- プロファイル名、UUID、期限、Bundle ID
- API Key ID、Issuer ID、ファイルSHA-256
- 各検査の合否

次は保存しません。

- 証明書の秘密鍵
- `.p12`パスワード
- `.p8`の内容
- GitHub Secretの値
- Apple Accountの認証情報

## 合格後

GitHub Actions代替経路を使う場合だけ、`configure_github_testflight_environment_macos.sh`でEnvironment secretsへ登録します。

初回提出では、先にMacinCloudのXcode Organizer経路を実行し、Generate Privacy ReportとValidate Appを画面で確認することを推奨します。
