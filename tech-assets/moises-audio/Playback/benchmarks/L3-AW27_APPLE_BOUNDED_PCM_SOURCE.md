# L3-AW27｜Apple / Decoder-backed Bounded PCM Source

Result: `COMPLETE_NON_PARITY`

## Goal

Connect the AW26 `Lane3PCMChunkReadable` long-track evidence path to a real Apple file decoder without materializing an entire candidate/reference track into a `Lane3PCMBufferDescriptor` solely for analysis.

## Why this wave

AW26 removed analysis-time full-track copy amplification, but `Lane3ArrayPCMChunkSource` still owns the complete in-memory PCM array. A real >=30-minute iPhone evidence run therefore still needed a file/decoder-backed source before AW26 could reduce the input-side PCM array burden.

## Implementation

### `Lane3PCMChunkReadPolicy.swift`

- Hard maximum frames per read; default `65_536`.
- Fail-closed negative/out-of-range/overflow checks before decoder access.
- Exact expected interleaved sample-count calculation.
- Aggregate read audit only:
  - successful read calls
  - zero-length reads
  - total returned frames
  - maximum requested frames
  - initial/sequential/backward/forward-gap access counts
- Audit contains no file path and cannot promote PARITY.

### `AppleFilePCMChunkSource.swift`

- `AVAudioFile(forReading:commonFormat:.pcmFormatFloat32, interleaved:false)` supplies the decoder-facing processing format.
- Implements the AW26 `Lane3PCMChunkReadable` contract directly.
- `NSLock` serializes mutable `AVAudioFile.framePosition` + read operations.
- Every non-empty read revalidates:
  - file remains open
  - file length remains the opened length
  - Float32 processing format remains intact
  - channel count remains intact
  - sample-rate bit pattern remains intact
- Random access seeks with `framePosition` and verifies both seek position and post-read end position.
- Reads exactly the requested frame count or fails closed on short read.
- Converts the bounded deinterleaved Float32 buffer to the interleaved `[Float]` required by AW26.
- Underlying Apple/NSError text is not exported; public errors are path-free categories.
- Public metadata explicitly states:
  - `sourcePathIncluded = false`
  - `fullTrackPCMArrayRetainedByAdapter = false`
  - `frameworkDecoderBufferingMeasured = false`
  - `actualProcessRSSMeasured = false`
  - `parityPromotionAllowed = false`

The adapter claim is intentionally narrow: it does not allocate/retain a whole-track PCM array itself. It does **not** claim anything about AVFAudio internal decoder buffering or process RSS.

### `AppleLongTrackEvidenceInputs.swift`

- Opens reference + observed files as bounded Apple sources.
- Runs AW26 pair format preflight before analysis.
- Computes the AW26 resource profile before returning the pair.
- Rejects a decoder read budget smaller than `resourceProfile.maximumSingleReadFrames`, avoiding a late failure deep in a long analysis.
- With current default AW26 settings the required single-read budget is `40_962` frames and the Apple adapter default is `65_536` frames.

## Portable validation actually executed

Environment:

- Swift 6.2.1
- Linux x86_64
- `-strict-concurrency=complete`
- `-warnings-as-errors`

Exact GitHub policy blob validated locally:

- `Lane3PCMChunkReadPolicy.swift`: `d6c7f5a6ff46db9cc8148ec373cc1de63dd56151`

Self-test PASS:

- accepts AW26-sized `40_962`-frame stereo read
- rejects `65_537` frames against a `65_536` maximum
- rejects EOF overrun
- rejects Int64 frame-range overflow
- audit correctly distinguishes initial, sequential, backward and forward-gap reads
- audit remains path-free and non-PARITY

Output:

`L3-AW27 bounded PCM policy PASS reads=4 max=16384`

Portable policy benchmark PASS:

- 20 rounds
- 100,000 randomized valid range checks + audit updates per round
- median `0.721 ms`
- p95 `0.760 ms`
- max `0.760 ms`
- checksum `82197314834`

This benchmark measures only range-policy + audit CPU overhead. It excludes AVAudioFile decode, file IO, AW07/AW08/AW10 analysis, AVFAudio buffers, physical-device RSS, thermal and battery.

## Apple source validation status

Exact Apple source blob mirrored into the local syntax-validation input:

- `AppleFilePCMChunkSource.swift`: `a2b3c987cb97c9211f327aad328066a7db83d7a2`

Linux parsing with the `#if canImport(AVFAudio)` source present succeeds, but Linux does not typecheck the Apple branch. Therefore this is **not** selected-Xcode compile evidence.

`L3_AW27_AppleFilePCMChunkSourceSelfTest.swift` is authored for selected Apple execution. It creates an actual Float32 CAF fixture and verifies:

- source metadata
- random forward/backward seek/read sample values
- exact frame/sample counts
- read-limit rejection
- EOF-range rejection
- zero-length behavior
- path-free diagnostics
- AW26 read-budget preflight rejection at 4,096 frames
- successful default 65,536-frame preflight with the current 40,962-frame requirement

## Integration contract for HQ

1. Use app-owned candidate/reference file URLs; Lane 3 does not own security-scoped import lifecycle.
2. Open both with `Lane3AppleLongTrackEvidenceInputFactory.openPair`.
3. Pass `pair.reference` and `pair.observed` directly to `Lane3LongTrackUnifiedEvidencePipelineV2.analyze`.
4. Do not convert the complete file to `Lane3PCMBufferDescriptor` solely for AW26 evidence.
5. Preserve AW13 SHA-256/run-binding and AW24 capture/listening binding.
6. Record Apple source diagnostics after the run; a valid bounded run should have no counter overflow and `maximumRequestedFrames <= maximumFramesPerRead`.
7. Measure physical iPhone RSS/thermal/battery independently. AW26/AW27 allocation bounds and adapter metadata are not device-performance measurements.
8. If Apple read/open/format/short-read failures occur, treat the evidence run as invalid rather than silently filling or truncating PCM.

## Remaining gates

- selected Xcode/iOS compile of the actual AVFAudio branch
- actual Apple file decode execution for representative app-supported codecs
- corrupted/truncated real-file behavior on the selected device
- >=30-minute rights-cleared candidate/current-Moises pair through AW27 -> AW26 -> AW13 V2 -> AW24
- physical iPhone RSS, thermal and battery evidence
- current-Moises differential and listening review
- PARITY decision by HQ

No PARITY state is changed by AW27.
