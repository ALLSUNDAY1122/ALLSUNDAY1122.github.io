# L4-W16 Validation — Analysis differential benchmark scalability / integrity hardening

## Scope

Worker 4 only. This wave changes Lane-4 Analysis, Package registration, tests, benchmark evidence, and the real-audio Analysis runbook. Shared/App/PARITY/Queue/Work Packages/Lane Plan/Resource Locks remain untouched.

## Why this wave was necessary

W11–W15 bounded and made the product Analysis pipeline cooperatively cancellable, but the differential evidence path still contained quadratic evaluation work:

- beat one-to-one F-measure rescanned every unused reference beat for every estimated beat;
- beat median error performed all-pairs nearest search;
- chord boundary median error performed all-pairs nearest search;
- chord interval scoring rescanned the event array for every comparison interval;
- section-boundary PRF rescanned every unused reference boundary for every estimate;
- bidirectional section-boundary error performed all-pairs nearest search;
- sampled section labels repeatedly searched section arrays from the beginning.

This meant the product inference path could be bounded while the PARITY evidence path itself became the long-audio bottleneck.

## Production changes

### Scalable timestamp matching

Added `AnalysisBenchmarkScalability.swift` with `BenchmarkTimelineMatcher`.

The one-to-one matcher intentionally preserves the old metric semantics:

1. reference and estimated timestamps are sorted;
2. each estimated timestamp is processed in ascending order;
3. the nearest unused reference timestamp inside tolerance is selected;
4. equal-distance ties choose the lower reference index, matching the prior ascending scan and strict `< bestError` update rule.

Unused predecessor/successor discovery uses binary search plus union-find deletion instead of rescanning the whole reference array.

This is intentionally **not** changed to maximum-cardinality bipartite matching. For example:

- reference: `[0, 1]`
- estimate: `[1, 2]`
- tolerance: `1 s`

The historical greedy metric returns one match / F=0.5. W16 returns the same result so benchmark history is not silently redefined.

Nearest-boundary/error queries use a sorted target plus binary-search nearest lookup.

### Analysis benchmark runner

`AnalysisBenchmarkRunner` now provides cancellable counterparts while retaining existing APIs:

- `evaluateCancellable`
- `beatFMeasureCancellable`
- `chordMetricsCancellable`

Additional changes:

- beat F-measure uses the scalable exact-greedy matcher;
- beat median nearest error is no longer all-pairs;
- chord boundary median error is no longer all-pairs;
- chord interval labels advance monotonic cursors across sorted events instead of using `events.first` for every comparison span;
- W15-derived duration-aware evaluator cardinality limits are checked before expensive metric evaluation;
- beat/chord evaluator overflow fails the affected row closed with `parity_eligible=false` and an explicit limitation instead of truncating arrays and manufacturing a score;
- supplemental W14/W15/W16 diagnostic metrics can be attached to rows.

### Section benchmark evaluator

`SectionBenchmarkEvaluator` retains existing `evaluate` / `metrics` APIs and adds cancellable variants.

- boundary PRF uses the W16 scalable matcher;
- nearest-boundary medians use binary-search nearest error;
- sampled reference/estimate section lookup uses monotonic cursors;
- clustering/functional/sampling/normalization loops contain cancellation checkpoints;
- section evaluator overflow returns `evaluator_input_accepted=0`, zero accuracy placeholders, and makes a benchmark row non-PARITY-eligible with `EVALUATOR_SECTION_CARDINALITY_REJECTED_NOT_PARITY_EVIDENCE`.

The zero values in an overflow row are not accepted accuracy evidence because the row is explicitly rejected by `evaluator_input_accepted` and `parity_eligible`.

### Product-aligned real-audio runner

Added `AnalysisRealAudioBenchmarkRunner.runProductAligned` as the canonical path for new Analysis differential evidence.

It executes the current product-aligned Lane-4 stages:

1. `AnalysisWorkingSetPolicy.prepareCancellable`
2. `BoundedTempoBeatAnalyzer.analyzeCancellable`
3. `BoundedMusicalKeyAnalyzer.analyzeCancellable`
4. `BoundedChordTimelineAnalyzer.analyzeCancellable`
5. `CancellableSongSectionPipeline.analyze`
6. `SongSectionBoundaryHardener.harden`
7. `AnalysisSnapshotRobustness.hardenCancellable`
8. W16 cancellable benchmark evaluators

The legacy `AnalysisRealAudioBenchmarkRunner.run` remains source-compatible for earlier tests/evidence but the runbook now forbids using it for new PARITY evidence.

