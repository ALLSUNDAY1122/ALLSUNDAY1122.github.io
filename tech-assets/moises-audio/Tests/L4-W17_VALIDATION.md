# L4-W17 Validation — Differential report aggregation / anti-masking hardening

Evidence class: **NON_PARITY**. This wave hardens benchmark-report integrity. It does not supply rights-cleared real audio, current-iPhone Moises differential evidence, or physical-iPhone performance evidence.

## Problem found after W16

The compatibility `AnalysisRealAudioBenchmarkReport.summaries` implementation averages every finite numeric field inside a domain. After W14–W16 added richer diagnostics, that means values such as raw predicted BPM, reference/estimated counts, cardinality limits and W14/W15 integrity diagnostics could receive semantically meaningless means.

A second problem is more important for PARITY review: an ordinary mean can hide one catastrophic fixture or genre. Synthetic perfect rows can also make an all-row mean look excellent even though they are not eligible for PARITY.

## W17 canonical report

New entry point:

```swift
try await AnalysisRealAudioBenchmarkRunner.runProductAlignedAudited(...)
```

The W17 audited report wraps the W16 product-aligned execution output but does **not** expose the legacy all-number domain means as authoritative evidence. It emits raw rows plus audited quality aggregation.

### Explicit metric classification

Only metrics with an explicit direction are aggregatable.

Higher-is-better examples:

- tempo exact/octave-aware accuracy;
- beat F;
- key accuracy / weighted key score;
- chord root / maj-min accuracy and no-chord precision/recall;
- structure boundary F / pairwise F / ARI / functional F / coverage;
- derived tempo/key decision rate.

Lower-is-better examples:

- tempo relative error;
- beat/chord boundary median errors;
- section boundary errors;
- clustering conditional entropy values.

Excluded from quality means while remaining on raw rows:

- predicted BPM;
- confidence;
- reference/estimated counts;
- evaluator/cardinality limits;
- W14 boundary-fragmentation diagnostics;
- W15 snapshot cardinality diagnostics;
- W16 pipeline/evaluator flags;
- other unclassified context values.

`excludedContextMetricNames` is written into the audited report so the exclusion is reviewable rather than implicit.

## Anti-masking rules

For each domain and each domain+genre scope, every quality metric records:

- `sampleCount`;
- `parityEligibleSampleCount`;
- `populationComplete`;
- `parityEligiblePopulationComplete`;
- all-accepted-row mean;
- PARITY-eligible mean;
- direction-aware worst fixture/value;
- PARITY-eligible worst fixture/value.

Evaluator-rejected rows (`evaluator_input_accepted < 0.5`) are excluded from quality means and listed under `evaluatorRejectedRows`.

Rows with `parityEligible == false`, including synthetic rows, are listed under `nonParityRows` and cannot improve `parityEligibleMean` or `parityEligibleWorst`.

Tempo/key decision rate is derived as 1 when a normal decision metric is present and uses explicit `decision_emitted=0` on unknown output. This prevents excellent error metrics on only the decided subset from hiding a high unknown/refusal rate. Metrics whose values do not exist for every accepted row expose `populationComplete=false`.

## Portable validation

Swift: 6.2.1, x86_64 Linux.

Production-source-shaped checks:

- `AnalysisBenchmarkAggregation.swift`: typecheck PASS.
- audited report additions to `RealAudioBenchmarkCodec.swift`: typecheck PASS.

Optimized portable aggregation harness, five complete runs:

- 10/10 assertions PASS each run.
- 50,000 rows.
- 2 domain scopes.
- 20 domain+genre scopes.
- internal aggregation elapsed: 0.902982171, 0.897158589, 0.876449709, 0.897563405, 0.892873681 seconds.
- process wall: 0.95, 0.94, 0.92, 0.95, 0.94 seconds.
- max RSS kB: 69,800; 69,724; 69,716; 69,672; 69,724.

These are portable report-processing measurements only, not iPhone performance claims.

## Adversarial results

### Mean hides one catastrophic fixture

1,000 PARITY-eligible tempo rows were modeled: 999 exact successes and one exact failure.

- ordinary mean `exact_within_4pct`: 0.999.
- W17 worst fixture: `live-catastrophe`.
- W17 worst value: 0.0.
- `live` genre mean: 0.0.

Result: PASS. A reviewer cannot see only 99.9% and miss the catastrophic live fixture.

### Synthetic inflation

1,000 synthetic perfect key rows plus one real weak key row:

- all accepted mean exact key accuracy: 0.999000999000999.
- PARITY-eligible mean: 0.0.
- PARITY-eligible worst fixture: `real-weak`.

Result: PASS. Synthetic regression fixtures do not improve the PARITY aggregate.

### Evaluator rejection

One accepted beat row with F=0.2 plus one cardinality-rejected row carrying a nominal F=1.0:

- audited beat mean: 0.2.
- evaluator rejected row count: 1.
- rejected row is listed with its limitation.

Result: PASS. A rejected row cannot improve the quality mean.

### Decision population

One successful tempo decision plus one unknown tempo row:

- decision rate: 0.5.
- decision population complete: true.
- tempo-error population complete: false because the unknown row has no numeric tempo error.

Result: PASS. Decided-subset quality cannot silently masquerade as complete population quality.

## Durable tests added

`AnalysisBenchmarkAggregationTests.swift` covers:

- context/diagnostic metrics excluded from means;
- domain mean plus direction-aware worst fixture;
- genre-level visibility;
- synthetic-vs-PARITY mean separation;
- evaluator-rejected row exclusion/listing;
- tempo/key decision-rate population semantics;
- audited product runner synthetic end-to-end behavior;
- audited report Codable round-trip.

`RealAudioBenchmarkCodecTests.swift` now covers deterministic sorted-key ISO-8601 audited-report encode/decode.

Canonical full SwiftPM/Xcode XCTest execution is not available in this Worker environment and remains an HQ integrated-checkout gate.

## PARITY impact

No PARITY row is promoted by W17.

- MOI-P009 remains MISSING: rights-cleared multi-genre real audio, current-iPhone Moises differential and physical-iPhone evidence remain required.
- MOI-P011 remains MISSING for the corresponding key benchmark gates.
- MOI-P013 remains MISSING for chord vocabulary/reference and real-audio timestamp differential.
- MOI-P016 remains MISSING for varied real structures plus navigation/loop and current-iPhone differential evidence.
- MOI-P021 remains MISSING for physical-device memory/thermal/battery evidence.

W17 makes future evidence harder to misread; it does not substitute for the missing evidence itself.
