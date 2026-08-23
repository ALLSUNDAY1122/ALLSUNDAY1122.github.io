# L3-AW07 | PCM Differential & Artifact Analyzer

Result: `COMPLETE_NON_PARITY`

## Goal

AW06 can create an Apple offline PCM candidate, but its event evidence is a schedule-command trace rather than evidence derived from rendered audio. AW07 adds a portable differential layer that evaluates reference PCM against observed PCM without promoting PARITY.

## Implemented metrics

- global first-difference normalized cross-correlation and lag
- local lag observations across the track plus drift span
- reference-PCM onset detection around scheduled click/count-in frames
- observed onset matching after global alignment
- raw onset offset and residual onset timing error
- aligned residual RMS and residual/reference dB
- derivative RMS ratio and dB delta as a high-frequency/artifact proxy
- unexpected large sample discontinuities outside expected event masks
- clipped and non-finite observed sample counts
- Codable machine-readable report with `parityPromotionAllowed=false`

## Edge / negative / recovery-oriented coverage

- exact 137-frame shift is recovered and globally aligned
- scheduled events retain 137-frame raw offset while residual error becomes zero
- an injected two-sample pop outside expected event masks is detected
- synthetic insertion drift produces non-zero local lag span
- sample-rate mismatch fails closed
- malformed interleaved PCM fails closed
- out-of-range event frame fails closed
- NaN input is counted without hanging correlation loops
- report JSON encode/decode round-trip is stable
- 200 repeated shifted analyses pass

## Portable benchmark

Environment: Swift 6.2.1, linux-x86_64, optimized build.

20 rounds x 100 analyses, 24,000 reference frames, stereo 48 kHz, alignment search ±64 frames, three local drift anchors:

- median: 142.359 ms / 100 analyses
- p95: 154.270 ms / 100 analyses
- max: 157.017 ms / 100 analyses
- checksum: 29650

This benchmark excludes AVAudioEngine, real files, physical iPhone capture and Moises output.

## Evidence boundary

This is measurement infrastructure, not proof of audible equivalence. Final acceptance still requires:

1. selected Xcode/iOS compile of AW01-AW07 Apple sources;
2. AW06 actual Apple manual render with rights-cleared stems and click PCM;
3. AW07 analysis of actual Apple render/capture, not synthetic-only PCM;
4. physical-device click/pop/zipper, drift, latency and listening evidence;
5. current-Moises differential evidence on matched lawful fixtures;
6. HQ PARITY decision.

No PARITY row is promoted by AW07 alone.
