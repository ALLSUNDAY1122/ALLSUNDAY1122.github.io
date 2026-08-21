# AI引継ぎ帳 v0.6 申請保留状況

更新日：2026年7月25日

## 結論

ユーザー判断により、AI引継ぎ帳のTestFlightアップロードとApp Store申請を保留する。

理由は、申請前にプロダクトの内容と利用価値を見直し、体験を改善する必要があるため。

## Apple側で完了済み

- Explicit App ID `jp.allsunday.aihandoverlog`登録
- App Store Connectアプリレコード「AI引継ぎ帳」作成
- Apple Distribution証明書作成
- App Store用Provisioning Profile `AI_Handover_Log_AppStore`作成
- Provisioning ProfileのBundle ID、Team、配布種別、有効期限をローカル検証

## 実施していないこと

- App Store Connect APIアクセス申請
- GitHubへのApple署名Secret登録
- 署名済みBuild作成
- TestFlightアップロード
- TestFlightグループ作成・Build追加
- Beta App Review提出
- 外部テスター招待
- App Review提出

App Store Connect APIアクセス申請は確認ダイアログを開いたが、同意チェックや提出を行わずキャンセルした。

## 秘密情報の扱い

- Apple Accountのパスワード、2ファクタ認証コード、電話番号は保存していない
- 証明書秘密鍵、パスフレーズ、`.p12`、Provisioning ProfileはGit管理外のローカル領域に保持
- GitHub、PR、Notion、リリース文書へ秘密値を記録していない

## 再開条件

1. プロダクトの目的、利用価値、主要体験を再検討
2. 改善内容を実装
3. 自動テストとiOSビルド検証を再実施
4. App Storeメタデータとスクリーンショットを新しい内容へ更新
5. ユーザーがTestFlight再開を明示

Build `6`はAppleへ未アップロードのため現時点では未使用。ただし機能変更後は、成果物を明確に識別できるようBuild番号を更新してから再開することを推奨する。
