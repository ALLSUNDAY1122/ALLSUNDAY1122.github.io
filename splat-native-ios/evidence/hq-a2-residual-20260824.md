# HQ A2 residual closure — 2026-08-24

Validated app-source commit: `164f5b3d2e1002c1e69423049ba73d2bf01a268a`.

This closes two residuals explicitly carried from A2 PR #4175 into HQ:

1. Capture image-quality rejection now runs before JPEG persistence. Severe dark clipping, blown highlights, and clearly soft/low-detail frames are rejected conservatively while small/unsupported samples fail open.
2. Reconstruction resource/thermal preflight now runs before `GaussianDataset` / `GaussianTrainer` allocation, so an already pressured device can stop before the largest allocation spike.

Implementation evidence:
- `CapturePolicy.swift`: capture image-quality stats, evaluator, policy and user-facing rejection reasons.
- `CaptureMotionQualityTests.swift`: dark / highlight / softness / accepted / fail-open policy regressions.
- `ScanModel.swift`: image-quality gate before `makeJPEGData`; `SplatResourceGuard.evaluate(splatCount: 0)` before `GaussianDataset` construction.

TestFlight Build 2 predates these residual fixes and is therefore retained only as historical device evidence. A new internal TestFlight candidate must be built only after the standard Privacy / Smoke / Main iOS CI gates pass on the same app-source tree.

No production data or Supabase schema was changed by this closure.
