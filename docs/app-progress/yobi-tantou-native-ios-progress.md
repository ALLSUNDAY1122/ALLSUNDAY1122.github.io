# 開発連番#11｜司法試験予備試験・短答式｜Native iOS進捗

更新日: 2026-08-13

## 正本

- Notion台帳: https://app.notion.com/p/3b609c10697d81ea8021da198988f436
- 開発正本: https://app.notion.com/p/3ba09c10697d81888b47e05a81d863c1
- Golden Master v2.1: https://app.notion.com/p/3b609c10697d81f0b3d0f78d160a819f
- 標準手順 v2.2: https://app.notion.com/p/3a909c10697d81e0961bd0fd27a77d39
- 問題生成・監査ループ: https://app.notion.com/p/3b609c10697d8148a0c2db3a8c8d5e63
- GitHub branch: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/tree/feature/yobi-tantou-native-swiftui/learning-sprint/yobi-tantou
- Draft PR: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/pull/4136

## v1.0指定との互換性

現行最上位はv2.1。旧v1系の12問・3タブ・オレンジ中心UIは適用せず、8問・4タブ・生成り紙＋藍/朱/緑/金・明朝＋ゴシック・28px方眼・82px進捗リング・朱の○×・「ここだけ覚える」・5週ヒートマップ・JSONバックアップを適用する。

## Native実装済み

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
- XCTest＋XCUITestとGitHub Actions。

## 教材品質基盤 2026-08-13

- `content-loop/source-audit-2026-08-13.md`: R6-R8一次資料の到達状況とReleaseゲート。
- `content-loop/topic-map.v1.json`: 8科目の独自作問論点マップ。公式出題比率・問題数を推測しない。
- `content-loop/questions.candidates.v1.json`: 7法律科目×2問、計14問の一次法令ベース独自候補。正式教材ではない。
- `content-loop/validate_candidates.py`: 件数確定前に候補の必須項目・正答index・一次資料URL・基準日・権利根拠・重複・高類似・Release禁止を検査。
- `content-loop/build_native_release.py`: `audit_status=release_passed` かつ `release_eligible=true` の正式監査済みデータだけをNative形式へ変換。
- `QuestionRepository.swift`: `questions.release.json` が存在する場合はfail-closed。監査条件を満たさない正式バンクは起動時エラーとし、プレビューへ黙ってフォールバックしない。
- 法律科目は正式バンクで法令基準日必須。一般教養は法令基準日不要だが、正式変換前に一次資料・権利監査を要求する。

## 公式資料の確定状況

- R6（2024）問題ページ: 確認済み。
- R6「正解及び配点」ページ: 確認済み。PDF本文・科目別件数は未監査。
- R7（2025）問題ページ: 確認済み。
- R7「正解及び配点」ページ: 確認済み。PDF本文・科目別件数は未監査。
- R7には法務省の「短答式試験における試験問題の誤記およびその取扱いについて」が存在するため、訂正内容の反映を正式Releaseの必須条件に追加。
- R8（2026）問題4冊: 確認済み。
- R8正解及び配点: 2026-08-13時点の当開発環境では一次資料本文を確定できず、未確定。過年度から推測しない。
- 年度×科目の正式問題数: PDFページ単位監査ができるまで `null` のまま維持。

## 法令基準日

法務省は令和6年予備試験から、原則として短答式・論文式が行われる年の1月1日現在施行法令を基準とすると公表している。このため対象3回は次で固定する。

- R6（2024）: 2024-01-01
- R7（2025）: 2025-01-01
- R8（2026）: 2026-01-01

## 受入条件

1. `audit_native.py` PASS。
2. candidate preflight実データ PASS。
3. release builder self-test PASS。
4. XCTest＋XCUITest PASS。
5. WebKit/WKWebView 0。
6. Golden Master v2.1主要UI契約欠損0。
7. App ID / Bundle ID / IAP Product IDの推測値0。
8. 正式教材は3回分の年度×科目構成、正答、重複、高類似、根拠、法令基準日、権利根拠が全PASSするまでRelease不可。
9. R7訂正資料の対象・採点影響を反映済み。
10. StoreKit購入・復元・無料利用ゲートがテストPASS。
11. Internal TestFlight実機確認前にRelease監査PASS。
12. 外部Beta App ReviewとApp Store本審査はユーザー承認前に実行しない。

## 現在のリスク・ブロッカー

- R6-R8正式問題数・科目別内訳: 公式PDFのページ単位監査待ち。推測しない。
- R6/R7正答・配点・特殊採点: PDF本文監査待ち。
- R7誤記訂正: PDF本文監査待ち。
- R8公式正答・配点: 一次資料取得待ち。
- 一般教養の第三者文章・図表・写真: 権利処理なしで再利用しない。
- Bundle ID / App Store Connect App ID / IAP Product ID: ユーザー確認が必要になる最終段階まで未設定を維持。
- 学びスプリント正本AppIcon #11: 申請工程で個別PNGを取得・SHA固定する。

## 次の大ループ

最新CIをPASSさせる → 法令ベース独自候補を拡張・内容監査 → 公式PDF取得可能になり次第R6-R8正式構成・正答・訂正を確定 → 共通 `validate_questions.py` 用の3回分設定を固定 → 正式バンクを構造・高類似・法令・権利・正答の各監査でFAIL 0にする → Native Release変換 → StoreKit設定直前まで進める。
