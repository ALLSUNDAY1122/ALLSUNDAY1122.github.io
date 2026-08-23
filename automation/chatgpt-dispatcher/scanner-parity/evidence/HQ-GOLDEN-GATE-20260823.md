# HQ Golden Gate — 2026-08-23

## Dataset
Current project dataset is versioned as `golden-v2-current-project-20260823`; binary originals remain outside GitHub. Identity record: `HQ-GOLDEN-DATASET-IDENTITY-20260823.json`.

## Reproduction
The current FrameExtraction algorithm was reproduced against the actual 288.82-second / 8661-frame Golden video using the production configuration and algorithmic behavior:
- analysis rate: 8 fps
- 64x48 luma thumbnail
- motion MAD between sampled frames
- stable / unstable thresholds: 0.035 / 0.075
- minimum stable run: 420 ms
- settle / departure padding: 120 / 80 ms
- existing consecutive-duplicate collapse thresholds

Observed stable selections: **60**.
Reference PDF pages: **28**.

Selected timestamps include the book capture sequence but also later settings, review and non-book camera/UI states after the capture sequence. The current stable-frame stage has no semantic non-page rejection.

Current downstream code cannot guarantee removal of these states:
- `PageIntegrityAuditor` detects duplicate / missing / reversal relationships and can remove only sufficiently high-confidence duplicates; it does not classify a frame as non-page UI.
- `PageCorrectionEngine` chooses one best rectangle (or full-frame fallback) and returns one corrected page set per candidate; it does not split an open-book spread into two independent pages.

## Gate decision
**HQ_GOLDEN_GATE = FAIL**

This is an early hard failure. Continuing to OCR/package would produce a measurement that is known to be contaminated and would not satisfy the project completion line. Compile success and unsigned `.app` build success therefore remain necessary but insufficient.

## Required fix loop
1. Add capture/page-content eligibility so non-book stable states do not enter the page sequence.
2. Add book-spread detection/splitting so a stable open-book frame can emit left/right pages where appropriate.
3. Re-run the exact Golden video against the corrected pipeline.
4. Only then measure recall, transition acceptance, duplicate rate, ordering, correction quality, OCR, searchable PDF and BookPackage integrity.

## Submission state
App Store submission remains **LOCKED**. Signed external Build/TestFlight must not start until the corrected pipeline passes `HQ_GOLDEN_GATE` and the development Release Gate, followed by Submission Orchestrator preflight.
