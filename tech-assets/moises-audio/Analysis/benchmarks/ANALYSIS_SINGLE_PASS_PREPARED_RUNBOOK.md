# W29 Single-pass Prepared Analysis Runbook

Purpose: remove the W28 repeated prepared-sample reconstruction cost without reintroducing a whole-track prepared PCM allocation or lowering Analysis quality.

This is an engineering hardening gate for MOI-P021. It is not physical-iPhone acceptance and cannot declare PARITY.

## Product path

`ProjectOwnedMusicAnalyzer` now uses:

1. `AnalysisSignalLoading` to obtain the current source `AnalysisSignal`.
2. `AnalysisPreparedSampleReader` for the W11-equivalent bounded/clamped 8 kHz logical prepared signal.
3. `AnalysisSinglePassPreparedFeatureExtractor` to traverse every logical prepared sample once, in increasing index order.
4. During that one traversal the extractor emits:
   - the same Tempo energy/onset frame definition used by W28,
   - the same uniformly spaced Key windows used by W28,
   - the same Chord segment RMS and centered analysis-window decisions used by W28,
   - the same 100 Hz Section RMS feature used by W28.
5. `AnalysisSinglePassPreparedPipeline` sends those features into the existing Tempo/Key/Chord decision logic.
6. Section analysis and W14/W15 hardening continue after the bounded Section feature is produced.

No production sample-rate reduction beyond the existing W11 8 kHz prepared contract was introduced in W29.

## Single traversal invariant

For a newly created reader used by the W29 product path:

- `preparedSampleRequests == sampleCount`
- `preparedSampleComputations == sampleCount`
- `exactSinglePreparedTraversal == true`

The reader counters measure actual block reconstruction, not only call-site intent. A future change that causes block eviction/reload during the single-pass extractor will make the computation count exceed the logical prepared sample count and fail this invariant.

## Equivalence gate

Before accepting a W29 change, run the same source/configuration through both:

- W28 compatibility path: reader-based Tempo, reader-based Key, reader-based Chord, `AnalysisSectionEnergyFeatureExtractor`.
- W29 path: `AnalysisSinglePassPreparedPipeline`.

Require exact equality for:

- `TempoAnalysis?`
- `MusicalKey?`
- `[ChordEvent]`
- Section energy `AnalysisSignal`

Also test nonfinite and over-range source samples against the W11 materialized preparation semantics.

Synthetic equality is regression evidence only. Rights-cleared real-audio differential evidence remains mandatory for MOI-P009/P011/P013/P016.

## Long-audio memory budget

`AnalysisSinglePassPreparedBudget` keeps the W28 rule that source PCM is reported separately because it is supplied by `AnalysisSignalLoading` rather than created by Worker 4.

For a 44.1 kHz mono Float source, the analytical W29 budget is:

- 1 hour source PCM: 635,040,000 bytes — still present and not solved by W29.
- 1 hour avoided whole-track prepared PCM: 115,200,000 bytes.
- 1 hour estimated major Worker-4 additional working set: 10,766,976 bytes.
- 24 hour avoided whole-track prepared PCM: 2,764,800,000 bytes.
- 24 hour estimated major Worker-4 additional working set: 197,563,776 bytes.

The estimate includes reader cache, Tempo onset plus median scratch, retained Key windows, Chord decisions, Section energy, bounded Tempo/Chord rings and the W13 Section structural cap. Swift allocator overhead and system VM behavior are not modeled.

## CPU/recomputation benchmark

The W29 portable microbenchmark compares the W28 access pattern and W29 single-pass access pattern against the same synthetic 120-second 44.1 kHz source.

Observed five-run prepared-sample reconstruction counts:

- W28 compatibility path: 4,275,712 per run.
- W29 single-pass path: 960,000 per run.
- reduction: 77.55%.

Observed Linux wall time in that prepared-path harness:

- W28: 0.112119, 0.108618, 0.114212, 0.107812, 0.111664 seconds.
- W29: 0.051834, 0.052106, 0.051196, 0.051398, 0.055828 seconds.
- median ratio W29/W28: 0.464.

These timings are NON_PARITY engineering evidence. The portable harness uses a source-shaped Chord classifier stub so it isolates prepared traversal/recomputation; it does not measure production Chord CPU, Apple runtime behavior, thermal state or battery drain.

## Cancellation

A pre-cancelled W29 pipeline must throw `CancellationError`. Long loops retain cooperative checks in:

- the prepared traversal,
- reader block reconstruction,
- Tempo normalization/correlation/beat tracking,
- Key windows and chroma analysis,
- Chord post-processing,
- later Section/W15 processing.

No partial `AnalysisSnapshot` is published after cancellation.

## Physical-iPhone gate remains authoritative

W29 does not change the W23/W24 acceptance contract. HQ must still run the exact W22/W26-selected corpus on the exact approved iPhone/build/iOS epoch and evaluate worst-case:

- wall time,
- resident memory,
- physical footprint,
- thermal state,
- battery drain,
- memory warnings/pressure,
- cancellation latency.

W29 is successful engineering evidence only if it survives that physical-device gate.

## Remaining source-buffer gap

W29 still starts from the current `AnalysisSignalLoading` contract, whose value contains a whole decoded mono `[Float]`. One hour at 44.1 kHz is about 635.04 MB before Worker-4 prepared features are considered.

Removing that dominant source buffer requires a chunked/bounded decode seam across Lane 2 / HQ Late Integration. Worker 4 must not modify Lane-2 IO implementations or frozen Shared contracts to bypass ownership.
