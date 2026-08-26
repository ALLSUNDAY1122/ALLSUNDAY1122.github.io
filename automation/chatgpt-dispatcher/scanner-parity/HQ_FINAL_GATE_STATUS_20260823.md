# 書籍スキャナー同等化｜HQ Final Gate Status

Updated: 2026-08-26 14:55 JST
Owner: HQ
Integration branch: `scanner-parity/integration`

## Current canonical state

- Current integration HEAD before this Evidence-only update: `3f6e4749f2de5a5778a456b3bafdb20fcd0bbb5c`.
- Current product-code HEAD: `f90f4db18e1a8bd2106afaea293f1db3bb85b856`.
- PR #4611 Golden v3 reference-corpus fix merged at product-code HEAD above.
- PR #4611 final exact head `48895a339672e9cc7d8ea16336363b3141e62f2b` passed `Scanner Parity Apple Validation` run `32857264761` / #102.
- Post-merge product-code validation run `32911215915` / #103 on exact head `f90f4db18e1a8bd2106afaea293f1db3bb85b856` completed `success`.
- Every run #103 step completed `success`, including HQ Golden runner/calibrator/finalizer/failure-recorder builds, reference/calibration/machine/review tests, searchable-PDF generation, 240-page production long-run, iPhoneOS adapter/product compile, Privacy manifest validation, XcodeGen, unsigned Release app build, bundle verification, and evidence upload.
- Workers 1-4 are complete. Queue driving is stopped by design. Golden validation is HQ-owned.

## Formal Golden v3 identity

Dataset: `golden-v3-user-confirmed-20260825`

- video SHA-256: `8334cc4b3116b92f25541fe8144bff850b15808846ada4ce7dc7a998576c1677`
- PDF SHA-256: `4fae66be8ba95549859bbc5f9f1fc433ebe1a3a8b6c078cbd3317cf0e78e7b32`
- raw reference PDF page count: 28
- negative / non-book / incomplete raw captures: `1,2,3,4,5,6`
- canonical valid physical pages: 22
- canonical reading order by raw PDF page number: `8,7,10,9,12,11,14,13,16,15,18,17,20,19,22,21,24,23,26,25,28,27`
- SHA-bound corpus manifest: `automation/chatgpt-dispatcher/scanner-parity/evidence/golden-v3-reference-corpus.json`

Current local/conversation raw files were remeasured on 2026-08-26 and match the v3 SHA values above. Google Drive exact-name searches returned no matching raw Golden files. Raw/derived copyrighted book content remains excluded from GitHub/Actions evidence.

## Formal Golden execution state

Formal Golden: `PENDING_HQ_GOLDEN_EXECUTION`

Release Gate: `NOT_STARTED`

Identity-locked launcher: `scanner-parity/HQGoldenRunner/run-formal-golden-v3.sh`

Required order remains:

1. real v3 thresholdless run, without `--match-threshold`;
2. schema-v4 execution report + real reference-distance evidence;
3. `scanner-hq-golden-calibrator --analyze`;
4. explicit HQ threshold decision bound to execution/evidence/Golden identity;
5. same v3 pair rerun with validated threshold;
6. hard machine gates;
7. every output page visual/OCR review;
8. SHA-bound finalizer; only the finalizer may emit `FORMAL_GOLDEN_PASS`;
9. Release Gate only after Formal Golden PASS.

Hard machine gates remain: video/PDF SHA match, page recall >=99%, unmatched output =0, duplicate rate <=0.5%, ordering accuracy 100%, image-correction failures =0, OCR engine failures =0, valid BookPackage integrity.

## macOS execution-path classification

HQ re-applied `AIアプリ開発・公開フロー v2.7` and `申請手順` before classifying this gate.

- The production Formal Golden runner requires the Apple production path on macOS; Linux surrogate execution is not an acceptance substitute.
- Connected plugin search found no SSH / remote-shell / macOS-host connector available to this ChatGPT session.
- Codemagic provides macOS runners and the existing account/API gateway is suitable for build automation, but the current BookScanner canonical handling keeps raw Golden book/video content in local/conversation attachments and excludes it from GitHub/Actions. HQ will not silently broaden that data-handling contract by sending the raw copyrighted Golden pair to an external CI runner merely to clear the gate.
- MacStadium/MacinCloud are viable external macOS host classes, but provisioning/account/payment or authenticated remote-host access is a genuine external-resource gate if no already-authorized host exists.
- Therefore the blocker is not Worker work, not missing code, not Golden identity, and not CI. It is `HUMAN_REQUIRED_EXTERNAL_MACOS_HOST_ACCESS` unless an already-authorized private macOS execution endpoint becomes available.

Once such a host exists, HQ should run the identity-locked launcher against the exact raw pair and continue automatically through calibration/machine evaluation as far as the evidence permits. Do not reopen Workers for a Golden-only execution failure; record failure evidence, fix at HQ, regression-test, merge, and rerun.

## Human gates that remain intentionally human

- external macOS account/payment/login/2FA if a new host must be provisioned;
- per-page visual/OCR judgment after machine pass;
- later App Store Submit/publish, contracts/tax/bank/2FA, and final iPhone acceptance.

Historical detailed Evidence remains preserved in Git history, including prior canonical blob `8b64380cdfa20129e02234adac444d2d9fac4d5b`.
