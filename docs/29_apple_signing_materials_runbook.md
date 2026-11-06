# AI引継ぎ帳 Apple署名素材作成・検査ランブック

作成日：2026年7月24日

## 対象

- App：AI引継ぎ帳
- Bundle ID：`jp.allsunday.aihandoverlog`
- Version：`0.6.0`
- Build：`6`
- 用途：MacinCloudまたはGitHub ActionsからApp Store Connectへ署名済みBuildをアップロード

## 1. CSRを作成

MacinCloud上でKeychain Accessを開きます。

1. `Keychain Access`
2. `Certificate Assistant`
3. `Request a Certificate from a Certificate Authority`
4. User Email Address：Apple Developer Programで使用するメール
5. Common Name：`Kohei Morita Apple Distribution 2026`
6. CA Email Address：空欄
7. `Saved to disk`
8. `.certSigningRequest`を安全な作業フォルダへ保存

CSRを作成したMacのキーチェーンには秘密鍵が残ります。Appleから受け取る`.cer`だけを別のMacへ移しても、対応する秘密鍵がなければ`.p12`へ書き出せません。

## 2. Apple Distribution証明書

Apple Developer → Certificates, Identifiers & Profiles → Certificates → `+`

1. `Apple Distribution`を選択
2. 作成したCSRをアップロード
3. 証明書`.cer`をダウンロード
4. 同じMacinCloud環境で`.cer`をダブルクリック
5. Keychain Accessの`My Certificates`を開く
6. `Apple Distribution: ...`の下に秘密鍵が表示されることを確認
7. 証明書と秘密鍵を選択
8. Export Itemsで`.p12`へ書き出す
9. 強い書き出しパスワードを設定

`.p12`とパスワードは別々に保管します。

## 3. App Store Connectプロビジョニングプロファイル

前提：

- Explicit App ID `jp.allsunday.aihandoverlog`
- Apple Distribution証明書
- Account HolderまたはAdmin権限

Apple Developer → Profiles → `+`

1. Distributionの`App Store Connect`
2. App ID `jp.allsunday.aihandoverlog`
3. 作成したApple Distribution証明書
4. Profile Name：`AI Handover Log App Store 2026`
5. Generate
6. `.mobileprovision`をダウンロード

Automatic Signingを使うMacinCloud通常経路では、Xcodeがプロファイルを管理できます。GitHub Actionsの手動署名経路では、このプロファイルを使用します。

## 4. App Store Connect APIキー

App Store Connect → Users and Access → Integrations → App Store Connect API

初回のみAccount HolderがAPIアクセスをRequestします。承認後、Account HolderまたはAdminがTeam API keyを作成します。

推奨値：

- Name：`AI Handover TestFlight Upload`
- Access：`Developer`

作成後に記録：

- Key ID
- Issuer ID
- `AuthKey_<KEY_ID>.p8`

`.p8`は一度しかダウンロードできません。紛失・漏えい時は直ちにRevokeします。

## 5. ローカル検査

同梱スクリプトをMacinCloudで実行します。

```bash
chmod +x inspect_apple_signing_materials_macos.sh

./inspect_apple_signing_materials_macos.sh \
  --certificate "/安全な場所/AppleDistribution.p12" \
  --profile "/安全な場所/AI_Handover_Log_AppStore.mobileprovision" \
  --api-key "/安全な場所/AuthKey_XXXXXXXXXX.p8" \
  --team-id "ABCDEFGHIJ" \
  --key-id "KLMNOPQRST" \
  --issuer-id "00000000-0000-0000-0000-000000000000"
```

`.p12`パスワードは非表示で入力します。

検査内容：

- `.p12`にApple Distribution証明書と秘密鍵がある
- 証明書が有効期限内
- ProfileのTeam IDが一致
- ProfileのBundle IDが一致
- Development、Ad Hoc、Enterprise Profileでない
- Profileに同じDistribution証明書が含まれる
- Profileが有効期限内
- `.p8`が解析可能な秘密鍵
- Key ID、Issuer IDの形式
- API鍵ファイル名とKey IDの一致

検査結果には秘密鍵・パスワード・Base64データを含めません。

## 6. GitHub Environmentへ登録

検査合格後に、既作成の次のスクリプトを使用します。

`configure_github_testflight_environment_macos.sh`

GitHub Environment：

`testflight-production`

秘密情報をChatGPT、Notion、Issue、PRコメント、通常のWorkflow Artifactへ貼り付けないでください。

## 7. 失効・更新ルール

次の場合はApple DeveloperとApp Store Connectで失効し、再作成します。

- `.p12`またはパスワードの漏えい
- `.p8`の紛失または漏えい
- GitHub Secretへ誤った値を登録
- 証明書またはProfileの期限切れ
- Team ID、Bundle ID、証明書の不一致
- 退職者や不要ユーザーが鍵へアクセスできる状態

APIキーの名前や権限は作成後に編集できません。変更が必要な場合はRevokeして再作成します。

## 8. 現在の未完了

- App ID登録
- App Store Connectアプリレコード作成
- Apple Distribution証明書作成
- App Store Connect Profile作成
- App Store Connect APIキー作成
- ローカル検査
- GitHub Environment secrets登録
- Apple署名付きArchive
- TestFlightアップロード
