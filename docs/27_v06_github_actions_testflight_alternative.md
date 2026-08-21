# AI引継ぎ帳 v0.6 GitHub Actions署名・TestFlight代替経路

作成日：2026年7月24日

## 位置づけ

MacinCloudのXcode Organizerで実行する通常経路に加え、GitHub ActionsのmacOS runnerで署名、IPA書き出し、Transporterアップロードを行う代替経路です。

現時点ではテンプレートのみをPR #870へ追加します。`workflow_dispatch`はワークフローファイルがdefault branchに存在する必要があるため、PR #870が明示的な指示でmainへマージされるまではGitHub画面から実行できません。

## 安全設計

- 手動実行専用
- 確認欄へ`UPLOAD`と入力した場合だけ実行
- GitHub Environment `testflight-production`を使用
- EnvironmentのRequired reviewer設定を推奨
- 証明書、プロビジョニングプロファイル、API秘密鍵はEnvironment secretsだけに保存
- runner上では一時キーチェーンへ展開
- 完了・失敗を問わず秘密ファイルを削除
- IPA、Archive、証明書、プロファイル、秘密鍵をWorkflow Artifactへ保存しない
- 非秘密の検証結果とTransporterログだけを30日間保存
- mainへのマージ、App Store提出、公開を自動実行しない
- TestFlightアップロードまで。App Review提出は別途手動

## Apple側で事前に必要なもの

1. 最新契約への同意
2. Explicit App ID `jp.allsunday.aihandoverlog`
3. App Store Connectの「AI引継ぎ帳」アプリレコード
4. Apple Distribution証明書
5. 同じBundle IDのApp Store Connect provisioning profile
6. App Store Connect APIへのアクセス
7. Developer権限のTeam API key
8. API Key ID、Issuer ID、1回だけダウンロードできる`.p8`

AppleのBuildアップロードはAccount Holder、Admin、App Manager、Developerが実行できます。APIアクセスの初回リクエストはAccount Holder、Team API keyの作成はAccount HolderまたはAdminが必要です。

## GitHub Environment

リポジトリのSettings → Environmentsで次を作成します。

`testflight-production`

推奨設定：

- Required reviewers：本人または管理者
- Prevent self-review：一人運用では無効
- Deployment branches：Protected branches only、またはmainだけ

Environment secretsは承認されるまでJobへ渡されません。

## 必須Environment secrets

| Secret | 内容 |
|---|---|
| `APPLE_TEAM_ID` | Apple Developerの10文字Team ID |
| `APPLE_DISTRIBUTION_CERTIFICATE_P12_BASE64` | Apple Distribution証明書`.p12`のBase64 |
| `APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD` | `.p12`書き出し時のパスワード |
| `APPLE_PROVISIONING_PROFILE_BASE64` | App Store Connect用`.mobileprovision`のBase64 |
| `APPLE_TEMP_KEYCHAIN_PASSWORD` | runner用一時キーチェーンのランダムパスワード |
| `APP_STORE_CONNECT_API_KEY_P8_BASE64` | `AuthKey_XXXXXXXXXX.p8`のBase64 |
| `APP_STORE_CONNECT_API_KEY_ID` | 10文字のAPI Key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID |

これらをリポジトリファイル、Issue、PRコメント、ChatGPT、Notionへ貼り付けないでください。

## 証明書とプロファイル

Apple DeveloperでApple Distribution証明書を作成し、秘密鍵を含む`.p12`としてMacのKeychain Accessから書き出します。

ProfilesではDistribution → App Store Connectを選び、App ID `jp.allsunday.aihandoverlog`と配布証明書を指定して`.mobileprovision`を作成します。

Automatic Signingを使う通常経路ではXcodeがプロファイルを管理できますが、このGitHub Actions代替経路では再現性を優先して手動署名用プロファイルをEnvironment secretへ登録します。

## App Store Connect API Key

Users and Access → Integrations → App Store Connect APIからTeam API keyを作成します。

推奨ロール：`Developer`

秘密鍵`.p8`は1回しかダウンロードできません。紛失または漏えいが疑われる場合は直ちにRevokeしてください。

## Secret登録補助

同梱の`configure_github_testflight_environment_macos.sh`をMacinCloudで実行できます。

必要条件：

- GitHub CLI `gh`
- `gh auth login`済み
- `.p12`
- `.mobileprovision`
- `AuthKey_XXXXXXXXXX.p8`
- Team ID、Key ID、Issuer ID

スクリプトは値を画面表示せず、Base64を一時ファイルへ保存せずに`gh secret set --env testflight-production`へ送ります。

## 実行

PR #870を明示的な指示でmainへマージした後：

1. GitHub → Actions
2. `AI Handover Log v0.6 Signed TestFlight Upload`
3. Run workflow
4. Branchはmain
5. confirmationへ`UPLOAD`
6. Environment承認
7. Workflow完了
8. App Store Connect → TestFlight → Build Uploads
9. `0.6.0 (6)`がProcessingからCompleteになることを確認

## ワークフローの自動検査

- Secretの存在
- Team ID、Key IDの形式
- ソースアーカイブSHA-256
- iPhone専用化
- Portrait固定
- App-level Privacy Manifest
- プロファイルのTeam ID
- プロファイルのapplication-identifier
- Development profileの誤登録
- Flutter Analyze
- Flutter Test 16件
- arm64 Release
- Apple Distribution署名
- Bundle ID、Version、Build
- `UIDeviceFamily=[1]`
- Portraitのみ
- 暗号化申告false
- 全Privacy Manifestのplist検査
- IPA SHA-256
- Transporterアップロード

## 実行後

Transporterが受領しても、App Store Connectの処理完了は別工程です。BuildがCompleteになるまで、iPhone 16受入テストやApp Review提出へ進みません。

## 通常経路との比較

MacinCloud/Xcode Organizer経路：

- Apple推奨UIで状況を確認しやすい
- Generate Privacy ReportとValidate Appを操作しやすい
- 初回提出向き

GitHub Actions経路：

- 一度Secretを設定すれば再ビルドを繰り返しやすい
- Build番号を上げる更新版で有効
- 認証情報管理を誤ると影響が大きい
- 初回はMacinCloud経路を優先し、代替・継続運用として保持する
