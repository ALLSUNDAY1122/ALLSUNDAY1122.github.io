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
- PR #4569 added reference-PDF page metrics; merge commit: `00eb294d479c93e10d1ce40d0d41d1a953b283e4`.
- PR #4570 synchronized HQ evidence; merge commit: `b7b5fd5d6b27b7e356f14bf525184f5f193be053`.
- PR #4571 fixed macOS searchable-PDF generation for the HQ Golden runner; merge commit: `8a1b4c4accac1a9b23c4a51eeed2cd6ca063cbe1`.
- PR #4572 synchronized HQ evidence after the searchable-PDF fix; merge commit: `60e725de5e727959844fc93d5581f115ec3dc74b`.
- PR #4573 added the Formal Golden machine-gate aggregator; merge commit: `3bd3a53d4f84fe69ae01cea8d679ea87887a2a42`.
- PR #4574 synchronized HQ evidence after machine-gate aggregation; merge commit: `2bded3d2417dfa0f5788ba58671a3b3f4afd001e`.
- PR #4580 added the local Formal Golden visual/OCR review bundle; merge commit: `315c085a72303cdffc0edcf8932f7bb3363320a8`.
- PR #4581 synchronized HQ evidence after the review-bundle integration; merge commit: `050c3a02e36eee049838bc63bd13e4084061bf91`.
- PR #4584 added the SHA-bound Formal Golden human-review finalizer; merge commit: `4e92833193b835bbf09158551847febb3bbfc8c1`.
- PR #4585 synchronized HQ evidence after the finalizer integration; merge commit: `25216b4f12b5bb06bad188bea8b5033ab9d24028`.
- PR #4588 added fail-safe Formal Golden pipeline-failure evidence; merge commit: `705e7608e038f5e6566a26c0a61ffe3dae9a0c85`.
- PR #4590 synchronized HQ evidence after failure-evidence integration; merge commit: `dd168258de934568146d00f82803a4d58ef22139`.
- PR #4591 added a 240-page production-runtime long-run gate; validated head: `a2a2b4d0b0367239434430e4fb8509ba9ea5fd7f`; merge commit/current product-code integration HEAD before this evidence-only update: `b49cdb1004190933117f65f9effa3c230625e74d`.

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

## macOS searchable-PDF prerequisite fix

PR #4571 exact head `f9d950868fbb80533c887074958cadfc703a4d57` passed `Scanner Parity Apple Validation` run `32652036917` in full and merged as `8a1b4c4accac1a9b23c4a51eeed2cd6ca063cbe1`.

HQ found that the existing `SearchablePDFWriter` only generated `book_searchable.pdf` when UIKit was importable. Because the Formal Golden runner executes on macOS, the previous runner would reach package creation without producing the required searchable PDF and would then fail BookPackage integrity even if every prior stage succeeded.

The fix:

- replaces the UIKit-only writer with CoreGraphics/CoreText/ImageIO PDF generation shared by macOS and iOS;
- keeps OCR text as an invisible PDF text layer;
- adds a macOS regression test that generates a PDF and verifies PDFKit can extract the embedded text;
- keeps existing reference-metric, iPhoneOS module, Privacy, XcodeGen, unsigned Release app, and bundle-verification gates green.

This removes a deterministic HQ-runner failure that was independent of the raw Golden data. It does not constitute Formal Golden PASS.

## Formal Golden machine-gate aggregation

PR #4573 exact head `d309b061203f17a18cb29c2b721fa1cda2651429` passed `Scanner Parity Apple Validation` run `32653792426` in full and merged as `3bd3a53d4f84fe69ae01cea8d679ea87887a2a42`.

The runner report schema version 3 aggregates the real E2E artifacts into one machine-readable assessment. It records:

- Golden video/PDF SHA identity and explicit expected-SHA match state;
- reference-PDF page recall, unmatched outputs, duplicate rate, and ordering accuracy after an explicitly calibrated threshold is supplied;
- image-correction stage failure count and failed page IDs;
- PageAudit ordered page count, duplicate groups, missing-page suspicions, reversal events, auto-fixes, and review count;
- OCR engine failures, review count, empty-text pages, mean/minimum confidence, and layout counts;
- searchable-PDF page count, pages with/without extractable text, and extractable character count;
- canonical BookPackage `integrity-report.json` and required output presence.

