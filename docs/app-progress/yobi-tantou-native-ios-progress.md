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
- R6・R7の公式採点canonicalをBundleからfail-closed読込。
- 模試タブにR6・R7の確認済み公式構造・満点・公式合格点を表示。公式問題本文は教材・権利監査PASSまで開始不可。
- XCTest・XCUITest・unsigned Release configuration buildをGitHub Actions対象化。

## 教材品質基盤

- `content-loop/source-audit-2026-08-13.md`: 一次資料の到達状況とReleaseゲート。
- `content-loop/RIGHTS_AND_CONTENT_POLICY.md`: PDL1.0、第三者権利、CBT体験版二次利用禁止を分離。
- `content-loop/topic-map.v1.json`: 8科目の独自作問論点マップ。
- `content-loop/questions.candidates.v1.json`: 7法律科目×2問、計14問の一次法令ベース独自候補。正式教材ではない。
- `content-loop/validate_candidates.py`: 必須項目・正答index・一次資料URL・基準日・権利根拠・重複・高類似・Release禁止を検査。
- `content-loop/audit_candidate_sources.py`: e-Gov一次法令を法令基準日まで含めて監査。
- `content-loop/audit_candidate_answers.py`: 正答・解説・根拠整合性を監査。
- `content-loop/build_native_release.py`: `audit_status=release_passed` かつ `release_eligible=true` の正式監査済みデータだけをNative形式へ変換。
- `QuestionRepository.swift`: `questions.release.json` が存在する場合はfail-closed。監査条件を満たさない正式バンクは起動時エラーとし、プレビューへ黙ってフォールバックしない。
- 法律科目は正式バンクで法令基準日必須。一般教養は法令基準日不要だが、正式変換前に一次資料・権利監査を要求する。

## 公式資料・採点正本

R6・R7・R8の法務省公式問題PDFをGitHub Actions runner上で取得し、年度構成をPDF本文から監査した。

- 法律基本科目はR6・R7・R8とも95問。
- 科目内訳: 憲法12、行政法12、民法15、商法15、民事訴訟法15、刑法13、刑事訴訟法13。
- 法律基本科目は210点満点。
- 一般教養: R6=42題、R7=44題、R8=44題。20題選択・1題3点・60点満点。
- 短答式全体: 270点満点。
- R6公式合格点: 165点以上。
- R7公式合格点: 159点以上。
- R6・R7は正答、解答欄、配点、順不同、部分点あり／なしを全問題単位で `official-scoring-canonical.v1.json` に固定。
- 同canonicalを `ios/Resources/official-scoring-canonical.v1.json` としてBundleへ収録。
- `OfficialScoringRepository.swift` が95問・210点・一般教養20/60・総計270を再検証し、不整合時はfail-closed。
- R7一般教養第41・42問の共通英文23行目 `were` → `wire` を訂正情報として保持。法務省の取扱いどおり特段の採点措置なし。
- R8は問題構成・法令基準日まで確定。2026-08-13時点で公式正答・配点・合格点は未確認のため、R6/R7から推測しない。

## 一般教養の権利ゲート

`triage_general_education_rights.py` と `official-general-education-rights-triage.v1.json` を追加した。

- 対象: R6 42題 + R7 44題 + R8 44題 = 130題。
- 出典・引用・原文変更、著者／作品、図表・写真、出版物／Web、著作権表示、長い英文、共通文章などを手動確認優先度の信号として検出。
- 信号0件でも利用可とは判定しない。
- 全130題を `manual_review_required` / `reuseEligible=false` / `clearanceBasis=null` から開始。
- トリアージJSONへ公式問題本文・第三者著作物の抜粋を保存しない。
- `Yobi Official Source Audit` #16で生成・検証・branch固定までPASS。

この監査は権利クリアランスではない。誤った自動許可を防ぐfail-closedゲートであり、公式一般教養本文のRelease許可は現在0題。

## 法令基準日

- R6（2024）: 2024-01-01
- R7（2025）: 2025-01-01
- R8（2026）: 2026-01-01

現行法学習と過去年度模試の法令時点を混同しない。

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

申請原稿は、固定価格0、推測ID0、法務省公式と誤認させる表現0を条件とする。公開ページはmain統合後にHTTP 200を再検証する。

