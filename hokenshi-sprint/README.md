# 保健師国家試験｜学びスプリント

開発連番 #13。ChatGPT が担当し、Codex へ引き継がず開発を継続する。

## 現在地

- 状態: 開発開始 / Native foundation
- UI正本: 学びスプリント Golden Master v2.1
- v1.0互換: v1.0 指定は資格固有差分を除き v2.1 の固定UI・学習導線へ読み替える
- 実装: SwiftUI native。WKWebView を主UI・代替UIとして使用しない
- 問題方針: 厚生労働省・法令・公的ガイドライン等の一次資料からの独自作問を主軸にする
- TestFlight: Internal Testing only
- App Store 本審査: ユーザー承認まで実行しない

## 確認済みの試験基準

- 最新参照回: 第112回（2026年2月13日）
- 午前 55問 / 午後 55問 / 合計 110問
- 合格発表上の配点: 一般問題 75点満点、状況設定問題 70点満点（1問2点）
- 現行出題基準: 令和5年版
- 出題基準の10分類: 公衆衛生看護学概論、公衆衛生看護方法論I、公衆衛生看護方法論II、対象別公衆衛生看護活動論、学校保健・産業保健、健康危機管理、公衆衛生看護管理論、疫学、保健統計、保健医療福祉行政論

## 未確定・推測禁止

以下は正本に値がないため決めない。

- Bundle ID
- App Store Connect App ID
- IAP Product ID
- Codemagic profile
- 販売価格 / 無料範囲

上記が確定するまでは、署名対象のXcode app targetとStoreKit商品紐付けを作らない。Swift Packageとして資格固有ロジックとSwiftUI画面を先行実装する。

## 初期構成

- `docs/RESEARCH_AND_REQUIREMENTS.md`: 市場・競合・権利・要件・受入条件
- `NativePackage/`: 真正SwiftUI資格機能の先行実装
- `NativePackage/Tests/`: 試験構成・権利ゲートの単体テスト
- `.github/workflows/hokenshi-sprint-foundation.yml`: macOS Swift test + WebView禁止監査

## 次の大ループ

1. 市場・競合・権利監査を正本へ固定
2. Native foundation CI をPASSさせる
3. 3模試 x 110問 = 330問の独立作問枠を固定し、一次資料マップを作る
4. 問題生成・重複・正答・制度・著作権監査をPASSさせる
5. 識別情報確定後、Xcode app target + StoreKit 2 + UI testsへ進む
6. 辛口レビュー3回、Release Gate、Internal TestFlight

## ブロッカー

現時点の人間確認ブロッカーは App Store識別情報・IAP方針のみ。問題作成、Native package、静的監査は先行可能。
