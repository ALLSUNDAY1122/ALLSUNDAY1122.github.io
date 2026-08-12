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
- JSON書出し・読込。5MiB上限と件数・再開進捗の整合性検証。
- 無料スプリント消費状態はバックアップ／リセットで復活不可。
- Premium専用セッションは途中保存後も再開時に購入資格を再確認。権利失効時の再開バイパスを修正済み。
- 旧バックアップに `requiresPremium` がない場合も安全側へ移行。
- StoreKit 2はProduct ID未設定時fail-closed。購入・復元を開始しない。
- verified transaction、current entitlements、revocation、Transaction.updatesを扱う。
- Privacy Manifest: Tracking false / collected data none / UserDefaults CA92.1。
- 8問の非教材UIプレビュー。全問 `releaseEligible=false`。
- XCTest＋XCUITest＋unsigned Release configuration buildをGitHub Actions対象化。

## 教材品質基盤

- `content-loop/source-audit-2026-08-13.md`: R6-R8一次資料の到達状況とReleaseゲート。
- `content-loop/RIGHTS_AND_CONTENT_POLICY.md`: PDL1.0、第三者権利、CBT体験版二次利用禁止を分離。
- `content-loop/topic-map.v1.json`: 8科目の独自作問論点マップ。公式出題比率・問題数を推測しない。
- `content-loop/questions.candidates.v1.json`: 7法律科目×2問、計14問の一次法令ベース独自候補。正式教材ではない。
- `content-loop/validate_candidates.py`: 必須項目・正答index・一次資料URL・基準日・権利根拠・重複・高類似・Release禁止を検査。
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

## AppIcon

正本の確認・固定は完了。

- Drive個別PNG: `11_司法試験予備試験_短答式.png`
- Drive file ID: `1EyeJxBN2WPEjEw9TUszhmyhuk3_3Lu6K`
- 1024×1024 PNG / 721,851 bytes
- SHA-256: `c56c3f0acf7e05ec6096fdee881081b7b7e8e863ae2933b496550e902b840bf9`
- `app-icon-lock.json` で固定。
- Canonical buildはDriveから正本を直接取得してSHA一致必須。
- Simulator CIは専用placeholderを生成し、本番正本と分離。

## App Store準備

作成済み:
- `privacy/index.html`
- `support/index.html`
- `app-store/APP_STORE_METADATA_JA.md`
- `app-store/APP_REVIEW_NOTES_JA.md`
- `app-store/STOREKIT_TEST_PLAN.md`
- `app-store/RELEASE_CHECKLIST.md`
- `app-store/APPLE_CONNECT_PACKET.md`
- `validate-app-store-draft.py`
- `ios/release-preflight.py`

申請原稿は、固定価格0、推測ID0、法務省公式と誤認させる表現0、正式問題数の断定0を条件とする。公開ページはmain統合後にHTTP 200を再検証する。

## Production Releaseハードゲート

次が揃うまで署名工程をBLOCKする。

1. canonical `questions.release.json`
2. Bundle IDの明示値
3. App Store Connect App IDの明示値
4. IAP Product IDの明示値
5. canonical AppIcon SHA一致

`UNSET`、ビルド変数文字列、`jp.ci.*`、preview識別子は本番preflightで拒否する。

## 現在の受入条件

- [ ] 最新 `audit_native.py` PASS
- [ ] 最新 candidate preflight実データ PASS
- [ ] 最新 release builder self-test PASS
- [ ] 最新 production release preflight self-test PASS
- [ ] 最新 App Store draft consistency PASS
- [ ] 最新 XCTest PASS
- [ ] 最新 XCUITest PASS
- [ ] 最新 unsigned Release configuration build PASS
- [x] WebKit/WKWebView 0
- [x] Golden Master v2.1主要UI契約実装
- [x] App ID / Bundle ID / IAP Product IDの推測値0
- [x] 正本AppIconをDrive個別PNGから固定
- [ ] R6-R8の年度×科目構成・正答・特殊採点を一次資料PDFで確定
- [ ] R7訂正資料の対象・採点影響を反映
- [ ] 正式3回分の重複・高類似・正答・根拠・法令基準日・権利根拠FAIL 0
- [ ] StoreKit Sandbox実機確認
- [ ] Internal TestFlight実機確認
- [ ] 外部Beta App Review／App Store本審査はユーザー承認後のみ

## 現在のブロッカー

- 法務省PDF本体: 当開発環境では法務省HTMLが403となり、PDFビューアへ正答・配点・訂正PDFを渡せない。PDF本文を見ずに正式件数・正答を推測しない。
- R8公式正答・配点: 一次資料本文未確定。
- 一般教養の第三者文章・図表・写真: 権利処理なしで再利用しない。
- Bundle ID / App Store Connect App ID / IAP Product ID: 正式教材完成後の署名境界まで未設定を維持。

## 次の大ループ

最新CIをPASSさせる → 独自候補の内容・法令時点監査を拡張 → 公式PDF本文を取得可能になり次第R6-R8正式構成・正答・訂正を確定 → 共通3回分validator設定固定 → canonical正式バンク監査FAIL 0 → Native Release変換 → 本番識別子確定 → Canonical AppIcon付きsigned IPA → Internal TestFlight実機確認。外部審査は明示承認まで実行しない。
