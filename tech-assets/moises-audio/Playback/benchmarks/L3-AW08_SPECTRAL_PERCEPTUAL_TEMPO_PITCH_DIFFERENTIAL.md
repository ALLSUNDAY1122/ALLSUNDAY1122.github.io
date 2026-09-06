# L3-AW08 — Spectral / Perceptual-Proxy Tempo-Pitch Differential

Result: `COMPLETE_NON_PARITY`

## Goal

Extend AW07's time-domain PCM differential with deterministic frequency-domain evidence useful for MOI-P010 (tempo/speed) and MOI-P012 (pitch/key). AW07 derivative RMS could detect excess high-frequency activity, but it could not describe spectral-shape damage or verify an expected frequency-scale change.

## Implementation

The AW08 implementation is split across four lane-owned Playback sources: `Lane3SpectralDifferentialModels.swift`, `Lane3SpectralPerceptualDifferential.swift`, `Lane3SpectralDSPCore.swift`, and `Lane3SpectralDSPMetrics.swift`. It uses a portable radix-2 STFT analyzer over the existing `Lane3PCMBufferDescriptor`.

Metrics:
- global-lag-aware aligned STFT windows;
- normalized log-spectral distance (mean / p95);
- expected frequency-scale correlation plus a bounded best-ratio search;
- sub-bin spectral-peak matching with median and p95 cents error;
- spectral centroid ratio error in cents;
- spectral flatness delta;
- high-band energy fraction delta;
- eight logarithmic band-energy cosine distance;
- frame RMS-envelope correlation;
- spectral-flux delta as a transient-smear proxy;
- non-finite sample counts.

Hardening:
- only power-of-two FFT sizes are accepted;
- sample-rate/channel mismatches fail closed;
- invalid frequency/search/window configuration fails closed;
- both-silent windows are excluded from aggregate quality metrics;
- non-finite samples are counted and replaced by silence for bounded analysis rather than entering FFT math;
- all outputs explicitly set `perceptualClaimAllowed=false` and `parityPromotionAllowed=false`.

## Intended evidence modes

1. Transform correctness: compare source/reference PCM with transformed PCM. For tempo-only with pitch preservation use `expectedFrequencyRatio=1`. For a key shift use `2^(semitones/12)`.
2. Current-Moises differential: after AW07 time alignment, compare our transformed PCM against a lawful current-Moises transformed PCM at the same control setting. In this mode the expected inter-output frequency ratio is normally 1.

The metrics are engineering proxies. They are not PESQ/POLQA/PEAQ and do not replace human listening or formant-specific/perceptual validation.

## Portable validation

Swift 6.2.1 / Linux x86_64:
- identical-signal baseline: zero/near-zero spectral deltas PASS;
- known +12-semitone synthetic harmonic shift: expected ratio tracking and sub-bin spectral-peak cents matching PASS;
- injected 10.5 kHz tone plus isolated pop: log-spectral distance, high-band delta, band-shape distance and flux delta rise versus clean control PASS;
- known 128-frame AW07-style lag applied before spectral analysis PASS;
- NaN sample counting without FFT propagation/hang PASS;
- non-power-of-two FFT, sample-rate mismatch and channel mismatch rejection PASS;
- 120 varied expected-frequency-ratio stress analyses PASS;
- Codable JSON report round-trip PASS.

The final four-file source split was recompiled and the self-test passed unchanged.

## Benchmark

20 rounds × 10 analyses, 16,384 stereo frames per analysis, 48 kHz, 1024-point FFT, 512 hop, up to 30 windows:
- median: 21.288 ms per 10 analyses;
- p95: 22.124 ms per 10 analyses;
- p99/max: 22.124 ms per 10 analyses;
- checksum: 711.809156.

This benchmark is Linux portable computation only. It is not an iPhone performance claim.

## Remaining gates

- selected Xcode/iOS compilation and integration remain HQ-owned;
- rights-cleared real PCM must be rendered with AW06 and analyzed with AW07/AW08;
- current-Moises transformed PCM pairs are still required;
- spectral proxies do not prove absence of formant damage, warble, phasiness, transient smear or other audible artifacts;
- physical-device capture and human listening remain required before P010/P012 promotion;
- MOI-P006/P007/P008/P010/P012/P014/P015 remain MISSING.
