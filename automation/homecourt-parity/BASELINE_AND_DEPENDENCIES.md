# HomeCourt同等化｜Baseline / Dependency Graph v1.0

## Integration baseline

Integration mainline: `tech/homecourt-cv`

Baseline SHA: `16b150c633e5817d0f1864223b03351b85003191`

- SwiftPM core package: GREEN by equivalent local Swift 6.2.1 build/test.
- `ShotEventDetectorTests`: 2/2 PASS on the HQ bootstrap environment.
- Canonical iPhone app target: MISSING.
- AVFoundation/Vision real-time integration: MISSING.
- iOS-capable integration CI: MISSING.

Therefore the algorithm-core baseline is GREEN, while the product integration baseline is `BLOCKED_DEPENDENCY` until an iOS app/build lane exists. This is not a Human Gate.

## Initial dependency graph

Parallel discovery lanes:

- HC-001 Reference mining + differential contract
- HC-002 Vision approach benchmark
- HC-003 Golden real-motion QA/evidence design
- HC-004 Product/session state reference proposal

These four lanes are independent and may be READY simultaneously.

Critical implementation chain after discovery:

`HC-002 + HC-004 -> HC-010 Camera/app integration baseline`

`HC-010 -> HC-011 Player/Pose`

`HC-010 -> HC-012 Ball detection/tracking`

`HC-010 + HC-001 -> HC-013 Rim/Court calibration`

`HC-011 + HC-012 + HC-013 -> HC-020 Temporal fusion`

`HC-020 + HC-003 -> HC-021 Shot release/make/miss/unknown`

`HC-021 -> HC-022 Shooting metrics`

`HC-020 -> HC-023 Dribble/crossover events`

`HC-023 -> HC-024 Ball-handling metrics/drills`

`HC-011 + HC-013 -> HC-025 Agility/vertical measurement`

`HC-021 + HC-022 + HC-024 + HC-025 -> HC-030 Real-time feedback + first complete vertical slice`

`HC-030 -> HC-040 Session history/video evidence`

`HC-040 -> HC-050 Long-session/interruption/edge-case hardening`

`HC-050 + differential evidence across all major rows -> product PARITY review`

## Promotion principle

Dependencies describe the minimum safe order, not completion sufficiency. Later discovery may add nodes; new major Reference features are added to PARITY/Queue rather than silently dropped.