Hard machine failures include SHA mismatch, page recall below 99%, unmatched output, duplicate rate above 0.5%, ordering below 100%, correction-stage failure, OCR engine failure, or invalid BookPackage integrity.

Fail-safe verdict policy is fixed:

- expected SHA absent: `PENDING_GOLDEN_IDENTITY_EXPECTATIONS`;
- reference threshold not calibrated: `PENDING_REFERENCE_THRESHOLD_CALIBRATION`;
- hard machine gate failure: `FORMAL_GOLDEN_FAIL_MACHINE_GATE`;
- all machine gates pass: `PENDING_HUMAN_VISUAL_OCR_REVIEW`.

The runner and the machine-gate library contain no automatic `FORMAL_GOLDEN_PASS` path. Even with all machine metrics green, the real Golden pages still require HQ review of visual correction quality and OCR semantic accuracy before Formal Golden PASS can be issued. CI explicitly tests this no-auto-PASS contract.

PR #4573 changed only the HQ runner/support/tests/package manifest/workflow. It did not modify `scanner-parity/SHARED_CONTRACT.md`, the product runtime source files, or any Golden SHA value.

## Local Golden visual/OCR review bundle

PR #4580 exact head `fd0d63c67aef5e9ad0cf674cd72b6ca08e640421` passed `Scanner Parity Apple Validation` run `32655389099` in full and merged as `315c085a72303cdffc0edcf8932f7bb3363320a8`.

The runner report is now schema version 4 and points to a local-only review bundle at `06-golden-review/`. For every final output page the bundle provides:

- a rendered image of the nearest reference-PDF page;
- the final scanner output image;
- side-by-side HTML comparison;
- full OCR text;
- OCR confidence, layout, and `needsReview` state;
- nearest and second-best reference feature-print distances;
- a relative-path-only `review-manifest.json`.

The bundle is deliberately local-only because it contains rendered book pages and OCR text derived from the Golden book. It must not be committed to GitHub or uploaded as repository/Actions evidence. The CI upload list remains limited to synthetic validation reports/build logs and does not include `06-golden-review/`.

Synthetic macOS tests verify that the bundle can render a reference PDF, copy an output page, write OCR TXT, generate the side-by-side HTML/manifest, HTML-escape OCR content, reject output/OCR count mismatch, and avoid persisting absolute local paths or `file://` references in the manifest.

This does not weaken the no-auto-PASS policy. Even when machine gates pass, the runner still stops at `PENDING_HUMAN_VISUAL_OCR_REVIEW`; the bundle only makes that review reproducible and fast.

## SHA-bound Formal Golden human-review finalizer

PR #4584 exact head `778cd64620559a89d91aa2cd8695dba980808e76` passed `Scanner Parity Apple Validation` run `32656983198` in full and merged as `4e92833193b835bbf09158551847febb3bbfc8c1`.

A separate macOS executable `scanner-hq-golden-finalizer` now closes the final human-review stage without weakening the existing runner/machine-gate fail-safe contract.

The finalizer can first generate a `review-decisions.json` template from the real `hq-golden-execution.json`. The template is bound to:

- exact SHA-256 of that execution-report file;
- Golden video SHA-256;
- Golden PDF SHA-256;
- book ID;
- complete contiguous output-page sequence.

The human/HQ review record requires a separate decision for every output page on both dimensions:

- visual correction quality;
- OCR semantic accuracy.

`FORMAL_GOLDEN_PASS` can be emitted only by this finalizer, and only if all of the following are true:

- execution report schema is compatible with the local review bundle;
- runner verdict is `PENDING_HUMAN_VISUAL_OCR_REVIEW`;
- machine gate verdict is `MACHINE_GATES_PASS_HUMAN_VISUAL_OCR_REVIEW_PENDING` with no machine blockers;
- expected video/PDF SHA checks are both true;
- review record matches the exact execution-report SHA, Golden SHA values, book ID, page count, and contiguous page sequence;
- every page has visual-correction `PASS` and OCR-semantic `PASS`;
- `reviewComplete=true`;
- reviewer is non-empty and `reviewedAt` is valid ISO-8601.

