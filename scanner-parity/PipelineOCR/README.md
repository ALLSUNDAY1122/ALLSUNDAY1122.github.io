# SCAN-009 Pipeline OCR Bridge

`PageAuditResult -> OCRPage[] -> BookPackage` を既存型のまま接続するadapter。

## Contract

- `PageAuditResult.orderedPageIDs` を最終ページ順の正本として、BookPackageの `sequence` を1始まりで再構成する。
- `PipelinePageLineage` から `correctedImageRef` と `sourceTimeMS` を引き継ぐ。
- `OCRPage.text / blocks / layout / engine` はOCR結果を保持し、`sourceTimeMS` はlineageの値で正規化する。
- `needsReview` は OCR判定、PageAudit `reviewRequired`、stage failure のORで保持し、`BookManifest` と `reviewRequiredPageIDs` まで伝播する。
- PageAudit確定順に存在するページでOCRまたはlineage/image参照が欠ける場合、黙ってdropせず明示エラーにする。
- PageAudit確定順から除外された重複等のページは、lineage/OCR入力に残っていてもBookPackageへ再混入させない。

Shared Contractと既存のFrameExtraction / ImageCorrection / PageAudit / OCRExport型は変更しない。

## Fixture coverage

`Tests/PipelineOCR/PipelineOCRBridgeTests.swift` で以下を検証する。

1. PageAuditの隣接逆転修復後の順序がBookPackageへ反映される。
2. reorder後もページごとの `source_time_ms` とOCR本文が正しいページへ残る。
3. PageAudit reviewとOCR reviewがmanifestまで保持される。
4. horizontal / vertical / mixed layoutをstage横断で保持する。
5. audited pageのOCR欠落・lineage欠落・duplicate OCR IDをfail-closeする。
6. final audit orderから除外されたページをBookPackageへ戻さない。

Golden Datasetは不要で、正式Golden PASS/FAILは行わない。
