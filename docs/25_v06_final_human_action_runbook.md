# AI引継ぎ帳 v0.6 最終人間操作ランブック

作成日：2026年7月24日

## この資料の目的

Apple認証が必要な残作業を、1回のMacinCloudセッションで順番どおり実施するためのランブックです。

## 現在完了していること

- Version 0.6.0 / Build 6
- Bundle ID `jp.allsunday.aihandoverlog`
- 16件の自動テスト合格
- iPhone専用・Portrait固定
- App-level Privacy Manifest追加
- macOS/Xcode上の署名なしArchive作成成功
- Archive実測でiPhone専用、Portrait、Privacy Manifestを確認
- App Store用スクリーンショット5枚完成
- App Storeメタデータ完成
- TestFlight受入テスト40件完成

## 本人操作が必要な残作業

1. 最新契約の確認
2. Explicit App ID登録
3. App Store Connectのアプリレコード作成
4. 公開ページPR #1661の公開判断
5. MacinCloudでXcodeへサインイン
6. Team設定
7. 署名付きArchive作成
8. Generate Privacy Report
9. Validate App
10. TestFlight & App StoreへUpload
11. 内部テスター設定
12. iPhone 16受入テスト

## 固定値

- Name：AI引継ぎ帳
- Bundle ID：jp.allsunday.aihandoverlog
- App ID Description：AI引継ぎ帳
- Platform：iOS
- Primary Language：Japanese
- SKU：AIHANDOVERLOG-IOS-001
- User Access：Full Access
- Version：0.6.0
- Build：6
- Minimum iOS：13.0

## 停止条件

- 最新契約が未同意
- Bundle IDが一致しない
- 同じBuild 6が既にアップロード済み
- Privacy Reportが「Trackingなし／Collected Dataなし」にならない
- Validate Appにエラーがある
- 公開URLが404
- TestFlightでBuildがFailed
- 受入テストでP0またはP1が発生

## 禁止事項

- 旧署名なしArchiveをアップロードしない
- Apple ID、パスワード、2ファクタ認証コード、秘密鍵、APIキーをChatGPTやGitHubへ貼らない
- 明示的な指示なしにPR #1661またはPR #870をmainへマージしない
