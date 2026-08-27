# L3-AW53 | Lifecycle-Safe Physical Sampling Driver

Result: `COMPLETE_NON_PARITY`

## Goal

Close the host-lifecycle gap left by AW52. AW52 can sample the candidate app's own RSS, thermal state and battery state, but a host previously had to remember to call it every 15 seconds and explicitly call `cancel()` on every abort path. AW53 adds a portable fail-closed lifecycle gate plus a selected-iOS driver that owns cadence scheduling, application lifecycle aborts, recorder cleanup and the AW51 candidate handoff.

## Canonical audit at wave start

- Notion canonical fetch still reported HQ Epoch44 / Lane3 AW49.
- GitHub integration head was HQ Epoch45 `0fea2b5f2db390cb1dc45ea9a9899d47ac549719`, integrating Lane3 through AW50.
- Worker branch started at AW52 status `7e3c52d5a8c9e16297c512dff291b24ea90a08a4`.
- AW51-AW52 remained pending HQ Late Integration.
- P006/P007/P008/P010/P012/P014/P015/P021 remained `MISSING`.

## Portable lifecycle gate

`Lane3CandidatePhysicalSamplingLifecycle` owns:

- `prepared -> running -> completed|aborted` transitions;
- first/last monotonic sample uptime;
- accepted sample count;
- maximum observed sampling gap;
- terminal abort reason;
- rejection of non-finite/negative uptime;
- rejection of non-monotonic ticks;
- rejection of gaps greater than the existing AW52/AW51 30-second maximum.

The recommended cadence remains 15 seconds. A 30-second gap is accepted by the evidence contract; `>30` seconds fails closed.

## Selected-iOS driver

`Lane3AppleCandidatePhysicalSamplingDriver`:

1. requires `UIApplication.applicationState == .active` before starting;
2. constructs the AW52 recorder only after that preflight;
3. samples immediately;
4. installs a 15-second repeating `Timer` in `RunLoop.main` common modes;
5. uses a weak timer target so the timer does not strongly retain the driver;
6. aborts on `UIApplication.willResignActive`, `didEnterBackground`, or `willTerminate`;
7. aborts on sampling failure or a lifecycle-observed gap over 30 seconds;
8. invalidates the timer and removes lifecycle observers before cancelling the recorder;
9. calls AW52 `cancel()` on every driver-controlled abort, restoring the previous UIDevice battery-monitoring state;
10. leaves an early `finish()` failure non-terminal so a <30-minute physical run can keep sampling;
11. on successful `finish()`, returns exactly one digest-bound candidate receipt plus canonical artifact data for AW51;
12. exposes `withDriver` so throw/early-return paths use `defer` to cancel an unfinished session.

The driver does not inspect another application's process RSS and does not relax AW51's current-Moises measurement question.

## Focused portable verification

Environment:

- Swift 6.2.1
- Linux x86_64
- `-swift-version 6`
- `-strict-concurrency=complete`
- `-warnings-as-errors`
- `-O`

Observed:

- 121 samples at 15-second cadence: PASS;
- 30.0-second exact gap: accepted;
- 30.000001-second gap: rejected;
- stable completed lifecycle: 121 samples, maximum gap 15 seconds;
- 1,000 valid 121-sample lifecycles across 10/12/15/20/25/30-second cadences: PASS;
- 1,000 `>30s` gap cells: rejected;
- 1,000 non-monotonic tick cells: rejected;
- 1,002 lifecycle abort cells across all six abort reasons: PASS;
- total stress cells: 4,002.

A focused 20,000-lifecycle optimized run processed 2,420,000 accepted sample transitions in approximately 0.0282 seconds, about 1.41 microseconds per lifecycle on that Linux run. This is only a portable state-machine reference and is not an iPhone performance claim.

## Repository-native artifacts

- `Playback/Sources/Lane3CandidatePhysicalSamplingLifecycle.swift`
- `Playback/Sources/AppleCandidatePhysicalSamplingDriver.swift`
- `Playback/Tests/L3_AW53_CandidatePhysicalSamplingLifecycleSelfTest.swift`
- `Playback/Tests/L3_AW53_CandidatePhysicalSamplingLifecycleStress.swift`
- `Playback/Tests/L3_AW53_CandidatePhysicalSamplingLifecycleBenchmark.swift`

## Boundaries / non-claims

- The selected-iOS driver is authored but not compiled with the selected Xcode/iOS SDK in the Worker environment.
- No physical iPhone session was run.
- No physical RSS, thermal, battery, audio, Moises differential, or listening result is claimed.
- `withDriver` guarantees cleanup for its scoped host workflow and UIKit lifecycle notifications cover driver-managed application aborts; arbitrary host misuse outside this contract must not be interpreted as measured evidence.
- A process termination does not need persistent restoration of UIDevice battery-monitoring state because the process terminates, but the driver still issues its normal cancellation path when `willTerminate` is delivered.
- AW53 does not solve the current-Moises third-party process RSS observability limitation.
- `parityPromotionAllowed` remains false and final PARITY authority remains HQ.
