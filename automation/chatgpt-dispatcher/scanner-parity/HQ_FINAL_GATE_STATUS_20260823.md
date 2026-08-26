# 書籍スキャナー同等化｜HQ Final Gate Status

Updated: 2026-08-26 22:29 JST
Owner: HQ
Integration branch: `scanner-parity/integration`

## Current canonical state

- Current overall integration HEAD before this Evidence-only correction: `6b9195281f6f1918eadd7157bf0f951871ffd39a`.
- Current application/runtime + HQ Golden tooling milestone: `a264a8485e8193f0b935d95920b70bfe960e2b7b`.
- Last core scanner product-code milestone remains `f90f4db18e1a8bd2106afaea293f1db3bb85b856`; later integration commits add HQ Golden execution/review tooling and Evidence, not a replacement Golden PASS.
- Post-merge product-code validation run `32911215915` / #103 completed `success` on `f90f4db18e1a8bd2106afaea293f1db3bb85b856`.
- PR #4618 thresholdless+calibration one-command helper merged after exact-head run #104 success.
- PR #4619 SHA-bound threshold-decision rerun helper merged after corrected exact-head run #107 success.
- PR #4620 interactive local visual/OCR review + finalization helper merged after exact-head run #109 success.
- PR #4621 private-local macOS Golden bootstrap merged after exact-head `Scanner Parity Apple Validation` run `32945106648` / #111 completed `success` on exact head `02c0f159f3760dd90bf03e7eb2dd0e569e55616d`.
- PR #4621 merge commit: `a264a8485e8193f0b935d95920b70bfe960e2b7b`.
- Post-merge `Scanner Parity Apple Validation` run `32948251475` / #112 on exact merge head `a264a8485e8193f0b935d95920b70bfe960e2b7b` completed `success`.
- Every run #112 step completed successfully, including HQ Golden contracts/builds/tests, searchable PDF generation, 240-page production long-run, iPhoneOS adapter/product compile, Privacy manifest validation, XcodeGen, unsigned Release app build, bundle verification and evidence upload.
- Scanner-parity open PR count was rechecked and is zero before this Evidence-only correction PR.
- Workers 1-4 remain complete. Queue driving remains stopped by design. Golden validation is HQ-owned.

## Formal Golden v3 identity

Dataset: `golden-v3-user-confirmed-20260825`

- video bytes: `191911175`
- video SHA-256: `8334cc4b3116b92f25541fe8144bff850b15808846ada4ce7dc7a998576c1677`
- PDF bytes: `25751801`
- PDF SHA-256: `4fae66be8ba95549859bbc5f9f1fc433ebe1a3a8b6c078cbd3317cf0e78e7b32`
- raw reference PDF page count: 28
- negative / non-book / incomplete raw captures: `1,2,3,4,5,6`
- canonical valid physical pages: 22
- canonical reading order by raw PDF page number: `8,7,10,9,12,11,14,13,16,15,18,17,20,19,22,21,24,23,26,25,28,27`
- SHA-bound corpus manifest: `automation/chatgpt-dispatcher/scanner-parity/evidence/golden-v3-reference-corpus.json`

The current conversation-local raw files were remeasured again on 2026-08-26 and exactly match the byte counts and SHA-256 values above. Raw/derived copyrighted book content remains excluded from GitHub/Actions evidence.

## Formal Golden execution state

Formal Golden: `PENDING_HQ_GOLDEN_EXECUTION`

Release Gate: `NOT_STARTED`

Formal Golden has **not** passed. Synthetic fixtures, compile success and the 240-page synthetic long-run are not substitutes for the real Golden pair.

Required sequence remains:

1. real v3 thresholdless production run;
2. real reference-distance calibration evidence;
3. HQ inspection of distributions / nearest-vs-second-best / negative distances / sweep / gaps;
4. explicit HQ threshold decision SHA-bound to execution report, calibration evidence, book ID and Golden SHAs;
5. same v3 pair rerun through the decision-bound helper;
6. hard machine gates;
7. explicit per-page human visual + OCR semantic review;
8. SHA-bound finalizer; only the finalizer may issue `FORMAL_GOLDEN_PASS`;
9. Release Gate only after Formal Golden PASS.

Hard machine gates remain: video/PDF SHA match, page recall >=99%, unmatched output = 0, duplicate rate <=0.5%, ordering accuracy 100%, image-correction failures = 0, OCR engine failures = 0, valid BookPackage integrity.

## Integrated contract-preserving local execution path

Private/local macOS bootstrap:

