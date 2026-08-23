# SCAN-010 Evidence — BookPackage Integrity Verifier

## Scope
BookPackage output validation for searchable PDF / page images / per-page TXT / aggregate Markdown+TXT / manifest lineage.

## Implementation
Branch: `task/SCAN-010/attempt-1`

Implemented under:
- `scanner-parity/PackageValidation/Package.swift`
- `scanner-parity/PackageValidation/Sources/PackageValidation/PackageValidationModels.swift`
- `scanner-parity/PackageValidation/Sources/PackageValidation/PackageIntegrityVerifier.swift`
- `scanner-parity/PackageValidation/Tests/PackageValidationTests/PackageIntegrityVerifierTests.swift`
- `scanner-parity/PackageValidation/ROADMAP.md`

## Acceptance coverage
- manifest page count/order/id correspondence: implemented
- duplicate sequence detection: implemented
- duplicate page_id detection: implemented
- duplicate image/text reference detection: implemented
- non-contiguous sequence detection: implemented
- image/text reference existence: implemented
- UTF-8 text readability: implemented
- unsafe absolute/path-traversal reference rejection: implemented
- searchable PDF page count vs manifest page count: implemented through injected `PackagePDFInspecting`; PDFKit implementation is used when available
- missing searchable PDF/book.md/book.txt: hard error
- structured review page IDs: implemented
- JSON/Markdown report generation: implemented
- Golden original data is not stored or required for this Worker task

## Fixture / compile evidence
Environment: Swift 6.2.1, x86_64-unknown-linux-gnu.

Command:
`swift test`

Result:
- build: PASS
- tests: 9 executed
- failures: 0
- unexpected failures: 0

Covered fixture cases:
1. valid package PASS
2. duplicate sequence/page_id FAIL
3. duplicate image/text references FAIL
4. missing image + unreadable TXT FAIL and review IDs preserved
5. manifest order mismatch + sequence gap FAIL
6. searchable PDF page-count mismatch FAIL
7. missing PDF/book.md/book.txt FAIL
8. path traversal FAIL
9. JSON round-trip + Markdown report PASS

## Boundary / Gate
Linux cannot inspect real PDF with PDFKit; this does not block Worker completion because the package provides an injected inspector and production builds use PDFKit when available. Apple SDK compile validation is already a separate project gate. Formal Golden PASS/FAIL remains owned by `HQ_GOLDEN_GATE`.

## Worker conclusion
Non-Golden acceptance: COMPLETE.
Recommended task status: `INTEGRATION_READY`.
Golden status: `NOT_APPLICABLE_WORKER`.
