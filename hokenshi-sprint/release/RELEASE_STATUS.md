# Release Status｜保健師国家試験｜学びスプリント

更新: 2026-08-14

## 到達状態
**Native Release Gate PASS / Apple新規Appレコード作成待ち**

## 完了
- Notion正本照合
- 初期Safari試作品のユーザー採用
- Golden Master v2.1適用
- SwiftUI Native製品シェル
- WebKit/WKWebView不使用
- 330問独自問題bankを `release_ready` としてSwift Packageへ同梱
- 3回×110問 / 各回75一般+35状況設定 / 10分野×11
- 36 scenario groups
- 状況設定本文をNative問題画面へ接続
- 一次根拠を解説画面から開く導線
- Evidence / Content / Rights / current-guidance gate
- 現行保健師活動指針（2026-05-15）再照合
- 3回辛口レビュー記録
- オフライン学習
- 4/8/16、苦手、わからない、3連続解除、途中再開、履歴、35日ヒートマップ、目標試験日、文字サイズ、JSON backup
- 午前55／午後55／通し110模試
- Privacy Manifest
- Support / Privacy公開ページ原稿
- App Store日本語原稿
- iPhone向けXcodeGen App target
- StoreKit 2買い切りPremium実装
- verified transaction / revocation確認 / transaction updates
- 購入復元常設
- StoreKit `Product.displayPrice` だけを価格表示に使用
- `codemagic.yaml` にInternal TestFlight専用 `hokenshi_appstore` workflow追加

## 決定済み識別情報
ユーザーが2026-08-13に「課金あり、3項目はあなたが決めて」と明示し、命名判断をAIへ委任したため以下を正本へ登録済み。
- Bundle ID: `jp.allsunday1122.hokenshi`
- Codemagic profile/workflow: `hokenshi_appstore`
- IAP Product ID: `jp.allsunday1122.hokenshi.premium`
- Apple Team ID: `MN3D2ZM44N`
- Version: `1.0.0`
- SKU: `hokenshi-sprint-13-ios`

App Store Connectの数値App IDはApple自動発行値のため仮値を作らない。

## 課金方式
- 非消耗型・買い切りPremium
- 無料: 30問。第1回の10分野から各3問ずつを均等に公開
- Premium: 残り300問＋模試機能
- 無料版でも8問スプリント・分野別学習・苦手復習の中心体験を確認できる
- App Store上の価格は本審査前の最終承認地点で確定

## AppIcon正本
Google Drive個別PNG `13_保健師国家試験.png` を正本として特定・取得済み。
- Drive file ID: `13fX8V5AuEiOHu2vhhnzHo4NosZ6pwTBt`
- format: PNG RGB
- size: 1024×1024
- bytes: 609,807
- SHA-256: `34c1ec303ef5420947bf13ab4b05d2045a70b79417ac40ebd667e05c8f2f2c64`

Asset Catalogは `AppIcon-1024.png` を参照済み。GitHub ActionsからDrive匿名直取得はHTTP 403だったため、署名ビルド前に正本バイトの搬送とSHA完全一致を必須ゲートとして残す。ユーザーへ画像再提出は求めない。

## CI
2026-08-14に旧IAP禁止ガードとshell quoting不備を修正し、正本一致検証へ移行。

フルNative検証PASS実績:
- Hokenshi Sprint Native Foundation run #232: content-plan / native-foundation / persist-release-resources 全PASS
- その後のrunでもcontent-planは連続PASSし、free=30 / premium=300 / 無料10分野×3問を固定
- Swift Package / LearningSprintCore tests PASS
- Bundle ID / Team ID / IAP Product ID正本一致 PASS
- WebView禁止 PASS
- XcodeGen + IAP capability PASS
- iOS Simulator Release build PASS

運用改善:
- release文書だけの更新でmacOS buildを再実行しないようpath filterを限定
- `push` と `pull_request` の二重実行を廃止し、PR同期＋手動実行へ一本化

## 現在の外部ブロッカー
Apple Developer / App Store Connectへのログイン操作が必要。
1. Explicit App ID `jp.allsunday1122.hokenshi` が未登録なら登録
2. App Store Connectで新規Appレコードを作成
3. Appleが発行した実App IDを取得

固定入力値は `release/APP_STORE_RECORD_VALUES.md` に記録済み。

Appレコード作成後は、実App IDを正本へ記録→非消耗型IAP作成→正本AppIcon搬送→Codemagic署名→signed IPA→Internal TestFlightへ進む。

## 人間確認地点
次の製品判断の人間確認地点は #3「Internal TestFlight実機確認」。ただしその前段として、Appleログイン/MFAを伴う新規Appレコード作成はユーザー操作が必要。
App Store本審査は #4 の明示承認まで実行しない。
