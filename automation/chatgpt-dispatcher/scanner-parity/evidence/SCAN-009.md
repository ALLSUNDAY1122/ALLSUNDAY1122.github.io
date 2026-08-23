# SCAN-009 Evidence

## Task
PageAudit→OCRExport→BookPackage E2E Bridge

## Baseline / branch
- integration baseline: `45e420e9befb52ccb1b26837f3c7fd41078701c3`
- branch: `task/SCAN-009/attempt-1`
- implementation head: `544467c450398bce2320dc0b5f294696d994984c`
- PR: #4499

## Acceptance evidence
- `PageAuditResult.orderedPageIDs` をBookPackage sequenceの正本として使用。
- `PipelinePageLineage.correctedImageRef/sourceTimeMS` をOCR artifactとmanifestへ引き継ぐ。
- OCR本文・layout・engineを保持し、source_timeはlineageへ正規化。
- `OCRPage.needsReview || PageAudit.reviewRequired || stageFailure` を最終 `needs_review` としてmanifestまで伝播。
- audited final orderに必要なOCR/lineage/image参照が欠ける場合はfail-closeし、黙ってdropしない。
- final audit orderから除外されたページは入力側に残っていてもBookPackageへ再混入しない。
- horizontal / vertical / mixed OCR layout fixtureを実装。
- Shared Contractおよび既存stage型は変更していない。

## Fixture / verification
Repository fixture:
- `scanner-parity/Tests/PipelineOCR/PipelineOCRBridgeTests.swift`
- `scanner-parity/Tests/PipelineOCR/run-fixtures.sh`

Fixture coverage:
1. PageAudit隣接逆転修復後の順序をPackageへ反映
2. reorder後のsource_time/text lineage照合
3. Audit review + OCR reviewの伝播
4. horizontal/vertical/mixed layout保持
5. OCR欠落 fail-close
6. lineage欠落 fail-close
7. duplicate OCR ID fail-close
8. final audit order除外ページの再混入防止

Local semantic harness:
- Swift: `6.2.1`
- target: `x86_64-unknown-linux-gnu`
- result: `PASS`
- verified: final order, source_time mapping, mixed layouts, review propagation, text file lineage, missing OCR fail-close
- harness used contract-compatible definitions matching the integrated public signatures; repository runner is retained as the reproducible canonical fixture.

GitHub PR CI:
- workflow: `Scanner Parity Apple Validation`
- run: `32625239428`
- conclusion: `success`
- purpose: scanner-parity Apple adapter regression check after SCAN-009 diff

## Scope audit
PR #4499 changed only:
- `scanner-parity/PipelineOCR/PipelineOCRBridge.swift`
- `scanner-parity/PipelineOCR/README.md`
- `scanner-parity/Tests/PipelineOCR/PipelineOCRBridgeTests.swift`
- `scanner-parity/Tests/PipelineOCR/run-fixtures.sh`

This is fully inside SCAN-009 write_scope.

## Golden policy
- `golden_status=NOT_APPLICABLE_WORKER`
- Golden Dataset not required for this bridge fixture.
- No formal Golden PASS/FAIL or canonical SHA decision is made by Worker 1.

## Result
`non_golden_acceptance=COMPLETE`
`INTEGRATION_READY`
