# Worker 3 Completion Roadmap — LANE-3-PACKAGE

Scope: BookPackage, OCR quality, output integrity, and AI-ingestion usability.

## Final completion definition
Worker 3's lane is non-Golden complete when BookPackage output can be deterministically validated for identity/order/completeness/text-layer/OCR-review/lineage using synthetic fixtures, and the final lane PR is open to integration. Formal real-book Golden acceptance remains HQ-owned.

Target outcomes:
- ordering accuracy: 100% target
- duplicate rate: <= 0.5%
- project page recall: >= 99% target
- BookPackage manifest/image/text/PDF correspondence: 100%
- searchable PDF text-layer coverage/order: 100% on accepted package
- Markdown/TXT page-boundary order: 100%
- AI-ingestion lineage coverage: 100%
- no unsafe/broken/duplicate package references
- low-confidence/failed OCR pages are observable as review items, never silently accepted

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

## Phase 3 — SCAN-010 BookPackage Integrity Verifier — DONE
- deterministic manifest decode
- manifest order / contiguous sequence / unique sequence / unique page_id
- duplicate image_path / text_path detection
- safe image/text relative references and path traversal rejection
- referenced image/TXT existence
- UTF-8 TXT readability
- searchable PDF page count vs manifest count
- required searchable PDF / book.md / book.txt existence
- structured issue codes and review page IDs
- JSON/Markdown integrity report
- synthetic PASS/FAIL fixtures

## Phase 4 — PackageQuality deep validation — DONE
- searchable PDF text-layer coverage
- searchable PDF page-text order against per-page TXT
- Japanese vertical / horizontal / mixed OCR fixtures
- low-quality/unknown-layout OCR must be review-marked or fail closed
- Markdown `## Page N` boundary/order verification
- TXT `=== PAGE N ===` boundary/order verification
- manifest schema-version check
- `source_time_ms` lineage coverage
- flattened, sequence-stable AIIngestionRecord generation
- JSON/Markdown quality-report interface consumable by HQ Golden Gate

## Phase 5 — Cross-lane Review/Recovery compatibility — READY FOR FINAL INTEGRATION
Worker 3 emits stable issue codes, page IDs, sequence values, needs-review state and source lineage. ReviewCore may map those values during final integration. Worker 3 does not redefine Shared Contract and does not wait for another lane.

## Phase 6 — Long-run regression compatibility — READY FOR FINAL INTEGRATION
PackageValidation is stateless over a completed package and can be run after 200-page LongRun output. Required final-integration checks are no silent page loss, no duplicate output after resume, stable sequence ordering, and zero package-integrity errors.

## Phase 7 — HQ Golden calibration — POST-INTEGRATION / HQ OWNED
HQ supplies canonical real-book inputs and runs the integrated pipeline. Worker 3 owns targeted fixes if Golden results expose PageAudit/PackageValidation/PackageQuality defects. Golden dataset absence or SHA mismatch is never a Worker BLOCKED_HUMAN condition.

Required Golden checks:
- known duplicate detection precision/recall
- known reversal detection precision/recall
- false missing-page rate
- ordering accuracy after auto-fix
- package count/order/page_id/image/text correspondence
- searchable PDF page count and text-layer order
- OCR-review correctness on vertical/horizontal/mixed pages
- AI-ingestion lineage completeness

## Exit state for this lane
Non-Golden lane exit requires:
- PackageValidation fixtures PASS
- PackageQuality fixtures PASS
- no Shared Contract modification
- final LANE-3 Evidence saved
- final PR open toward `scanner-parity/integration`

Project-wide final acceptance additionally requires HQ Golden Gate to record the real-book result and any Worker 3-attributed defect to be fixed and rerun.
