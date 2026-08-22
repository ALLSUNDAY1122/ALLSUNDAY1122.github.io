# L4-M03 validation — chord timeline analysis

Date: 2026-08-22 JST
Lane: `LANE-4-IOS-ANALYSIS`
Frozen epoch contract SHA: `be1c84314db182d6eee5097de34e017af1a4a7de`
PARITY row touched by evidence only: `MOI-P013`
PARITY promotion: **none**

## Implemented surface

L4-M03 adds deterministic, playback-clock-friendly chord analysis behind the frozen `AnalysisSnapshot.chords` contract:

- `ChordTimelineAnalyzer`
  - project-owned time-window pitch-class/chroma extraction;
  - major/minor triad template scoring;
  - explicit `N` no-chord and `X` unknown states;
  - confidence thresholding rather than forced labels;
  - deterministic tie ordering;
  - local single-frame flicker suppression;
  - short uncertain-segment absorption;
  - adjacent-label merge and gap-free/non-overlapping timeline normalization;
  - analysis-only downsampling with simple block averaging so full-rate app audio does not require another Lane implementation;
- `ProjectOwnedMusicAnalyzer`
  - now fills BPM/beat/key from L4-M02 plus chord timeline from L4-M03 while leaving sections for L4-M04;
- `AnalysisBenchmarkRunner`
  - duration-weighted root accuracy;
  - duration-weighted major/minor accuracy;
  - no-chord precision/recall;
  - chord-boundary median absolute error;
  - explicit coverage so an estimator cannot hide difficult intervals by emitting `X` selectively;
- `ChordTimelineAnalysisTests`
  - timeline order/contiguity, N/X behavior, short glitch handling, benchmark semantics, JSON order/timestamps and frozen `MusicAnalyzing` integration.

No third-party chord model/runtime is embedded. No `IO/**`, `Library/**`, `Playback/**`, `DSP/**` or `Separation/**` implementation was copied into Lane 4. `Shared/**`, `App/**`, Queue and `PARITY_MATRIX.json` were not edited.

## Output vocabulary and clock semantics

Current clean baseline labels are:

- major triad: `C`, `C#`, ... `B`;
- minor triad: `C:min`, `C#:min`, ... `B:min`;
- no chord / silence: `N`;
- unknown / insufficiently confident: `X`.

The final timeline is:

- sorted by `startSeconds`;
- non-overlapping;
- gap-free from `0` to analyzed duration when the input is non-empty;
- adjacent identical labels merged;
- directly consumable by a playback clock using `startSeconds <= t < endSeconds`.

The baseline deliberately does not pretend to support inversions, sevenths, extensions or slash chords yet. The frozen contract can carry richer normalized labels later without redesign, but vocabulary expansion must be justified by real-audio benchmark evidence.

## Failure-driven corrections during the Macro Bundle

1. Initial wide-window classification detected the intended C → A:min → N → G progression, but the 0.7 s chroma window leaked harmonic energy into a 1 s silence interval. The emitted `N` interval was only `4.25–4.75 s`, reducing no-chord recall to 0.5.
2. The analyzer was changed to decide `N` first from the local hop RMS while retaining the wider chroma window for harmonic classification.
3. Final output became exactly `C 0–2`, `A:min 2–4`, `N 4–5`, `G 5–7` on the deterministic synthetic fixture, with no-chord recall restored to 1.0 and median boundary error to 0.
4. A temporary local XCTest harness initially used leading-dot numeric literals such as `.75`, which Swift 6 rejects. That transcription-only harness issue was corrected to `0.75`; the committed branch test already used valid explicit literals and was not affected.

## Swift build/test evidence

Worker environment:

```text
Swift version 6.2.1 (swift-6.2.1-RELEASE)
Target: x86_64-unknown-linux-gnu
```

The Worker container cannot resolve github.com for a normal clone, so a temporary SwiftPM harness was assembled from the exact L4-M03 chord algorithm/evaluator logic plus minimal frozen-contract-shaped stubs. This validates the implemented portable logic but does not replace HQ's later canonical checkout regression.

Final targeted XCTest run:

```text
swift test --disable-sandbox
Build complete! (3.88s)
ChordTests: 8/8 PASS
0 failures, 0 unexpected
```

Covered behaviors:

1. C → A:min → N → G detection and exact playback-clock ordering;
2. silence emits one explicit `N` interval;
3. equal-energy chromatic ambiguity emits `X`, not a forced chord;
4. a 50 ms chromatic glitch does not create an unstable standalone segment;
5. exact reference timeline produces perfect root/major-minor/N/boundary/coverage metrics;
6. a half-track `X` estimate retains root accuracy on decided material but coverage falls to 0.5, preventing hidden selective-output success;
7. chord timestamps/labels survive JSON Codable round-trip in order;
8. `ProjectOwnedMusicAnalyzer` fills chords through the frozen `MusicAnalyzing` interface.

Additional executable negative/resample checks:

```text
44.1 kHz C-major -> analysis downsample -> C: PASS
A-minor with NaN + Infinity samples -> A:min: PASS
empty signal -> []: PASS
50 ms chromatic glitch between C regions -> merged C timeline: PASS
```

## Benchmark evidence

Machine-readable output is stored at:

`Analysis/benchmarks/L4-M03_SYNTHETIC_BENCHMARK.json`

Optimized portable run (`swiftc -O`) on the 7 s synthetic C/A:min/N/G fixture:

```text
wall_seconds = 0.018093585968017578
rtf = 0.0025847979954310824
root_weighted_accuracy = 1.0
majmin_weighted_accuracy = 1.0
no_chord_precision = 1.0
no_chord_recall = 1.0
coverage = 1.0
boundary_median_abs_error_seconds = 0.0
```

`peak_rss_mb`, `thermal` and battery remain `null` because they were not measured. They are not converted to favorable zeros.

## Remaining quality gates

L4-M03 is a measurable legal-clean baseline, not a product parity result. Still required before `MOI-P013` can move from `MISSING`:

- rights-cleared multi-genre real-audio chord benchmark;
- inversions and complex chords wherever current reference behavior supports them;
- dense mixes, live recordings, weak harmony and ambiguous/no-chord cases;
- real iPhone wall-time/RSS/thermal/battery evidence;
- playback-clock UI synchronization on device;
- current Moises differential comparison for chord labels, boundaries, coverage and visible operation behavior.

## PARITY statement

No PARITY row is promoted by L4-M03. Synthetic-only/test-only evidence remains explicitly non-PARITY.
