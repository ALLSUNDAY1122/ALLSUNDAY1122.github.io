# 書籍スキャナー同等化｜HQ Final Gate Status

Updated: 2026-08-24 JST
Owner: HQ
Integration branch: `scanner-parity/integration`

## Current integration

- PR #4544 `scanner-parity: Golden fix page eligibility and spread splitting` merged successfully.
- Golden-fix merge commit: `3134620a0f6d1dde253edd3af1f0ca39bbd65092`
- PR #4544 validated head: `85fd28f0c3801f205c7ce23f405ac0c9a936644f`
- PR #4544 base at validation: `f03b173bdb9f24604daf5a49aa57cca3a3d15b34`
- PR #4544 did not modify `scanner-parity/SHARED_CONTRACT.md`.
- PR #4555 restored this canonical HQ evidence path; merge commit: `190ec7b21b2107a08aa0fd4d04c72a5b28e6b9a4`.
- PR #4567 added the Formal HQ Golden E2E runner; merge commit: `74cfdcd332b4bdbe7c857fdcbfe16fd4ab3d9260`.
- PR #4569 added reference-PDF page metrics; merge commit/current product integration HEAD before this evidence-only update: `00eb294d479c93e10d1ce40d0d41d1a953b283e4`.

## Non-Golden acceptance

PR #4544 GitHub Actions run `32640669074` (`Scanner Parity Apple Validation`) completed with `success` on exact PR head `85fd28f0c3801f205c7ce23f405ac0c9a936644f`.

The exact workflow and fail-fast runner sources establish execution of:

- Apple validation harness contract
- final source contract
- Privacy / Security gate
- SwiftPM manifest resolution
- FrameExtraction / ImageCorrection / PageAudit Apple adapter compile
- ScannerRuntime iPhoneOS compile
- ReviewCore iPhoneOS compile
- Recovery iPhoneOS compile
- ProductFlow iPhoneOS compile
- AppShell iPhoneOS compile
- application Privacy manifest lint
- XcodeGen project generation
- unsigned Release `ScannerParity.app` build for iPhoneOS
- generated application bundle verification

The shell runners use fail-fast / pipe-failure propagation. This evidence satisfies the non-Golden integration acceptance for PR #4544. It is not a Formal Golden PASS.

## HQ Golden execution runner

PR #4567 exact head `e48dc3ec0ca7a0d0c12f47966596af16bd3b6652` passed `Scanner Parity Apple Validation` run `32650746143`.

The runner:

- is a macOS Swift executable `scanner-hq-golden-runner`;
- executes the same physical source files used by the app: `ProductionScannerRuntime.swift` and `GoldenHardenedScannerRuntime.swift`;
- drives the full `SourceVideo -> PageCandidate[] -> CorrectedPage[] -> PageAuditResult -> OCRPage[] -> BookPackage` production composition;
- records observed video/PDF SHA-256, reference PDF page count, stage page/review counts, and BookPackage required-file presence;
- does not commit or upload the raw Golden files;
- does not issue a Formal Golden PASS merely because the E2E run completes.

The initial macOS SwiftPM build exposed a pre-existing multiple-producer defect caused by README/unhandled files in the root target. HQ corrected the target source/exclusion definition and reran CI; the final exact-head run passed the runner build and all existing Apple/Privacy/Release regression gates.

## Golden reference-page metrics

PR #4569 exact head `5b76ad0dce85fc5638d740c0131e7cf950cd8438` passed `Scanner Parity Apple Validation` run `32651130098` in full.

The integrated reference matcher:

- renders every page of the reference PDF;
- generates Apple Vision feature prints for reference pages and final BookPackage page images;
- records nearest and second-best reference distance for every output page;
- never invents a default page-match threshold;
- with an explicitly calibrated threshold computes:
  - page recall;
  - unmatched output count (transition/non-book/other non-reference output proxy);
  - duplicate extra count and duplicate rate;
  - ordering accuracy using the unique matched sequence;
- includes synthetic tests covering perfect order, unmatched/missing page behavior, duplicate output, and reversal.

Threshold policy is intentionally fail-safe:

- no threshold supplied: `PENDING_REFERENCE_THRESHOLD_CALIBRATION`;
- the four reference metrics satisfy targets: `REFERENCE_METRICS_PASS_OTHER_GOLDEN_GATES_PENDING`;
- reference metrics fail: `REFERENCE_METRICS_FAIL`.

None of these strings is a Formal Golden PASS. The real dataset must first produce an observed distance distribution; HQ then calibrates the threshold from that evidence and reruns the same dataset.

## Formal HQ Golden Gate

Status: `PENDING_HQ_GOLDEN_EXECUTION`

Dataset version: `golden-v2-current-project-20260823`

Current observed identity:

- video SHA-256: `f95fb931dd57658d139a87df8f28b2545e293728a0f7663957b4cd8d5fd7c276`
- PDF SHA-256: `00f77321a221f7fb6d614a372b568c3b45292a2952bb2c113554ad2fa6d1d8c0`
- video: approximately 288.820 s / 8661 frames / 1108x512 / H.264
- PDF: 28 pages / 25,751,801 bytes / 1774x2429 / no text layer

Migration-era expected hashes remain audit history and must not be silently replaced by the current observed hashes.

The first Formal Golden execution failed because:

1. extraction reproduced about 60 stable candidates and allowed later settings/review/non-book stable states into the sequence;
2. correction emitted one page per stable candidate and could not split an open-book spread into multiple pages.

PR #4544 addresses those two root causes, but the same real Golden Dataset has not yet been rerun after merge.

Current Formal Golden metrics remain unissued until the same raw dataset is processed end-to-end on the integrated implementation. Required gates include:

- page recall >= 99%;
- transition-frame adoption = 0 / no unmatched non-reference output;
- duplicate rate <= 0.5%;
- ordering accuracy = 100% target;
- missing / reversal / duplicate detection;
- spread splitting;
- perspective / skew / crop / color / shadow correction quality;
- Japanese vertical and horizontal OCR;
- searchable PDF, page images, TXT, Markdown, manifest;
- BookPackage integrity.

## Raw Golden availability and next execution

Raw Golden files are intentionally not committed to GitHub. In the 2026-08-24 HQ session, the raw video/PDF could not be reacquired through the currently accessible ChatGPT File Library, execution sandbox, or connected Google Drive. No fixture result, compile result, synthetic metric result, or historical measurement is promoted to Golden PASS in place of the real rerun.

When the current raw Golden bytes are accessible, HQ execution order is fixed:

1. run the integrated `scanner-hq-golden-runner` without `--match-threshold` on the current video/PDF;
2. verify observed SHA-256 against the versioned current identity and preserve old migration hashes as history;
3. capture nearest/second-best reference distance distribution and full E2E/BookPackage evidence;
4. calibrate the page-match threshold from the real distribution rather than guessing it;
5. rerun with the calibrated threshold and evaluate page recall, unmatched outputs, duplicate rate, and ordering;
6. evaluate the remaining correction/OCR/audit/package Golden gates;
7. only if all Formal Golden gates pass may HQ proceed to Release Gate.

This does not reopen Worker work and is not a Worker `BLOCKED_HUMAN` condition. Workers 1-4 remain complete. Queue driving remains stopped. Golden validation remains HQ-owned.

## Release Gate

`NOT_STARTED` — Release Gate must not begin until Formal HQ Golden PASS is issued.
