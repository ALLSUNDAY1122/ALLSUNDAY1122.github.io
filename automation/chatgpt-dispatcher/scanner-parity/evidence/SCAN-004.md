# SCAN-004 Evidence｜日本語OCR・検索可能PDF・AIデータ書き出し

- worker: `worker1`
- claim_token: `c219bcba-aa08-44ac-9961-471e077afa53`
- claim_epoch: `1`
- attempt_branch: `task/SCAN-004/attempt-1`
- baseline_sha: `99a8d30f2a09c85119869feabae9b411a3431133`
- integration_epoch: `1`
- task_status_at_evidence: `BLOCKED_HUMAN`

## 実装

`scanner-parity/OCRExport/` に以下を実装した。

- `OCRModels.swift`
  - Shared Contractの `OCRPage` / `BookPackage` に必要なOCR本文、block座標、confidence、engine、layout、review flag、元動画時刻を型定義。
  - manifestは `page_id / image_path / text_path / source_time_ms / ocr_confidence / needs_review / engine / layout` を保持。
- `AppleVisionBookOCR.swift`
  - Apple Vision `VNRecognizeTextRequest` `.accurate`。
  - `ja-JP + en-US`、language correction、`minimumTextHeight = 0.006`。
  - 0/90/180/270度を比較し、書籍向けquality scoreで最良候補を採用。
  - OCR blockのnormalized bounding boxを保持し、検索可能PDFのtext layerへ渡せる。
- `OCRQualityScorer.swift`
  - Vision confidence、日本語比率、有意味行、本文長、断片行、noiseを合成。
  - 低品質・短すぎるページを `needs_review` にする。
  - block形状から horizontal / vertical / mixed / unknown を推定。
- `ReadingOrder.swift`
  - 横書き: 上→下、同一行は左→右。
  - 縦書き: 右列→左列、同一列は上→下。
  - mixedは縦横block比率に応じた保守的heuristic。
- `TesseractComparison.swift`
  - Tesseract TSVをnormalized OCR blocksへ変換。
  - macOS/Linux開発時にTesseract CLIを使って `jpn` / `jpn_vert` をApple Visionと比較できるharnessを追加。
  - Tesseractは初期iOS runtimeの必須dependencyにはしていない。
- `PageImageWriter.swift`
  - BookPackageの `pages/NNNN.jpg` が拡張子だけJPEGになる事故を避けるため、Apple環境ではImageIOで実JPEGへ正規化。
- `SearchablePDFWriter.swift`
  - UIKit/CoreText利用可能環境では補正済みページ画像をPDFページとして描画。
  - OCR block座標に対応するinvisible text layerを重ね、見た目のページ画像を維持しながら検索可能PDFを生成する設計。
- `BookPackageWriter.swift`
  - sequenceを昇順に固定し重複sequenceを拒否。
  - `pages/NNNN.jpg`, `text/NNNN.txt`, `book.md`, `book.txt`, `manifest.json`, 対応環境では `book_searchable.pdf` を生成。
  - low-confidence page IDをreview listとして返す。
  - source imageを逐次書き出しし、200ページ分の画像を一括decodeして保持しない。

## 内部資産再利用監査

撮る単語帳の内部baselineを確認した。

- PR `#3959`
- PR `#4064`
- source branch: `qa/toru-tango-mobile-20260726`
- source: `toru-tango-mobile/modules/toru-tango-ocr/ios/ToruTangoOcrModule.swift`
- source blob SHA: `4ba553db64918462d49ef52760ed88fc51f9d711`
- `app/(tabs)/create.tsx` の複数画像順序保持、OCR編集、削除、再撮影導線も確認。

再利用した考え方:

- Apple Vision `.accurate`
- `ja-JP + en-US`
- language correction
- 4方向OCR比較
- 日本語量 / 有意味行 / noiseによるquality判定
- 複数画像を選択順に処理する方針
- OCR失敗を自動確定せず編集/再撮影へ戻せる復旧方針

書籍向け拡張:

- OCR block座標保持
- 横書き / 縦書き / mixed layout
- 縦書きreading order
- searchable PDF text layer
- page image / OCR / source timeをmanifestで対応付け
- BookPackage生成前の `needs_review` page抽出

撮る単語帳のGemini画像送信経路は本Taskへ転用していない。

## Privacy / Security

- 初期OCR標準経路はApple Visionの端末内処理。
- OCRExport moduleに外部AI/API/network送信経路を追加していない。
- Tesseract比較は開発環境のローカルCLIのみ。
- secret / token / credential追加なし。
- 書籍ページ画像・Golden Dataset原本をGitHubへ保存していない。

## Fixture Test

実行環境:

- Swift `6.2.1`
- target `x86_64-unknown-linux-gnu`
- 実行: 同期したisolated Swift Packageで `swift test`
- 結果: **6 tests / 0 failures**

