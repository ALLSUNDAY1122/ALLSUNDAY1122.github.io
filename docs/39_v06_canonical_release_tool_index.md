# AI引継ぎ帳 v0.6 正規リリースツール索引

作成日：2026年7月24日

## 目的

PR #870には開発過程で作成した複数の署名・検証スクリプトがあります。この文書で、本人が使用する正規ツールと用途を固定します。

操作時は原則として次を使用します。

`./scripts/ai_handover_release_tool_macos.sh`

## 初回提出の正規経路

初回提出ではGitHub Actionsではなく、MacinCloudのXcode Organizerを優先します。

1. Apple DeveloperでExplicit App IDを作成
2. App Store Connectでアプリレコードを作成
3. 修正版FlutterプロジェクトをMacinCloudへ配置
4. XcodeへApple Accountでサインイン
5. TeamとAutomatically manage signingを設定
6. 統合入口の`archive`を実行
7. Xcode OrganizerでGenerate Privacy Report
8. Validate App
9. TestFlight & App StoreへUpload
10. iPhone 16で受入テスト40件

実行：

```bash
DEVELOPMENT_TEAM=実際のTeamID \
  ./scripts/ai_handover_release_tool_macos.sh archive \
  --project-dir "/Users/ユーザー名/Projects/AI_Handover_Log_Flutter_v0.6"
```

この経路ではApp Store Connect APIキー、手動プロビジョニングプロファイル、`.p12`は原則不要です。

## GitHub Actions代替経路

将来の更新版やMacinCloud障害時に使用します。

### 1. CSR

```bash
./scripts/ai_handover_release_tool_macos.sh csr \
  --email Apple Developerに登録したメール
```

正規実体：

`scripts/generate_apple_distribution_csr_macos.sh`

出力された`.certSigningRequest`だけをAppleへアップロードします。`.key.pem`は秘密鍵であり外部へ送信しません。

### 2. P12

AppleからダウンロードしたApple Distribution `.cer`を使います。

```bash
./scripts/ai_handover_release_tool_macos.sh p12 \
  --private-key /secure/AppleDistribution.key.pem \
  --certificate ~/Downloads/distribution.cer
```

正規実体：

`scripts/build_apple_distribution_p12_macos.sh`

秘密鍵と証明書の公開鍵を比較してから`.p12`を作成します。

### 3. オフライン検証

```bash
./scripts/ai_handover_release_tool_macos.sh verify-offline ...
```

正規実体：

`scripts/verify_apple_signing_assets_macos.sh`

確認内容：

- Apple Distribution証明書
- 証明書のTeam ID
- 証明書と秘密鍵の一致
- App Store profileのTeam ID、Bundle ID、期限、種別
- profile内の証明書一致
- API `.p8`のPKCS#8、EC P-256形式
- Key IDとファイル名

Appleへ通信しません。

### 4. オンライン認証検証

```bash
./scripts/ai_handover_release_tool_macos.sh verify-online ...
```

正規実体：

`scripts/validate_apple_release_credentials_macos.sh`

上記に加えて短時間のJWTを作成し、App Store Connect APIへ認証します。APIアクセスがまだ承認されていない場合は`--offline-api`を使用します。

### 5. GitHub Environment登録

すべての検証が合格した後だけ実行します。

```bash
./scripts/ai_handover_release_tool_macos.sh configure-github ...
```

正規実体：

`scripts/configure_github_testflight_environment_macos.sh`

登録先：

`testflight-production`

## 内部・互換ツール

以下は開発過程の個別検査、CI、互換用途で残しますが、本人操作の正規入口にはしません。

- `scripts/validate_apple_signing_assets_macos.sh`
- `scripts/inspect_apple_signing_materials_macos.sh`
- `scripts/validate_apple_release_credentials_macos.sh`の直接実行
- 個別のCI補助スクリプト

削除すると既存CIや記録との参照関係を壊す可能性があるため、初回提出前には削除しません。

## 選択基準

| 状況 | 使用コマンド |
|---|---|
| 初回App Store提出 | `archive` |
| CSRを作る | `csr` |
| Appleの`.cer`から`.p12`を作る | `p12` |
| Appleへ接続せず署名資産を検査 | `verify-offline` |
| API Key IDとIssuer IDを含め認証確認 | `verify-online` |
| GitHub Actions用Secret登録 | `configure-github` |

## 秘密情報の扱い

次をChatGPT、GitHub、Notion、メール、共有フォルダへ貼り付けません。

- Apple Accountパスワード
- 2ファクタ認証コード
- CSR秘密鍵
- `.p12`
- `.p12`パスワード
- `.mobileprovision`
- `.p8`
- GitHub Environment secretの値

ChatGPTへ共有してよいのは、各ツールが生成した`report.json`や`summary.txt`など、`sensitive_values_in_report=false`または`secrets_in_report=false`の非秘密レポートだけです。

## 現在の状態

- 正規入口：作成済み
- 初回経路：MacinCloud／Xcode Organizer
- GitHub Actions経路：代替・未実行
- Apple署名資産：未作成
- Apple秘密情報：GitHub未登録
- TestFlightアップロード：未実施
- PR #870：ドラフト・未マージ
