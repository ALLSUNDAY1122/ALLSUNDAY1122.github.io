# Codex handoff — 司法書士試験・択一式｜学びスプリント

更新: 2026-08-09 JST

## 目的
この文書はChatGPT側で完了した開発状態をCodexへ引き継ぐための正本補助メモ。ここに書かれたPASS済み範囲を不用意に作り直さず、未完了ゲートから継続すること。

## 正本
- Notion 標準手順 v2.2: https://app.notion.com/p/3a909c10697d81e0961bd0fd27a77d39
- Notion 申請手順: https://app.notion.com/p/3b009c10697d81eba325f86d8af55481
- UI正本 v2.1 Golden Master: https://app.notion.com/p/3b609c10697d81f0b3d0f78d160a819f
- 問題生成・監査ループ v1.0: https://app.notion.com/p/3b609c10697d8148a0c2db3a8c8d5e63
- 司法書士 開発正本: https://app.notion.com/p/3b709c10697d81059119e5b324dbfb0c

## GitHub
- Repository: ALLSUNDAY1122/ALLSUNDAY1122.github.io
- iOS基盤PR: #4119
- PR merge commit: e9fd90e2b87fbf310d814cab0d0a1fb5ec9d5671
- 問題監査PR: #4095
- 問題監査 merge commit: 986e7fe01aebdfdcd0cf66f8f92c3ed63ab1146a

## PASS済み — 問題データ
- 令和5・6・7年度、各70問、合計210問。
- 午前35 + 午後35。
- 11科目件数は各年度で固定検証済み。
- R7午後33は `all_correct`。架空の正答番号を設定しない。
- 210問の公式本文・公式正答・固定短解説・出典/権利情報は監査済み。
- 問題データ: `learning-sprint/shoshi/content-loop/questions.generated.json`
- 共通validator: `automation/learning-sprint-question-pipeline/validate_questions.py`
- 内容監査レポート: `learning-sprint/shoshi/content-loop/content-audit-report.json`

### 重要な境界
- 現行の固定解説は「出題当時の公式正答を示す短い説明」。現行法の各肢詳細解説ではない。
- 正確な条文番号・判例番号は、公式問題に印字されていない場合は推測していない。
- 問題本文、正答、解説、法令基準、新年度問題を変更する場合は、影響する問題内容・制度・著作権監査PASSを失効させて再監査する。

## PASS済み — UI / PWA
- v2.1 Golden Master準拠。
- 今日のスプリント8問。
- 下部4タブ: ホーム / 模試 / 記録 / 設定。
- 生成り紙 + 藍 + 朱 + 緑 + 金。
- 210問接続、オフライン、JSON入出力、PWA、Safari実ブラウザ監査PASS。
- 初期プロトタイプは人間確認PASS済み。

## PASS済み — iOS基盤
主要パス: `learning-sprint/shoshi/ios/`

実装済み:
- SwiftUI + WKWebView。
- Web資産と210問をアプリ本体へローカル同梱。`file://`読込。
- StoreKit 2 Non-Consumable。
- Bundle ID: `jp.allsunday1122.shoshi`
- Product ID: `jp.allsunday1122.shoshi.premium`
- 価格はコード固定禁止。`Product.displayPrice`だけを使用。
- 価格未取得時は購入ボタン無効。
- 最初の「今日のスプリント」1回、最大8問を無料で試せる。
- 以後、年度×科目、模試、苦手復習、再スプリントはプレミアム対象。
- 購入復元、pending、revocation、entitlement更新対応。
- Privacy Manifest実装。
- Privacy / Support公開ページ実装。
- App Store metadata / Review Notes / StoreKit実機計画を作成済み。

主要ファイル:
- `learning-sprint/shoshi/ios/App.swift`
- `learning-sprint/shoshi/ios/project.yml`
- `learning-sprint/shoshi/ios/prepare-ios.sh`
- `learning-sprint/shoshi/ios/native-storekit.js`
- `learning-sprint/shoshi/ios/native_ui_audit.py`
- `learning-sprint/shoshi/ios/PrivacyInfo.xcprivacy`
- `learning-sprint/shoshi/validate-apple-preflight.mjs`
- `.github/workflows/shoshi-ios-release-gate.yml`
- `learning-sprint/shoshi/ios/codemagic-shoshi.yml`

