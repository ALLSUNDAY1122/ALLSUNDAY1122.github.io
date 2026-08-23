# 書籍スキャナー同等化｜HQ Final Gate Status

Updated: 2026-08-24 JST
Owner: HQ
Integration branch: `scanner-parity/integration`

## Current integration

- PR #4544 `scanner-parity: Golden fix page eligibility and spread splitting` merged successfully.
- Merge commit: `3134620a0f6d1dde253edd3af1f0ca39bbd65092`
- Validated PR head: `85fd28f0c3801f205c7ce23f405ac0c9a936644f`
- PR base at validation: `f03b173bdb9f24604daf5a49aa57cca3a3d15b34`
- PR #4544 did not modify `scanner-parity/SHARED_CONTRACT.md`.

## Non-Golden acceptance

GitHub Actions run `32640669074` (`Scanner Parity Apple Validation`) completed with `success` on exact PR head `85fd28f0c3801f205c7ce23f405ac0c9a936644f`.

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

Current Formal Golden metrics remain unissued until the same raw dataset is processed end-to-end on the integrated implementation. Required metrics include page recall, transition adoption, duplicate rate, ordering accuracy, missing/reversal/duplicate detection, spread splitting, correction quality, Japanese vertical/horizontal OCR, searchable PDF, page images, TXT, Markdown, manifest, and BookPackage integrity.

## Raw Golden availability

Raw Golden files are intentionally not committed to GitHub. In the 2026-08-24 HQ session, the raw video/PDF could not be reacquired through the currently accessible ChatGPT File Library, execution sandbox, or connected Google Drive. No fixture result, compile result, or historical measurement is promoted to Golden PASS in place of that rerun.

This does not reopen Worker work and is not a Worker `BLOCKED_HUMAN` condition. Workers 1-4 remain complete. Queue driving remains stopped. Golden validation remains HQ-owned.

## Release Gate

`NOT_STARTED` — Release Gate must not begin until Formal HQ Golden PASS is issued.
