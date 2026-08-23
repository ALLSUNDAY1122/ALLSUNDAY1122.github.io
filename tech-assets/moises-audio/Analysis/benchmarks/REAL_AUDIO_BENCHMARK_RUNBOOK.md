# Lane 4 Real-Audio MIR Benchmark Runbook

Purpose: make MOI-P009 / P011 / P013 / P016 measurable from rights-cleared audio without allowing synthetic, unverified, expired-rights, checksum-mismatched, evaluator-overflow, non-product analysis paths, or misleading aggregate means to become PARITY evidence.

## Inputs

1. App-owned audio file under a relative path.
2. Stable projectID and assetID UUID values.
3. Rights grant identifier and rights class.
4. `ANALYSIS_BENCHMARK` explicitly present in permittedUses.
5. Rights expiry, when applicable, later than the run date.
6. SHA-256 of the exact source file.
7. Expected duration.
8. Ground truth for one or more domains: tempo, beats, key, chords, sections.

Use `GOLDEN_MIR_MANIFEST_TEMPLATE.json` only as a shape template. Its placeholder SHA is intentionally invalid and must not pass validation.

## Loader contract

HQ/integration supplies an `AnalysisBenchmarkSignalLoading` adapter. It must:

- resolve only app-owned relative paths;
- decode the exact source represented by the manifest;
- compute or otherwise securely obtain the source-file SHA-256;
- return the decoded `AnalysisSignal` plus that SHA-256.

The runner compares the returned checksum to the rights evidence before analysis. A mismatch aborts the run.

## Canonical W17 execution and report path

Use:

```swift
try await AnalysisRealAudioBenchmarkRunner.runProductAlignedAudited(...)
```

for all new differential evidence.

`runProductAlignedAudited` executes the W16 product-aligned Analysis pipeline, then applies W17 anti-masking aggregation:

1. bounded/cancellable working-set preparation;
2. bounded Tempo/Beat analysis;
3. bounded Key analysis;
4. bounded Chord analysis;
5. W13 cancellable Section detection;
6. W14 Section boundary over-segmentation hardening;
7. W15 cancellable/cardinality-safe final `AnalysisSnapshot` publication;
8. W16 scalable/cancellable metric evaluation;
9. W17 audited quality aggregation with genre and worst-fixture visibility.

The older `AnalysisRealAudioBenchmarkRunner.run` and W16 `runProductAligned` entry points remain for compatibility with prior evidence/tests. Do not use either entry point as the final report for new PARITY evidence; W17 `runProductAlignedAudited` is the canonical report path.

## W16 evaluator behavior

- beat one-to-one matching preserves the prior greedy-nearest semantics but uses an ordered availability index instead of all-pairs rescanning;
- beat/chord/section nearest-boundary errors use sorted binary-search nearest queries;
- chord interval comparison advances timeline cursors instead of rescanning every event for every interval;
- section sample lookup advances monotonic cursors;
- duration-aware evaluator cardinality limits are derived from the W15 publication policy;
- evaluator cardinality overflow fails closed: the affected row becomes `parity_eligible=false` and carries an explicit `EVALUATOR_*_CARDINALITY_REJECTED_NOT_PARITY_EVIDENCE` limitation;
- no metric array is silently truncated to manufacture an accuracy score.

Every W16/W17 product-aligned row includes W15 snapshot cardinality diagnostics. Structure rows additionally include W14 before/after section-fragmentation diagnostics. These diagnostic values describe integrity/performance context; they are not accuracy or PARITY proof by themselves.

## W17 aggregation integrity

W17 does not average every finite number in a benchmark row.

Only metrics with an explicit quality direction are aggregatable. Examples include:

- higher-is-better accuracy/coverage/F metrics;
- lower-is-better tempo and boundary errors;
- derived tempo/key decision rate.

The following remain raw row context and are intentionally excluded from quality means:

