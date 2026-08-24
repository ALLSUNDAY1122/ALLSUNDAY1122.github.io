# L4-W29 Validation — Single-pass Prepared Feature Extraction

## Result

W29 is complete as Worker-4 engineering hardening. It does **not** establish MOI-P021 PARITY.

The W28 product path removed the whole-track 8 kHz prepared PCM array, but each Analysis stage could reconstruct prepared blocks again. W29 changes the product path so one increasing-index traversal of the logical W11 prepared signal simultaneously produces Tempo onset features, bounded Key windows, Chord frame decisions, and the 100 Hz Section energy signal.

## Production changes

- `AnalysisPreparedSampleReader` now exposes diagnostic counters for actual prepared block loads and prepared-sample reconstruction operations.
- `AnalysisSinglePassPreparedFeatureExtractor` performs one prepared traversal and emits all Worker-4 PCM-derived features.
- `AnalysisSinglePassPreparedPipeline` reuses the existing Tempo/Key/Chord decision semantics from precomputed features.
- `StreamingBoundedTempoBeatAnalyzer` accepts a precomputed normalized onset representation.
- `StreamingBoundedMusicalKeyAnalyzer` accepts the same bounded uniformly spaced windows and sampled global RMS used by W28.
- `StreamingBoundedChordTimelineAnalyzer` accepts preclassified frame decisions and keeps the existing flicker/merge/short-segment/timeline normalization semantics.
- `ProjectOwnedMusicAnalyzer` now calls the W29 single-pass pipeline before Section and W15 publication hardening.
- `AnalysisSinglePassPreparedBudget` reports long-duration Worker-4 buffer estimates without hiding the still-dominant loader-owned source PCM.

The W28 reader-based compatibility APIs remain available for regression/evidence tooling.

## Prepared semantics and output equivalence

Source-shaped Swift 6.2.1 strict-concurrency typecheck: **PASS**.

A 120-second 44.1 kHz synthetic click+triad fixture was run through both the W28 compatibility path and W29 path five times.

All five runs produced exact equality for:

- `TempoAnalysis?`
- `MusicalKey?`
- `[ChordEvent]`
- Section energy `AnalysisSignal`

The source-shaped portable timing harness uses a Chord classifier stub to isolate the prepared traversal. Therefore timing is not production Chord CPU evidence. The durable package XCTest uses the production classifier when the canonical package is compiled by HQ.

Pathological source samples (`NaN`, infinity, values outside the ±16 preparation bound) were also exercised against W11 materialized preparation semantics. W29 continues to use the same finite/clamped block-average prepared definition.

## Recomputation reduction

For each 120-second run:

- W28 prepared-sample computations: **4,275,712**
- W29 prepared-sample computations: **960,000**
- logical W29 prepared sample count: **960,000**
- reduction: **77.547599%**
- W28/W29 computation ratio: **4.4538667x**

The W29 `exactSinglePreparedTraversal` diagnostic is true only when both prepared requests and actual prepared reconstructions equal the logical prepared sample count. This avoids declaring success merely because the call sites appear sequential while cache eviction silently causes rework.

## Portable timing

W28 seconds:

`0.112119, 0.108618, 0.114212, 0.107812, 0.111664`

W29 seconds:

`0.051834, 0.052106, 0.051196, 0.051398, 0.055828`

Median:

- W28: **0.111664 s**
- W29: **0.051834 s**
- W29/W28: **0.464196**

Whole comparison harness: approximately 1.00 s wall, max RSS 39,892 kB.

These Linux figures are **NON_PARITY synthetic engineering evidence**. They do not substitute for W23/W24 physical-iPhone wall-time, memory, thermal, battery, pressure, or cancellation measurements.

## Long-audio analytical memory budget

### One hour / 44.1 kHz mono Float source

- source PCM supplied by `AnalysisSignalLoading`: **635,040,000 bytes**
- avoided whole-track prepared PCM: **115,200,000 bytes**
- estimated major Worker-4 additional working set: **10,766,976 bytes**
- prepared/additional ratio: **10.699383x**
- logical prepared samples traversed once: **28,800,000**

### Twenty-four hours / 44.1 kHz mono Float source

- source PCM: **15,240,960,000 bytes**
- avoided prepared PCM: **2,764,800,000 bytes**
- estimated major Worker-4 additional working set: **197,563,776 bytes**
- prepared/additional ratio: **13.994468x**

The analytical estimate includes reader cache, Tempo onset + median scratch, retained bounded Key windows, Chord decisions, Section energy, bounded Tempo/Chord rings and W13 Section structural scratch. Swift allocator/VM overhead is not modeled.

## Cancellation / failure behavior

A pre-cancelled W29 pipeline returns `CancellationError`: **PASS**.

Cancellation checks remain inside the prepared traversal and downstream Tempo/Key/Chord/Section/W15 loops. The product actor does not publish a partial final snapshot after cancellation.

Invalid/nonfinite source PCM is sanitized through the existing W11 prepared semantics rather than being interpreted as zero-size or valid performance evidence.

## Durable XCTest

`AnalysisSinglePassPreparedPipelineTests.swift` covers:

1. exact W29 vs W28 Tempo/Key/Chord/Section equality;
2. exact one-traversal prepared reconstruction count;
3. W11 pathological prepared semantics;
4. Section energy equivalence;
5. exact 1-hour budget;
6. exact 24-hour budget;
7. pre-cancel failure before publication.

Full canonical SwiftPM/Xcode test execution remains an HQ integrated-checkout gate.

## PARITY boundary

MOI-P021 remains **MISSING**.

W29 addresses a real Worker-4 CPU/recomputation risk introduced by W28, but no approved physical iPhone has been run and no production W24 limits have been applied. W23/W24 remain authoritative for actual wall time, memory, thermal, battery, memory pressure/warnings and cancellation latency.

MOI-P009/P011/P013/P016 also remain MISSING until HQ performs the required rights-cleared current-iPhone Moises differential work.

## Remaining highest-value gap

The dominant memory object is now outside this Worker-4 prepared pipeline: `AnalysisSignalLoading` still returns a whole decoded mono `[Float]`. At one hour / 44.1 kHz this is about **635.04 MB** before Worker-4 feature buffers.

The next engineering step should introduce a Worker-4-owned optional chunked Analysis input seam and compatibility adapter, then request Lane 2 / HQ Late Integration to wire its concrete decoder to that seam. Worker 4 must not edit Lane-2 IO code or frozen Shared/App contracts.
