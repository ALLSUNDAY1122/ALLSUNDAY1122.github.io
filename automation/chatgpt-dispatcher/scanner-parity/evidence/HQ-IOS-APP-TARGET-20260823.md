# HQ iOS Application Target / Golden Gate Readiness

Date: 2026-08-23 JST
Owner: HQ

## Integrated application target

- Integration branch: `scanner-parity/integration`
- PR: #4535 `scanner-parity: add real iOS application target`
- Merge commit: `a306302e8cc95b6eb54af3c6db60cac083e772b2`
- Post-merge compare: integration is identical to merge commit (ahead 0 / behind 0).

## Final-head Apple CI

- Workflow: `Scanner Parity Apple Validation`
- Run: `32634402276` / run number 62
- Head under validation: `8e3721beb9e0b11bc026b01ecbe3ea743d1fe04f`
- Conclusion: PASS
- Existing Apple adapter compile: PASS
- Final product modules / privacy / security gates: PASS
- XcodeGen project generation: PASS
- Unsigned Release build for generic iPhoneOS: PASS
- Actual `ScannerParity.app` bundle verification: PASS
- Production Bundle ID / Version / Build number remain unresolved by design; CI uses non-release validation values only.

## Golden Gate readiness

Formal `HQ_GOLDEN_GATE` remains pending. The canonical real-book inputs are expected as:

- `RPReplay_Final1787451151.mp4`
- `本 2026-08-23 0842.pdf`

HQ searched both current-conversation uploads and File Library by exact filenames and semantic Golden Dataset context on 2026-08-23; neither canonical binary was retrievable. Returned results were unrelated files and must not be substituted.

This is not a Worker `BLOCKED_HUMAN` state. Worker implementation and integration are complete. It is an HQ data-availability gate for formal same-Golden measurement.

When the two canonical binaries become accessible, HQ must execute the same-input end-to-end measurement for at least:

- page recall
- mid-transition accepted count
- duplicate rate
- ordering accuracy
- image correction quality
- OCR quality
- searchable PDF text layer
- BookPackage integrity

Do not declare parity completion before that formal measurement and final iPhone device acceptance.