## Production Releaseハードゲート

次が揃うまで署名工程をBLOCKする。

1. canonical `questions.release.json`
2. Bundle IDの明示値
3. App Store Connect App IDの明示値
4. IAP Product IDの明示値
5. canonical AppIcon SHA一致

`UNSET`、ビルド変数文字列、`jp.ci.*`、preview識別子は本番preflightで拒否する。

## 2026-08-13 Native CI確定結果

`Yobi Tantou Native iOS` #122 / head `d936a239434bba681f5fd026045b8332af669d8c` を受入基準とする。

- source-contract: PASS。
- native source contract: PASS。
- candidate preflight / exact-date source / answer audit: PASS。
- R6-R8公式PDF構造監査: PASS。
- release builder / production release preflight self-test: PASS。
- App Store draft consistency: PASS。
- XCTest: PASS。37 tests / 0 failures。
- XCUITest: PASS。Simulator再起動付き、インフラ起動失敗のみ1回再試行する方式へ改善。
- unsigned Release configuration build: PASS。
- Release app bundle: `questions.preview.json`、`official-scoring-canonical.v1.json`、Privacy Manifest、Assets、native executableを確認済み。

過去にGitHub Actionsのcancelled macOS jobがpost-job cleanupに残り、新runのPR-wide concurrencyを占有する症状が発生した。Native workflowはcommit SHA単位のconcurrencyへ変更し、新しい正しいrunを旧cleanupが停止させない構成へ変更した。

## 現在の受入条件

- [x] 最新 `audit_native.py` PASS
- [x] 最新 candidate preflight実データ PASS
- [x] 最新 release builder self-test PASS
- [x] 最新 production release preflight self-test PASS
- [x] 最新 App Store draft consistency PASS
- [x] 最新 XCTest PASS
- [x] 最新 XCUITest PASS
- [x] 最新 unsigned Release configuration build PASS
- [x] WebKit/WKWebView 0
- [x] Golden Master v2.1主要UI契約実装
- [x] App ID / Bundle ID / IAP Product IDの推測値0
- [x] 正本AppIconをDrive個別PNGから固定
- [x] R6-R8の年度×科目構成を一次資料PDFで確定
- [x] R6・R7の正答・配点・特殊採点を一次資料PDFでcanonical化
- [x] R7訂正資料の対象・採点影響を反映
- [x] 一般教養R6-R8全130題をfail-closed権利トリアージ
- [ ] 正式教材問題バンクのRelease監査PASS
- [ ] 公式問題本文を収録する場合の設問単位権利クリアランス
- [ ] R8公式正答・配点・合格点の公開後監査
- [ ] StoreKit Sandbox実機確認
- [ ] Internal TestFlight実機確認
- [ ] 外部Beta App Review／App Store本審査はユーザー承認後のみ

## 現在のブロッカー

- 正式教材問題バンク: 現在0問。14問は独自候補でありRelease承認前。
- 公式一般教養本文: 130題すべて権利クリアランス未完了。`reuseEligible=false`。
- R8公式正答・配点・短答合格点: 2026-08-13時点で未確認。推測しない。
- Bundle ID / App Store Connect App ID / IAP Product ID: 正式教材完成後の署名境界まで未設定を維持。

## 次の大ループ

1. 独自練習問題と公式年度模試問題をデータ上で分離し、独自問題が「令和X年公式模試」に混入しないReleaseゲートを実装。
2. 14独自候補を正式練習問題へ昇格できるよう、内容・一次根拠・法令時点・重複・権利のRelease監査を強化。
3. 正式問題バンクを拡充し、Golden Masterの日次・分野別・苦手復習を実教材で解放。
4. 公式問題本文を年度模試へ収録する場合のみ、設問単位権利クリアランスを行う。一般教養は全件BLOCKEDから開始。
5. R8公式正答公開時に採点canonicalへ追加。
6. 本番Bundle ID / App Store Connect App ID / IAP Product ID確定 → StoreKit Sandbox / 実機 → canonical AppIcon付きsigned build → Internal TestFlight。
7. External Beta Review / App Store本審査は明示承認まで実行しない。
