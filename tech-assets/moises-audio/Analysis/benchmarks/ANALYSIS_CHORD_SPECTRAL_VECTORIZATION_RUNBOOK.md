# Analysis Chord Spectral Vectorization Runbook

## Purpose

W33 reduces the dominant Chord spectral CPU duty cycle without lowering the default 0.25-second Chord cadence or changing the Chord decision rules.

This is engineering evidence only. It is not MOI-P013 or MOI-P021 PARITY evidence.

## Production path

1. The current 0.70-second Chord window is Hann-windowed exactly as before.
2. The same MIDI 36...83 bins below 0.45 * sampleRate are retained.
3. The same Goertzel coefficient and recurrence equation are retained for each bin.
4. Instead of traversing the complete window once per bin, W33 traverses the window once and advances all bin recurrence states for each sample.
5. Bin powers are accumulated into chroma and bass chroma in the same bin order.
6. Both the legacy reference path and vectorized production path send spectrum evidence to the same `AnalysisChordDecisionScorer`.

No FFT approximation, reduced spectral vocabulary, reduced cadence, or product-quality threshold was introduced.

## Required portable checks

- Swift 6 strict-concurrency / warnings-as-errors source-shaped compile.
- Reference-per-bin vs interleaved-multi-bin spectrum comparison must be bit-identical for chroma, bass pitch class and bass dominance on deterministic fixtures.
- Legacy `ChordFrameClassifier` vs production `AnalysisReusableChordFrameClassifier` must have exact label and confidence equality.
- Workspace mismatch must fail back to the legacy classifier without incrementing vectorized classification count.
- One-hour operation budget must keep 14,400 Chord frames, 5,600-sample windows and 48 active bins at the product baseline.

## Portable benchmark

Benchmark configuration:

- sample rate: 8,000 Hz
- Chord window: 5,600 samples
- windows per timing run: 160
- five timing runs per process
- five independent processes
- deterministic harmonic/noise fixtures

Observed 25-run aggregate:

- reference-per-bin median: 0.108393495 s
- interleaved-multi-bin median: 0.016527544 s
- vectorized/reference median ratio: 0.1524772681
- approximate median speedup: 6.56x
- all benchmark checksums identical
- five-process max RSS observed: 24,328 kB

These timings are portable Linux microbenchmark results only. They must not be substituted for W23/W24 physical-iPhone wall-time, thermal or battery evidence.

## One-hour analytical budget

At 8 kHz, 0.70-second window and 0.25-second hop:

- Chord frames: 14,400
- active bins: 48
- recurrence updates remain: 3,870,720,000
- reference window element visits: 3,870,720,000
- interleaved window element visits: 80,640,000
- traversal reduction: 48x

The arithmetic recurrence count is intentionally unchanged. W33 improves locality, loop structure and redundant window traversal while preserving the per-bin recurrence sequence.

## Apple/runtime boundary

W33 deliberately does not select an unverified Accelerate/vDSP/FFT replacement. A future Apple-specific backend may be evaluated behind the same evidence/scoring seam, but it must demonstrate approved numerical and final label/confidence equivalence before product selection.

HQ Late Integration still owns physical-iPhone execution and final PARITY judgment.
