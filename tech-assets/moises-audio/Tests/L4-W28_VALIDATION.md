# L4-W28 Validation — Long-audio bounded-memory Analysis pipeline

Date: 2026-08-24 JST

Evidence class: **NON_PARITY_SYNTHETIC_PORTABLE**.

## Scope

W28 returns from evidence-chain hardening to MOI-P021 product memory engineering. It removes the additional whole-track 8 kHz prepared Float array from `ProjectOwnedMusicAnalyzer` and replaces it with bounded prepared-sample access plus feature buffers.

Production additions:

- `AnalysisPreparedSampleReader.swift`
- `AnalysisBoundedMemoryBudget.swift`
- `StreamingBoundedTempoBeatAnalyzer.swift`
- `StreamingBoundedMusicalKeyAnalyzer.swift`
- `StreamingBoundedChordTimelineAnalyzer.swift`

Production route changed:

- `AnalysisSignal.swift` / `ProjectOwnedMusicAnalyzer`
- `Package.swift`

The legacy W11 materialized preparation API remains available for compatibility/regression evidence.

## Correctness design

`AnalysisPreparedSampleReader` reproduces the W11 prepared sample definition lazily:

- same target `min(sourceRate, 8 kHz)`;
- same `sourceRate > target * 1.05` resampling decision;
- same output sample count rounding;
- same source-block start/end floor rules;
- same finite/±16 sanitization;
- same block-average Float result.

It caches only two 16,384-sample prepared blocks by default.

Tempo/Key/Chord streaming analyzers copy the existing bounded product algorithms but fetch prepared samples through that reader. W15 final publication/cardinality hardening remains unchanged.

Section harmonic evidence continues to come from the bounded chord timeline. Section dynamics use a 100 Hz RMS energy feature signal with the exact prepared duration. This feature is purpose-specific; Tempo/Key/Chord sample rate is not lowered for W28.

## Source-shaped compilation

Swift 6.2.1 x86_64 Linux:

- four W28 streaming/reader production sources: PASS;
- `AnalysisBoundedMemoryBudget`: PASS;
- reconstructed product actor route with strict concurrency + warnings-as-errors: PASS;
- durable XCTest source parse: PASS.

Full canonical SwiftPM/Xcode XCTest remains an HQ integrated-checkout gate because the Worker environment is not the canonical Apple checkout.

## Portable adversarial harness

Five clean optimized runs.

Every run: **25/25 assertions PASS**.

Validated:

1. lazy resampled reader samples exactly equal the materialized W11 preparation, including NaN/infinity/out-of-range sanitization;
2. non-resampled sanitization semantics remain exact;
3. random cross-block access returns exact prepared values;
4. streaming Tempo is identical when fed the original 44.1 kHz source versus its materialized prepared signal;
5. streaming Key is identical under the same comparison;
6. Section energy feature preserves exact duration and deterministic low/high energy steps;
7. pre-cancelled feature extraction throws `CancellationError`;
8. one-hour and twenty-four-hour analytical memory budgets are deterministic.

Harness process results:

| Run | Assertions | Wall s | Max RSS KB |
|---|---:|---:|---:|
| 1 | 25/25 | 0.06 | 23,532 |
| 2 | 25/25 | 0.06 | 23,548 |
| 3 | 25/25 | 0.05 | 23,572 |
| 4 | 25/25 | 0.06 | 23,552 |
| 5 | 25/25 | 0.05 | 23,664 |

These RSS values describe the small portable harness, not a long-track iPhone run.

## Working-set budget

For one hour of 44.1 kHz mono Float source:

- loader-owned source PCM: **635,040,000 bytes**;
- previous additional whole-track 8 kHz prepared PCM: **115,200,000 bytes**;
- W28 prepared reader two-block cache upper bound: **131,072 bytes**;
- W28 100 Hz Section energy feature: **1,440,000 bytes**;
- conservative major Worker-4 additional buffers including Tempo onset + median scratch, Key window, Chord decisions and Section structural scratch: **10,366,272 bytes**;
- old prepared PCM / W28 major additional estimate: **11.112963x**.

For 24 hours:

- avoided whole-track prepared PCM: **2,764,800,000 bytes**;
- estimated major Worker-4 additional buffers: **197,163,072 bytes**;
- ratio: **14.022910x**.

This is an analytical buffer budget, not process RSS. The source buffer remains deliberately visible and unsolved.

## CPU / thermal negative finding

A bounded reader can recompute prepared blocks after a stage restarts from the beginning. A 120-second synthetic microbenchmark compared one materialization pass with three full bounded-reader passes.

Materialize seconds:

- 0.018343
- 0.018288
- 0.017039
- 0.015062
- 0.015155

Three-pass bounded reader seconds:

- 0.069176
- 0.060412
- 0.060521
- 0.054886
- 0.133739

Ratios:

- 3.771x
- 3.303x
- 3.552x
- 3.644x
- 8.825x

Median ratio: **3.644x**. Worst observed ratio: **8.825x**.

This is intentionally recorded rather than masked. It is not the full analyzer wall-time ratio, but it shows that memory savings can increase resampling/read CPU. Therefore W28 does **not** close P021. A follow-up should share/single-pass feature extraction to avoid repeated prepared-block computation before HQ physical thermal/battery acceptance.

## Durable XCTest

`AnalysisBoundedMemoryPipelineTests.swift` covers:

- every-sample equality against legacy materialized preparation for high-rate pathological input;
- no-resample equality;
- legacy Bounded Tempo equivalence;
- legacy Bounded Key equivalence;
- legacy Bounded Chord Timeline equivalence;
- deterministic Section boundary fixture equivalence using the energy feature;
- one-hour budget;
- 24-hour budget;
- cooperative pre-cancellation.

## Remote read-back

Confirmed on `moises/wp4-analysis-platform`:

- new W28 sources are registered in `Package.swift`;
- `ProjectOwnedMusicAnalyzer` uses `AnalysisPreparedSampleReader` and streaming Tempo/Key/Chord;
- Section uses the bounded RMS feature before existing Section hardening;
- final W15 snapshot hardening remains in the publication path.

## Remaining gates

`MOI-P021` remains **MISSING** because:

- no integrated physical iPhone W28 run has occurred;
- HQ production memory/thermal/battery/wall/cancellation thresholds have not been applied;
- source-loader whole-track PCM remains possible;
- repeated prepared-block recomputation can increase CPU/thermal load;
- real-audio Analysis output equivalence remains an HQ differential gate.

`MOI-P009`, `MOI-P011`, `MOI-P013` and `MOI-P016` likewise remain MISSING until rights-cleared current-Moises/Project real-audio differential evidence is completed.

W28 makes no PARITY claim and does not edit `PARITY_MATRIX.json`.
