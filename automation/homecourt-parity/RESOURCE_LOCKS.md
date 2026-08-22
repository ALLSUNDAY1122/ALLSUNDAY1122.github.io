# HomeCourt同等化｜Logical Resource Locks v1.0

Locks are semantic, not merely file-based. Claiming a task acquires every lock listed on that task until finalize/cancel/stale resolution.

| Lock | Canonical meaning | HQ-owned contract? |
|---|---|---|
| camera-session | AVFoundation capture configuration, camera lifecycle, orientation, FPS policy | yes |
| vision-frame-pipeline | frame sampling, timestamps, coordinate normalization, inference scheduling | yes |
| pose-contract | player identity and pose keypoint public contract | yes |
| ball-tracking-contract | ball detection/tracking identity, confidence, occlusion behavior | yes |
| rim-court-calibration | rim/court detection, calibration, image-to-court transform | yes |
| temporal-fusion | cross-frame association and synchronized player/ball/rim state | yes |
| shot-event-contract | shot candidate/release/make/miss/unknown event semantics | yes |
| dribble-event-contract | dribble/crossover/hand-switch event semantics | yes |
| sports-metrics | release time/angle, shot speed/location, dribble speed, vertical, agility metrics | yes |
| confidence-policy | confidence thresholds, unknown/reject policy, false-measure prevention | yes |
| session-lifecycle | start/pause/resume/end/interruption/background recovery | yes |
| video-evidence | capture retention, overlays, evidence timestamps, replay alignment | yes |
| history-schema | persisted sessions, metrics, progress, migration | yes |
| shared-navigation | app shell/navigation/shared routes | yes |
| app-state | canonical global state and dependency ownership | yes |
| realtime-feedback | visual/audio feedback event mapping and latency policy | yes |
| reference-parity-spec | reference mining and parity evidence only | no; HQ finalizes scope |
| vision-benchmark | isolated benchmark code/results; may not redefine canonical contracts | no |
| qa-evidence-contract | golden-set manifest and evaluation protocol proposal | HQ finalizes protocol |
| product-flow-proposal | reference UX/state proposal only; no canonical app-state writes | HQ finalizes |
| ci-build-lane | build/test workflow and non-product CI configuration | yes for final integration |

## Lock rules

1. Any task touching two semantic domains must declare both locks before claim.
2. Two tasks with overlapping locks cannot be concurrently canonical WORKING tasks.
3. A Worker discovering an undeclared lock requirement must stop writes to that domain, heartbeat, and request Queue reclassification; it must not silently expand scope.
4. HQ may split a broad lock only after proving the new boundaries have independent contracts.
5. `reference-parity-spec`, `vision-benchmark`, `qa-evidence-contract`, and `product-flow-proposal` are intentionally independent initial lanes and may run in parallel.
