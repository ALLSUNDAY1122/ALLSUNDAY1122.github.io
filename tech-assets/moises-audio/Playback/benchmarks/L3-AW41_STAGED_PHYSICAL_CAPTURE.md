# L3-AW41 | Staged Physical Capture Coordinator

Result: `COMPLETE_NON_PARITY`

## Why this wave exists

AW38 correlates an executed seek/loop receipt with the exact Playback token timing ledger and an independently supplied audible timestamp. AW39 stamps that operation with the exact selected reconstruction-slot generation held by its shared lease. AW40 aggregates complete v2 observations, including `loopDisabled`, into a bounded physical-device session.

The remaining integration gap was temporal: a physical host does not necessarily receive first intent, stamped transport completion, and the external audible marker in one synchronous call. Audible detection may arrive before or after transport completion, callbacks may be retransmitted, and a reconstruction can occur before a delayed marker is delivered. AW41 provides one Lane-local sampleID authority for those stages without moving iOS/device ownership out of HQ/Lane 4.

## Contract

`Lane3InteractiveContinuityV2StagedCaptureCoordinator` is an actor. A sample is admitted with:

- stable `sampleID`
- first-intent uptime timestamp
- requested v2 target (`seek`, enabled loop, or `loopDisabled`)

The host may then deliver the AW39 stamped transport outcome and external audible marker in either order.

Executed work is finalized only after both are present. The coordinator then calls the AW39/AW38 correlation path and appends the resulting executed observation to AW40. Non-executed outcomes retire immediately and are counted separately; they never enter executed latency percentiles.

## Duplicate / reentrancy rules

Exact duplicate callbacks are idempotent while the sample is pending, while AW38 correlation is in-flight, and while its callback fingerprint remains in the bounded retired-identity window. Conflicting duplicates fail closed and increment AW40 unusable instrumentation.

The explicit `finalizing` state is required because the coordinator actor re-enters while awaiting the AW38 correlator. Without it, a duplicate marker/stamped callback could start a second finalization.

Retired callback identity is also bounded. Once that ring wraps, `retiredIdentityDrops` increments and the staged session cannot be complete: older duplicate sample IDs can no longer be proven absent.

## Expiry

AW41 intentionally owns no timer. HQ/iOS supplies an expiry cutoff in the same monotonic uptime clock domain used for first intent. `expirePending(firstIntentBeforeUptimeNanoseconds:)` distinguishes:

- missing stamped transport outcome
- executed stamped outcome waiting for an external audible marker

Every expiry is explicit evidence loss, increments AW40 unusable instrumentation, and prevents physical-session completeness.

## Fail-closed cases

- duplicate sample ID still retained by the coordinator
- pending capacity exceeded
- unknown stamped callback
- unknown audible callback
- conflicting duplicate stamped outcome
- conflicting duplicate audible marker
- audible marker attached to a non-executed transport outcome
- expiry before stamped outcome
- expiry before external audible marker
- an AW39 executed stamp unexpectedly correlating as non-executed
- retired callback identity window truncation

No backend-completion time, `AVAudioPlayerNode` scheduling time, UI completion, or AW32 fade scheduling time is manufactured into an audible timestamp.

## Portable validation

Environment:

- Swift 6.2.1
- Linux x86_64
- Swift language mode 6
- strict concurrency complete
- warnings as errors
- optimized (`-O`) for stress/benchmark

Structural staged-state test: `PASS`.

Covered marker-first and stamped-first ordering, exact duplicate callbacks in pending/retired state, executed and non-executed retirement, audible+non-executed contradiction, no-stamp expiry, no-audible expiry, pending capacity, bounded issue retention, and retired identity-window wrap.

Actor reentrancy regression: `PASS`.

A deliberately slow correlator held AW38 correlation across an actor `await`. While `finalizingCount == 1`, the same audible marker and stamped outcome were retransmitted. Both were classified as idempotent duplicates, not a second finalization. After release, exactly one executed sample was finalized. Portable result:

- finalizing during await: 1
- idempotent duplicate callbacks: 2
- unexpected issues before injected conflict: 0

100,000-operation boundedness stress: `PASS`.

- total staged non-executed samples: 100,000
- final pending: 0
- final finalizing: 0
- retained retired identities: 4,096
- retired identity drops: 95,904
- finalized non-executed: 100,000
- issues: 1 (`retiredIdentityWindowTruncated`, expected after first wrap)
- issue detail drops: 0
- elapsed: 5,083,326,055 ns

A 1,000,000-operation actor stress attempt did not finish inside the available 45-second execution limit. AW41 therefore does **not** claim a 1M stress PASS. The 100k PASS plus fixed-capacity invariants are the durable portable evidence for this wave.

20 x 10,000 staged begin/non-executed benchmark: `PASS`.

- median: 487,962,683 ns / run
- p95: 700,156,342 ns / run
- max: 735,207,759 ns / run
- checksum: 318,100

This benchmark includes actor-hop and staged bookkeeping overhead only. It is not Apple transport latency, output latency, or audible-response latency.

## Selected repository tests authored

- `Playback/Tests/L3_AW41_StagedPhysicalCaptureSelfTest.swift`
- `Playback/Tests/L3_AW41_StagedPhysicalCaptureReentrancySelfTest.swift`
- `Playback/Tests/L3_AW41_StagedPhysicalCaptureStress.swift`
- `Playback/Tests/L3_AW41_StagedPhysicalCaptureBenchmark.swift`

The selected SwiftPM/Xcode/AVFAudio graph was not executable in this environment. These repository tests are authored evidence, not a selected-stack PASS.

## HQ / iOS execution requirements

1. Generate one unique sample ID when the user intent is first observed.
2. Record first intent in the declared monotonic uptime clock domain.
3. Submit via AW39 `submitSeekStamped` / `submitLoopStamped`.
4. Deliver the returned stamped outcome to AW41 under the same sample ID.
5. Independently observe audible output and deliver timestamp + non-empty source under that sample ID. Never substitute backend or scheduling timestamps.
6. Expire genuinely missing callbacks using an HQ/iOS supplied monotonic cutoff; do not silently delete pending samples.
7. Require AW41 `captureCoordinatorComplete`, AW40 `physicalSessionComplete`, current-Moises differential and human listening before any HQ PARITY decision.
8. Treat any retired identity-window truncation as an incomplete evidence session; start a fresh bounded session instead of waiving it.

## Non-claims

AW41 does not prove:

- selected SwiftPM/Xcode compile
- AVFAudio execution
- physical iPhone timing
- correctness of the external audible detector
- rights-cleared real-audio behavior
- current-Moises differential equivalence
- human listening equivalence
- PARITY for P006/P007/P008/P010/P012/P014/P015
