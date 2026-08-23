# Lane 4 Paired Project-vs-Reference Differential Runbook

## Purpose

This runbook defines the W18 machine-enforced pairing gate for future HQ comparison of the Project Analysis implementation against the **current iPhone Moises reference**.

W18 does **not** define product-quality thresholds and does **not** declare PARITY. It prevents a later differential review from silently using different corpora, dropping weak fixtures, reversing metric direction, omitting unfavorable metrics, or self-approving a tolerance profile.

## Inputs

HQ Late Integration supplies all three inputs:

1. Project `AnalysisAuditedRealAudioBenchmarkReport` produced from the W17 audited path.
2. Reference `AnalysisAuditedRealAudioBenchmarkReport` representing current-iPhone Moises observations scored with the same fixture annotations and metric semantics.
3. `AnalysisDifferentialToleranceProfile` approved outside Worker 4.

The tolerance profile contains:

- `profileID`
- `authority == HQ_LATE_INTEGRATION`
- durable `approvalReference`
- approval timestamp
- expected Project engine identifier
- expected Reference engine identifier
- explicit `(domain, metric, maximumRegression, required)` rules

Worker 4 intentionally ships **no production maximum-regression numbers**.

## Exact pairing identity

Rows are paired by:

`fixture_id + domain`

The comparator then verifies paired row metadata:

- genre
- duration (identity tolerance only, <= 1 ms)
- rights class
- synthetic/non-synthetic provenance

Project-only or Reference-only rows fail the comparison. Duplicate `fixture_id + domain` rows also fail because the pairing becomes ambiguous.

This blocks the common cherry-pick failure mode where a difficult Reference fixture is simply absent from the Project report.

## Metric pairing

Within each paired row, W18 iterates the explicit W17 quality registry only.

Context/diagnostic values such as counts, limits, raw BPM, confidence, W14/W15 diagnostics, W16 pipeline flags, RSS or thermal metadata are not differential quality metrics.

For every quality metric that exists on either side:

- both Project and Reference must provide a finite value;
- an externally supplied tolerance rule must exist for that exact `domain + metric`;
- profile rules marked `required=true` must occur in the paired corpus.

A tolerance profile cannot make an unfavorable observed metric disappear by simply omitting its rule. Observed quality metrics without rules produce `MISSING_TOLERANCE_RULE` and the comparison is incomplete.

## Direction normalization

W18 uses the W17 quality registry as the sole direction source.

For `HIGHER_IS_BETTER` metrics:

`signed_quality_delta = project - reference`

For `LOWER_IS_BETTER` metrics:

`signed_quality_delta = reference - project`

Therefore a positive signed delta always means the Project result is better in the metric's intended direction.

`regression = max(0, -signed_quality_delta)`

A pair is inside the supplied margin only when:

`regression <= maximum_regression`

The comparator never guesses or derives `maximum_regression` itself.

## Evidence provenance

A metric pair is only marked `parityCandidateEvidence=true` when both paired rows are:

- metadata-compatible;
- evaluator-accepted;
- `parityEligible` on their audited reports;
- non-synthetic.

Synthetic fixtures may exercise the comparator and may be inside a supplied test margin, but remain `WITHIN_TOLERANCE_NON_PARITY_EVIDENCE`.

## Fail-closed issue classes

The report records machine-readable issues for:

- invalid or self-approved profile metadata;
- Project/Reference engine mismatch;
- manifest mismatch;
- validation issues in either audited report;
- duplicate rows;
- Project-only or Reference-only rows;
- paired-row metadata mismatch;
- evaluator rejection on either side;
- quality metric present on only one side;
- observed quality metric without a tolerance rule;
- required profile metric absent from the corpus.

## Output statuses

`INVALID_PROFILE`
: supplied profile is not acceptable for this gate or the selected engines do not match it.

`INCOMPLETE_PAIRING`
: same-corpus or metric pairing is incomplete. No differential quality conclusion is allowed.

`OUTSIDE_SUPPLIED_TOLERANCE`
: pairing is complete, but at least one paired quality value exceeds the supplied regression margin.

`WITHIN_TOLERANCE_NON_PARITY_EVIDENCE`
: pairing is complete and inside the supplied margin, but the inputs are not eligible real-audio PARITY-candidate evidence.

`WITHIN_SUPPLIED_TOLERANCE_PENDING_HQ`
: pairing is complete, all paired evidence is real/non-synthetic and eligible, and every compared metric is inside the supplied profile. **This still is not PARITY.** `finalParityAuthority` remains `HQ_LATE_INTEGRATION`.

## Anti-masking output

Every paired metric stores:

- fixture ID
- domain
- genre
- direction
- Project value
- Reference value
- signed quality delta
- regression
- supplied maximum regression
- within-tolerance result
- evidence eligibility

Per `domain + metric`, W18 also stores pair count, parity-candidate pair count, failed-pair count and the worst regression fixture. An aggregate mean cannot hide one catastrophic fixture.

## Reference capture requirement

The Reference audited report must be traceable to the current iPhone Moises build used by HQ. W18 currently preserves engine/version/timestamp provenance from the report, but it does not itself perform the iPhone capture or verify the authenticity of the external approval reference.

Those remain HQ Late Integration responsibilities.

## Required sequence for future HQ differential evidence

1. Freeze the rights-cleared corpus and manifest.
2. Produce the Project report with `runProductAlignedAudited`.
3. Capture current-iPhone Moises outputs against the exact same corpus and annotations.
4. Score/reference-encode them into the same audited row semantics.
5. Obtain an HQ-approved tolerance profile with a durable approval reference.
6. Run `AnalysisPairedDifferentialComparator.compare(...)`.
7. Preserve the paired report JSON and raw Project/Reference audited reports together.
8. Investigate every issue and every worst-regression fixture.
9. HQ performs the final PARITY judgment and updates `PARITY_MATRIX.json` only after all relevant product/device gates are also satisfied.

## NON-PARITY warning

W18 synthetic/unit/portable tests validate comparator integrity only. They do not establish MOI-P009, MOI-P011, MOI-P013, MOI-P016 or MOI-P021 PARITY.
