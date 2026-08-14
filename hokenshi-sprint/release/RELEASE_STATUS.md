# Release Status｜保健師国家試験｜学びスプリント

更新: 2026-08-14

## 到達状態
**Native製品ターゲット実装済み / 変更後CI再検証中 / Apple新規Appレコード作成待ち**

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
- 無料: 第1回110問
- Premium: 第2・3回を追加し全330問
- 模試のPremium範囲も同じentitlementで解放
- App Store上の価格は本審査前の最終承認地点で確定

## AppIcon正本
Google Drive個別PNG `13_保健師国家試験.png` を正本として特定・取得済み。
- Drive file ID: `13fX8V5AuEiOHu2vhhnzHo4NosZ6pwTBt`
- format: PNG RGB
- size: 1024×1024
- bytes: 609,807
- SHA-256: `34c1ec303ef5420947bf13ab4b05d2045a70b79417ac40ebd667e05c8f2f2c64`

GitHubのAsset Catalogには正本ファイル名を登録済み。署名ビルド前に正本バイト自体の配置とSHA照合を必須とする。

## CI
2026-08-14に、正式決定前の旧「IAP ID禁止」ガードが正式Product IDまで弾いていたことを特定。ガードを正本一致検証へ変更し、以下を再実行する。
- canonical/content/current-guidance/release-resource gate
- Native product shell audit
- LearningSprintCore tests
- Hokenshi Native tests
- Bundle ID / Team ID / IAP Product ID正本一致
- IAP capability生成
- iOS App target Simulator Release build
- WebView禁止
- audited resource persist

## 現在の外部ブロッカー
App Store Connectの新規Appレコードがまだ確認できないため、数値App IDだけ未取得。
固定入力値は `release/APP_STORE_RECORD_VALUES.md` に記録済み。

Appレコード作成後は、実App IDを正本へ記録→非消耗型IAP作成→Codemagic署名→signed IPA→Internal TestFlightへ進む。

## 人間確認地点
次の人間確認地点は #3「Internal TestFlight実機確認」。App Store本審査はその後もユーザー最終承認まで実行しない。
