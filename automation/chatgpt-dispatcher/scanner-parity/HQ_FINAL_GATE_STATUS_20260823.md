# 書籍スキャナー同等化｜HQ Final Gate Status

Updated: 2026-08-26 17:34 JST
Owner: HQ
Integration branch: `scanner-parity/integration`

## Current canonical state

- Current integration application/runtime + HQ tooling HEAD before this Evidence-only update: `a264a8485e8193f0b935d95920b70bfe960e2b7b`.
- Last core scanner product-code milestone remains `f90f4db18e1a8bd2106afaea293f1db3bb85b856`; later integration commits add HQ Golden execution/review tooling and Evidence, not a replacement Golden PASS.
- Post-merge product-code validation run `32911215915` / #103 completed `success` on `f90f4db18e1a8bd2106afaea293f1db3bb85b856`.
- PR #4618 thresholdless+calibration one-command helper merged after exact-head run #104 success.
- PR #4619 SHA-bound threshold-decision rerun helper merged after corrected exact-head run #107 success.
- PR #4620 interactive local visual/OCR review + finalization helper merged after exact-head run #109 success.
- PR #4621 private macOS Golden bootstrap merged after exact-head `Scanner Parity Apple Validation` run `32945106648` / #111 completed `success` on exact head `02c0f159f3760dd90bf03e7eb2dd0e569e55616d`.
- Run #111 completed every validation step successfully, including HQ Golden contracts/builds/tests, searchable PDF, 240-page production long-run, iPhoneOS compile, Privacy, XcodeGen, unsigned Release app build and bundle verification.
- Merge commit for PR #4621: `a264a8485e8193f0b935d95920b70bfe960e2b7b`.
- Post-merge integration validation run `32948251475` / #112 started on exact merge head `a264a8485e8193f0b935d95920b70bfe960e2b7b` and is currently `IN_PROGRESS`; running CI is not PASS.
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

Formal Golden has **not** passed. Synthetic fixtures, compile success and 240-page synthetic long-run are not substitutes for the real Golden pair.

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

## Integrated local-only execution path

Private macOS bootstrap:

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

## Current external-resource classification

HQ re-read `AIアプリ開発・公開フロー v2.7` and `申請手順` on 2026-08-26 before classifying this state.

- The real production Golden path requires macOS / Apple frameworks; Linux execution is not an acceptance substitute.
- This ChatGPT session still has no connected private macOS host / SSH / remote-shell execution endpoint that can access the raw Golden bytes.
- The project contract intentionally keeps raw copyrighted Golden video/PDF and derived pages/OCR local and out of GitHub/Actions. HQ will not silently widen that contract just to use an external CI runner.
- Therefore the only pre-execution external-resource blocker is access to a private macOS host that can hold the exact raw pair locally.
- Under the standard procedure, provisioning/payment/login/2FA for a new host is a genuine human gate only if no already-authorized private macOS host is available. Once such a host exists, the bootstrap reduces the technical start operation to one local command and HQ resumes from the sanitized execution/calibration evidence.

## Human gates intentionally retained

- provisioning/payment/login/2FA only if a new private macOS host must be created;
- per-page visual/OCR judgment after machine pass;
- later TestFlight/iPhone final device acceptance;
- later App Store `Add for Review` / `Submit for Review` final approval, publish, contracts/tax/bank/payment/2FA.

Do not reopen Workers for a Golden-only failure. Record sanitized failure evidence, fix at HQ, regression-test, merge, then rerun the same real Golden pair.

Historical detailed Evidence remains preserved in Git history, including prior canonical blobs and the pre-compaction detailed record.
