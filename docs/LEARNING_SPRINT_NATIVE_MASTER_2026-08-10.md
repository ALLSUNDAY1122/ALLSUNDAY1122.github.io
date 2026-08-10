# 学びスプリント｜SwiftUI Native移行マスター

更新: 2026-08-10 JST
担当: ChatGPT（Codexへ引継がない）

## 最上位固定識別情報

| # | App | Bundle ID | App Store Connect App ID | Codemagic profile | IAP |
|---|---|---|---|---|---|
| 1 | 危険物乙4 | `jp.allsunday1122.otsu4` | `6799755566` | `otsu4_appstore` | `jp.allsunday1122.otsu4.premium` |
| 2 | 通関士 | `jp.allsunday1122.tsukanshi` | `6799753744` | `tsukanshi_appstore` | 資格正本の既存Product IDを使用 |
| 4 | 管理栄養士国家試験 | `jp.allsunday1122.kanrieiyoushi` | `6799753841` | `kanrieiyoushi_appstore` | 資格正本の既存Product IDを使用 |
| 5 | 薬剤師国家試験 | `jp.allsunday1122.yakuzaishi` | `6799753724` | `yakuzaishi_appstore` | 資格正本の既存Product IDを使用 |
| 6 | 応用情報技術者試験 | `jp.allsunday1122.apmanabisprint` | **未記載・推測禁止** | `apmanabisprint_appstore` | 未記載・推測禁止 |
| 7 | ネットワークスペシャリスト試験 | `jp.allsunday1122.networkspecialist` | **未記載・推測禁止** | `networkspecialist_appstore` | 現行初期版は課金なし |
| 9 | 公認会計士短答 | `jp.allsunday1122.cpamanabisprint` | `6799754783` | `cpamanabisprint_appstore` | 未記載・推測禁止 |
| 10 | 司法書士 | `jp.allsunday1122.shoshi` | `6799755748` | `shoshi_appstore` | `jp.allsunday1122.shoshi.premium` |

共通: Team `MN3D2ZM44N` / Version `1.0.0` / App Store distribution / Internal Testing only / App Store本審査自動提出禁止。

## 共通ネイティブ要件
- SwiftUIでホーム／模試／記録／設定を実装し、WKWebViewを主UIとして使用しない。
- 標準8問、4／8／16問。
- 生成り紙＋藍＋朱＋緑＋金。学習本文は明朝、操作はゴシック。
- 通常問題は選択肢タップで即時採点。`わからない`を正式回答。
- 誤答／わからない→苦手。3連続正解で解除。
- 中断・再開、履歴、5週間ヒートマップ、試験日、JSONバックアップ／復元、完全オフライン。
- VoiceOver、Dynamic Type、44pt以上、portrait、横スクロールなし。
- `contentVersion` / `lawBaselineDate` / `sourceCheckedAt` を問題単位で保持。
- StoreKit 2はverifiedかつ非revokedのみ解放。価格は`Product.displayPrice`のみ。購入復元を常設。

## 現状と不足

### #1 危険物乙4
**現状:** `feat/otsu4-360-productization` に真正SwiftUI native実装あり。360問、無料72、模試3×35、StoreKit 2、単体/UIテストを実装。最新Content Audit/Native TypecheckはPASS。

**不足:** PR #4069がDraft未マージ。最新Xcode Build＋小型/大型iPhone UI testの完了確認、App Store署名付きIPA、Internal TestFlight、実機購入・復元。

**Release blocker:** 署名/TestFlight実機ゲート。コード面では8アプリ中もっとも進んでいるため共通実装の参照元とする。

### #2 通関士
**現状:** 480学習問＋申告書12、権利監査、StoreKit 2、Privacy、申請資料、Xcode Simulator buildまで存在。ただし現行iOS主UIはSwiftUI＋WKWebView。

**不足:** 全画面のSwiftUI native化。5回答型（single/multi/numeric/blank/declaration）をネイティブ表示。既存監査済みJS問題バンクをビルド時に正規化JSONへ変換。

**Release blocker:** WKWebView主UI。native移行後の単体/UIテスト、Codemagic profile `tsukanshi_appstore`でのsigned IPA、Internal TestFlight。

