# 書籍スキャナー同等化｜Worker Pool 契約 v0.3

## 最終目的
動画で本を連続撮影・画面録画するだけで、ページ抽出、補正、ページ完全性監査、OCR、検索可能PDF、TXT/Markdownまで自動生成し、人間にも生成AIにも読みやすい書籍データを作る。

単なるPoC、compile成功、OCR単体成功、PDF生成だけを完成扱いにしない。

## 正本
- Notion「🚀 【標準手順】AIアプリ開発・公開フロー v2.7」
- Notion「申請手順」 page id `3b009c10-697d-81eb-a325-f86d8af55481`
- Notion「分割セッション手順 v1.1｜AIアプリ開発のQueue駆動・並列化・統合運用」
- Notion「書籍スキャナー同等化｜動画式ブックスキャナー＋AIデータ化 正本」 page id `3c509c10-697d-8139-867e-c3f7605665ed`
- GitHub `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- Integration branch `scanner-parity/integration`
- Dispatcher branch `automation/scanner-parity-dispatcher`
- Queue `automation/chatgpt-dispatcher/scanner-parity/queue.json`
- Shared contract `scanner-parity/SHARED_CONTRACT.md`

## Golden Dataset
初期評価はユーザー提供の実書籍動画・28ページ画像PDFを基準にする。成果物をGitHubへ原本転載しない。必要な評価指標・ハッシュ・ページ番号・観測結果だけをEvidenceとして保存する。

- `RPReplay_Final1787451151.mp4`
  - SHA-256 `37642d44cf881d4e595535e57d13bd4e11a8f93eae4f879e230e5301efecc714`
- `本 2026-08-23 0842.pdf`
  - SHA-256 `7c75889931949df96c0c1f9fba6fdef4e670a196675418b184444120a1d50567`

移行先プロジェクトにGolden Datasetが未添付でも実装・fixture test・Evidence作成を進める。実書籍Golden PASSはWorkerが付けず、`PENDING_HQ_GOLDEN` としてHQ統合後の専用Golden Gateへ送る。
Golden Datasetの取得可否、canonical SHAの確定・SHA mismatch解消、実書籍Golden実測、Golden PASS/FAIL判定はHQ所有とする。

## Golden停止条件の恒久ルール
**「Golden Dataset未取得、SHA mismatch、Golden実測未完了だけを理由にBLOCKED_HUMANへ遷移してはならない。非Golden acceptanceが完了したTaskはINTEGRATION_READYへ送り、Golden検証はHQ統合Gateで行う。」**

- WorkerはGolden関連だけが未完了の場合、TaskのGolden状態を `PENDING_HQ_GOLDEN` と記録し、Task本体は `INTEGRATION_READY` にする。
- `BLOCKED_HUMAN` は、仕様選択・権限・契約・2FA・実機最終受入など、実際に人間判断または人間操作がなければ安全に前進できない場合だけ使用する。
- Golden SHA mismatchをWorkerの人間判断Gateへ変換してはならない。Evidenceへ観測SHAを残してHQへエスカレーションし、Workerは非Golden acceptanceを継続する。
- Golden正式検証はWorker単位では行わず、HQが対象Taskをintegrationへ統合した後、専用 `HQ_GOLDEN_GATE` で一気通貫に実施する。

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
11. 実装変更は意味のある単位でcommitし、標準手順v2.7のcheckpointルールに従う。実装を伴う回答3回ごと、または長時間離脱・人間Gate・Build前には担当branchへpushしremote read-backする。
12. Task終了時は `evidence_path` に検証結果を保存し、自分のTaskだけを `INTEGRATION_READY` または真正な `BLOCKED_*` へ更新する。MERGED/VERIFIEDはHQ/finalizerが確定する。Goldenだけが未完了なら `golden_status=PENDING_HQ_GOLDEN` を残して `INTEGRATION_READY` にする。
13. **撮る単語帳を必須内部参照資産として監査する。** Notion「撮る単語帳｜正本・関連資料」、GitHub PR #3959/#4064、特に `toru-tango-mobile/modules/toru-tango-ocr/ios/ToruTangoOcrModule.swift`、`app/(tabs)/create.tsx`、Safari OCR比較資産を確認し、使える実装を再利用する。ユーザー所有コードなので直接転用可能だが、書籍Golden Datasetに適合しないロジックを無検査でコピーしない。
14. 撮る単語帳で発生した第三者AI画像送信とPrivacy申告不一致を再発させない。初期版は端末内OCRを標準とし、外部AIへ書籍画像を送る経路は必須依存にしない。将来導入する場合は送信前の明示同意・Privacy申告・保持/ログ監査を必須Gateとする。
15. 写真・カメラ・書籍ページを扱うためPrivacy監査を必須とする。外部AI/API/認証を導入するTaskはSecurity監査も起動する。
16. 課金・広告は未決定。Product ID・価格・広告SDKをWorkerが独自判断で追加しない。

## 完成品質の方向性
- ページ再現率 >= 99%
- ページ送り途中採用 = 0を目標
- 重複率 <= 0.5%
- ページ順序 = 100%を目標
- 抜け/逆転/重複をページ番号OCR + 画像類似度 + 本文連続性 + 元動画時系列で監査
- 台形、傾き、クロップ、色、影、必要に応じ湾曲を補正
- 日本語縦書き/横書きOCRを評価
- 検索可能PDF + ページ画像 + TXT/Markdown + manifestを生成
- 200ページ級長尺処理でcrashしない

## Release / Submission原則
開発完了まではApp Store申請を先行しない。Release Gate通過後にNotion「申請手順」へ移行する。

申請工程ではBuild前preflightを必須とし、Bundle ID / App ID / Version / Build番号、Support URL / Privacy Policy URL、App Privacy、Age Rating、輸出コンプライアンス、Review Detail、Screenshots、IAP有無、TestFlight状態をread-backする。API/CIで安全に処理できる工程はAPI-firstで進める。

`Submit for Review`、公開、2FA、契約・税務・銀行、iPhone実機最終受入は人間Gateとし、Workerは実行しない。

## 再利用候補
優先評価対象：Apple Vision/VisionKit/PDFKit/CoreGraphics、OpenCV、swift-document-scanner、page-dewarp、PySceneDetect相当の考え方、Tesseract jpn/jpn_vert、OCRmyPDFの出力設計、OpenScannerのapp shell設計。

内部既存資産：
- Notion「いっしょに一冊（仮）｜10冊版iOS実装・PDFスキャナー v0.7」。当時のSwiftUI/輪郭検出/台形補正/PDFKit設計を再利用候補として評価する。OCR除外という旧要件は引き継がない。
- Notion「撮る単語帳｜正本・関連資料」およびGitHub PR #3959/#4064。Apple Vision OCR、4方向比較、OCR品質スコア、複数画像順序保持、OCR編集/再撮影、教材向け補正比較、後方互換保存の実装を再利用候補として評価する。
