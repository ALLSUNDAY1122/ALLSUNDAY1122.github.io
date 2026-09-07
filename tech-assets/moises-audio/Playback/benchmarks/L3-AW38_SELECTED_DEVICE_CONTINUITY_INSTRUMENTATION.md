# L3-AW38｜Selected Device Continuity Instrumentation

Result: `COMPLETE_NON_PARITY`

## Purpose

AW35 defined the physical seek/loop evidence fields, but the selected stack did not expose a race-safe exact transport-token timestamp or a backend-success-correlated applied target. AW38 adds those fields without treating backend completion or AW32 fade-in scheduling as physical audible output.

## Exact transport token

`RescheduleFencedPlaybackBackend` now owns a bounded `Lane3TransportTokenTimingLedger` per project. The timestamp is captured immediately after `PlaybackTransportRescheduleFence.invalidate` creates the generation and before the underlying backend is invoked.

Correlation MUST use the `playbackGeneration` from `Lane3UnifiedTransportExecutionReceipt`. Reading only the current/latest token is forbidden because a newer operation may already have advanced the fence.

Default retained generations: 4096. Capacity is clamped to 64...65536. Old generations are explicitly dropped with `capacityDrops`; a completion returning after its generation has been evicted increments `completionMissesAfterEviction` instead of recreating unbounded historical state.

## Backend-applied target

The timing record is created with no applied target. Only after the underlying backend returns successfully does `RescheduleFencedPlaybackBackend` attach:

- seek: `.seek(positionSeconds:)`
- enabled loop: `.loop(startSeconds:endSeconds:)`
- disabled loop: `.loopDisabled`

A backend throw therefore cannot be reported as an applied target.

AW35 schema cannot encode `setLoop(nil)`. AW38 does not fabricate a numeric loop range. Loop-disable remains in the versioned AW38 v2 observation and `legacyAW35Observation()` returns nil for it.

## Audible result boundary

`backendCompletedUptimeNanoseconds` is NOT audible output time.

The following MUST NOT be substituted for `audibleResultUptimeNanoseconds`:

- transport method return time
- UI completion time
- `AVAudioPlayerNode.play(at:)` call time
- AW32 restart-fade-in arm time
- AW32 restart-fade-in ramp scheduling time

A physical-device run must provide an independently observed audible marker in the same uptime clock domain and a non-empty `audibleTimestampSource`. A physical loopback/capture marker or another validated device measurement mechanism is acceptable; a human button press after hearing audio includes reaction latency and must be labeled as such rather than treated as precise audio onset.

## Selected-stack run procedure

1. Capture `firstIntentUptimeNanoseconds` before submitting seek/loop, using the same uptime-nanosecond clock domain as AW38.
2. Capture `slotGenerationAtIntent` from `Lane3SelectedTransportReconstructionSlot`.
3. Submit through the selected AW31/AW33 transport stack. Do not bypass the slot/facade/authority.
4. For an executed outcome, take `transportTicket` and `playbackGeneration` from the unified execution receipt.
5. Correlate that generation with `Lane3SelectedInteractiveContinuityInstrumentationAdapter`.
6. Capture `slotGenerationAtCompletion` immediately after the operation. If it differs, the v2 validator fails the observation closed. Never reinterpret it as a successful cross-generation operation.
7. Supply a physical audible timestamp + source. Without it `physicalMeasurementFieldsComplete=false`.
8. Run `Lane3InteractiveContinuityInstrumentationValidator`.
9. For seek/enabled-loop, the v2 observation may be converted to AW35 and analyzed by the AW35 evidence analyzer. Loop-disable stays v2 because AW35 has no disable target shape.
10. During a longer run, also execute the AW37 cancellation race path and at least one AW33 reconstruction sequence. Do not let reconstruction/device evidence promote PARITY by itself.

## Portable validation in AW38

Environment: Swift 6.2.1, Linux x86_64, `-swift-version 6 -strict-concurrency=complete -warnings-as-errors`; stress/benchmark optimized with `-O`.

Timing ledger self-test:
- capacity 64
- 100 issued generations
- retained 64
- capacity drops 36
- evicted generation lookup nil
- one completion-after-eviction counted as miss
- loop-disabled target retained

Optimized stress:
- 1,000,000 issued/completed generations
- retained 4096
- capacity drops 995904
- completion misses during normal path 0
- explicit post-run evicted completion miss 1
- no counter overflow
- wall time approximately 0.14s in the portable runner; this is not Apple/device latency

Optimized benchmark, 20 x 1,000,000 issue+completion operations:
- median 126.750 ms
- p95 132.563 ms
- max 144.293 ms
- checksum 20000190

Bridge structural strict-concurrency execution:
- seek exact-token/applied-target/external-audible correlation PASS
- loop-disabled v2 retention PASS
- loop-disabled legacy AW35 conversion rejected by design

## Still open

- complete selected SwiftPM/Xcode compile and execution of all AW38 source/tests
- physical iPhone exact first-intent -> token -> audible p50/p95/p99
- validated physical audible timestamp source
- rights-cleared real audio
- current-Moises differential
- human listening
- AW33 reconstruction during device run
- AW37 actual-authority cancellation race on selected Apple runtime
- PARITY judgment by HQ

No AW38 portable evidence authorizes a change to MOI-P006/P007/P008/P010/P012/P014/P015.
