# L4-W12 Validation — Analysis cooperative cancellation / responsiveness

Status: **NON_PARITY hardening evidence**

## Goal

Make long-running Lane-4 Analysis cooperate with Swift Task cancellation without changing the frozen `MusicAnalyzing` / Shared contracts, and guarantee that cancellation cannot publish a partially completed combined `AnalysisSnapshot`.

## Production changes

- Added `AnalysisCancellationPolicy` with bounded checkpoint cadence.
- Added `AnalysisWorkingSetPolicy.prepareCancellable(signal:)`.
  - Checks cancellation during long resampling.
  - Checks cancellation during long finite-value scans and sanitization copies.
  - Retains the existing non-throwing `prepare(signal:)` compatibility path.
- Added `BoundedTempoBeatAnalyzer.analyzeCancellable`.
  - Cancellation checkpoints in onset-frame scanning, candidate lags, sampled autocorrelation, phase-grid traversal, beat tracking and post-envelope normalization.
- Added `BoundedMusicalKeyAnalyzer.analyzeCancellable`.
  - Checks before/after global probes and through selected chroma windows / frequency groups.
- Added `BoundedChordTimelineAnalyzer.analyzeCancellable`.
  - Checks every chord frame and through timeline post-processing / short-segment absorption.
- Updated `ProjectOwnedMusicAnalyzer` to use only cancellable Lane-4 stages.
  - `CancellationError` propagates through the already-frozen `async throws` `MusicAnalyzing` contract.
  - Cancellation is checked before loading, after loading, between every major MIR stage, after song-section inference, and before final snapshot return.
  - The combined snapshot is created/published only after all stages finish, so cancelled work cannot return a partial tempo/key/chord/section value.

## Compatibility behavior

The existing non-throwing `BoundedTempoBeatAnalyzer.analyze`, `BoundedMusicalKeyAnalyzer.analyze`, `BoundedChordTimelineAnalyzer.analyze`, and `AnalysisWorkingSetPolicy.prepare` entry points remain available for deterministic unit/benchmark callers. They execute the same inference logic with cancellation checkpoints disabled. Product analysis uses the new throwing variants.

## Edge / negative / recovery coverage

1. A Task cancelled before high-rate preparation returns `CancellationError`; it does not return a partially resampled buffer.
2. Cancellation during a 10-minute synthetic Tempo workload is observed inside the long-running tempo loops.
3. Cancellation during a 5-minute synthetic Chord workload is observed between chord frames / post-processing passes.
4. Pre-cancelled Key analysis fails immediately with `CancellationError`.
5. Uncancelled compatibility and cancellable Tempo APIs return the same output for the same deterministic fixture.
6. Combined `ProjectOwnedMusicAnalyzer` cancellation has a regression test asserting that no `AnalysisSnapshot` value is returned after cancellation.
7. Section inference is still internally synchronous in W12; cancellation is checked immediately before and after the stage. This preserves atomic publication but does not yet guarantee sub-section-stage cancellation latency.

## Portable execution evidence

Runtime: Swift 6.2.1, `x86_64-unknown-linux-gnu`.

Portable production-source-shaped harness: **5/5 assertions PASS** in each of five complete runs.

Observed cancellation latencies after the cancellation request:

| Run | preparation | tempo | chord |
|---|---:|---:|---:|
| 1 | 0.000723488 s | 0.000050189 s | 0.000113809 s |
| 2 | 0.000681196 s | 0.000612629 s | 0.000161820 s |
| 3 | 0.000390244 s | 0.000125031 s | 0.000178090 s |
| 4 | 0.000664226 s | 0.000199095 s | 0.000477068 s |
| 5 | 0.000648653 s | 0.000642429 s | 0.001354094 s |

Portable acceptance threshold used by the harness: `< 0.25 s` for preparation / Tempo / Chord cancellation observation.

Worst observed portable values:

- preparation: `0.000723488 s`
- Tempo: `0.000642429 s`
- Chord: `0.001354094 s`

These numbers measure this Linux harness only. They are not physical-iPhone responsiveness claims.

## XCTest source validation

`AnalysisCancellationTests.swift` was parsed successfully and typechecked against an `-enable-testing` MoisesAudioCore-shaped module exposing the frozen-domain-shaped contracts and the exact W12 cancellable APIs: **PASS**.

The committed tests cover:

- pre-cancelled preparation,
- cancellation during long Tempo work,
- cancellation during long Chord work,
- pre-cancelled Key work,
- non-cancelled compatibility equivalence,
- combined analyzer atomic/no-partial-snapshot cancellation behavior.

## PARITY discipline

W12 does **not** change `PARITY_MATRIX.json`.

- MOI-P009 remains MISSING.
- MOI-P011 remains MISSING.
- MOI-P013 remains MISSING.
- MOI-P016 remains MISSING.
- MOI-P021 remains MISSING.

Cancellation correctness is necessary product hardening, but it does not replace rights-cleared real-audio accuracy, current-iPhone Moises differential, actual integrated navigation/loop behavior, physical-device memory/thermal/battery evidence, or iPhone cancellation-latency measurement.

## Remaining Lane-4 gap after W12

Song-section analysis still has only stage-boundary cancellation. A long section-analysis stage cannot currently observe Task cancellation inside its own context scanning / clustering loops. The next high-value Lane-4 wave should make section inference cooperatively cancellable and bound its worst-case structural post-processing cost while preserving the W09 functional-label behavior.