Fail-safe outcomes are explicit:

- stale/wrong-run/missing-page identity binding: `FORMAL_GOLDEN_FAIL_REVIEW_BINDING`;
- machine prerequisite not met: `FORMAL_GOLDEN_PRECONDITION_NOT_MET`;
- any explicit human page failure: `FORMAL_GOLDEN_FAIL_HUMAN_REVIEW`;
- incomplete review: `PENDING_HUMAN_VISUAL_OCR_REVIEW`;
- all machine + bound human review conditions pass: `FORMAL_GOLDEN_PASS`.

CI verifies finalizer build plus template binding, pending review rejection, explicit review failure, stale execution-report SHA rejection, missing-page rejection, machine-precondition rejection, and the only permitted all-pass path. The existing production runner and machine-gate library still contain no automatic `FORMAL_GOLDEN_PASS` path.

PR #4584 changed only HQ finalizer/support/tests/package manifest/workflow. It did not change product runtime, `scanner-parity/SHARED_CONTRACT.md`, or any Golden identity SHA.

## Fail-safe Formal Golden pipeline-failure evidence

PR #4588 exact head `8e40ffe847ea159318523e3c70a40942c6d08f8e` passed `Scanner Parity Apple Validation` run `32658672807` in full and merged as `705e7608e038f5e6566a26c0a61ffe3dae9a0c85`.

Formal Golden execution now has a canonical launcher at `scanner-parity/HQGoldenRunner/run-formal-golden.sh`. The launcher:

- requires an explicit workspace;
- invokes the unchanged production `scanner-hq-golden-runner`;
- preserves the runner's original nonzero exit code;
- captures raw stderr only in a temporary local file and deletes it after use;
- on runner failure invokes `scanner-hq-golden-failure-recorder`;
- never converts a failed pipeline execution into a Golden PASS or pending-human-review result.

Failure evidence is written locally to `hq-golden-execution-failure.json` and records:

- Golden video/PDF filenames and observed SHA-256 when readable;
- expected SHA values and match state when supplied;
- book ID and runner exit code;
- completed stage marker relative paths;
- any discovered `integrity-report.json` relative paths;
- sanitized stderr with known raw video/PDF/workspace/temp-log absolute paths redacted;
- terminal verdict `FORMAL_GOLDEN_FAIL_PIPELINE_EXECUTION`.

CI builds the recorder, unit-tests path sanitization, and creates a synthetic failure report with exit code 17. The fixture verifies SHA match, completed-stage marker discovery, integrity-report discovery, absence of local absolute paths, and absence of `FORMAL_GOLDEN_PASS`. Existing reference metrics, machine gate, visual/OCR review bundle, finalizer, searchable PDF, Apple adapters, product modules, Privacy manifest, XcodeGen, unsigned iPhoneOS Release app, and bundle verification all remained green in the same run.

PR #4588 did not modify product runtime, `scanner-parity/SHARED_CONTRACT.md`, the successful schema-v4 execution report, the finalizer PASS contract, or any Golden identity SHA.

## 240-page production-runtime long-run stability gate

PR #4591 exact head `a2a2b4d0b0367239434430e4fb8509ba9ea5fd7f` passed `Scanner Parity Apple Validation` run `32660140183` in full and merged as `b49cdb1004190933117f65f9effa3c230625e74d`.

HQ audited the pre-existing 240-page `LongRunHarness` fixture and determined that it directly validated checkpoint/resume behavior around an arbitrary per-page closure, but did not by itself prove that the actual scanner production composition could survive a 200-page-class book. The old harness remains useful for checkpoint/resume testing, but it is no longer treated as the sole long-run acceptance evidence.

PR #4591 adds `scanner-production-longrun`. Its CI run creates 240 real JPEG page inputs and executes them through the same `ProductionScannerRuntime.makeDriver()` production composition used by the app, covering:

