# 開発連番#11｜司法試験予備試験・短答式｜Native iOS進捗

更新日: 2026-08-12

## 正本

- Notion台帳: https://app.notion.com/p/3b609c10697d81ea8021da198988f436
- Golden Master v2.1: https://app.notion.com/p/3b609c10697d81f0b3d0f78d160a819f
- 標準手順 v2.2: https://app.notion.com/p/3a909c10697d81e0961bd0fd27a77d39
- 問題生成・監査ループ: https://app.notion.com/p/3b609c10697d8148a0c2db3a8c8d5e63
- GitHub branch: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/tree/feature/yobi-tantou-native-swiftui/learning-sprint/yobi-tantou

## v1.0指定との互換性

現行最上位はv2.1。旧v1系の12問・3タブ・オレンジ中心UIは適用せず、8問・4タブ・生成り紙＋藍/朱/緑/金・明朝＋ゴシック・28px方眼・82px進捗リング・朱の○×・「ここだけ覚える」・5週ヒートマップ・JSONバックアップを適用する。

## 実装済み

- 純SwiftUI。WebKit/WKWebViewなし。
- ホーム／模試／記録／設定4タブ。
- 8問標準スプリント、4/8/16目標。
- 分野別演習、苦手復習、わからない記録。
- 苦手は3連続正解で解除。
- 中断再開。再開前の正解数を保持。
- 学習履歴、分野別正答率、5週間ヒートマップ。
- JSON書出し・読込。5MiB上限と整合性検証。
- 無料スプリント消費状態はバックアップ／リセットで復活不可。
- StoreKit 2の購入・復元・entitlement確認骨格。本番Product IDは未設定。
- Privacy Manifest（UserDefaults CA92.1）。
- 8問の非教材UIプレビュー。全問 `releaseEligible=false`。
- XCTestとGitHub Actionsを追加。

## 受入条件

1. `audit_native.py` PASS。
2. XCTest PASS。
3. WebKit/WKWebView 0。
4. Golden Master v2.1主要UI契約欠損0。
5. App ID / Bundle ID / IAP Product IDの推測値0。
6. 正式教材は3回分の年度×科目構成、正答、重複、高類似、根拠、法令基準日、権利根拠が全PASSするまでRelease不可。
7. StoreKit購入・復元・無料利用ゲートがテストPASS。
8. Internal TestFlight実機確認前にRelease監査PASS。
9. 外部Beta App ReviewとApp Store本審査はユーザー承認前に実行しない。

## 現在のリスク・ブロッカー

- 令和6・7・8年度の正式問題数・科目別内訳: 公式PDFのページ単位監査待ち。
- 令和6・7年の法令基準日: 一次資料確認待ち。
- 公式正答・部分点: 一次資料監査待ち。
- 一般教養等に含まれ得る第三者著作物: 問題単位の権利監査待ち。
- Bundle ID / App Store Connect App ID / IAP Product ID: 要確認。
- 学びスプリント正本AppIcon #11: 申請工程で個別PNGを取得・SHA固定する。

## 次の大ループ

PRのCIをPASSさせた後、公式R6-R8資料の問題・正答・権利・法令基準日を監査し、`exam-config.pending.json` のnullを一次根拠で確定する。その後、独自短問の論点マップ→正式問題バンク→共通validator→内容/法令/著作権監査をPASSまで反復する。
