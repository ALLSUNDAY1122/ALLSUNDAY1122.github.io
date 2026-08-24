# L3-AW22｜DSP-entry / Click-schedule Runtime Telemetry

Result: `COMPLETE_NON_PARITY`

## Goal

Complement AW19 Playback-backend telemetry with a privacy-preserving measurement path for actual time/pitch DSP backend entry/execution, click-generation invalidation, and Apple click-node replace/append execution. The measurement must survive Swift actor hops and concurrent tempo/pitch submissions without FIFO mis-attribution or capture of user audio/content.

## Production implementation

- `Lane3DSPRuntimeTelemetryCollector`
  - fixed-bucket latency histograms
  - saturating counters
  - aggregate-only snapshots
  - per-operation product end-to-end, submission-to-first-DSP-entry, backend execution, submission-to-first-click-invalidation, and click invalidation execution latency
  - additional backend apply/click invalidation calls inside one logical operation are counted separately from the primary entry
- `Lane3DSPRuntimeTelemetryProbe`
  - establishes an ephemeral Swift `TaskLocal` trace around the existing selected product operation
  - trace contains only operation kind and monotonic start time
  - trace is never exported or persisted
- `Lane3DSPTelemetryTransactionalBackend`
  - wraps the selected `PracticeDSPTransactionalBackendApplying`
  - measures the real synchronous `apply(tempoRatio:pitchSemitones:)` entry and execution time
  - transaction rollback/recovery applies remain visible as additional apply calls but do not duplicate submission-to-entry samples
- `Lane3DSPTelemetryClickInvalidator`
  - wraps the selected `PracticeDSPClickScheduleInvalidating`
  - measures actual click queue invalidation entry/execution under the same TaskLocal context
- `Lane3DSPTelemetryAppleClickExecutor` (`canImport(AVFAudio)`)
  - wraps the selected `AppleSampleAccurateClickExecutor`
  - measures metronome replacement, rolling metronome append, and count-in replacement execution through aggregate probe timings
  - does not copy click buffers, events, host times, render origins, generations, or audio into telemetry

## Why TaskLocal instead of another FIFO bridge

AW19 needed a bounded bridge between independent product and Playback-backend surfaces. DSP mutations execute inside the same Swift task that enters the transactional backend/click invalidator, including across actor hops. `TaskLocal` therefore carries the operation category and monotonic start through the exact async call chain. Concurrent tempo and pitch calls cannot swap attribution because each task owns its own trace.

Rollback can call the DSP backend more than once for a single logical product operation. The trace atomically claims only the first backend entry for queue-latency measurement; all later applies are counted as additional internal applies. The same rule applies to click invalidation.

## Privacy contract

Exported snapshot contains no:

- raw event log
- absolute wall-clock timestamp
- ProjectID
- media/file name or path
- PCM/audio content
- click buffer or event content
- individual Playback/click generation
- individual ticket/trace identifier

The ephemeral TaskLocal trace contains only operation kind + monotonic start nanoseconds and is not persisted.

## Portable validation actually executed

Environment: Swift 6.2.1, Linux x86_64.

1. Exact telemetry core declaration parse: PASS.
2. Exact core + adapter declarations against interface-compatible production protocols: PASS.
3. Deterministic TaskLocal behavior probe: PASS.
   - tempo: one product submission -> one primary DSP backend entry + one primary click invalidation
   - pitch: two backend applies inside one logical operation -> one primary entry + one additional apply
   - failed count-in discard remains attributed to its own operation
   - deliberately unscoped backend/click calls increment `unscoped` counters rather than being mis-attributed
   - privacy snapshot assertions PASS
4. Concurrent attribution stress: PASS.
   - 20,000 concurrent operations
   - 10,000 tempo primary backend entries
   - 10,000 pitch primary backend entries
   - 10,000 tempo click invalidation entries
   - unscoped backend = 0
   - unscoped click = 0
5. Portable telemetry overhead benchmark: PASS.
   - 20 rounds x 5,000 operations
   - median 166.224 ms / round
   - p95 201.937 ms / round
   - max 224.576 ms / round
   - checksum 250190

Benchmark scope is the telemetry probe/collector/decorators with lightweight protocol-compatible backend objects. It excludes AVAudioEngine, AVAudioUnitTimePitch, actual Apple click-node scheduling, AVAudioSession, file/device IO, real audio, thermal behavior, and current-Moises execution. It is not an audible or device latency claim.

## Repository validation authored

- `DSP/Tests/L3_AW22_DSPRuntimeTelemetrySelfTest.swift`
  - actual `PracticeDSPProductionController`
  - actual `PracticeDSPGenerationCoordinator`
  - measured transactional backend and click invalidator
  - tempo, pitch success/failure, metronome, count-in arm/consume/discard and recovery attribution
  - privacy and zero-unscoped assertions
- `DSP/Tests/L3_AW22_DSPRuntimeTelemetryBenchmark.swift`
  - actual controller/coordinator route
  - alternating tempo/pitch operations

Selected complete Xcode/iOS execution remains HQ Late Integration.

## HQ integration contract

For a physical-iPhone measurement window:

1. Create one `Lane3DSPRuntimeTelemetryCollector` and one `Lane3DSPRuntimeTelemetryProbe`.
2. Wrap the real time/pitch backend with `Lane3DSPTelemetryTransactionalBackend` before constructing `PracticeDSPProductionController`.
3. Wrap the real click invalidator with `Lane3DSPTelemetryClickInvalidator` before constructing `PracticeDSPGenerationCoordinator`.
4. Wrap existing product submission boundaries with `probe.measureAsync` using the correct operation kind. Do not create a second DSP authority merely for telemetry.
5. Use `Lane3DSPTelemetryAppleClickExecutor` for selected metronome/count-in replace/append timing on iPhone.
6. Require `unscopedBackendApplyCalls == 0` and `unscopedClickInvalidationCalls == 0` for a valid selected measurement run. Nonzero values mean the instrumentation path was bypassed.
7. Preserve the AW19 privacy boundary. Do not add IDs, media metadata, individual generations or raw timings to persistent logs.
8. Tune/compare p50/p95/p99 only on physical iPhone with the real production graph and rights-cleared audio.

## Remaining gates

- selected Xcode compile/runtime for the AVFAudio wrapper
- physical-iPhone DSP backend and click-node timing
- real AVAudioSession interruption path
- real-audio click/pop, drift, pitch/formant and tempo artifact evidence
- current-Moises differential/listening evidence
- final P010/P012/P014/P015 PARITY judgment by HQ

AW22 therefore remains `COMPLETE_NON_PARITY`.
