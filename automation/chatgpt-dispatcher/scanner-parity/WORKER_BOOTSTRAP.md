# 書籍スキャナー同等化｜Worker Pool 契約 v0.1

## 最終目的
動画で本を連続撮影・画面録画するだけで、ページ抽出、補正、ページ完全性監査、OCR、検索可能PDF、TXT/Markdownまで自動生成し、人間にも生成AIにも読みやすい書籍データを作る。

単なるPoC、compile成功、OCR単体成功、PDF生成だけを完成扱いにしない。

## 正本
- Notion「🚀 【標準手順】AIアプリ開発・公開フロー v2.7」
- Notion「分割セッション手順 v1.1｜AIアプリ開発のQueue駆動・並列化・統合運用」
- 本プロジェクトNotion正本（作成後にURL/IDを追記）
- GitHub `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- Integration branch `scanner-parity/integration`
- Dispatcher branch `automation/scanner-parity-dispatcher`
- Queue `automation/chatgpt-dispatcher/scanner-parity/queue.json`
- Shared contract `scanner-parity/SHARED_CONTRACT.md`

## Golden Dataset
初期評価はユーザー提供の実書籍動画・28ページ画像PDFを基準にする。成果物をGitHubへ原本転載しない。必要な評価指標・ハッシュ・ページ番号・観測結果だけをEvidenceとして保存する。

## Worker原則
1. Worker 1〜4は固定部署ではない。Queueの `READY` Taskから capability / dependency / resource lock 条件を満たすものを1件だけatomic claimする。
2. Queueを読んだだけで作業開始しない。claim成功後、read-backで `claimed_by / claim_token / claim_epoch` が自分であることを確認する。
3. 1 Wave = 1 Task Attempt。Taskごとに `task/<task-id>/attempt-<claim_epoch>` の短命branchを使う。
4. 旧epochはcanonical branch、Queue確定、production promotionを行わない。
5. `resource_locks` はファイルではなく意味領域で排他する。
6. 会話履歴を正本にしない。開始時・各Macro Wave開始時にNotion / GitHub / Queue / integration HEADを再取得する。
7. shared contract、integration、共通data model、app shellの変更はHQ所有。Workerが独自に契約を再定義しない。
8. 人間判断不要なら質問せず、調査→実装→test→監査→Evidence→INTEGRATION_READYまで進める。
9. 外部OSSはライセンスを確認し、採用・参考・不採用を明示する。ライセンス不明または競合制限があるコードをコピーしない。
10. secret/token/署名鍵/ユーザー提供書籍そのものをGitHubへ保存しない。
11. 実装変更は意味のある単位でcommitし、Task完了時にattempt branchへpushしてremote反映を確認する。
12. Task終了時は `evidence_path` に検証結果を保存し、自分のTaskだけを `INTEGRATION_READY` または `BLOCKED_*` へ更新する。MERGED/VERIFIEDはHQ/finalizerが確定する。

## 完成品質の方向性
- ページ再現率 >= 99%
- ページ送り途中採用 = 0を目標
- 重複率 <= 0.5%
- ページ順序 = 100%を目標
- 抜け/逆転/重複をページ番号OCR + 画像類似度 + 本文連続性 + 元動画時系列で監査
- 台形、傾き、クロップ、色、影、必要に応じ湾曲を補正
- 日本語縦書き/横書きOCRを評価
- 検索可能PDF + ページ画像 + TXT/Markdown + manifestを生成

## 再利用候補
優先評価対象：Apple Vision/VisionKit/PDFKit/CoreGraphics、OpenCV、swift-document-scanner、page-dewarp、PySceneDetect相当の考え方、Tesseract jpn/jpn_vert、OCRmyPDFの出力設計、OpenScannerのapp shell設計。

内部既存資産：Notion「いっしょに一冊（仮）｜10冊版iOS実装・PDFスキャナー v0.7」。当時のSwiftUI/輪郭検出/台形補正/PDFKit設計を再利用候補として評価する。OCR除外という旧要件は引き継がない。
