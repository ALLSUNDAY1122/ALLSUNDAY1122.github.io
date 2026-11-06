# AI引継ぎ帳 v0.6 TestFlight準備状況

更新日：2026年7月24日

## 完了

- App Store Connect入力稿
- App Privacy回答
- App Reviewメモ
- 1290×2796スクリーンショット5枚
- プライバシーポリシー・サポートページ公開用ドラフトPR #1661
- Apple Developer / App Store Connect登録実行シート
- MacinCloud署名付きArchiveスクリプト
- Automatic Signing用TestFlight実行手順
- App Store Connect向けExportOptions
- スクリプトの`bash -n`構文検査
- ExportOptions plist解析

## 人間操作待ち

1. Apple Accountでログイン
2. 2ファクタ認証
3. 最新契約への同意確認
4. Explicit App ID `jp.allsunday.aihandoverlog`登録
5. App Store Connectアプリレコード作成
6. PR #1661の公開判断
7. MacinCloudでApple Developer Teamを設定
8. 署名付きArchiveを新規作成
9. Xcode OrganizerでValidate App
10. TestFlight & App StoreへUpload

## 禁止事項

- 署名なしArchiveをそのままアップロードしない
- Apple ID、パスワード、2ファクタ認証コード、秘密鍵、APIキーをGitHubへ保存しない
- Bundle IDを変更しない
- Build 6を一度アップロードした後に再利用しない
- プライバシー・サポートURLが404の状態で審査提出しない

## 現在の判定

技術資料と自動化準備は完了。Apple認証を伴う人間操作を開始できる状態です。mainへのマージ、公開、Apple署名、TestFlightアップロードは未実施です。