- production image correction;
- PageAudit and ordering pipeline;
- Apple Vision OCR;
- searchable-PDF generation;
- BookPackage creation;
- `PackageIntegrityVerifier`.

The retained Actions artifact `scanner-parity-production-longrun/production-longrun-report.json` records:

- `inputPageCount = 240`;
- `completedPageCount = 240`;
- `searchablePDFPageCount = 240`;
- `checkpointStageCount = 5`;
- `packageIntegrityValid = true`;
- `requiredBookPackageFilesPresent = true`;
- `elapsedMilliseconds = 1587579` (about 26 minutes 28 seconds);
- `reviewCount = 1985`;
- verdict `PRODUCTION_LONG_RUN_PASS`.

The high synthetic `reviewCount` is intentionally not hidden or reclassified. These generated pages are a stability/load fixture, not a reference-quality corpus. Therefore `PRODUCTION_LONG_RUN_PASS` means the 240-page production composition completed and produced a structurally valid 240-page package without crashing; it does **not** mean visual correction quality, page-recall quality, ordering quality, or OCR semantic quality passed. Those quality claims remain exclusively under the real Formal Golden Gate.

The same exact-head CI also passed the existing Formal Golden runner/finalizer/failure-recorder builds, Golden support tests, searchable-PDF test, Apple adapters, final product modules, Privacy manifest, XcodeGen generation, unsigned iPhoneOS Release app build, and application-bundle verification.

PR #4591 did not modify product runtime source, `scanner-parity/SHARED_CONTRACT.md`, Golden identity SHA values, Worker/Queue policy, or Formal Golden PASS logic.

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

Raw Golden files are intentionally not committed to GitHub. On 2026-08-24 HQ rechecked both the current ChatGPT File Library and connected Google Drive again before PR #4591; neither current source file was found. File Library returned unrelated files only and Drive returned zero exact-name matches for both Golden files. No fixture result, compile result, synthetic metric result, searchable-PDF fixture result, machine-gate unit test, review-bundle synthetic test, finalizer unit test, failure-report synthetic test, production long-run stability result, or historical measurement is promoted to Golden PASS in place of the real rerun.

When the current raw Golden bytes are accessible, HQ execution order is fixed:

1. use `bash scanner-parity/HQGoldenRunner/run-formal-golden.sh` with explicit `--workspace`, current expected Golden SHA values, and no `--match-threshold` for the first run; the launcher invokes the integrated production runner;
2. verify observed SHA-256 against the versioned current identity and preserve old migration hashes as history;
3. capture nearest/second-best reference distance distribution and the schema-v4 E2E/BookPackage evidence;
4. calibrate the page-match threshold from the real distribution rather than guessing it;
5. rerun through the same fail-safe launcher with the calibrated threshold; pipeline execution failure emits `hq-golden-execution-failure.json`, while a completed run evaluates hard machine gates and emits either machine failure or `PENDING_HUMAN_VISUAL_OCR_REVIEW`;
6. if pipeline or machine gates fail, HQ performs root-cause analysis, HQ fix PR, non-Golden regression, integration merge, then reruns the same Golden; Workers are not reopened;
7. if machine gates pass, HQ opens local `06-golden-review/index.html` and reviews all actual page pairs plus OCR text for perspective/skew/crop/color/shadow/spread-split quality and semantic Japanese OCR accuracy;
8. generate a SHA-bound `review-decisions.json` with `scanner-hq-golden-finalizer --create-template`, record every page's visual/OCR decision, reviewer, ISO-8601 reviewedAt, and `reviewComplete=true` only after the review is actually complete;
9. run `scanner-hq-golden-finalizer --review-decisions`; only an emitted `FORMAL_GOLDEN_PASS` may advance the project to Release Gate.

This does not reopen Worker work and is not a Worker `BLOCKED_HUMAN` condition. Workers 1-4 remain complete. Queue driving remains stopped. Golden validation remains HQ-owned.

## Release Gate

`NOT_STARTED` — Release Gate must not begin until Formal HQ Golden PASS is issued.
