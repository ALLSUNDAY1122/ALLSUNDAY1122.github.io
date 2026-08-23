# L4-W18 Validation — Paired Moises Differential Comparator / Non-Inferiority Gate Hardening

## Scope

Worker 4 owns Analysis benchmark/evidence code. W18 hardens the future HQ Project-vs-current-iPhone-Moises differential gate without changing frozen `Shared/**`, root `App/**`, or `PARITY_MATRIX.json`.

W18 is an **evidence-integrity** wave. It does not provide current-Moises measurements, real-audio quality proof, iPhone performance proof, or production tolerance values.

## Problem before W18

W17 made one Analysis report auditable and anti-masking, but there was no machine-enforced rule requiring the Project report and Moises Reference report to use:

- the same fixture corpus;
- the same domains;
- the same quality metrics;
- the same metric direction;
- a complete externally approved tolerance profile.

A manual reviewer could therefore accidentally or deliberately:

- remove a weak Project fixture;
- compare different fixture sets;
- omit an unfavorable metric from the tolerance sheet;
- interpret a lower-is-better error metric backwards;
- compare the wrong engines;
- treat synthetic comparison evidence as if it were PARITY evidence.

## Production implementation

Added:

`Analysis/AnalysisBenchmarkDifferential.swift`

Main entry point:

```swift
AnalysisPairedDifferentialComparator.compare(
    project: projectAuditedReport,
    reference: currentMoisesAuditedReport,
    profile: hqApprovedToleranceProfile
)
```

The comparator never writes `PARITY` and never updates `PARITY_MATRIX.json`.

## Pair identity and corpus integrity

Rows are indexed by exact:

`fixtureID + domain`

Fail-closed issues are emitted for:

- duplicate Project rows;
- duplicate Reference rows;
- Project-only rows;
- Reference-only rows;
- manifest mismatch;
- genre/duration/rights/synthetic metadata mismatch;
- validation issues in either audited report;
- evaluator rejection on either side.

Duration equality uses <= 1 ms only as an identity tolerance; this is not a quality/non-inferiority threshold.

## Metric integrity

Only W17 `AnalysisBenchmarkAggregation.metricDirections` quality metrics are paired.

For every quality metric observed on either side:

1. both Project and Reference finite values must exist;
2. an exact `domain + metric` tolerance rule must exist;
3. profile rules marked `required=true` must occur in the paired corpus.

This means an unfavorable metric cannot be hidden by simply removing it from the tolerance profile.

Context metrics and diagnostics remain excluded from quality comparison.

## Direction normalization

Higher-is-better:

`quality_delta = project - reference`

Lower-is-better:

`quality_delta = reference - project`

Thus positive always means better for the Project.

`regression = max(0, -quality_delta)`

A pair is inside margin only when the externally supplied:

`regression <= maximumRegression`

No production `maximumRegression` values are defined by Worker 4.

## Tolerance profile safety

`AnalysisDifferentialToleranceProfile` requires:

- schema version 1;
- non-empty profile ID;
- `authority == HQ_LATE_INTEGRATION`;
- non-empty durable approval reference;
- distinct expected Project/Reference engine IDs;
- at least one rule;
- W17-known metric names only;
- finite non-negative regression margins;
- no duplicate `domain + metric` rules.

`Analysis/benchmarks/DIFFERENTIAL_TOLERANCE_PROFILE_TEMPLATE.json` intentionally has an empty `rules` array and therefore fails validation until HQ supplies an actual approved profile. It is a shape template, not an approval or default threshold set.

## Output states

- `INVALID_PROFILE`
- `INCOMPLETE_PAIRING`
- `OUTSIDE_SUPPLIED_TOLERANCE`
- `WITHIN_TOLERANCE_NON_PARITY_EVIDENCE`
- `WITHIN_SUPPLIED_TOLERANCE_PENDING_HQ`

