# Worker 3 Completion Roadmap

Scope: Page integrity, quality measurement, and BookPackage output validation.

## Final completion definition
Worker 3's lane is complete only when integrated output preserves page identity/order end-to-end and HQ Golden Gate reports no unresolved integrity defect attributable to PageAudit or PackageValidation.

Target outcomes:
- ordering accuracy: 100% target
- duplicate rate: <= 0.5%
- page recall contribution: >= 99% project target
- BookPackage manifest/image/text/PDF correspondence: 100%
- no unsafe/broken package references
- all low-confidence or failed pages remain observable as review items instead of being silently dropped

## Phase 1 — PageAudit core — DONE
- page-number OCR candidate scoring and position prior
- page-number + image similarity + text similarity + source timeline evidence
- missing/reversal/duplicate detection
- high-confidence auto-fix only; ambiguous cases remain review-required
- false missing suppression for adjacent reversal patterns
- fixture evidence and integration merge

## Phase 2 — Golden metrics harness — DONE
- page recall
- mid-transition accepted count
- duplicate rate
- ordering accuracy
- expected/observed SHA observation without canonical SHA decision
- JSON/Markdown parity report
- HQ owns formal Golden PASS/FAIL

## Phase 3 — BookPackage Integrity Verifier — ACTIVE (SCAN-010)
Acceptance closure:
1. decode manifest.json deterministically
2. verify manifest order, contiguous sequences, unique page_id and sequence
3. verify every image_path and text_path is safe and exists
4. reject path traversal / absolute paths
5. verify TXT can be read as UTF-8
6. compare searchable PDF page count to manifest page count
7. keep aggregate book.md/book.txt absence visible
8. emit structured issue codes and review page IDs
9. serialize report as JSON and Markdown
10. reproduce PASS/FAIL with synthetic fixture tests

## Phase 4 — HQ Golden calibration — POST-INTEGRATION
HQ provides canonical Golden input and runs integrated pipeline. Worker 3 fixes PageAudit/PackageValidation defects if metrics miss thresholds. Golden dataset absence or SHA mismatch is not a Worker BLOCKED_HUMAN condition.

Required calibration checks:
- known duplicate detection precision/recall
- known reversal detection precision/recall
- false missing-page rate
- ordering accuracy after auto-fix
- package page count/order/id correspondence
- PDF vs manifest page-count equality

## Phase 5 — Review Queue integration — CROSS-LANE
Confirm PageAudit and PackageValidation issue IDs survive into ReviewCore without losing source page ID, original order, image reference, or reason code. Do not redefine shared contract from Worker 3.

## Phase 6 — 200-page integrated regression
Re-run page integrity and package validation on long-run output after LongRun and PipelineOCR are merged. Confirm no duplicate generation after resume, no silent page loss, and stable package ordering.

## Phase 7 — Final closure loop
Repeat: HQ Golden Gate -> defect attribution -> targeted Worker 3 fix -> fixture regression -> integration -> HQ Golden rerun.

Exit only when:
- no unresolved Worker 3 defect remains
- BookPackage integrity report has zero errors on accepted Golden output
- ordering target is satisfied
- duplicate target is satisfied
- HQ Golden Gate owns and records final acceptance
