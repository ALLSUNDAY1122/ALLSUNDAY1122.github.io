# AI引継ぎ帳 v0.6 Apple登録完了証跡

作成日：2026年7月24日

## 目的

本人がApple DeveloperとApp Store Connectで登録操作を終えた後、秘密情報をChatGPT、GitHub、Notionへ渡さずに、登録結果だけを証跡として保存します。

## 前提

以下が完了していること。

1. Explicit App ID `jp.allsunday.aihandoverlog`
2. App Store Connectのアプリレコード
3. Apple Distribution証明書
4. App Store Connect provisioning profile
5. App Store Connect API key（GitHub Actions代替経路を使う場合）

Apple Distribution証明書とApp Store Connect provisioning profileを作成できるのは、原則としてAccount HolderまたはAdminです。App Store Connect APIへの初回アクセス申請はAccount Holder、Team API keyの作成はAccount HolderまたはAdminが行います。

## 実行

MacinCloudの安全なローカルフォルダで実行します。

```bash
chmod +x scripts/capture_apple_release_evidence_macos.sh

./scripts/capture_apple_release_evidence_macos.sh \
  --p12 "$HOME/Secure/AIHandoverSigning/AppleDistribution.p12" \
  --profile "$HOME/Secure/AIHandoverSigning/AI_Handover_Log_AppStore.mobileprovision" \
  --api-key "$HOME/Secure/AIHandoverSigning/AuthKey_XXXXXXXXXX.p8" \
  --team-id "ABCDEFGHIJ" \
  --key-id "KLMNOPQRST" \
  --issuer-id "00000000-0000-0000-0000-000000000000" \
  --app-store-app-id "1234567890" \
  --output "$HOME/Secure/AIHandoverSigning/evidence"
```

`.p12`パスワードは画面に表示されない入力欄で求められます。コマンド引数やシェル履歴へ入れません。

## 自動確認

- `.p12`をパスワードで開ける
- Apple Distribution証明書である
- 証明書が7日以内に期限切れにならない
- Provisioning ProfileをApple形式として解析できる
- Team ID一致
- application-identifierが`TEAM_ID.jp.allsunday.aihandoverlog`
- `get-task-allow`がtrueではない
- Enterprise Profileではない
- 登録端末を含まないためAd Hoc／Developmentではない
- APIキー名が`AuthKey_<Key ID>.p8`
- `.p8`にprivate-key headerがある
- 出力へ秘密鍵や証明書本文が混入していない

## 出力

- `AI_Handover_Log_v0.6_Apple_Registration_Evidence.json`
- `AI引継ぎ帳_v0.6_Apple登録完了証跡.md`

記録されるのは識別子、期限、SHA-256、証明書Subject、Profile UUIDなどの非秘密メタデータです。

## 共有してよい範囲

生成したJSONとMarkdownは秘密鍵本文やパスワードを含まない設計です。ただしTeam ID、Profile UUID、API Key ID、Issuer IDなどの運用情報は含むため、公開投稿は避け、開発記録として限定的に扱います。

元の以下のファイルは共有しません。

- `.p12`
- `.p12`パスワード
- `.p8`
- 暗号化秘密鍵
- `.mobileprovision`
- Apple Accountのパスワード
- 2ファクタ認証コード

## 証跡作成後

結果が`APPLE_REGISTRATION_EVIDENCE_VALID`なら、MacinCloudの署名付きArchive作成へ進みます。

```bash
DEVELOPMENT_TEAM=実際のTeamID ./scripts/macincloud_testflight_submission.sh
```

GitHub Actions代替経路を使う場合は、証跡確認後にEnvironment secretsを設定します。初回提出はXcode Organizer経路を優先します。
