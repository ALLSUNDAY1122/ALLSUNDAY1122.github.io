# AI引継ぎ帳 v0.6 App Review提出状況

更新日：2026年7月24日

## 現在の結論

App Review提出準備資料は完成したが、Apple認証を伴う実工程とiPhone 16実機受入テストが未完了のため、現時点では提出不可。

## 完成済み

- App Store Connect日本語入力稿
- App Review Notes
- 1290×2796スクリーンショット5枚
- Privacy PolicyとSupportページ用ドラフトPR #1661
- Apple App ID／アプリレコード登録手順
- MacinCloud署名・Archive・TestFlight実行キット
- TestFlight Beta App Description
- TestFlight What to Test
- 40件の受入テストCSV
- P0／P1／P2重大度基準
- App Review Go／No-Go基準

## 未完了・提出ブロッカー

- Apple DeveloperでApp ID登録
- App Store Connectでアプリレコード作成
- Privacy／Supportページ公開
- Apple署名付きBuildのアップロード
- Build UploadsのComplete確認
- iPhone 16へTestFlightインストール
- 40件の受入テスト全件合格
- App Privacyと実装の最終照合
- App Review連絡先の最終確認

## 提出許可条件

- 必須テスト全件合格
- P0 = 0
- P1 = 0
- Build Uploads = Complete
- Bundle ID、Version、Buildが一致
- Privacy URLとSupport URLが公開済み
- メタデータ、スクリーンショット、App Privacyが実装と一致
- App Review Notesが最新

## 初回TestFlight方針

- 内部テストから開始
- iPhone 16を受入対象にする
- 外部テストは内部受入合格後に判断
- 外部テスト用Feedback Emailは専用サポートメールを推奨

## 現在値

- Bundle ID：`jp.allsunday.aihandoverlog`
- Version：`0.6.0`
- Build：`6`
- 受入テスト件数：40
- Ready for Review：false
