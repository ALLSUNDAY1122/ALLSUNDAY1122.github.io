# L3-AW26｜Long-track Evidence Memory / Copy-cost Hardening

Result: `COMPLETE_NON_PARITY`

AW26 reduces the memory/copy amplification of the Lane-3 AW07/AW08/AW10/AW13 evidence path before HQ runs the required >=30-minute physical-iPhone evidence. It does not claim actual device RSS, thermal, battery, audible quality, current-Moises parity or PARITY.

## Problem

At 48 kHz stereo Float32, 30 minutes contains 86,400,000 frames and about 691.2 MB of raw interleaved PCM per source (decimal bytes). Candidate + reference therefore already require about 1.38 GB if both are retained as in-memory arrays.

The earlier analysis path could add large secondary allocations:

- AW13 created a full byte array while hashing Float32 PCM.
- AW07 collapsed both sources to full-track `[Double]` mono arrays, then created full first-difference arrays and a full derivative array for discontinuity analysis.
- AW08 and AW10 collapsed full tracks to `[Double]` even though their configured evidence uses a bounded number of selected FFT windows.

Those algorithms were acceptable for fixture evidence but create avoidable memory pressure before a 30-minute device gate.

## New bounded PCM boundary

`Lane3PCMChunkReadable` exposes only metadata plus bounded random-access Float32 reads:

- channels
- sample rate
- frame count
- `readInterleavedFrames(startFrame:frameCount:)`

Provided adapters:

- `Lane3ArrayPCMChunkSource` for compatibility/tests.
- `Lane3ClosurePCMChunkSource` for a later file/decoder-backed HQ adapter without persisting a file path in durable evidence.

The reader fails closed on invalid metadata, out-of-bounds reads, integer overflow and short reads.

Important: `Lane3ArrayPCMChunkSource` still retains its complete input descriptor. The material long-track input-RSS benefit requires the selected integration to supply a file/decoder-backed bounded reader. AW26 removes full-track retention from the *pipeline*, not from an explicitly in-memory source chosen by its caller.

## AW13 identity compatibility

`Lane3LongTrackPCMIdentityHasher` implements incremental SHA-256 while preserving the exact historical `SHA256_FLOAT32_LE_V1` byte contract:

1. `LANE3_PCM_IDENTITY_V1` plus `0xff` delimiter.
2. channels UInt64 little-endian.
3. sample-rate bit pattern UInt64 little-endian.
4. frame count UInt64 little-endian.
5. interleaved sample count UInt64 little-endian.
6. every Float32 bit pattern as four little-endian bytes.

The unified run binding preserves the existing `LANE3_UNIFIED_RUN_BINDING_V2` field sequence and delimiter contract. AW24 therefore continues to receive the existing `Lane3UnifiedEvidenceReportV2` type.

Fixed-vector portable check:

- 8 Float32 samples, stereo, 48 kHz.
- expected/reference SHA-256: `df8a40df70a07aba6c124401e71319e690b2c1a188f47082183ad7d171072bdd`.
- chunk sizes 1 / 3 / 257 / 4096 produced the same digest.

## AW07 time-domain bounded analysis

`Lane3LongTrackPCMDifferentialAnalyzer` returns the existing `Lane3PCMDifferentialReport` and keeps the historical evidence scope.

It uses:

- bounded center alignment reads for global lag,
- bounded local reads for drift anchors,
- event-radius reads for onset detection,
- chunked residual/reference RMS and derivative accumulation,
- two chunked discontinuity passes instead of a full derivative array,
- chunked clipping/non-finite health scans.

No full mono or first-difference track is retained by the analyzer.

## AW08 spectral bounded analysis

`Lane3LongTrackSpectralPerceptualDifferentialAnalyzer` returns the existing `Lane3SpectralDifferentialReport`.

Only the legacy selected FFT windows are read. The implementation preserves the historical:

- window selection,
- Hann/FFT math,
- frequency-ratio search,
- log spectral distance,
- centroid/flatness/high-band/band-energy/flux metrics,
- spectral peak threshold,
- log-parabolic sub-bin peak interpolation,
- peak matching rules.

The bounded implementation retains only the configured selected spectra, not a full-track mono copy.

