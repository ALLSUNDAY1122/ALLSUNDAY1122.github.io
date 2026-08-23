# 書籍スキャナー同等化｜ChatGPT Project移行引継ぎ

更新: 2026-08-23 12:02 JST

## 1. 移行判定
`MIGRATION_READY`

この文書は移行補助であり正本ではない。移行先HQは開始時にNotion / GitHub / Queue / integration HEADを再取得し、会話履歴やこの文書だけで現在状態を確定しない。

## 2. 推奨ChatGPT Project名
`書籍スキャナー同等化`

推奨セッション構成:
- HQ 1
- Worker Pool 4

Workerは固定部署ではない。GitHub Queueからatomic claimする。

## 3. 最終目的
本を連続撮影または画面録画するだけで、ページ送り途中を除外した完成ページ抽出、書籍向け補正、ページ番号/抜け/逆転/重複監査、日本語OCR、検索可能PDF、ページ画像、TXT/Markdown、manifestまで自動生成する。

人間の読書用と生成AIの知識源の両方で実用品質にする。

## 4. 正本
### Notion
- `🚀 【標準手順】AIアプリ開発・公開フロー v2.7`
  - page id: `3a909c10-697d-81e0-961b-d0fd27a77d39`
- `申請手順`
  - page id: `3b009c10-697d-81eb-a325-f86d8af55481`
- `分割セッション手順 v1.1｜AIアプリ開発のQueue駆動・並列化・統合運用`
  - page id: `3bd09c10-697d-81ca-b637-c02d1f00d22d`
- `書籍スキャナー同等化｜動画式ブックスキャナー＋AIデータ化 正本`
  - page id: `3c509c10-697d-8139-867e-c3f7605665ed`
- 内部再利用資産: `いっしょに一冊（仮）｜10冊版iOS実装・PDFスキャナー v0.7`
- 内部再利用資産: `撮る単語帳｜正本・関連資料`

### GitHub
Repository: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`

- Integration: `scanner-parity/integration`
- Integration baseline at migration: `99a8d30f2a09c85119869feabae9b411a3431133`
- Dispatcher: `automation/scanner-parity-dispatcher`
- Queue: `automation/chatgpt-dispatcher/scanner-parity/queue.json`
- Worker contract: `automation/chatgpt-dispatcher/scanner-parity/WORKER_BOOTSTRAP.md`
- Worker start prompt: `automation/chatgpt-dispatcher/scanner-parity/START_PROMPT.md`
- Shared contract: `scanner-parity/SHARED_CONTRACT.md`

## 5. Golden Dataset
著作物原本はGitHubへ保存しない。ChatGPT Projectへユーザーが再添付する。

### Video
- filename: `RPReplay_Final1787451151.mp4`
- size: 190105098 bytes
- SHA-256: `37642d44cf881d4e595535e57d13bd4e11a8f93eae4f879e230e5301efecc714`
- sample observation: 約4分49秒 / 8661 frames / 1108x512

### Current scanner PDF
- filename: `本 2026-08-23 0842.pdf`
- size: 25751801 bytes
- SHA-256: `7c75889931949df96c0c1f9fba6fdef4e670a196675418b184444120a1d50567`
- 28 image pages
- page images approx 1774x2429
- OCR text layerなし
- 冒頭に誤取り込みがあり、ページ順逆転・重複候補もGolden defectとして使用する

Golden Datasetが未添付でもfixtureによる実装は可能。ただし実書籍でのParity PASSは付けない。

## 6. 初回Queue
- `SCAN-001`: Stable Frame Engine
- `SCAN-002`: Image Correction
- `SCAN-003`: Page Integrity Audit
- `SCAN-004`: Japanese OCR / Searchable PDF / AI export

移行時点では4 TaskともREADY。claim前に必ず最新Queueをread-backする。

## 7. 内部資産の利用方針
### いっしょに一冊
再利用候補:
- SwiftUI書籍スキャンUI
- 自動輪郭検出
- 台形補正
- 補正済みページ取得
- PDFKit閲覧

旧要件の「OCR除外」は継承しない。

### 撮る単語帳
必須参照:
- PR #3959 / #4064
- `toru-tango-mobile/modules/toru-tango-ocr/ios/ToruTangoOcrModule.swift`
- Apple Vision OCR `.accurate`
- `ja-JP + en-US`
- language correction
- 0/90/180/270度比較
- 日本語量/有意味行/ノイズによるOCR quality score
- 複数画像順序保持
- OCR編集/削除/再撮影UX
- 原画像/補正画像/Otsu等のOCR比較設計

撮る単語帳で発生した第三者AI画像送信とPrivacy申告不一致を再発させない。初期標準経路は端末内OCR。

## 8. 外部再利用候補
- Apple Vision / VisionKit / PDFKit / CoreGraphics
- OpenCV
- `swift-document-scanner`
- `page-dewarp`
- PySceneDetect相当の変化区間ロジック
- Tesseract `jpn` / `jpn_vert`
- OCRmyPDFの検索可能PDF構造
- OpenScannerのapp shell設計

コード採用前にライセンス/NOTICE/競合制限を確認する。

## 9. 品質Gate
初期目標:
- page recall >= 99%
- mid-transition accepted = 0
- duplicate rate <= 0.5%
- ordering accuracy = 100%目標
- ページ抜け/逆転/重複を検知し、高信頼だけ自動修復
- 台形/傾き/色/影補正
- 必要ならdewarp
- 日本語横書き/縦書きOCR
- OCR低信頼ページを要確認化
- searchable PDF + page images + TXT/Markdown + manifest
- 200ページ級長尺でcrashしない

PoC/compile/OCR単体/PDF生成だけでは完了扱いにしない。

## 10. 標準手順 v2.7 適用
- 正本はルーター、詳細は専門手順、反復は品質ループとして運用する。
- 実装回答ごとにローカルcommit。3実装回答ごと、または長時間離脱/人間Gate/Build前にGitHub checkpoint push + remote read-back。
- 写真/カメラを扱うためPrivacy監査必須。
- 外部AI/API/認証を追加するならSecurity監査必須。
- 課金/広告は未決定。決定時に専門手順を起動する。
- 開発完了後のみ申請手順へ移る。

## 11. 申請手順の適用
Release Gate通過後、Build前にSubmission Orchestrator preflightを行う。

確認対象:
- Bundle ID / App Store Connect App ID
- Version / Build番号
- Version/App Info localization
- Support URL / Privacy Policy URL
- Review Detail
- Age Rating
- App Privacy
- 輸出コンプライアンス
- Screenshots / previews
- IAP/Subscription（導入時のみ）
- Build / processing / Version紐付け
- Internal TestFlight group / tester
- Review Submission状態

分類:
- AUTO-FIX
- BUILD-REQUIRED
- HUMAN-REQUIRED
- FINAL-APPROVAL

API/CIで安全にできるものは read → canonical照合 → write → read-back で自動化する。

人間Gate:
- Appleログイン / 2FA / 本人確認
- 契約 / 税務 / 銀行
- iPhone実機最終受入
- `Add for Review` / `Submit for Review`直前の最終承認
- 公開の最終判断

## 12. 移行後の最初のHQ動作
1. Notion正本4件を再取得。
2. GitHub integration / dispatcher / Queue / Worker contract / Shared contractを再取得。
3. `integration_head` と各Task `baseline_sha` が実integration HEADと一致するか検証。
4. Golden Dataset添付の有無とSHA-256を確認。
5. 4 Taskのclaim競合がないことを確認。
6. Worker 1〜4を起動。
7. HQはshared contract、integration、Parity、Privacy/Release Gateを所有する。

会話履歴を正本にしない。