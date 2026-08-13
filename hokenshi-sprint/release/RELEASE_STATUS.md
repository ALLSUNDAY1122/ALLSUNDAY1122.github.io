# Release Status｜保健師国家試験｜学びスプリント

更新: 2026-08-13

## 到達状態
**署名前Native Release Gate到達 / Apple識別情報の正本登録待ち**

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
- Native product shell audit
- Privacy Manifest原稿
- Support / Privacy公開ページ原稿
- App Store日本語原稿
- GitHub Actionsによる構造・証拠・権利・Nativeテスト

## AppIcon正本
Google Drive個別PNG `13_保健師国家試験.png` を正本として特定・取得済み。
- Drive file ID: `13fX8V5AuEiOHu2vhhnzHo4NosZ6pwTBt`
- format: PNG RGB
- size: 1024×1024
- bytes: 609,807
- SHA-256: `34c1ec303ef5420947bf13ab4b05d2045a70b79417ac40ebd667e05c8f2f2c64`

署名対象App target作成時はこの正本バイトを配置する。一覧画像からの切り出し・再生成は禁止。

## Release blocker
最上位識別情報正本に開発連番#13が未登録で、さらに現在利用可能な連携にもApp Store Connect書込手段がない。正本ルールにより次の値は推測・命名規則生成を行わない。
- Bundle ID
- App Store Connect App ID
- Codemagic profile
- IAP Product ID（課金採用時のみ）

このため現時点では、署名対象Xcode app target、Apple署名、signed IPA、Internal TestFlight uploadを実行できない。

## 次の工程
上記の識別情報が正本へ登録されたら、同じPRから以下を再開する。
1. iOS App target / signing config作成
2. AppIcon正本配置・SHA照合
3. PrivacyInfo.xcprivacyをtargetへ追加
4. Codemagic App Store署名build
5. signed IPA検証
6. Internal TestFlight upload
7. 人間確認地点 #3「TestFlight実機確認」
8. Golden Master 30状態スクリーンショット比較・修正

## 本審査
Internal TestFlight確認後も、ユーザー明示承認までApp Store本審査提出を実行しない。
