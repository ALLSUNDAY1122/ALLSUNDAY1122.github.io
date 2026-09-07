# L3-AW06｜Apple Offline Reference Render Adapter

## Goal
Turn the deterministic Lane-3 offline control plan into an Apple `AVAudioEngine` manual-rendering path that can produce actual PCM for stem mix + tempo/pitch + metronome/count-in evidence without changing Shared/App contracts.

## Implemented
- `Lane3OfflineExecutionValidator`
  - regenerates the deterministic M04 plan and rejects request/plan mismatch
  - requires an exact stem-ID set before graph mutation
  - validates file sample rate, frame-count tolerance, source-window bounds and render-window bounds
  - requires click PCM when count-in/metronome events exist and rejects click sample-rate mismatch
- `Lane3StreamingPCMAccumulator`
  - streams long renders without retaining the full PCM in memory
  - records peak/RMS/DC/non-finite counts
  - records first/last non-silent frame, clipped-sample count and FNV-1a sample fingerprint
- `AppleOfflineReferenceRenderer`
  - opens and preflights every stem before AVAudioEngine graph mutation
  - uses `AVAudioUnitTimePitch` for production-equivalent tempo/pitch primitives
  - schedules stem windows and click events onto the deterministic render timeline
  - uses `AVAudioEngine.enableManualRenderingMode(.offline, ...)`
  - optionally streams the rendered PCM into an `AVAudioFile`
  - produces a `Lane3ReferenceObservation`, PCM summary and PCM digest
  - event evidence is explicitly marked `SCHEDULE_COMMAND_TRACE_NOT_AUDIO_ONSET_DETECTION`
  - `parityPromotionAllowed` remains false

## Portable validation executed
Environment: Swift 6.2.1, linux-x86_64.

The new portable execution source was compiled and executed against interface-compatible M04 reference-render types. The Apple source was parsed behind `#if canImport(AVFAudio)`; Linux does not typecheck or execute the AVFAudio branch.

PASS coverage:
- deterministic manifest generation
- missing stem metadata rejection
- unexpected stem metadata rejection
- click PCM required when click events exist
- source window beyond actual file length rejection
- click sample-rate mismatch rejection
- streaming PCM summary and digest
- malformed interleaved PCM rejection
- 100,000 repeated manifest validations

## Benchmarks executed
### Portable preflight/source-equivalent harness
20 rounds × 100,000 validations:
- median: 125.805 ms
- p95: 130.295 ms
- p99/max: 135.079 ms
- checksum: 8,000,000

This measures portable preflight/control work only. It is not an Apple render-latency claim.

### Streaming PCM accumulator
20 rounds × 4,096,000 stereo frames per round (8,192,000 Float samples):
- median: 93.634 ms
- p95: 99.561 ms
- p99/max: 102.774 ms
- checksum frames: 81,920,000

This measures the exact new streaming accumulator implementation; it does not include AVAudioEngine rendering cost.

## Explicit non-PARITY gates
Not executed in this Wave:
- selected Xcode/iOS SDK typecheck of `AppleOfflineReferenceRenderer`
- Apple manual-rendering runtime execution
- rights-cleared real stem files
- actual metronome/count-in click PCM through the Apple graph
- audible/time-domain artifact analysis on rendered PCM
- physical-iPhone capture
- current-Moises differential comparison

Therefore this Wave is `COMPLETE_NON_PARITY`. It prepares real PCM evidence but does not promote P006/P007/P008/P010/P012/P014/P015.

## HQ late-integration usage
1. Compile the Apple renderer with the selected Xcode/iOS SDK.
2. Supply rights-cleared stem file URLs matching a deterministic `Lane3ReferenceRenderRequest`.
3. Supply normal/accent click buffers at the plan output sample rate when click events exist.
4. Render a baseline (tempo 1, pitch 0) and transformed cases to PCM files.
5. Persist plan JSON, execution manifest, observation, PCM digest and PCM artifact together.
6. Compare rendered timing/audio against the deterministic plan and device/current-Moises evidence; do not treat a control-trace match alone as PARITY.
