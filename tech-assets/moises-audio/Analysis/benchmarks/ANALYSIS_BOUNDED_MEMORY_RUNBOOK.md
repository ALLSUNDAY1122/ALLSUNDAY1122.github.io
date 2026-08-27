# W28 Long-audio Analysis bounded-memory runbook

Purpose: reduce Worker-4 Analysis transient memory on long audio without lowering the product analysis sample rate or weakening P021 acceptance.

W28 is product memory engineering, not a PARITY claim. Physical-iPhone memory/thermal/battery evidence still comes from W23/W24 under HQ Late Integration.

## Product path

`ProjectOwnedMusicAnalyzer` now keeps the loader-owned `AnalysisSignal` as the source and replaces the additional whole-track prepared PCM allocation with:

1. `AnalysisPreparedSampleReader`
   - exposes the same logical prepared sample stream used by W11;
   - preserves the 8 kHz maximum analysis rate, block-average resampling and ±16/nonfinite sanitization semantics;
   - caches at most two 16,384-sample Float blocks by default;
   - does not allocate a second whole-track prepared `[Float]`.
2. `StreamingBoundedTempoBeatAnalyzer`
   - consumes the prepared reader while preserving the W11/W15 tempo/beat algorithm and cardinality semantics.
3. `StreamingBoundedMusicalKeyAnalyzer`
   - reads only the bounded uniformly spaced key windows required by productBaseline.
4. `StreamingBoundedChordTimelineAnalyzer`
   - processes bounded chord hop/windows and keeps only timeline decisions.
5. `AnalysisSectionEnergyFeatureExtractor`
   - creates a 100 Hz RMS energy feature signal for section dynamics;
   - harmonic/structural evidence continues to come from the bounded chord timeline;
   - this is a purpose-specific energy feature, not a lower sample-rate replacement for Tempo/Key/Chord analysis.
6. Existing `CancellableSongSectionPipeline`, `SongSectionBoundaryHardener` and W15 final snapshot hardening remain the publication path.

The legacy `AnalysisWorkingSetPolicy.prepare` path remains available for deterministic regression/evidence comparison. It is no longer the product analyzer's required whole-track preparation step.

## Memory accounting

For 44.1 kHz mono Float source PCM, one hour contains 158,760,000 source samples = 635,040,000 bytes. That source buffer is supplied by `AnalysisSignalLoading` and is not hidden or claimed as solved by W28.

The previous 8 kHz prepared signal adds 28,800,000 Float samples = 115,200,000 bytes.

With default W28 settings:

- two-block prepared reader cache upper bound: 131,072 bytes;
- 100 Hz section energy feature for one hour: 1,440,000 bytes;
- tempo onset buffer and worst-case positive-value median scratch are budgeted separately;
- key scratch is bounded to the analysis window;
- chord decision and section structural scratch receive conservative analytical allowances.

`AnalysisBoundedMemoryBudget.estimate` reports these values without allocating the represented track.

The one-hour 44.1 kHz portable budget is:

- source PCM: 635,040,000 bytes, still loader-owned and unresolved;
- avoided whole-track prepared PCM: 115,200,000 bytes;
- estimated major Worker-4 additional working set: 10,366,272 bytes;
- prepared-to-major-additional ratio: 11.112963x.

For 24 hours, the avoided prepared PCM is 2,764,800,000 bytes and the estimated major Worker-4 additional working set is 197,163,072 bytes. These are analytical buffer budgets, not process RSS guarantees.

## Correctness requirements

Before accepting a W28 build for physical-device testing:

- lazy prepared samples must exactly equal the W11 materialized preparation on deterministic resampled and non-resampled fixtures;
- Tempo, Key and Chord outputs must match the materialized prepared-analyzer outputs on deterministic equivalence fixtures;
- Section energy-feature fixtures must preserve duration and expected energy transitions, and Section boundary/label regressions must remain covered;
- cancellation must abort before publication;
- W15 snapshot cardinality/fail-closed rules remain unchanged.

Any quality regression has priority over the memory saving. Do not weaken thresholds or reduce Tempo/Key/Chord analysis rate to make the budget pass.

## CPU / thermal trade-off

A bounded cache can recompute prepared blocks when later stages restart from the beginning. Portable microbenchmarking therefore records the resampling/read cost rather than hiding it.

In the W28 120-second synthetic read microbenchmark, one materialization pass took about 0.015–0.018 s while three complete bounded-reader passes took about 0.055–0.134 s. The median ratio was approximately 3.64x and the worst observed ratio was 8.83x. This microbenchmark is not an iPhone acceptance metric and does not include the full real analyzers.

This trade-off means W28 is not sufficient for P021 by itself. HQ must run W23/W24 physical-device telemetry on the integrated W28 build. A follow-up Worker-4 wave should reduce repeated prepared-sample computation, preferably by sharing extracted features/single-pass work, without reintroducing whole-track PCM memory.

## Source-loader boundary

W28 does not change `AnalysisSignalLoading`: the loader can still return a whole decoded Float track. The 635 MB one-hour 44.1 kHz example therefore remains possible before Worker-4 analysis begins.

Chunked/bounded decode requires a later Analysis loader seam plus HQ/Lane-2 integration. Worker 4 must not edit Lane-2 IO implementation to force that change.

## HQ physical-device gate

Use the W22→W26 selected long-audio corpus and the exact W24 planned runs. Archive W23 raw telemetry and W25 workload receipts through W27.

For the integrated W28 build, HQ should compare at minimum:

- peak resident and physical-footprint memory;
- complete-analysis wall time;
- thermal-state progression;
- battery drain under the approved battery protocol;
- memory warnings/pressure;
- cancellation latency;
- output equivalence/quality against the approved real-audio Analysis benchmark.

W28 portable evidence cannot set or replace HQ production thresholds.

## PARITY boundary

W28 does not change `PARITY_MATRIX.json`. `MOI-P021` remains MISSING until representative physical-iPhone evidence satisfies the HQ-approved P021 gate. BPM/Key/Chord/Section rows likewise still require rights-cleared real-audio and current-Moises differential evidence.