- reference/estimated counts;
- evaluator and snapshot cardinality limits;
- raw predicted BPM;
- confidence values;
- W14 boundary-fragmentation diagnostics;
- W15 snapshot cardinality diagnostics;
- W16 pipeline/evaluator flags;
- runtime/context values without a defined quality direction.

The audited report provides both domain-level and domain+genre quality summaries. Every quality metric records:

- sample count;
- parity-eligible sample count;
- whether the metric population is complete for the scope;
- ordinary mean for all evaluator-accepted rows;
- PARITY-eligible mean using only `row.parityEligible == true` rows;
- worst fixture/value with direction-aware ordering;
- PARITY-eligible worst fixture/value.

This prevents a high overall mean from hiding one weak genre or fixture. Synthetic rows can remain useful for regression analysis but cannot improve `parityEligibleMean` or `parityEligibleWorst`.

Rows rejected by W16 evaluator cardinality gates are excluded from quality means and are listed explicitly under `evaluatorRejectedRows`; they cannot contribute a perfect-looking score. All rows with `parityEligible == false` are separately listed under `nonParityRows` with their limitations.

`excludedContextMetricNames` is emitted so reviewers can verify which raw metrics were deliberately not aggregated.

## Fail-closed gates

The manifest is rejected for:

- unsupported schema;
- empty/duplicate fixture IDs;
- unsafe or traversal paths;
- invalid duration;
- missing rights grant;
- benchmark use not explicitly permitted;
- expired rights grant;
- invalid source SHA-256;
- no reference domain;
- invalid BPM;
- beat timestamps outside duration or not strictly increasing;
- chord intervals outside duration or overlapping;
- sections outside duration, overlapping/gapped, or not covering the full track.

The batch runner additionally aborts for:

- source checksum mismatch;
- decoded duration mismatch beyond max(50 ms, 0.1%);
- non-finite decoded PCM;
- task cancellation.

The evaluator additionally fails the affected domain closed when reference or estimate cardinality exceeds its duration-aware safety limit.

## PARITY eligibility

A case is eligible only when:

- `sourceKind == REAL_AUDIO`;
- all manifest validation gates pass;
- the loaded source checksum matches the manifest;
- the current product-aligned Analysis path completed without cancellation/failure;
- evaluator inputs remain within cardinality safety limits;
- the produced benchmark rows are themselves parity-eligible.

The audited report itself is `parityEligible` only when the underlying product-aligned report is eligible and no evaluator-rejected row exists.

`SYNTHETIC_TEST` always remains non-PARITY, even when every metric is perfect.

## Outputs

`AnalysisRealAudioBenchmarkRunner.runProductAlignedAudited` produces:

- every raw tempo / beat / key / chord / structure row;
- W15 snapshot cardinality diagnostics on raw rows;
- W14 section-fragmentation diagnostics on structure rows;
- W16 evaluator acceptance/limit metrics on raw rows;
- W17 domain quality summaries;
- W17 domain+genre quality summaries;
- direction-aware worst-fixture evidence;
- evaluator-rejected row list;
- non-PARITY row list;
- excluded context-metric name list;
- machine-readable report metadata and validation issues.

The W17 audited report is directly `Codable`; use sorted-key / ISO-8601 encoding in the evidence writer used by HQ integration. The existing `AnalysisRealAudioBenchmarkCodec` remains valid for the legacy W16 report shape.

## Required Golden MIR coverage before HQ PARITY judgment

The final corpus should contain multiple genres and difficult cases rather than only clean studio pop. At minimum include:

- clear studio percussion;
- weak/no percussion;
- live tempo drift;
- syncopation;
- half/double-tempo ambiguity;
- major/minor and relative-key ambiguity;
- modal or key-changing material if current reference requires it;
- simple and rapid chord changes;
- no-chord regions;
- repeated and non-standard song structures.

Actual corpus selection, rights clearance, physical-device measurement, and current-Moises differential remain HQ gates.
