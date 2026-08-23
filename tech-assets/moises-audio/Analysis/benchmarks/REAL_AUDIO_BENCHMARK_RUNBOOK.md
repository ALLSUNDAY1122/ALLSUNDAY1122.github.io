# Lane 4 Real-Audio MIR Benchmark Runbook

Purpose: make MOI-P009 / P011 / P013 / P016 measurable from rights-cleared audio without allowing synthetic, unverified, expired-rights, checksum-mismatched, evaluator-overflow, or non-product analysis paths to become PARITY evidence.

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

## Canonical W16 execution path

Use:

```swift
try await AnalysisRealAudioBenchmarkRunner.runProductAligned(...)
```

for all new differential evidence.

`runProductAligned` executes the same current Lane-4 product stages used by `ProjectOwnedMusicAnalyzer`:

1. bounded/cancellable working-set preparation;
2. bounded Tempo/Beat analysis;
3. bounded Key analysis;
4. bounded Chord analysis;
5. W13 cancellable Section detection;
6. W14 Section boundary over-segmentation hardening;
7. W15 cancellable/cardinality-safe final `AnalysisSnapshot` publication;
8. W16 scalable/cancellable metric evaluation.

The older `AnalysisRealAudioBenchmarkRunner.run` entry point is retained only for compatibility with pre-W16 evidence/tests. Do not use it for new PARITY evidence because it does not guarantee the complete current product Analysis path.

## W16 evaluator behavior

- beat one-to-one matching preserves the prior greedy-nearest semantics but uses an ordered availability index instead of all-pairs rescanning;
- beat/chord/section nearest-boundary errors use sorted binary-search nearest queries;
- chord interval comparison advances timeline cursors instead of rescanning every event for every interval;
- section sample lookup advances monotonic cursors;
- duration-aware evaluator cardinality limits are derived from the W15 publication policy;
- evaluator cardinality overflow fails closed: the affected row becomes `parity_eligible=false` and carries an explicit `EVALUATOR_*_CARDINALITY_REJECTED_NOT_PARITY_EVIDENCE` limitation;
- no metric array is silently truncated to manufacture an accuracy score.

Every W16 product-aligned row includes W15 snapshot cardinality diagnostics. Structure rows additionally include W14 before/after section-fragmentation diagnostics. These diagnostic values describe integrity/performance context; they are not accuracy or PARITY proof by themselves.

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

`SYNTHETIC_TEST` always remains non-PARITY, even when every metric is perfect.

## Outputs

`AnalysisRealAudioBenchmarkRunner.runProductAligned` produces:

- one row per available tempo / beat / key / chord domain;
- one section row when section ground truth exists;
- W15 snapshot cardinality diagnostics on every row;
- W14 section-fragmentation diagnostics on the structure row;
- W16 evaluator acceptance/limit metrics;
- per-domain aggregate mean metrics;
- fixture and parity-eligible counts;
- machine-readable report metadata.

Use `AnalysisRealAudioBenchmarkCodec` for ISO-8601, sorted-key JSON manifest/report serialization.

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
