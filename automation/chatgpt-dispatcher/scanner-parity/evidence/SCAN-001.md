# SCAN-001 Evidence｜Stable Frame Engine

- worker: `worker2`
- claim_epoch: `1`
- claim_token: `e9ecdfea-fb71-4aff-8cf2-6854f9d33958`
- baseline: `99a8d30f2a09c85119869feabae9b411a3431133`
- attempt branch: `task/SCAN-001/attempt-1`
- attempt HEAD at evidence time: `a7dd6a0b2c27573aff14f475402d6a0bd8249b49`
- status recommendation: `BLOCKED_HUMAN`

## Implemented

1. Streaming stable-run detector with strict stable/unstable thresholds and hysteresis.
2. Minimum stable duration plus settle/departure padding so page-turn boundaries are not selected directly.
3. Best-frame scoring: 60% sharpness + 30% stability + 10% temporal centrality.
4. Consecutive same-page collapse using exposure-insensitive centered MAD + 64-bit dHash distance.
5. `AVAssetReader` single-pass low-resolution analysis and `AVAssetImageGenerator` selected-frame export.
6. `PageCandidate` JSON fields aligned to Shared Contract: candidate/book IDs, source time/range, image ref, stability/sharpness/motion, duplicate group, flags.
7. `page_candidates.json` output.
8. Memory behavior is streaming: active stable run + one thumbnail per accepted page; full-resolution video frames are not retained.

## Fixture verification

Local verification environment:

- Swift `6.2.1`
- command: `swift test` in a temporary package containing the SCAN-001 core sources/tests
- result: `5 tests, 0 failures`

Covered cases:

- PASS: page-turn transition frames are not selected.
- PASS: a short static pause inside a page turn is rejected by minimum stable duration.
- PASS: same page split by a camera bump is collapsed to one candidate, including exposure shift.
- PASS: sharpest frame inside a stable interval is selected.
- PASS: comparison against a naive scene-change baseline; naive baseline selects the transition boundary, stable selector does not.

## Acceptance matrix

| Acceptance | State | Evidence |
|---|---|---|
| ページ送り途中ではなく変化終了後の安定フレームを選ぶ | FIXTURE_PASS | `testTransitionFramesAreNotSelected`, `testShortPauseDuringPageTurnIsRejected` |
| 同一ページの連続フレームを1候補へ圧縮する | FIXTURE_PASS | `testSamePageSeparatedByCameraBumpCollapsesToOneCandidate` |
| ブレ/鮮明度を採点し安定区間内のbest frameを選ぶ | FIXTURE_PASS | `testSharpestFrameWinsWithinStableInterval` |
| Golden Datasetで抽出結果をページ単位にEvidence化する | BLOCKED_HUMAN | Golden video binary is not accessible in this Worker session. No Golden PASS is claimed. |
| 単純scene-change方式との比較を残す | FIXTURE_PASS | test + `FrameExtraction/README.md` rationale |

## Golden Dataset gate

Expected Golden video:

- `RPReplay_Final1787451151.mp4`
- SHA-256 `37642d44cf881d4e595535e57d13bd4e11a8f93eae4f879e230e5301efecc714`

The binary is intentionally not stored in GitHub and was not accessible from this Worker session. Therefore the following metrics are **not measured yet**:

- page recall
- transition false-positive count
- duplicate rate
- per-page selected timestamp/frame
- calibration of motion thresholds / minimum stable duration

Do not promote this task to `VERIFIED` or claim Golden parity until the Golden video is run.

## Additional validation still required

The pure Swift selector/models were type-checked and tested on Linux Swift 6.2.1. The AVFoundation adapter is Apple-platform conditional source and requires an iOS/macOS build/run before integration finalization.

## Remote diff read-back

`task/SCAN-001/attempt-1` is 5 commits ahead of baseline and changes only:

- `scanner-parity/FrameExtraction/AVFoundationStableFrameExtractor.swift`
- `scanner-parity/FrameExtraction/FrameExtractionModels.swift`
- `scanner-parity/FrameExtraction/README.md`
- `scanner-parity/FrameExtraction/StableFrameSelector.swift`
- `scanner-parity/Tests/FrameExtraction/StableFrameSelectorTests.swift`