The strongest Worker-4 comparator result explicitly remains pending HQ. `finalParityAuthority` is fixed to `HQ_LATE_INTEGRATION`.

## Provenance behavior

Each metric pair retains:

- fixture ID;
- domain;
- genre;
- Project/Reference values;
- direction;
- signed quality delta;
- regression;
- supplied maximum regression;
- within-tolerance decision;
- whether the pair is real/non-synthetic PARITY-candidate evidence.

The report also preserves Project/Reference engine, engine version, manifest ID and generation timestamp.

## Anti-masking summary

Per `domain + metric`, W18 stores:

- total pair count;
- PARITY-candidate pair count;
- failed pair count;
- supplied maximum regression;
- worst-regression fixture and genre.

A favorable mean therefore cannot hide a catastrophic paired fixture.

## Canonical XCTest source

Added:

`Tests/MoisesAudioCoreTests/AnalysisBenchmarkDifferentialTests.swift`

It covers:

1. higher-is-better within supplied margin;
2. lower-is-better direction normalization;
3. outside-margin worst fixture;
4. cherry-picked missing Project row;
5. one-sided metric;
6. omitted unfavorable tolerance rule;
7. required profile metric absent;
8. synthetic within-margin remains non-PARITY evidence;
9. wrong authority and engine swap;
10. duplicate row and metadata mismatch;
11. tolerance-profile and paired-report JSON round-trip.

Canonical SwiftPM/Xcode XCTest execution remains an HQ integrated-checkout gate.

## Portable Swift 6.2.1 evidence

Environment:

- Swift 6.2.1
- x86_64 Linux
- optimized `swiftc -O`

### Pairing / anti-cherry-pick harness

Five complete runs: **11/11 assertions PASS each**.

50,000 exact fixture pairs per run.

Internal elapsed seconds:

- 0.133332
- 0.239420
- 0.169821
- 0.151693
- 0.178003

Process wall seconds:

- 0.17
- 0.29
- 0.19
- 0.17
- 0.20

Max RSS kB:

- 72596
- 72556
- 72596
- 72600
- 72620

Assertions include higher/lower direction, row-set mismatch, one-sided metric, missing tolerance, synthetic non-candidate behavior, outside-margin behavior, required metric absence and 50k pairing correctness.

### Profile-validation harness

Five complete runs: **8/8 assertions PASS each**.

Verified fail-closed behavior for:

- Worker/self authority;
- missing approval reference;
- identical Project/Reference engine IDs;
- negative margin;
- unknown metric;
- duplicate rule;
- empty rule list.

Portable RSS was approximately 18.0–18.1 MB.

## Durable machine evidence

`Analysis/benchmarks/L4-W18_PAIRED_DIFFERENTIAL_GATE.json`

Evidence class is explicitly `NON_PARITY` and `synthetic_only=true`.

## Codec

`AnalysisRealAudioBenchmarkCodec` now supports sorted-key / ISO-8601 encode/decode for:

- `AnalysisDifferentialToleranceProfile`
- `AnalysisPairedDifferentialReport`

## Remaining external gates

W18 does not satisfy:

- MOI-P009 BPM;
- MOI-P011 Key;
- MOI-P013 Chord;
- MOI-P016 Song Section;
- MOI-P021 physical-device performance.

Still required at HQ Late Integration:

- rights-cleared multi-genre real audio;
- exact current-iPhone Moises reference capture;
- approved production tolerance profile;
- paired differential execution;
- physical-iPhone evidence;
- section navigation/loop integration for P016;
- final HQ PARITY judgment.

## Newly exposed gap

W18 makes reference provenance visible only through the audited report's engine, version and timestamp. There is still no dedicated machine-validated schema proving current-iPhone Moises capture context such as app/build version, device/OS, capture operator/run ID, source-manifest hash, repeated-capture consistency and observation method.

That reference-capture provenance/repeatability layer is the next high-value Analysis evidence-integrity target.
