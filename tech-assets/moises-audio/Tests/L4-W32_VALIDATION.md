# L4-W32 Validation — Long-audio Analysis CPU Duty Cycle

## Result

W32 is complete as Worker-4 engineering hardening. It does not establish MOI-P021 PARITY.

The wave reduces long-audio Tempo frame-energy rescanning and repeated Chord spectral setup while preserving ordinary-song Tempo summation order, the existing 0.25-second Chord cadence, Chord vocabulary, candidate scoring and Goertzel recurrence.

## Production changes

- Added `AnalysisTempoFrameEnergyTracker` and `AnalysisLongAudioCPUDutyPolicy` in the shared sequential prepared-feature accumulator.
- Audio shorter than 1800 seconds keeps the historical per-frame Tempo window rescan.
- Audio at or above 1800 seconds uses rolling sum-of-squares with an exact ring-window rebase every 2048 natural Tempo frames.
- Added `AnalysisReusableChordSpectralKernel` / `AnalysisReusableChordSpectralWorkspace` / `AnalysisReusableChordFrameClassifier`.
- Hann weights, MIDI-bin metadata and Goertzel coefficients are built once per Analysis accumulator and reused across Chord frames.
- Reusable Chord workspace mismatch falls back to the legacy `ChordFrameClassifier`.
- Added `AnalysisLongAudioCPUDutyBudgetEstimator`.
- Package registration, durable XCTest, runbook and machine-readable NON_PARITY evidence were added.

## Ordinary-song preservation

The Tempo optimization is intentionally disabled below 1800 seconds. This keeps the historical floating-point summation order for ordinary songs rather than accepting small rounding changes merely for speed.

Chord cadence is not reduced. The default 0.25-second hop and 0.70-second analysis window remain unchanged wherever W31 structural safety permits them.

## Tempo equivalence

A deterministic 2,000,000-prepared-sample comparison produced 24,996 natural Tempo frames.

- maximum absolute energy delta: `5.259681579161679e-15`
- maximum relative energy delta: `4.86737580558946e-14`
- reference window square terms: `9,198,528`
- rolling square updates: `3,999,632`
- periodic exact-rebase terms: `4,784`

The rolling path therefore preserved the same frame-energy sequence to floating-point noise while materially reducing window-square work.

## Tempo portable microbenchmark

4,000,000 prepared samples, five independent runs:

- reference seconds: `0.055386317, 0.055557615, 0.055883090, 0.057483409, 0.054973207`
- rolling seconds: `0.027668790, 0.027901065, 0.027460570, 0.027778122, 0.027187745`
- reference median: `0.055557615 s`
- rolling median: `0.027668790 s`
- rolling/reference median ratio: `0.4980197584`

This is a portable Tempo energy-path microbenchmark, not physical-iPhone thermal/battery evidence.

## Chord numerical equivalence

The reusable spectral path was compared against the legacy per-frame setup on:

- 8 kHz sample rate
- 5,600-sample Chord window
- 48 spectral bins
- 64 deterministic windows
- 1,536 raw chroma/bass values

Result:

- bit-pattern mismatches: `0`
- maximum absolute delta: `0`

Durable XCTest also compares final label and confidence against the legacy classifier on multiple harmonic fixtures and requires exact equality.

## Chord portable microbenchmark

160 windows per run, five runs:

- legacy seconds: `0.118455576, 0.115859155, 0.115655543, 0.115591508, 0.118714571`
- reused seconds: `0.109654260, 0.108155742, 0.111033701, 0.108285269, 0.117474066`
- legacy median: `0.115859155 s`
- reused median: `0.109654260 s`
- reused/legacy median ratio: `0.9464444998`

The modest wall reduction is expected. W32 removes repeated setup transcendental work and scratch allocation, but deliberately leaves the dominant Goertzel sample recurrence unchanged.

## One-hour analytical CPU budget

At 8 kHz Analysis input:

- Tempo frame size: `368`
- natural Tempo frames: `359,996`
- baseline Tempo window-square terms: `132,478,528`
- rolling square updates upper bound: `57,599,632`
- periodic-rebase terms upper bound: `64,768`
- Tempo square-term reduction ratio: about `2.297x`
- Chord window: `5,600` samples
- Chord frames: `14,400`
- Chord spectral bins: `48`
- repeated Chord setup evaluations: `82,022,400`
- reused setup evaluations: `5,696`
- setup reduction ratio: `14,400x`
- Goertzel sample iterations unchanged: `3,870,720,000`

The last figure is the principal remaining Worker-4 Chord CPU/thermal risk.

## Stress / edge validation

The CPU budget estimator was exercised on 250,000 duration/sample-rate cases per process for five processes:

- failures: `0`
- checksum each run: `16,375,889,024`
- internal seconds: `0.050834363, 0.050603440, 0.049839365, 0.048414935, 0.051530939`
- maximum RSS: `17,064 kB`

The reusable Chord path fails back to the legacy classifier on kernel/sample-count/sample-rate mismatch instead of applying an invalid optimization.

Cancellation behavior remains governed by the existing W12/W29/W30 pipeline checks; W32 does not introduce a separate publication path.

## Maintainability risk

`AnalysisReusableChordFrameClassifier` currently mirrors the legacy candidate-scoring logic so the optimized spectral evidence can be consumed without changing `ChordFrameClassifier` internals. Regression tests compare legacy and reusable output, but future changes to one scorer could drift from the other. A later hardening wave should centralize the shared scoring stage before introducing a more aggressive Apple Accelerate/vectorized spectral backend.

The reusable workspace also retains one extra Double scratch window (44,800 bytes at the default 5,600 samples), which is small relative to W31 retained-feature bounds but is included in the current accumulator retained-byte estimate.

## Durable artifacts

- `AnalysisReusableChordFrameClassifier.swift`
- `AnalysisLongAudioCPUDutyBudget.swift`
- updated `AnalysisSequentialPreparedFeatureAccumulator.swift`
- `AnalysisCPUDutyCycleTests.swift`
- `L4-W32_LONG_AUDIO_CPU_DUTY_CYCLE.json`
- `ANALYSIS_CPU_DUTY_CYCLE_RUNBOOK.md`

Full canonical SwiftPM/Xcode XCTest execution remains an HQ integrated-checkout gate. Portable source-shaped checks and microbenchmarks do not replace Apple-runtime testing.

## PARITY boundary

MOI-P021 remains MISSING. A genuine Lane-2 bounded decoder, integrated physical-iPhone W23 telemetry and W24 HQ-approved acceptance are still required. P009, P011, P013 and P016 also remain subject to rights-cleared W22 differential evidence and actual current-iPhone Moises comparison. W32 does not update `PARITY_MATRIX.json` and makes no PARITY claim.