## AW10 cepstral-envelope bounded analysis

`Lane3LongTrackCepstralEnvelopeDifferentialAnalyzer` returns the existing `Lane3CepstralEnvelopeDifferentialReport`.

It reads only selected windows and preserves the legacy low-order DCT-II envelope, tilt, aggregate envelope and peak-matching math. Raw non-finite counts are scanned in chunks.

## AW13-compatible unified route

`Lane3LongTrackUnifiedEvidencePipelineV2`:

- validates the current AW12 production generation receipt,
- validates AW05/AW11 recovery lineage,
- runs bounded AW07/AW08/AW10,
- calls the existing `Lane3IntegratedEvidenceAssembler`,
- computes the exact AW13-compatible streaming PCM identity,
- computes the existing V2 run binding,
- returns `Lane3UnifiedEvidenceReportV2` inside `Lane3LongTrackUnifiedEvidenceResult`.

All perceptual/formant/PARITY claims remain false.

## Resource profile

Default stereo configuration with `chunkFrames = 16,384`:

- maximum single read: 40,962 frames,
- maximum single interleaved Float32 read: 81,924 samples,
- approximate maximum single read bytes: 327,696,
- conservative tracked major-analysis-buffer upper bound: 9,740,384 bytes,
- pipeline full-track PCM retention: false,
- actual process RSS measured: false.

The 9.74 MB figure is a deterministic upper-bound estimate for major buffers owned/tracked by this analysis design. It is **not** iPhone RSS and excludes runtime allocator overhead, decoder buffers, framework caches, stack/runtime metadata and caller-owned source storage.

## Portable validation

Environment:

- Swift 6.2.1
- Linux x86_64
- `-strict-concurrency=complete`
- `-warnings-as-errors`

PASS:

- final split AW26 source strict typecheck,
- fixed known SHA-256 vector,
- identity invariant across multiple chunk boundaries,
- deterministic bounded time-domain/spectral/envelope small-fixture execution,
- AW13-compatible unified report construction on the portable interface-compatible object graph,
- short-read fail-closed path,
- virtual 30-minute 48 kHz stereo identity scan with no full-track allocation by the source and maximum requested read <=16,384 frames.

Virtual 30-minute identity probe:

- frames/source: 86,400,000,
- max requested read: 16,384 frames,
- reference + observed read calls: 10,548.

This proves the streaming access pattern only. It does not prove physical-device RSS, IO throughput or audio quality.

## Repository regression authored

`Playback/Tests/L3_AW26_LongTrackEvidenceSelfTest.swift` compares the bounded implementation against the legacy in-memory implementation for:

- exact AW13 `Lane3PCMIdentityReceipt`,
- entire AW07 report equality,
- entire AW08 report equality,
- entire AW10 report equality,
- short-read rejection,
- default resource-profile bounds.

The repository test is authored but the complete selected Lane-3/Xcode execution remains HQ Late Integration. Do not convert this authored regression into a PASS claim until it is run against the integrated source set.

## Portable identity benchmark

10 rounds × 250,000 frames/source × candidate/reference generated stereo sources:

- median: 24.946 ms,
- p95: 27.151 ms,
- max: 27.151 ms,
- checksum: 44,240.

This measures generated-source streaming SHA identity only. It excludes actual file decoding, AVFAudio, complete AW07/AW08/AW10 analysis, iPhone RSS/thermal/battery, real audio, current Moises and listening.

## HQ integration contract

For the real >=30-minute gate:

1. Use a bounded file/decoder-backed `Lane3PCMChunkReadable`; do not convert the complete capture to `Lane3ArrayPCMChunkSource` solely for evidence analysis.
2. Run the AW26 repository legacy-equivalence regression before relying on the bounded path.
3. Feed the resulting existing `Lane3UnifiedEvidenceReportV2` into AW24 so chain-of-custody remains unchanged.
4. Measure actual iPhone RSS/thermal/battery separately. Resource-planner estimates are not device metrics.
5. Keep raw PCM/audio and local file paths out of durable AW24/AW26 manifests.
6. Perform rights-cleared real-audio/current-Moises/listening gates before any PARITY promotion.
