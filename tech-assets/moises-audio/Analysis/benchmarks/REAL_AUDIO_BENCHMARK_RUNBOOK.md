# Lane 4 Real-Audio MIR Benchmark Runbook

Purpose: make MOI-P009 / P011 / P013 / P016 measurable from rights-cleared audio without allowing synthetic, unverified, expired-rights, or checksum-mismatched material to become PARITY evidence.

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
- non-finite decoded PCM.

## PARITY eligibility

A case is eligible only when:

- `sourceKind == REAL_AUDIO`;
- all manifest validation gates pass;
- the loaded source checksum matches the manifest;
- the existing benchmark rows are themselves parity-eligible.

`SYNTHETIC_TEST` always remains non-PARITY, even when every metric is perfect.

## Outputs

`AnalysisRealAudioBenchmarkRunner.run` produces:

- one row per available tempo / beat / key / chord domain;
- one section row when section ground truth exists;
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
