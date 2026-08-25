# 書籍スキャナー同等化｜HQ Final Gate Status

Updated: 2026-08-26 08:34 JST
Owner: HQ
Integration branch: `scanner-parity/integration`

## Canonical state

- Current product-code integration HEAD: `f90f4db18e1a8bd2106afaea293f1db3bb85b856`
- PR #4611 `scanner-parity: bind Golden v3 to canonical reference corpus` merged to integration as `f90f4db18e1a8bd2106afaea293f1db3bb85b856`.
- PR #4611 final validated exact head: `48895a339672e9cc7d8ea16336363b3141e62f2b`.
- Exact-head `Scanner Parity Apple Validation` run `32857264761` / run #102 completed `success`.
- All steps in run #102 completed `success`, including HQ Golden runner/calibrator/finalizer/failure-recorder builds, reference/calibration/machine/review tests, searchable-PDF test, 240-page production long-run, iPhoneOS adapter/product compile, Privacy manifest validation, XcodeGen, unsigned Release build, and bundle verification.
- Post-merge integration validation run `32911215915` / run #103 has been triggered on exact integration HEAD `f90f4db18e1a8bd2106afaea293f1db3bb85b856`; status at this evidence update: `QUEUED`.
- PR #4543 stale Worker2 privacy-finalgate PR is closed without merge. Its substantive hardening was superseded by HQ PR #4597 and is already present in integration.
- Workers 1-4 remain complete. Queue driving remains stopped. Golden validation is HQ-owned.

## Current Formal Golden identity

Dataset: `golden-v3-user-confirmed-20260825`

User explicitly confirmed the currently uploaded raw video + PDF as the Formal Golden pair.

- video SHA-256: `8334cc4b3116b92f25541fe8144bff850b15808846ada4ce7dc7a998576c1677`
- PDF SHA-256: `4fae66be8ba95549859bbc5f9f1fc433ebe1a3a8b6c078cbd3317cf0e78e7b32`
- raw reference PDF page count: 28
- raw files are not committed to GitHub/Actions.
- v2 and migration-era SHA values are retained only as audit history and must not override v3.

### v3 reference corpus

HQ re-read the actual rendered 28 reference images. The accepted mapping is:

- negative / non-book / incomplete raw captures: `1,2,3,4,5,6`
- canonical valid physical pages: `22`
- canonical Japanese reading order by raw PDF page number:
  `8,7,10,9,12,11,14,13,16,15,18,17,20,19,22,21,24,23,26,25,28,27`

The earlier draft assumption that pages 13-26 contained repeated valid pages was rechecked and rejected before merge. Those pages are distinct valid pages.

The SHA-bound manifest is:
`automation/chatgpt-dispatcher/scanner-parity/evidence/golden-v3-reference-corpus.json`

PR #4611 makes recall / unmatched / duplicate / ordering metrics corpus-aware while preserving the nearest raw reference page for local visual review. It also rejects threshold-qualified outputs whose negative-reference match is at least as close as the canonical-positive match. Manifest schema/page-count/PDF-SHA mismatch, overlap, and unassigned pages fail closed.

## Formal Golden execution contract

Current Formal Golden state: `PENDING_HQ_GOLDEN_EXECUTION`

Release Gate: `NOT_STARTED`

Formal Golden must execute the real v3 raw bytes through the integrated Apple production path. Synthetic fixtures, compile success, 240-page synthetic long-run, or historical measurements are not Golden PASS.

The identity-locked v3 launcher is:
`scanner-parity/HQGoldenRunner/run-formal-golden-v3.sh`

Execution order is fixed:

1. Run v3 launcher with real raw video/PDF, explicit local workspace, and **without** `--match-threshold`.
2. Require observed video/PDF SHA to match the v3 identity above.
3. Require the thresholdless schema-v4 execution report and complete nearest/second-best reference-distance evidence.
4. Run `scanner-hq-golden-calibrator --analyze`.
5. Inspect the real distribution/sweep/gaps. HQ must explicitly select the threshold with rationale, reviewer, and ISO decision time. No automatic recommendation is permitted.
6. Validate the decision binding to exact execution-report SHA, calibration-evidence SHA, book ID, and Golden SHA values. Only `THRESHOLD_DECISION_VALID_FOR_RERUN` may supply the threshold.
7. Rerun the same v3 raw pair with that bound threshold.
8. Hard machine gates require: video SHA match, PDF SHA match, page recall >=99%, unmatched output =0, duplicate rate <=0.5%, ordering accuracy 100%, image-correction failures =0, OCR engine failures =0, and valid BookPackage integrity.
9. Machine success stops at `PENDING_HUMAN_VISUAL_OCR_REVIEW`; it is not Formal Golden PASS.
10. Review every real output page locally for split/crop/perspective/skew/color/shadow/content loss/wrong-page issues and Japanese OCR semantic/read-order accuracy.
11. Complete the SHA-bound finalizer review record. Only the finalizer may emit `FORMAL_GOLDEN_PASS`.
12. Only then may Release Gate begin.

Pipeline failure must produce local sanitized `hq-golden-execution-failure.json`, followed by HQ root-cause fix -> non-Golden regression -> merge -> rerun. Workers are not reopened for Golden-only failures.

## Privacy / product hardening already integrated

- PR #4597 `scanner-parity: harden final privacy lifecycle gate on current integration` was exact-head validated and merged before #4611.
- Non-bypassable privacy risk handling and explicit processing-workspace purge semantics are present in current integration.
- Current validation continues to cover Privacy manifest, Apple adapters, final product modules, unsigned Release iPhoneOS app, and generated bundle verification.

## Stability / HQ gate infrastructure already integrated

Key milestones retained in Git history include:

- PR #4544: Golden page eligibility + spread splitting root-cause fix.
- PR #4567: Formal Golden E2E runner.
- PR #4569: reference-page metrics.
- PR #4571: macOS searchable-PDF prerequisite fix.
- PR #4573: Formal Golden machine-gate aggregator.
- PR #4580: local visual/OCR review bundle.
- PR #4584: SHA-bound human-review finalizer.
- PR #4588: fail-safe pipeline-failure evidence.
- PR #4591: 240-page production-runtime long-run gate.
- PR #4595: SHA-bound threshold calibration and explicit operator decision binding.
- PR #4597: final privacy lifecycle gate hardening on current integration.
- PR #4611: v3 canonical reference corpus + negative-reference semantics + identity-locked v3 launcher.

The detailed pre-compaction canonical Evidence remains immutable in Git history at blob `8b64380cdfa20129e02234adac444d2d9fac4d5b`. This file is intentionally compacted to current gate truth while preserving prior audit history in Git.

## Current blocker classification

- Worker blocker: none.
- Queue blocker: none; queue driving is stopped by design.
- Golden source identity blocker: none; the user confirmed the current uploaded pair as v3 and local SHA measurements match the v3 identity.
- Code acceptance blocker for #4611: none; exact-head PR CI passed and PR is merged.
- Immediate remaining technical gate: run the real v3 raw Golden through the integrated macOS/Apple production path.
- Human review gate after machine pass: required.
- App Store Submit / publish / contracts / tax / bank / 2FA / final iPhone acceptance remain later human gates.