### #4 管理栄養士
**現状:** 600問、200問模試×3、StoreKit 2、Privacy、Simulator技術ゲートPASS。ただし主UIはSwiftUI＋WKWebView。

**不足:** 10分類／600問／3模試をnative化。既存無料60問・Premium範囲を維持。

**Release blocker:** WKWebView主UI＋採用AppIconの正本バイトをRelease環境へ搬送する既存BLOCKER。

### #5 薬剤師
**現状:** 111/110/109回×345＝1,035問（採点対象1,031）、監査・StoreKit・Privacy・Simulator Preflightまで完了。ただし主UIはSwiftUI＋WKWebView。

**不足:** 必須／理論／実践、症例連問、将来`examSystemVersion`をnativeデータ駆動化。

**Release blocker:** WKWebView主UI。native移行・signed IPA・Internal TestFlight・実機購入復元。

### #6 応用情報
**現状:** 別repo `ALLSUNDAY1122/it-passport-quiz-ios` Draft PR #1。科目A 240問、Privacy、AppIconあり。ただし実装はSwiftUI＋WKWebViewラッパーで、旧監査の「Native source PASS」は今回要件では失効。

**不足:** 科目A 240問を真正SwiftUIへ置換。2027制度移行用`examSystemVersion`を維持。Xcode実ビルド未確認。

**Release blocker:** WKWebView主UI、Cloud Xcode gate未PASS、App Store Connect App ID未記載（推測禁止）。

### #7 ネットワークスペシャリスト
**現状:** 75出題枠／68 canonical unique、権利・UI監査、iOS wrapperあり。現行Release StatusがSwiftUI＋WKWebViewを明示。初期版は課金なし。

**不足:** 科目A-2中心の真正SwiftUI化、2027制度移行データ駆動化、正本AppIcon配置。

**Release blocker:** WKWebView主UI、正本AppIcon、App Store Connect App ID未記載（推測禁止）、signed IPA/TestFlight。

### #9 公認会計士短答
**現状:** Web/PWA・279問構成資産・権利監査資産あり。現時点で検索可能な完成iOS native targetは確認できない。

**不足:** 4科目、93問模試、英語問題対応を含むSwiftUI iOS targetを新規作成。問題・第三者権利フラグをnative decoderへ維持。

**Release blocker:** native iOS target未完成、IAP Product ID未記載（課金を導入する場合は推測禁止）、signed IPA/TestFlight。

### #10 司法書士
**現状:** 210問、StoreKit 2、Privacy、Simulator build、辛口レビューまで存在。ただし主UIはSwiftUI＋WKWebView。

**不足:** 午前35＋午後35、11科目、公式訂正メタデータを真正SwiftUI化。

**Release blocker:** WKWebView主UI＋採用AppIcon正本バイト配置＋signed IPA/TestFlight/実機購入復元。

## 実装順
1. 共通 `LearningSprintCore` をXCTestで固定。
2. #1 乙4を共通ネイティブ基準として最終CIまで通す。
3. #2 通関士を共通コアへ移し、5回答型を完成。
4. #4 / #5 / #10 の既存wrapperをnativeへ移行。
5. #6 別repoのWebView targetをnativeへ置換。
6. #7をnative化（課金なしを維持）。
7. #9にnative targetを新設。
8. 各資格で問題監査→単体/UIテスト→2サイズ以上→辛口レビュー3回→Release Gate。
9. Codemagic profileを正本名へ一致させ、signed IPA→ASC upload→Internal TestFlight。
10. App Store本審査はユーザー最終承認まで実行しない。

## ループ失効ルール
- 既存の「SwiftUI＋WKWebViewでPASS」は、今回の「WebViewだけの簡易実装禁止」に対してnative UI PASSとして扱わない。
- 既存問題監査・権利監査・Privacy・申請原稿は、内容変更がない限り再利用可能。ただしデータ変換時は件数・ID・正答・出典の同値監査を必須とする。
- 識別情報は `docs/APP_STORE_IDENTIFIERS_CANONICAL.md` とユーザー指定値を最優先し、未記載値を補完しない。
