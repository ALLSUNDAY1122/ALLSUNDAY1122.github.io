# SCAN-005 Evidence — HQ Golden Gate Quality Metrics Harness

## Attempt
- worker: `worker3`
- branch: `task/SCAN-005/attempt-1`
- baseline: `1bb35c1070477fdc34d0082291e64e48a84abf91`
- integration epoch: `2`
- claim epoch: `1`

## Implemented
- `GoldenGroundTruth` / observed SHA / metric target / report models
- `GoldenQualityEvaluator`
  - page recall
  - mid-transition accepted count
  - duplicate rate
  - ordering accuracy
- PageCandidate lineage is used to count transition acceptance only for known candidates that reach CorrectedPage.
- `PageAuditResult` supplies ordered page IDs, duplicate groups, and review counts.
- expected/observed SHA are recorded as observations only; mismatch resolution is explicitly `HQ_ONLY`.
- JSON output uses deterministic sorted keys when pretty printing.
- Markdown report is HQ-readable and explicitly states that formal Golden PASS/FAIL is owned by `HQ_GOLDEN_GATE`.
- Worker report field is fixed to `NOT_ISSUED_HQ_GOLDEN_GATE_ONLY`.

## Fixture tests
Repository fixture tests: `scanner-parity/Tests/GoldenEvaluation/GoldenEvaluationTests.swift`

Cases added:
1. perfect fixture meets all metric targets without issuing Golden verdict
2. missing + misordered pages miss recall/order targets
3. transition candidate accepted into corrected pages is counted
4. duplicate group contributes duplicate-rate failure
5. SHA mismatch is recorded but ownership remains HQ
6. JSON/Markdown outputs contain no formal Worker PASS/FAIL

### Executed harness
A temporary SwiftPM harness was executed on Linux with `FrameExtraction`, `ImageCorrection`, and `PageAudit` represented by dependency-signature stubs matching the public types consumed by `GoldenEvaluation`.

Result:
- Swift build: PASS
- GoldenEvaluation module compile: PASS
- 6 XCTest cases were discovered/executed by the SwiftPM runner without assertion failure.

This proves the GoldenEvaluation logic/module boundary and fixture behavior. It does **not** claim Apple SDK integration compile; that is SCAN-007 responsibility.

## Acceptance mapping
- PageCandidate/CorrectedPageMetadata/PageAuditResult input -> metrics: COMPLETE
- no Golden originals committed; report-only JSON/Markdown: COMPLETE
- expected/observed SHA recorded without canonical decision: COMPLETE
- fixture threshold/report tests: COMPLETE
- no formal Worker Golden PASS/FAIL: COMPLETE

## Golden policy
`golden_status=NOT_APPLICABLE_WORKER` for this harness. It prepares evidence for the HQ post-integration Golden Gate but does not consume or adjudicate the formal Golden Dataset.

## Result
`INTEGRATION_READY`
