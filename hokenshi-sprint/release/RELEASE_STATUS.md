# Release Status｜保健師国家試験｜学びスプリント

更新: 2026-08-13

## 到達状態
**Native Release Gate PASS / Apple識別情報待ち**

## 完了
- Notion正本照合
- Golden Master v2.1適用
- SwiftUI Native製品シェル
- WebKit/WKWebView不使用
- 330問独自問題bank
- 3回×110問 / 各回75一般+35状況設定 / 10分野×11
- 36 scenario groups
- Evidence Gate
- Content/Rights Gate
- 現行保健師活動指針（2026-05-15）再照合
- 3回辛口レビュー
- オフライン学習
- 4/8/16、苦手、わからない、3連続解除、途中再開、履歴、35日ヒートマップ、試験日、JSON backup
- 午前55／午後55／通し110模試
- Privacy Manifestテンプレ
- Support / Privacy公開ページ原稿
- App Store原稿ドラフト
- GitHub Actionsによる構造・証拠・権利・Nativeテスト

## Release blocker
識別情報正本に開発連番#13が未登録のため、以下は推測禁止で停止する。
- Bundle ID
- App Store Connect App ID
- IAP Product ID（課金採用時）
- Codemagic profile

このため、署名対象Xcode app target、StoreKit本番商品紐付け、signed IPA、Internal TestFlightは未実施。

## AppIcon
学びスプリントAppIcon正本はGoogle Driveの個別PNGを使用する。#13対応PNGはRelease target作成時に正本バイトを取得・SHA-256記録して配置する。一覧画像からの切り出しは禁止。

## 本審査
ユーザー明示承認までApp Store本審査提出を実行しない。