## 辛口レビュー3回 — 完了
1. 起動直後Paywall誤表示を検出 → `[hidden]`競合修正。小型画面内スクロール対応。
2. アクセシビリティ → 背景`inert`、背景スクロール固定、モーダルフォーカス移動/復帰、Escape対応。
3. 課金表現 → サブスク無料トライアルと誤認しないよう「最初の1スプリントは無料 / プレミアムは買い切り」へ統一。

監査結果:
- 390×844 + 390×667 browser audit PASS。
- console error 0。
- StoreKit価格未取得時disabled、実行時価格反映、8問完了後ロック、restore bridge、premium unlock PASS。
- macOS/XcodeGen → IAP capability → unsigned Release Simulator build PASS。
- 生成 `.app` 内の210問、R7午後33、native-storekit、Privacy Manifest、Assets確認PASS。

## 現在のRelease BLOCKER — 最優先
### 1. 正本AppIconをGitHubへ配置
Google Drive正本:
- Name: `10_司法書士試験_択一式.png`
- Drive: https://drive.google.com/file/d/1lALyLGEVFvdWvMZVsQqdRnEJmJzUOFu7
- File ID: `1lALyLGEVFvdWvMZVsQqdRnEJmJzUOFu7`
- Expected SHA-256: `c34399358e182a4709f805127fc7244f9763a1f796bb68dfed24b5c4ee815506`
- Destination: `learning-sprint/shoshi/ios/AppIcon.png`

禁止:
- 再生成
- 切り出し
- 圧縮再保存
- 仮アイコンでArchive/TestFlight

配置後、必ずSHA-256一致を確認すること。

### 2. App Store Connect側
作成/確認:
- App name: `司法書士 学びスプリント`
- Bundle ID: `jp.allsunday1122.shoshi`
- SKU: `shoshi-sprint-ios`
- IAP type: Non-Consumable
- Product ID: `jp.allsunday1122.shoshi.premium`
- 正式価格をApp Store Connectで設定。

## Codemagic
司法書士専用workflow断片は:
`learning-sprint/shoshi/ios/codemagic-shoshi.yml`

root `codemagic.yaml` は他アプリの並行開発で頻繁に更新される。古い全体ファイルで上書きしないこと。最新mainを読み、司法書士workflowだけを追加する。

公開設定の方針:
- `submit_to_testflight: false` のまま、まずsigned IPAを生成する。
- `submit_to_app_store: false`。
- 人間確認前にApp Store審査提出しない。

## Codexでの推奨開始順
1. 最新 `main` をpull。
2. この `CODEX_HANDOFF.md` とNotion正本を読む。
3. 正本AppIconをDriveから取得し、`learning-sprint/shoshi/ios/AppIcon.png`へ無加工配置。
4. `shasum -a 256` で期待SHAと一致確認。
5. `.github/workflows/shoshi-ios-release-gate.yml` を実行し、canonical iconを含めRelease Gate全体をPASSさせる。
6. 最新root `codemagic.yaml`へ `codemagic-shoshi.yml` のworkflowだけを競合なく統合。
7. App Store ConnectのApp / IAP / 価格 / signingが存在するか確認。
8. signed IPA build。
9. Internal TestFlightへアップロード。
10. iPhone実機確認で停止し、ユーザーに確認を依頼。

## iPhone実機確認項目
- 初回起動。
- 今日のスプリント8問。
- 8問完了後の無料枠消費。
- Paywall表示と正式価格。
- 購入キャンセル。
- 購入成功。
- アプリ再起動後もpremium保持。
- 購入復元。
- 年度×科目、模試、苦手復習の解放。
- オフライン演習。
- JSON export/import。
- R7午後33が全員正答として扱われる。
- 小型画面、Safe Area、文字サイズ、背景スクロール、モーダル操作。

## 人間確認点
次の人間確認は **Internal TestFlightをiPhone実機へインストールした後**。
それ以前の実装・監査・署名準備はCodex側で可能な限り自律継続する。

## 完了判定
TestFlight実機確認前のRelease Gate PASS条件:
- canonical AppIcon SHA一致
- 210問validator PASS
- Apple preflight PASS
- native UI audit PASS
- macOS Release build PASS
- Privacy Manifest PASS
- App Store Connect App/IAP設定済み
- signed IPA生成成功
- Internal TestFlight upload成功

PASS状態を偽装しない。外部設定や署名が未確認ならBLOCKEDと明記すること。
