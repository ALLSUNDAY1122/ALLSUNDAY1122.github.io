# 不動産鑑定士試験・短答式｜学びスプリント（開発連番#12）

SwiftUIネイティブiOSアプリ。WebViewだけの実装は禁止。

## 正本

- Notion台帳: https://app.notion.com/p/3b609c10697d813f8d55fa0735c1e502
- 資格正本: https://app.notion.com/p/3b509c10697d8179927af2d9b99a3d7a
- 共通UI正本: https://app.notion.com/p/3b609c10697d81f0b3d0f78d160a819f
- UIは現行最上位 v2.1 Golden Masterを適用。

## iOSアプリ

`ios/project.yml` をXcodeGenで `KanteishiShortAnswer.xcodeproj` に生成する。

- App target: `KanteishiShortAnswer`
- Bundle ID: `jp.allsunday1122.kanteishishortanswer`
- Apple Developer Team: `MN3D2ZM44N`
- Deployment target: iOS 17.0
- Display name: `鑑定士スプリント`
- Unit test target: `KanteishiShortAnswerTests`
- UI test target: `KanteishiShortAnswerUITests`

GitHub ActionsのmacOS runnerで、XcodeGen生成、Simulatorビルド、XCTest、UIスモークテストまで実行する。

## 実装済み

- v2.1 Golden Master準拠のホーム／模試／記録／設定／問題／結果画面
- 4/8/16問スプリント、分野別、模試、苦手3連続正解解除、わからない、中断復帰
- 履歴、5週間ヒートマップ、試験日・必要ペース、JSONバックアップ
- Application Support永続保存、バックアップサニタイズ
- StoreKit 2購入・復元基盤（Product IDはApp Store Connect商品作成まで未設定）
- Privacy Manifest

## 公式問題枠

対象は令和8・7・6年。各年度は行政法規40問＋鑑定理論40問の80問、合計240問。240スロットを固定し、水増し禁止。

現在アプリへ入れている12問はUI・学習導線確認用の独自試作データで、全問 `公開不可`。製品240問の監査PASSとは別扱い。

## Apple側で後から必要なもの

- App Store Connectのアプリレコード／Apple ID
- StoreKit 2 Product ID、商品構成、価格
- 配布用Provisioning／署名の最終確認

これらが未作成でもSimulatorでのアプリ生成・実行・テストは止めない。

## 開発ルール

変更 → 対応する品質ループ → 静的監査 → 単体/UIテスト → FAIL修正 → 再テスト → Notion/GitHub正本更新、を反復する。

外部TestFlightベータ審査およびApp Store本審査はユーザー承認まで実行しない。
