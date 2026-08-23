# SCAN-008 Pipeline Contract Bridge

`FrameExtraction -> ImageCorrection -> PageAudit` の既存型を変更せず接続する薄いadapter。

## 目的

- `PageCandidate.candidateID / bookID / sourceTimeMS / sourceRangeMS / flags` を補正・監査境界で消失させない。
- `CorrectedPageMetadata.pageID / candidateID` と上流IDの不一致を黙って通さない。
- 補正失敗・低境界信頼度をページごと破棄せず `PageAuditResult.reviewRequired` へ伝播する。
- PageAuditへ渡す `sourceTimeMs` は必ず元 `PageCandidate.sourceTimeMS` を使用し、動画時系列を正本として保持する。

## 型

- `PipelinePageRecord`: PageCandidate、補正metadata、補正画像ref、監査signal、stage failureを1ページ単位で保持。
- `PipelinePageLineage`: stage横断で監査可能なID/time/flagsのEvidence用projection。
- `PipelineAuditBridge`: `PageAuditInput` を生成し既存 `PageIntegrityAuditor` を呼び、stage-level reviewを結果へ合流する。

Shared Contractおよび既存FrameExtraction/ImageCorrection/PageAudit型は変更しない。

## Failure policy

補正処理が失敗しても、そのページを監査入力から除外しない。`PageCandidate` の時刻とpage IDを残した `PageAuditInput` を生成し、`PageReviewReason.conflictingEvidence` と `stage_failure:` 詳細を付与する。低境界信頼度、ID lineage mismatchも同じくreviewへ送る。

## Fixture coverage

`Tests/PipelineCore/PipelineAuditBridgeTests.swift` で以下を再現する。

1. lineage保持
2. 正常順
3. 重複
4. 欠落
5. 隣接逆転と高信頼修復
6. stage failure伝播
7. low-confidence伝播
8. page/candidate ID mismatch検出

Golden原本は使用しない。SCAN-008は `golden_status=NOT_APPLICABLE_WORKER` であり、正式Golden判定は行わない。