`scanner-parity/HQGoldenRunner/bootstrap-formal-golden-v3-macos.sh`

Usage:

`bash bootstrap-formal-golden-v3-macos.sh --input-dir <folder-containing-the-exact-Golden-video-and-PDF>`

The bootstrap:

- refuses non-macOS execution;
- creates/updates a dedicated local checkout of `scanner-parity/integration`;
- finds the exact video/PDF by byte count + SHA rather than filename;
- fails closed on zero or duplicate exact matches;
- never stages or pushes raw/derived Golden content;
- runs the thresholdless production path and calibration helper locally;
- produces local `hq-golden-execution.json` and `hq-golden-calibration-evidence.json` for HQ analysis;
- never auto-selects a match threshold.

After HQ authors a valid SHA-bound threshold decision, use:

`scanner-parity/HQGoldenRunner/run-formal-golden-v3-from-threshold-decision.sh`

After machine pass, use:

`scanner-parity/HQGoldenRunner/run-formal-golden-v3-human-review.sh`

The human-review helper presents the local reference/output/OCR material, requires explicit visual and OCR judgment for every page, has no bulk-pass shortcut, and invokes the canonical finalizer only on the separately exported completed review JSON.

## Execution-route correction after re-reading the standard/application procedures

HQ re-read `AIアプリ開発・公開フロー v2.7`, `申請手順`, and the BookScanner canonical page on 2026-08-26.

- Standard v2.7's current **application/submission** baseline is Macless: GitHub → GitHub Actions validation → Codemagic signed Archive/IPA → Validate → App Store Connect. Mac/MacinCloud is not the normal submission dependency.
- The BookScanner canonical page separately states that signed external Build / TestFlight must **not** start before Formal Golden and the development Release Gate are complete. Therefore TestFlight cannot be pulled forward merely to bypass the Golden execution problem.
- The current Formal Golden production runner still requires Apple frameworks. Linux surrogate execution is not an acceptance substitute.
- Existing Codemagic infrastructure is real and already API-connected through `CM_API_TOKEN`. The Codemagic REST API can start macOS builds and pass runtime environment variables.
- However, the current BookScanner data-handling contract says the copyrighted raw Golden video/PDF are used locally/conversation-attached and are not copied to GitHub/Actions. It does not authorize HQ to silently upload the raw book material to Codemagic, object storage, Drive, Supabase, or another third-party transfer path.
- A Codemagic-only Golden run is technically designable without committing raw content: a non-publishing macOS QA workflow could download the exact pair from short-lived authenticated URLs, verify byte count/SHA before use, run the integrated Golden helpers, return only sanitized JSON evidence, and delete the raw/derived working data at job end. **That path is not activated without explicit user authorization to transmit the copyrighted Golden pair to the named external services.**
- Consequently, the prior statement that a new private Mac is the *only* route was too narrow. There are two viable classes:
  1. `LOCAL_PRIVATE_APPLE_EXECUTION`: keep the current local-only contract and run on a private/local Mac that can access the exact raw pair.
  2. `EXPLICITLY_AUTHORIZED_EPHEMERAL_CI_EXECUTION`: user explicitly approves temporary secure transfer of the exact Golden pair to a controlled external storage/Codemagic path; HQ then automates transport, SHA verification, non-publishing execution, sanitized evidence return, and deletion.

## Current human gate classification

The current stop is **not** “macOS setup is human work.” It is a genuine data-handling/execution-path decision because the two executable paths have different confidentiality boundaries.

`HUMAN_REQUIRED_GOLDEN_EXECUTION_PATH_AUTHORIZATION`

Human input is required only to choose/authorize one of the following when no already-agent-accessible local/private Mac exists:

- preserve local-only handling and provide access to a private/local Mac; or
- explicitly authorize temporary secure external transfer to a named Codemagic-based Golden execution path.

No raw content will be sent externally until that decision is explicit. Once the route is authorized and technically reachable, HQ resumes automatically through thresholdless execution, calibration analysis, threshold decision, thresholded rerun and machine evaluation.

## Human gates intentionally retained after execution starts

- explicit per-page visual/OCR judgment after machine pass;
- later TestFlight/iPhone final device acceptance;
- later App Store `Add for Review` / `Submit for Review` final approval, publish, contracts/tax/bank/payment/2FA.

Do not reopen Workers for a Golden-only failure. Record sanitized failure evidence, fix at HQ, regression-test, merge, then rerun the same real Golden pair.

Historical detailed Evidence remains preserved in Git history, including prior canonical blobs and the pre-compaction detailed record.
