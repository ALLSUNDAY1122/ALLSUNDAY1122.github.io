# L3-AW09｜Integrated Playback/DSP Evidence Pipeline

Result: `COMPLETE_NON_PARITY`

## Goal
Bind the previously independent Lane-3 evidence stages into one fail-closed run record:

1. AW05 Playback schedule generation + PracticeDSP click generation binding.
2. AW06 offline Apple render receipt with fixture/control signature and actual-audio status.
3. AW07 PCM-derived time alignment/onset/discontinuity evidence.
4. AW08 spectral/perceptual-proxy differential using the exact AW07 global lag.

The pipeline prevents evidence from different transport generations, fixtures, render outputs, alignments or pitch/tempo intents from being accidentally combined.

## Added
- `Playback/Sources/Lane3IntegratedEvidenceModels.swift`: comparison intent, transport/offline/time/spectral receipts, integrated report and fail-closed assembler.
- `Playback/Sources/Lane3IntegratedEvidencePipeline.swift`: AW05 transport validation, AW07→AW08 execution, and Apple-only AW06 receipt bridge.
- portable self-test and benchmark.

## Fail-closed coherence checks
The assembler rejects:
- unvalidated/stale transport receipts;
- missing actual-audio evidence;
- plan/render frame-count mismatch;
- observed PCM sample-rate/frame mismatch against AW06 receipt;
- reference/observed frame mismatch against AW07 report;
- click-event count mismatch against AW06 manifest;
- AW07 onset-observation count mismatch;
- AW07/AW08 global-lag mismatch;
- comparison intent vs AW08 expected-frequency-ratio mismatch;
- non-finite PCM evidence;
- any component attempting PARITY/perceptual claim;
- unexpected evidence scopes or non-finite metrics.

The Apple bridge additionally requires AW06 plan, execution manifest and observation to agree on fixture ID, control signature, output frame count and sample rate before creating a receipt.

## Portable validation
Environment: Swift 6.2.1 / Linux x86_64.

PASS:
- valid +12-semitone integrated report;
- Codable JSON round-trip;
- stale transport rejection;
- frame-count mismatch rejection;
- click-event mismatch rejection;
- AW07/AW08 alignment mismatch rejection;
- tempo-vs-pitch intent mismatch rejection;
- non-finite evidence rejection;
- sample-rate mismatch rejection;
- component perceptual/PARITY claim rejection;
- 200,000 varied semitone/expected-ratio assembly stress.

Production adapter source also compiled and executed against interface-compatible AW05/AW07/AW08 types. The Apple-specific AW06 bridge was syntax-parsed only on Linux because `AVFAudio` is unavailable; selected Xcode/iOS SDK typecheck remains an HQ gate.

## Benchmark
20 rounds × 100,000 integrated assemblies using a long-track-style 2,880,000-frame receipt:

- median: 17.181 ms / round
- p95: 18.529 ms / round
- max: 20.039 ms / round
- checksum: 532,000,000

This benchmark measures metadata/report coherence assembly only. It excludes AVAudioEngine rendering, AW07 PCM correlation and AW08 STFT work.

## Evidence boundary
This wave does **not** claim PARITY, standardized perceptual quality, or human inaudibility. Final P006/P007/P008/P010/P012/P014/P015 decisions still require selected-Xcode compile, actual Apple offline/device PCM, rights-cleared real tracks, current-Moises differential evidence and human listening where audible artifacts matter.
