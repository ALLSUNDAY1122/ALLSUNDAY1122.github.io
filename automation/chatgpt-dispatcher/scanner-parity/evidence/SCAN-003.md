# SCAN-003 Evidence｜ページ完全性監査

- worker: `worker3`
- claim_token: `d0e380f4-002d-4624-b2a9-728099600e5e`
- claim_epoch: `1`
- attempt_branch: `task/SCAN-003/attempt-1`
- baseline_sha: `99a8d30f2a09c85119869feabae9b411a3431133`
- integration_epoch: `1`
- task_status_at_evidence: `BLOCKED_HUMAN`

## 実装

`scanner-parity/PageAudit/` に以下を実装した。

- `PageAuditModels.swift`
  - Shared Contractの `ordered_page_ids / page_number_observations / duplicate_groups / missing_page_suspicions / reversal_events / auto_fixes / review_required` に対応する型を定義。
  - 各監査判断でconfidenceとevidence sourceを保持。
- `PageNumberScorer.swift`
  - 全角数字を正規化。
  - ページ端・ヘッダ/フッタ位置、OCR confidence、短い数字列を加点。
  - 年らしい4桁数値や複数数字列を減点/除外し、本文中の数字をページ番号と誤認しにくくした。
- `VisionPageAuditRecognizer.swift`
  - Apple Vision `VNRecognizeTextRequest` `.accurate`、`ja-JP + en-US`、language correctionを使用。
  - 0/90/180/270度を比較し、日本語量・有意味行・数字・ノイズで最良向きを選択。
  - 同一OCR結果からページ番号候補と本文テキストを生成する。
- `PagePerceptualHasher.swift`
  - 補正済みページ画像を端末内で9x8 grayscaleへ縮小し、64bit dHashを生成。
- `PageAuditInputFactory.swift`
  - corrected image + source timelineから、ページ番号OCR・本文・画像fingerprintを1つの `PageAuditInput` へ結合。
- `PageIntegrityAuditor.swift`
  - 元動画時系列を初期順序として保持。
  - ページ番号OCRだけでなく画像dHash類似度・本文trigram Jaccard類似度・source timelineを併用。
  - 重複、欠落、逆転を分離検出。
  - `10→12→11→13` のような逆転で、冊内に実在する11を「欠落」と二重誤検出しない。
  - 高信頼の同一ページ重複のみ自動削除。
  - 高信頼かつ前後連続性が一致する隣接1ページ反転のみ自動swap。
  - 低信頼ページ番号は元順序を変更せずreviewへ送る。
- `PageAuditReportFormatter.swift`
  - 1冊単位のMarkdown監査レポートを生成。

## 内部資産再利用監査

撮る単語帳の内部baselineを確認した。

- source commit: `a1385d1f997c25dff56b635906ed852d0b54567c`
- source: `toru-tango-mobile/modules/toru-tango-ocr/ios/ToruTangoOcrModule.swift`
- source blob SHA: `4ba553db64918462d49ef52760ed88fc51f9d711`
- 再利用した考え方:
  - Apple Vision `.accurate`
  - `ja-JP + en-US`
  - language correction
  - 4方向OCR比較
  - 日本語量 / 有意味行 / ノイズ減点による向き品質スコア
- 書籍向け拡張:
  - ページ番号専用の位置規則と短数字列スコア
  - 年・複数数字列の誤認抑制
  - 本文類似度をページ順監査へ利用

外部OSSコードのコピーは行っていない。Apple標準Frameworkとユーザー所有内部資産の設計baselineのみを使用。

## Privacy / Security

- OCR: Apple Visionの端末内処理。
- 画像fingerprint: CoreGraphics/ImageIOの端末内処理。
- 外部AI/APIへのページ画像送信経路は追加していない。
- secret / token / credential追加なし。

## Fixture Test

実行環境:

- Swift `6.2.1 (swift-6.2.1-RELEASE)`
- target `x86_64-unknown-linux-gnu`
- 実行: isolated Swift Packageで `swift test -q`
- 結果: **7 tests / 0 failures**

検証項目:

1. フッタの全角 `１２７` を本文中の `2026年8月` よりページ番号として優先。
2. `12 / 13` のような複数数字列をページ番号として不採用。
3. `10→12→11→13` を逆転として検出し、11のfalse missingを出さず、高信頼時だけ `10→11→12→13` に修復。
4. `10→12→13` では11を実欠落候補として検出。
5. 画像hash + 本文 + 同一ページ番号が一致する高信頼重複を自動削除。
6. 低信頼ページ番号では元動画順序を変更しない。
7. 1冊単位Markdown監査レポートの主要sectionを生成。

Test source:

- `scanner-parity/Tests/PageAudit/PageAuditTests.swift`

## Golden Dataset Gate

実書籍Golden DatasetはこのWorkerセッションの実行環境から取得できなかったため、**Golden PASSは付けない**。

既知の正本:

- `本 2026-08-23 0842.pdf`
- expected SHA-256: `7c75889931949df96c0c1f9fba6fdef4e670a196675418b184444120a1d50567`
- 正本上の既知欠陥: 冒頭の誤キャプチャ、ページ順逆転候補、重複候補。

未実施:

- 上記28ページGolden PDFでのページ単位precision/recall実測。
- 既知の逆転・重複候補を実画像から再検出するAcceptance確認。
- Apple SDK上でのVision/CoreGraphicsコードの実コンパイル/実機OCR確認。

したがってPoC/fixture成功を完成扱いにせず、Taskは `BLOCKED_HUMAN` とする。Golden PDFをWorkerが取得可能な実行面へ再接続し、Apple SDK buildを通した後にAcceptanceを再評価する。

## Branch read-back

実装ファイルとテストは `task/SCAN-003/attempt-1` 上でremote read-back済み。

主な最新コミット:

- `dd16a27d0e8f5d7065c0a474bd6d1fbffcc616bc` false missing抑制
- `f64d9547af0f82147fe04e2341223e38b889b8ba` Vision 4方向OCR
- `b4b3c63792fa61321b9a02cf35b26eedc10f9bb2` 監査レポート
- `7956959050600fd32dddb6e5b034eac4f85de326` fixture tests
- `c66c42c9a80d80d0538246d92c8852a404f10fdd` dHash
- `183e2cb7d305d6aab89c6bcc994cad7d06c17f23` corrected image→audit input接続
