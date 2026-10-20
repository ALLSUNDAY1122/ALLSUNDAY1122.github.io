# Scan Lab STEP06 Independent HQ P0 Integration Review
Date: 2026-10-20 09:34 JST

## Live heads / queues checked
- Canonical app base: 2bcbbd6128863739ad168610cd2e3f8e3b01b458, PR #4145 draft
- Control Queue: automation/scanlab-hq-control-20261020 @ 7196cc2776f38fe9260c6cf5fa244fba4c5563c0; W1 / W2 claims epoch1 remain active.
- W1 attempt: dc1dc00c5452f9ffdac6a3c889fce49be0acc8a9. Ahead by 1; only CapturePolicy.swift touched.
- W2 attempt: 1d2aab05fbbc6783d7a7c840779206810ada8e35. Ahead by 1; only W2_STEP04_FINDINGS.md added.
- Combined GitHub commit statuses: no statuses returned for either head. This does NOT prove tests failed or passed.

## HQ review of W1 change
Positive: frameDecision rejects NaN/Infinity in current pose columns, invalid homogeneous row, and nonfinite current timestamp before admitting first frame.
Remaining P0 risks:
1. Previous pose matrix is still passed to movement() without the equivalent full finite/homogeneous-row validation; corrupt previous pose may silently flow through quaternion/translation calculation.
2. Last-row checks alone do not establish rigid orthonormal camera-to-world transform (rotation column norms/determinant/reflection), so some finite malformed matrices could pass; define tolerances and reject with fixture.
3. Need XCTest fixtures: first-frame good identity ACCEPT; first-frame NaN/Inf REJECT; first-frame homogeneous row invalid REJECT; second-frame previous nonfinite REJECT; timestamp backward / nonfinite REJECT; det<0 or non-orthonormal pose REJECT; no RAW write after reject.
4. No evidence yet that this guard is applied before depth/frame lease pinning and disk writes in actual production capture path.
Integration decision: HOLD, not production-ready.

## HQ review of W2
Worker finding reports two concrete P0 candidates: metric distances derived from camera spread without separate calibration; viewer read-only recovery writes to sidecar. This is investigation, not implementation.
Required gates: uncalibrated models never display meter labels; corrupt/missing manifests UNKNOWN instead of EMPTY; sidecar reads do not mutate bytes/mtime; published data survives lost ACK/retry; revocation cannot be bypassed after republish; concurrency fixtures before integration.
Integration decision: HOLD, not production-ready.

## Integration/Release
- No new product build, Codemagic invocation, Apple upload or App Review submission.
- No cherry-picks/merges performed because P0 integration criteria not met.
- Distinct source edits observed, no current overlapping file changes.
- Worker sessions are independent; HQ checked remote artifacts only, not interactive progress.

## CI trigger isolation
STEP04 showed unrelated workflows executed on pushes to HQ attempt branch; their failures are distinct from Scan Lab product CI and must not be counted as parity failures or successes. Before further CI, inspect each trigger and select narrow Scan Lab only workflows and commit-specific checks; do not globally suppress unrelated security workflows.

## NEXT
1. W1 adds prior-pose/orthonormal validation, real capture admission ordering tests, Swift XCTest proof.
2. W2 implements calibration/display fail-closed, read-only library recovery, privacy receipts with test proof.
3. HQ verifies fresh HEAD, lock epoch, per-worker CI then prepares explicit, independently reviewable integration PRs.
