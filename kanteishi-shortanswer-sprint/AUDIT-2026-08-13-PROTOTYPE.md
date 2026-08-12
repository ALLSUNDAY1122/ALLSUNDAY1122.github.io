# 開発連番#12 初期ネイティブ試作品監査 2026-08-13

## 結論

- Phase 0 調査・正本固定: **PASS**
- Phase 1A SwiftUIネイティブ試作品: **PASS（静的・型検査）**
- Phase 1B iOSアプリターゲット/実機確認: **BLOCKED BY CONFIRMED APP IDENTIFIERS**
- Phase 2 製品問題240問: **枠・基準日固定 PASS / 本文生成・問題単位監査は未開始**
- 外部TestFlight/App Store審査: **未実行**

## 正本

- 学びスプリント標準手順 v2.2
- 問題生成・監査ループ v1.0
- 共通UI正本 v2.1 Golden Master
- UI v1.0との互換目的は維持するが、競合時はv2.1を優先

## ネイティブ実装

WebViewではなくSwiftUIで以下を実装した。

- ホーム / 模試 / 記録 / 設定の4タブ
- 問題 / 結果画面では下部タブを非表示
- 紙色 `#f7f3ea`
- 28pt方眼
- 最大幅520 / 外周18
- 藍・朱・緑・金の役割
- 明朝/ゴシックの文字階層
- 82pt進捗リング
- 試験日カウントダウンと240問一周ペース
- 8問標準スプリント（4/8/16設定）
- 分野別演習
- 年度別模試
- わからない
- 中断復帰
- 苦手3連続正解解除
- 朱の○×オーバーレイ
- 「ここだけ覚える」金罫線ブロック
- 学習履歴 / 分野バー / 5週間ヒートマップ / 苦手一覧
- JSONバックアップ/復元
- StoreKit 2非消耗型ロジック（Product ID未設定のためRelease Gate）
- ローカル問題JSONでオフライン動作可能な構成
- PrivacyInfo.xcprivacy初期版

## 3回の辛口レビュー改善

### Round 1｜表示整合性

発見:
- 試作問題が12問しかない状態で目標16問を選ぶと、CTAが「16問を解く」と表示し得る。

修正:
- 実際に開始可能な問題数 `min(dailyGoal, availableQuestions)` をUI・進捗リング・セッション生成で共通使用。
- 水増しで不足分を埋めない。

再判定: PASS

### Round 2｜データ耐久性

発見:
- 初期試作では学習状態の保存先が一時領域だった。
- 旧/破損バックアップが現在の問題IDと不整合を起こす余地があった。

修正:
- 保存先をApplication Support配下へ変更。
- バックアップ読込時に問題ID、dailyGoal、中断セッションをサニタイズ。
- 問題版更新時は不整合な中断データを破棄。
- 回答履歴4,000件、完答履歴100件を上限として肥大化を抑制。

再判定: PASS

### Round 3｜シリーズ逸脱・公開事故

発見リスク:
- UI要件の目視確認だけでは将来の変更でv2.1要素が欠落し得る。
- 試作12問が誤って「240問完成」と扱われる事故を機械的に防止する必要がある。

修正:
- v2.1ネイティブ静的監査をCI化。
- 240問は `production_target_only` マニフェストとして分離。
- 試作問題は全問 `公開不可` を保持するRelease GateをCI化。
- WebView禁止、未確認Bundle ID/IAP Product ID禁止を継続。

再判定: PASS

## 問題側

### 製品固定枠

- R1 令和8年: 行政法規40 + 鑑定理論40 = 80
- R2 令和7年: 行政法規40 + 鑑定理論40 = 80
- R3 令和6年: 行政法規40 + 鑑定理論40 = 80
- 合計240

年度基準日:
- R1: 2025-09-01
- R2: 2024-09-01
- R3: 2023-09-01

### 試作12問

- 各年度: 行政法規2 + 鑑定理論2 = 4問
- 合計12問
- 国土交通省一次資料を根拠に独自作問
- 構造・件数・重複・高類似・必須項目の共通監査: PASS
- `origin_type=primary_source_original_prototype` は意図的に共通監査のWARNINGを残す
- 製品版で問題単位の法令・権利・正答監査が完了するまで `original_from_primary_source` へ昇格しない

## CI

最新PR run:
https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/31650733310

PASS:
- Swift core unit tests 8/8
- 240-slot manifest
- 12-question shared audit
- v2.1 native UI static audit
- WebView prohibition
- unconfirmed identifier prohibition
- prototype non-release gate
- iOS Simulator SDK SwiftUI typecheck

## 現在の人間入力が必要な事項

App Store Connect/Apple側の確定値がNotion・GitHubに存在しないため、以下は推測禁止ルールにより未設定。

1. Bundle ID
2. App Store Connect App ID（作成済みなら値/対象アプリ）
3. Apple署名で使用するTeam/Provisioningの#12固有扱い

StoreKit 2 Product ID・商品構成・価格は課金実装をApp Store Connectへ接続する直前まで未設定のまま進められるため、初期アプリターゲット生成の必須入力にはしない。

## 次の処理

Bundle ID等のApple識別子が確定したら:

1. XcodeGen project.yml / Info.plistを作成
2. iOS Simulator build
3. XCTest/UI test target作成
4. UI runtime監査
5. 初期試作品のユーザー確認
6. 承認後に240問生成・問題単位監査へ進む

外部TestFlightベータ審査・App Store本審査はユーザー承認まで実行しない。
