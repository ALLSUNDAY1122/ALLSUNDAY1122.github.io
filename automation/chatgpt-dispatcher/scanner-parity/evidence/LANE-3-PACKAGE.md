# LANE-3-PACKAGE Final Evidence

## Mission
Complete BookPackage / OCR-quality / output-integrity validation without changing the shared contract, so HQ can later inject the real Golden Dataset and receive machine-readable quality evidence.

Branch: `scanner-parity/worker3-package-quality-lane`

## Completed inherited work
- SCAN-003 PageAudit: merged previously; page number + image/text similarity + source timeline, missing/reversal/duplicate detection, conservative auto-fix.
- SCAN-005 Golden metric harness: merged previously; page recall, transition acceptance, duplicate rate, ordering accuracy and SHA observations.

## Completed in this lane
### SCAN-010 PackageValidation
- manifest decode and schema snapshot
- count/order/sequence/page_id checks
- duplicate sequence/page_id/image_path/text_path checks
- missing/broken image and TXT reference detection
- UTF-8 TXT validation
- safe relative-path / traversal protection
- searchable PDF presence and page-count comparison
- aggregate Markdown/TXT presence
- structured issue codes, review page IDs, JSON/Markdown reports

Fixture result: 9 tests / 9 PASS, Swift 6.2.1 Linux.

### PackageQuality
- searchable PDF text-layer coverage measurement
- searchable PDF page-text ordering against page TXT
- vertical / horizontal / mixed Japanese OCR quality fixtures
- fail-close for low-quality or unknown-layout OCR when `needs_review=false`
- preserve reviewed low-quality pages as warnings rather than silent acceptance
- Markdown `## Page N` boundary/order verification
- TXT `=== PAGE N ===` boundary/order verification
- manifest schema-version validation
- `source_time_ms` lineage coverage
- sequence-stable AI ingestion records
- machine-readable JSON and Markdown quality report

Fixture result: 7 tests / 7 PASS after isolating PDF text-layer fixtures from OCR quality fixtures.

Combined non-Golden fixtures: 16 / 16 PASS.

## Critical hardening performed during audit
1. Duplicate image/text references are hard errors even if the referenced file exists.
2. Missing `book_searchable.pdf`, `book.md`, or `book.txt` is a hard error for a completed BookPackage.
3. Unsafe absolute/path-traversal references fail closed.
4. An unreadable searchable PDF is an error; only an execution environment that lacks PDF text inspection support may emit an observation warning.
5. Low OCR confidence/short text/unknown layout cannot pass silently when `needs_review=false`.

## Apple / platform boundary
The production PDF page/text inspector uses PDFKit when available. Apple SDK integration compile is a separate project gate and was already verified by SCAN-007. Linux fixture tests use injected inspectors so package logic remains deterministic and does not pretend to be an Apple runtime validation.

## Shared-contract / cross-lane boundary
- Shared Contract: unchanged.
- Review/Recovery lane is not blocked or modified. LANE-3 emits stable issue code, page_id, sequence and needs-review/lineage information for final integration mapping.
- LongRun lane is not modified. Package validation is stateless over the completed BookPackage and is suitable for post-run validation of 200-page output.

## Golden boundary
No Golden original is stored in GitHub. Golden availability, canonical SHA resolution and formal PASS/FAIL remain HQ-owned. The lane is non-Golden complete; any PageAudit/PackageValidation/PackageQuality defect exposed by HQ Golden Gate returns to Worker 3 for targeted correction and rerun.

## Lane conclusion
Non-Golden acceptance: COMPLETE.
Final action: open one lane PR to `scanner-parity/integration`; Worker 3 must not merge its own final PR.