Every product-aligned row carries W15 snapshot-cardinality diagnostics plus `w16_product_pipeline=1` and `w16_scalable_evaluator=1`. Structure rows additionally carry W14 section-fragmentation before/after diagnostics.

## Evaluator cardinality policy

W16 reuses W15 duration-aware limits instead of inventing unrelated evaluator limits.

If either the reference or estimate exceeds the relevant beat/chord/section limit:

- the affected domain is rejected from PARITY evidence;
- arrays are not silently truncated;
- the row records the evaluator limit and acceptance flag;
- other independent domains remain evaluable.

The 100,000-beat and 16,384-boundary portable stress cases deliberately exercise the matcher helper above typical short/medium-track limits. The active evaluator gate is evaluated before those matchers in real evidence flow.

## Portable semantic regression

Swift 6.2.1 / x86_64-unknown-linux-gnu source-shaped harness:

- 2,000 deterministic small cases containing duplicate timestamps and tie cases were compared against the prior quadratic greedy implementation;
- exact match count: 2,000 / 2,000;
- matched absolute-error sequence also matched the legacy Oracle;
- the adversarial `[0,1]` vs `[1,2]`, tolerance 1 s case remained one match / F=0.5;
- 100,000-beat exact-within-tolerance stress passed;
- 100,000 nearest-error queries passed;
- 16,384-section-boundary exact-within-tolerance stress passed;
- pre-cancelled cancellable matcher threw `CancellationError`.

Five optimized portable runs all passed 6/6 assertions:

| run | 100k beat match | 16,384 boundary match | pre-cancel completion | wall | max RSS |
|---|---:|---:|---:|---:|---:|
| 1 | 11.651 ms | 1.765 ms | 0.413 ms | 0.02 s | 22,100 kB |
| 2 | 13.153 ms | 2.305 ms | 0.460 ms | 0.03 s | 21,920 kB |
| 3 | 12.041 ms | 1.984 ms | 1.000 ms | 0.03 s | 22,028 kB |
| 4 | 12.340 ms | 3.679 ms | 0.490 ms | 0.03 s | 22,080 kB |
| 5 | 11.958 ms | 1.847 ms | 0.375 ms | 0.03 s | 22,028 kB |

A separate unoptimized Swift 6.2.1 recompile also passed all 2,000 semantic-Oracle cases and the adversarial case, but 100,000-beat matching took about 130.6 ms. Therefore timing is build-context-sensitive and is not used as an iPhone performance claim.

Conceptual worst-case comparison counts removed by W16 include:

- 100,000 × 100,000 beat all-pairs scan: 10,000,000,000 candidate comparisons in the prior shape;
- 16,384 × 16,384 section-boundary all-pairs scan: 268,435,456 candidate comparisons in the prior shape.

These are operation-count models, not measured CPU speedup ratios.

## XCTest coverage added

`AnalysisBenchmarkScalabilityTests.swift` covers:

- 2,000-case legacy-greedy semantic equivalence;
- adversarial greedy-vs-maximum-matching distinction;
- 20,000 beat scalable exact scoring;
- Section boundary greedy semantics;
- Section evaluator cardinality fail-closed behavior;
- W14/W15 supplemental metric presence;
- pre-cancelled large beat evaluation;
- synthetic `runProductAligned` end-to-end evidence wiring, including permanent synthetic NON-PARITY behavior.

The XCTest source is committed for canonical SwiftPM/Xcode execution. The Worker environment cannot perform the full Apple/integrated checkout build, so that execution remains an HQ Late Integration gate.

## Runbook

`Analysis/benchmarks/REAL_AUDIO_BENCHMARK_RUNBOOK.md` now designates `runProductAligned` as the canonical path for new differential evidence and documents evaluator overflow/cancellation behavior.

## PARITY status

**NON_PARITY.** W16 only makes the evidence path scalable, product-aligned, cancellable, and less capable of producing misleading scores from pathological cardinality.

MOI-P009 / P011 / P013 / P016 / P021 remain MISSING until HQ Late Integration supplies and executes the remaining gates, including:

- rights-cleared multi-genre real audio;
- current-iPhone Moises differential;
- current reference vocabulary/behavior verification where required;
- integrated Section navigation/loop evidence;
- physical-iPhone peak RSS / responsiveness / thermal / battery evidence;
- canonical integrated SwiftPM/Xcode execution with the concrete Lane-2 benchmark signal loader.

Synthetic/portable matcher timing and complexity evidence must not promote PARITY.
