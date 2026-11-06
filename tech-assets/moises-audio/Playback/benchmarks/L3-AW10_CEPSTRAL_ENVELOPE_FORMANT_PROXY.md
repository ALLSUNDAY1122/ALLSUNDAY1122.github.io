# L3-AW10｜Cepstral / Spectral-Envelope Formant Proxy

Result: `COMPLETE_NON_PARITY`

## Goal

P010 speed/tempo and P012 pitch/key need more than AW07 time-domain residuals and AW08 raw/STFT spectral-shape evidence. AW10 adds a broad spectral-envelope proxy intended to surface formant-like envelope movement or tilt damage while keeping the final audible-quality judgment outside the portable analyzer.

## Implementation

`Lane3CepstralEnvelopeDifferentialAnalyzer`:

- accepts the same `Lane3PCMBufferDescriptor` used by AW07/AW08;
- consumes an AW07-style `globalLagFrames` so the compared windows share one time alignment;
- collapses finite interleaved PCM to mono and counts non-finite source samples;
- uses Hann-windowed radix-2 FFT;
- converts the selected 100–5000 Hz log-power spectrum into a low-order DCT-II reconstruction;
- treats that low-order reconstruction as a deterministic cepstral-style broad spectral-envelope proxy;
- removes mean level before envelope RMSE so gain-only changes do not look like formant damage;
- reports per-window envelope RMSE, envelope correlation and spectral-tilt delta in dB/octave;
- builds an aggregate smoothed envelope and reports matched local envelope-peak frequency errors in cents;
- rejects invalid PCM/configuration, sample-rate/channel mismatch, insufficient comparable frames and all-silent evidence;
- always emits `standardizedPerceptualClaimAllowed=false`, `formantPreservationClaimAllowed=false`, and `parityPromotionAllowed=false`.

This is intentionally not PESQ/POLQA/PEAQ, LPC formant tracking, a speech-recognition score, or a human audibility model.

## Portable validation

Swift 6.2.1 / Linux x86_64:

- identical PCM: envelope RMSE ~0, correlation ~1, peak error 0;
- gain-only -6 dB: normalized envelope RMSE remains near zero;
- F0 200→300 Hz with the same synthetic broad envelope: median matched envelope-peak error `146.389 cents`;
- deliberately shifted broad formant bands: median matched envelope-peak error `438.562 cents`, >2x the same-envelope F0-change case;
- exact 137-frame leading offset with `globalLagFrames=137`: near-zero envelope RMSE;
- one NaN sample is counted and isolated rather than propagated through FFT;
- non-power-of-two FFT is rejected;
- sample-rate mismatch is rejected;
- all-silent evidence is rejected instead of producing a misleading quality report;
- Codable report round-trip PASS;
- 120 varied-F0 identical-envelope stress analyses PASS.

The synthetic cases validate sensitivity and failure behavior only. They are not real-audio acceptance evidence.

## Benchmark

20 rounds × 10 analyses, 16,384 stereo frames/analysis, 48 kHz, FFT 1024, hop 512, maximum 30 windows:

- median: `22.146 ms/round`
- p95: `25.599 ms/round`
- max: `26.078 ms/round`
- checksum: `20245.785794`

This Linux benchmark excludes AVAudioEngine, device capture, AW07 alignment computation, AW08 analysis, file I/O and current-Moises comparison.

## Evidence boundary / HQ use

For tempo-only source→transformed evidence, AW10 should compare the time-aligned source and transformed PCM without frequency-axis warping: the broad envelope is expected to remain substantially stable even though duration changes. For pitch/key source→transformed evidence, the harmonic/fundamental structure is expected to move while the broad formant-like envelope should not simply shift with the pitch ratio. Because this proxy still responds to harmonic sampling and synthetic signal structure, HQ must interpret AW10 alongside AW08 frequency-scale metrics, actual rights-cleared music/vocal fixtures, current-Moises differential and listening.

For ours-vs-current-Moises at the same controls, compare both outputs after the same AW07 alignment/normalization policy and retain raw PCM plus AW08/AW10 machine-readable reports together.

No PARITY row is promoted by AW10 alone.
