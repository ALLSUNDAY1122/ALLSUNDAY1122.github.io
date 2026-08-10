# 通関士｜学びスプリント Native Release Status

更新日: 2026-08-10

## 現在地
純SwiftUIネイティブ移行の実装・専門監査3周を実施。Release Gateは未通過。Internal TestFlight未実施。

## 固定識別子
- Bundle ID: `jp.allsunday1122.tsukanshi`
- App Store Connect App ID: `6799753744`
- Codemagic profile: `tsukanshi_appstore`
- Product ID: `jp.allsunday1122.tsukanshi.premium`
- Team ID: `MN3D2ZM44N`
- Version: `1.0.0`

## 実装済み
- WKWebViewを主UIから完全除去
- ホーム／模試／記録／設定の4タブ
- 4／8／16問、既定8問
- singleChoice / multiChoice / numeric / blankSelect / declaration
- 即時採点、`わからない`正式回答
- 苦手登録、3連続正解で解除
- 中断・再開
- 学習履歴、科目別正答率、5週間ヒートマップ
- 科目・模試・実務演習の完答回数
- 計算／申告書演習の専用導線
- JSONバックアップ／復元
- StoreKit 2 非消耗型、`Product.displayPrice`、購入復元
- verified entitlementのみ解放。pending/cancel/unverified/revocationで新規解放しない
- 監査済み480学習問＋申告書12セットをビルド時JSONへ変換
- `contentVersion` / `lawBaselineDate` / `sourceCheckedAt` / 権利根拠を保持
- 公式過去問本文は同梱せず、税関公式ページを外部リンクで開く
- portrait固定、iPhone専用、iOS 16.0+

## 今回の監査で修正済み
1. JSONバックアップの日時がISO-8601文字列化で精度落ちし、厳密round-trip testがFAIL → Foundation reference-dateのDoubleで保存し、旧ISO-8601バックアップも読める後方互換decoderへ修正。
2. スプリント開始直後はresume snapshotを保存しておらず、異常終了時に途中再開情報を失う可能性 → 開始時点からsnapshot保存。
3. 通常学習の回答直後にsnapshotへ回答内容が反映されない経路 → 回答記録と同時にsnapshot更新。
4. 複数選択で必要数未満のまま採点可能、必要数超過も選択可能 → 必要選択数を上限兼採点条件として固定。
5. 非公開Google Drive AppIconをCIが匿名curlし、HTML/中間レスポンスを画像として受け取る → ネットワーク取得を廃止。正本PNGを明示stageし、bytes/SHA-256/IHDRをオフライン検証する方式へ変更。
6. 無料模試が画面表示の問題数より減る将来退行を検知できない → free mock count regression test追加。

## 正本AppIcon
- Notion/Google Drive正本: `02_通関士.png`
- 1024×1024 / 8-bit RGB / alphaなし
- bytes: `556001`
- SHA-256: `ff9fd508930e8728ef54907ec64a7835dcffb69a1a773edc645b79715fbfccaa`
- stage先: `tsukanshi-sprint/native-ios/CanonicalAssets/02_通関士.png`
- 仮画像、再描画、一覧画像からの切り出しは禁止。

## テスト状況
- 共通 `LearningSprintCore` の日時round-trip修正後CI: PASS。
- 480＋12、権利・出典メタデータ、WebKit参照0のFast Preflightは前回PASS済み。
- 今回追加したresume/multi-choice/free mock回帰テストを含むmacOS Full Gateは、正本AppIcon未stageのため最終PASS未確認。
- Release simulator build / XCTest / 小型・大型iPhone UI testは、最新HEADでは未PASS確認。
- StoreKit Sandbox購入・再起動後権利維持・購入復元は実機/TestFlight環境で未実施。

## Codemagic
- root `codemagic.yaml` の `tsukanshi-ios` は旧 `tsukanshi-sprint/ios` WKWebView targetを参照しており、純SwiftUI版の配布設定としてはFAIL。
- 正しいnative候補を `tsukanshi-sprint/native-ios/codemagic-native-workflow.yaml` に作成済み。
- native candidateは `TsukanshiNative.xcodeproj` / `TsukanshiNative`、Bundle ID `jp.allsunday1122.tsukanshi`、ASC App ID `6799753744` を固定し、`submit_to_testflight: true` / `submit_to_app_store: false`。
- 実際のInternal TestFlight前にroot `codemagic.yaml` の対象workflowへ反映し、Codemagicで `tsukanshi_appstore` が選択されることを確認する。

## Release blockers
1. 正本 `02_通関士.png` がGitHub branchの `CanonicalAssets/` にまだ未配置。
2. そのため最新HEADのmacOS Full Gate Release build＋XCTest＋小型/大型iPhone UI testを完走できていない。
3. root `codemagic.yaml` が旧WKWebView workflowのまま。
4. signed IPA / App Store Connect upload / Internal TestFlight未実施。
5. TestFlight実機でStoreKit Sandbox購入・復元未実施。

## 判定
- UI/教材/状態設計/StoreKit 2実装: **暫定PASS**
- 最新HEAD macOS Full Gate: **FAIL（AppIcon stage待ち）**
- Codemagic native distribution config: **FAIL（root未切替）**
- Internal TestFlight: **FAIL（未配布）**
- App Store本審査: 対象外。自動提出禁止。