検証項目:

1. 横書きreading orderが上→下・左→右になる。
2. 縦書きreading orderが右→左・上→下になる。
3. 日本語本文をPASSし、noise/低confidence OCRをreviewへ送る。
4. Tesseract TSVをconfidence + normalized box付きblockへ変換する。
5. BookPackageが入力順に依存せずsequence順を保持し、review flagとmanifest/textを生成する。
6. **200ページ級BookPackage**を逐次書き出しし、200件のmanifest・最後のimage/textまで生成する。ローカル実測約1.1秒、crashなし。

Tesseract環境:

- Tesseract `5.5.0`
- `jpn` available
- `jpn_vert` available

## Acceptance対応状況

- 日本語横書き/縦書きOCR: **実装済み / fixture PASS / Golden未測定**
- Apple Vision vs Tesseract jpn/jpn_vert: **比較harness実装済み / Golden比較未測定**
- 撮る単語帳baseline再利用評価: **実施済み**
- 複数画像順序・編集/削除/再撮影UX転用評価: **実施済み**。app shellはHQ ownershipのためWorker scope外で独自変更していない。
- 元画像を保持した検索可能PDF: **実装済み / Apple SDK・実書籍text selection未検証**
- ページ別TXT + book Markdown/TXT: **fixture PASS**
- manifest: **fixture PASS**
- low-confidence review: **fixture PASS**
- 外部AI画像送信なし: **PASS（実装静的監査）**
- 200ページ級Export: **fixture PASS**

## Golden Dataset / Apple SDK Gate

実書籍Golden DatasetはこのWorkerセッションの実行環境から取得できなかったため、**Golden PASSは付けない**。

既知の正本:

- `RPReplay_Final1787451151.mp4`
  - expected SHA-256 `37642d44cf881d4e595535e57d13bd4e11a8f93eae4f879e230e5301efecc714`
- `本 2026-08-23 0842.pdf`
  - expected SHA-256 `7c75889931949df96c0c1f9fba6fdef4e670a196675418b184444120a1d50567`
  - 28 image pages / OCR text layerなし（正本記録）

未実施:

- Golden実書籍でApple Vision横書き/縦書きOCRの文字品質実測。
- 同一Golden pageでApple Vision / Tesseract `jpn` / `jpn_vert` の比較。
- iOS/macOS Apple SDK上でVision/ImageIO/UIKit/CoreText条件分岐部分の実コンパイル。
- 実書籍PDFで検索・文字選択し、invisible text layerの座標一致を確認。
- BookPackage review listを実アプリUIの編集/削除/再撮影導線へ接続する統合確認。

したがってfixture/PoCだけを完成扱いにせず、Taskは `BLOCKED_HUMAN` とする。Golden DatasetをWorkerから取得可能な実行面へ接続し、Apple SDK build + 実書籍OCR/PDF評価を行った後に `INTEGRATION_READY` を再判定する。

## Branch / Scope read-back

`scanner-parity/integration` はbaseline `99a8d30f2a09c85119869feabae9b411a3431133` と一致したまま。

`task/SCAN-004/attempt-1` はintegrationより12 commits ahead / 0 behindで、Evidence作成前の実装差分は以下10ファイルのみ。

- `scanner-parity/OCRExport/Package.swift`
- `scanner-parity/OCRExport/Sources/OCRExport/AppleVisionBookOCR.swift`
- `scanner-parity/OCRExport/Sources/OCRExport/BookPackageWriter.swift`
- `scanner-parity/OCRExport/Sources/OCRExport/OCRModels.swift`
- `scanner-parity/OCRExport/Sources/OCRExport/OCRQualityScorer.swift`
- `scanner-parity/OCRExport/Sources/OCRExport/PageImageWriter.swift`
- `scanner-parity/OCRExport/Sources/OCRExport/ReadingOrder.swift`
- `scanner-parity/OCRExport/Sources/OCRExport/SearchablePDFWriter.swift`
- `scanner-parity/OCRExport/Sources/OCRExport/TesseractComparison.swift`
- `scanner-parity/OCRExport/Tests/OCRExportTests/OCRExportTests.swift`

Shared Contract / integration / app shellは変更していない。

主な最新コミット:

- `43f8aae063a467452baeb5dac3a9a6917c078cf5` Apple Vision 4方向OCR
- `a2bc60d2314df643426204f5ca2e350244c45a5c` Tesseract比較harness
- `2e2fb8321ef449940d7f9e47045233c585ff7b92` searchable PDF
- `cc755680dc2b9b363042161729a2705d3aaada3b` JPEG正規化
- `1fde44224ee1b6cdd43a6fa6bbb0d0ec0399ab2c` BookPackage JPEG接続
- `64efe4c5e7a4e0d89b0772e221697434729fc658` 200ページfixture test
