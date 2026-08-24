# L4-W33 Validation — Chord Spectral Recurrence Vectorization

## Result

W33 is complete as Worker-4 engineering hardening. It does not establish MOI-P013 or MOI-P021 PARITY.

## Production changes

- Added `AnalysisChordDecisionScorer` so legacy and optimized Chord spectral paths share one evidence-to-label/confidence implementation.
- Retained the historical `ChordFrameClassifier` as the portable/reference spectral path.
- Reworked `AnalysisReusableChordFrameClassifier` to use an interleaved multi-bin Goertzel backend.
- The optimized backend traverses each Hann-windowed sample once and updates all active bin states, instead of traversing the complete window separately for each bin.
- Per-bin coefficient, recurrence equation, sample order, final power equation, chroma aggregation order, bass weighting, Chord vocabulary, confidence calculation and 0.25-second product cadence remain unchanged.
- Workspace mismatch still falls back to the legacy path.
- Added `AnalysisChordSpectralVectorizationBudgetEstimator`, Package registration and durable XCTest.

## Source-shaped compile

Swift 6.2.1 Linux:

- `-strict-concurrency=complete`
- `-warnings-as-errors`
- shared scorer + legacy classifier + vectorized classifier + vectorization budget
- PASS

This is a portable compile check, not the full HQ Xcode/integrated build gate.

## Numerical and decision equivalence

Five independent benchmark processes were executed. Each process asserted:

- 128 deterministic harmonic/noise windows
- reference-per-bin vs interleaved spectral evidence
- chroma and bass dominance bit-pattern equality
- bass pitch class equality
- legacy vs production label equality
- legacy vs production confidence bit-pattern equality

Result per process: `134 assertions PASS`.

Across all five processes:

- spectral bit mismatches: 0
- label/confidence mismatches: 0

## Portable performance

Each process also measured five reference and five optimized runs over 160 windows at 8 kHz / 5,600 samples.

Across all 25 timing runs:

- reference median: `0.108393495 s`
- interleaved median: `0.016527544 s`
- ratio: `0.1524772681`
- approximate speedup: `6.56x`
- maximum observed RSS: `24,328 kB`

The benchmark is a Linux CPU microbenchmark. It is not physical-iPhone wall time, thermal, battery, or PARITY evidence.

## One-hour analytical budget

Product baseline at 8 kHz:

- Chord window: 5,600 samples / 0.70 s
- Chord hop: 2,000 samples / 0.25 s
- Chord frames: 14,400
- active bins: 48
- Goertzel recurrence updates: `3,870,720,000` before and after W33
- reference window element visits: `3,870,720,000`
- interleaved window element visits: `80,640,000`
- window traversal reduction: `48x`

W33 therefore does not obtain speed by dropping frames, bins, or arithmetic recurrence fidelity.

## Negative / safety behavior

- Invalid workspace size/sample-rate pairing continues to route through the legacy classifier.
- Empty/no-chord handling remains unchanged.
- No FFT approximation was selected.
- No Apple Accelerate claim is made without Apple-capable numerical/device validation.
- No production quality or PARITY threshold was added.

## Remaining gates

MOI-P013 remains MISSING until current-iPhone Moises vocabulary/reference capture and rights-cleared real-audio Chord differential evidence are completed.

MOI-P021 remains MISSING until a genuine bounded Lane-2 decoder is integrated and W23/W24 physical-iPhone wall-time, memory/physical-footprint, thermal, battery and cancellation acceptance is completed.

Full canonical SwiftPM/Xcode XCTest and selected iPhone execution remain HQ Late Integration gates.
