# L3-AW19｜Generation Churn / Dispatch Latency Telemetry

Result: `COMPLETE_NON_PARITY`

Evidence scope: `LANE3_PRIVACY_PRESERVING_PRODUCTION_TELEMETRY_NON_PARITY`

## Purpose

AW16-AW18 make rapid transport, generation authority and interruption recovery deterministic, but the provisional continuous-control quiet period still needs physical-iPhone tuning. AW19 adds production instrumentation that can quantify generation churn and latency without retaining user audio/content.

## Production implementation

- `Playback/Sources/Lane3ProductionTelemetry.swift`
  - aggregate counters and fixed latency histograms only
  - per-kind product submissions / internal operations / executed / superseded / cancelled / rejected / failed
  - control Playback-token and automatic-recovery-token counts
  - coalesced predecessor count and generations-per-1000-submissions rate
  - end-to-end latency histograms
  - submission-to-real-Playback-backend-entry latency for backend-backed routes
  - residual latency after subtracting the configured seek/loop quiet period
  - real Playback backend execution latency
  - interruption begin/end/resume-path latency and resume/recovery counters
  - saturating counters and no PARITY claim
- `Playback/Sources/Lane3TelemetryPlaybackBackend.swift`
  - decorates the selected real `PlaybackBackendDriving`
  - records route category plus monotonic backend entry/exit timing only
  - never passes ProjectID/media metadata/path/audio samples to telemetry
- `Playback/Sources/Lane3TelemetryDispatchCorrelationBridge.swift`
  - bounded ephemeral correlation of backend-entry monotonic timestamps
  - default maximum 256 pending timestamps per transport kind
  - drops oldest correlation instead of allowing unbounded memory growth
  - exposes only aggregate pending/drop/unmatched health counters
- `Playback/Sources/Lane3InstrumentedInterruptionGate.swift`
  - outer product facade around AW18
  - intentionally has no mutable product state, so concurrent seek/loop/tempo submissions still reach AW18/AW17 concurrently and preserve pre-token coalescing
  - forwards bounded backend correlations immediately before aggregate outcome recording

## Privacy boundary

The exported telemetry snapshot records no:

- raw event log
- absolute wall-clock timestamp
- ProjectID
- filename or file path
- media metadata
- PCM/audio content
- individual ticket ID
- individual Playback/click generation value

The bounded correlation bridge temporarily holds only monotonic uptime timestamps required to match a real backend entry to a completed product call. Those timestamps are not exported or persisted and are capped per kind.

## Portable validation

Environment: Swift 6.2.1, Linux x86_64.

Exact AW19 production sources typechecked against interface-compatible AW17/AW18/Playback/coordinator contracts: PASS.

Aggregate self-test:

- 505 product submissions
- 499 seek intents superseded before token
- 5 total Playback tokens observed
  - 4 control tokens
  - 1 recovery token
- seek backend-entry sample matched correctly
- configured quiet-period residual histogram matched correctly
- backend execution histogram matched correctly
- interruption begin/end and no-token pause-resume suppression counters matched
- privacy flags all fail closed
- JSON snapshot contained none of the sentinel filename/path/ProjectID/PCM/absolute-timestamp strings
- result: PASS

Bounded correlation regression:

- cap = 2 pending entries/kind
- injected backend entries = 5
- retained pending entries = 2
- overflow drops = 3
- two valid product outcomes consumed both retained correlations
- final pending entries = 0
- valid correlation unmatched count = 0
- one deliberate outcome with no backend entry increments unmatched count to 1
- result: PASS

## Portable benchmark

Bounded bridge + aggregate collector, 20 independent rounds × 20,000 events:

- workload per round: 2,000 executed-token-shaped events + 18,000 pre-token superseded events
- median: 910.493 ms / 20,000 events
- p95: 959.372 ms
- max: 1145.208 ms
- checksum: 800190
- bridge pending after every round: 0
- bridge overflow drops during benchmark: 0
- bridge unmatched outcomes during benchmark: 0

This benchmark measures Swift actor aggregation/correlation overhead on Linux. It excludes AVAudioEngine, AudioUnit, real Playback/DSP cost, file/device IO, real audio, AVAudioSession delivery and current-Moises execution. It is not a physical-device performance claim.

## Repository validation prepared

- `Playback/Tests/L3_AW19_ProductionTelemetrySelfTest.swift`
  - full AW15-AW18 production chain + bounded bridge + measured Playback backend
  - 500 concurrent seek inputs
  - interruption block/no-token pause suppression
  - forced backend failure + automatic recovery
  - privacy and correlation-health assertions
- `Playback/Tests/L3_AW19_BoundedCorrelationSelfTest.swift`
  - deterministic bounded-correlation overflow/unmatched regression
- `Playback/Tests/L3_AW19_ProductionTelemetryBenchmark.swift`
  - integrated telemetry path benchmark for selected full Lane-3 build

Selected Xcode/iOS/full-Lane-3 execution remains an HQ Late Integration gate.

## Interpretation / limitations

For seek/loop and other real Playback-backend routes, `submissionToBackendEntryLatency` measures product submission to actual backend entry. For continuous routes it includes the configured quiet/coalescing window; `postConfiguredQuietResidualLatency` subtracts that configured floor and is intended for comparative tuning, not as a claim of pure scheduler queue time.

Tempo is an external Playback discontinuity followed by DSP mutation and therefore has no Playback-backend entry. AW19 still records tempo end-to-end latency, coalescing/token counts and failure/recovery behavior, but a distinct DSP-entry queue-latency probe remains a possible later hardening item.

No telemetry measurement can promote P006/P007/P008/P010/P012/P014/P015 without selected iPhone, real audio and current-Moises differential evidence.

## HQ integration requirements

1. Instantiate one `Lane3ProductionTelemetryCollector` per product-scoped Lane-3 session/project lifetime as appropriate for the desired device test window.
2. Instantiate one shared `Lane3TelemetryDispatchCorrelationBridge` and pass the same instance to both `Lane3TelemetryPlaybackBackend` and `Lane3InstrumentedInterruptionGate`.
3. Wrap the selected real Playback backend with `Lane3TelemetryPlaybackBackend` before constructing `RescheduleFencedPlaybackBackend`.
4. Route product controls and AVAudioSession interruption callbacks through `Lane3InstrumentedInterruptionGate`; do not bypass AW18/AW17.
5. Treat the bridge-less initializer path as isolated-test compatibility, not the selected production integration.
6. During iPhone tuning collect only aggregate snapshots and correlation-health snapshots. Do not add filenames, ProjectID, absolute timestamps or PCM to logs.
7. Compare 8/12/16/20/24 ms continuous quiet windows using user-perceived latency, pre-token supersession rate, tokens/1000 submissions, submission-to-backend-entry p50/p95 and post-quiet residual p50/p95.
8. Validate phone/Siri/route interruption resume latency and audible restart behavior on physical iPhone before PARITY promotion.
