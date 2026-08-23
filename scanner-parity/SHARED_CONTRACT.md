# 書籍スキャナー同等化｜Shared Contract v0.2

HQ所有。Workerはこの契約を独自に変更しない。変更が必要な場合はEvidenceと提案を出し、HQがintegration_epochを進める。

## Pipeline

`SourceVideo -> PageCandidate[] -> CorrectedPage[] -> PageAuditResult -> OCRPage[] -> BookPackage`

## Core IDs
- `book_id`: 1冊を一意に識別するUUID/安定ID
- `candidate_id`: 動画内候補フレームを一意に識別
- `page_id`: 採用ページを一意に識別
- `source_time_ms`: 元動画での代表フレーム時刻
- `source_range_ms`: 安定区間の開始/終了

## PageCandidate
必須情報：
- `candidate_id`
- `book_id`
- `source_time_ms`
- `source_range_ms`
- `image_ref`
- `stability_score` 0...1
- `sharpness_score` 0...1
- `motion_score`
- `duplicate_group_id?`
- `flags[]`

禁止：ページ番号やOCR本文をFrameExtractionが正本として確定しない。

## CorrectedPage
- `page_id`
- `candidate_id`
- `corrected_image_ref`
- `original_image_ref`
- `crop_quad`
- `rotation_degrees`
- `perspective_applied`
- `dewarp_applied`
- `color_profile`: `archive | reading | ocr`
- `quality_scores`
- `flags[]`

画像補正は原画像を破棄しない。

## PageAuditResult
- `ordered_page_ids[]`
- `page_number_observations[]`
- `duplicate_groups[]`
- `missing_page_suspicions[]`
- `reversal_events[]`
- `auto_fixes[]`
- `review_required[]`
- 各判定に `confidence` と根拠sourceを持つ

自動修復は高信頼のみ。低信頼は元順序を破壊せずHuman Reviewへ送る。

## OCRPage
- `page_id`
- `language`
- `layout`: `vertical | horizontal | mixed | unknown`
- `text`
- `blocks[]`
- `ocr_confidence`
- `engine`
- `engine_version`
- `needs_review`

## BookPackage
最低出力：

```text
BOOK_ID/
  pages/
    0001.jpg
    0002.jpg
  text/
    0001.txt
    0002.txt
  book_searchable.pdf
  book.md
  book.txt
  manifest.json
```

原動画は端末/ユーザー指定保存先に保持可能とするが、GitHub Evidenceへ転載しない。

## Searchable PDF
- 見た目は補正済みページ画像を保持
- OCR text layerをページ座標へ対応付ける
- ページ順はPageAudit確定順を使用
- 元画像とOCRを再照合できるmanifestを必須とする

## Quality Gates
初期目標：
- page recall >= 99%
- mid-transition accepted = 0
- duplicate rate <= 0.5%
- ordering accuracy = 100%目標
- 200ページ級の連続処理でcrashしない
- OCR低信頼ページを検知可能

### HQ_GOLDEN_GATE
Golden Datasetの正式検証はWorker単位ではなく、対象実装をintegrationへ統合した後にHQが一気通貫で実施する。

- Golden Dataset未取得、canonical SHA mismatch、Golden実測未完了はWorkerの `BLOCKED_HUMAN` 条件ではない。
- 非Golden acceptanceが完了したTaskは `INTEGRATION_READY` とし、Golden部分のみ `PENDING_HQ_GOLDEN` として保持する。
- Golden SHA mismatchの解決、canonical hash更新判断、Golden実測、PASS/FAIL確定はHQ所有。
- HQ_GOLDEN_GATEでは統合済みpipelineを対象に、ページ抽出・補正・完全性監査・OCR・検索可能PDF・BookPackageまで同一Golden Datasetで検証する。
- Golden PASS前に `VERIFIED` / Release Gate通過を確定してはならない。

## Resource Ownership
- `frame-extraction`, `video-timeline`: Worker Task SCAN-001系
- `image-processing`, `page-geometry`: SCAN-002系
- `page-audit`, `sequence-model`: SCAN-003系
- `ocr-export`, `document-output`: SCAN-004系
- `shared-contract`, `app-shell`, `integration`, `golden-gate`: HQ

## Reuse Policy
直接採用候補はライセンス確認必須。MIT/BSD/Apache等でもNOTICE/attribution/変更点を記録する。競合製品制限、用途制限、ライセンス不明のコードはコピーしない。

内部既存資産Notion「いっしょに一冊（仮）｜10冊版iOS実装・PDFスキャナー v0.7」は設計・実装再利用候補として評価するが、旧要件のOCR除外は継承しない。
