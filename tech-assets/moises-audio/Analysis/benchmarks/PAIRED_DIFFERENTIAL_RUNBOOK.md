# Lane 4 Paired Project-vs-Reference Differential Runbook

## Purpose

This runbook defines the W18 machine-enforced pairing gate for future HQ comparison of the Project Analysis implementation against the **current iPhone Moises reference**.

W18 does not define product-quality thresholds and does not declare PARITY. W19 additionally hardens the Reference side so an unproven/stale/manual one-off Moises report cannot silently become the comparator baseline.

## Canonical inputs after W19

HQ Late Integration supplies all three inputs:

1. Project `AnalysisAuditedRealAudioBenchmarkReport` produced from the W17 audited path.
2. Reference `AnalysisAuditedRealAudioBenchmarkReport` produced **only after** a W19 `AnalysisReferenceCaptureSet` passes `AnalysisReferenceCaptureValidator` under an HQ-approved `AnalysisReferenceCapturePolicy`, then is compiled with `compileAuditedReferenceReport(...)`.
3. `AnalysisDifferentialToleranceProfile` approved outside Worker 4.

The W19 capture set, W19 validation report, exact source manifest and all SHA-bound evidence artifacts must be archived beside the compiled Reference report. The compiled median report alone is insufficient provenance.

The W18 tolerance profile contains a durable HQ approval reference, expected Project/Reference engines, and explicit `(domain, metric, maximumRegression, required)` rules. Worker 4 ships no production maximum-regression numbers.

## Exact pairing identity

Rows are paired by `fixture_id + domain` and then checked for compatible genre, duration (identity tolerance <=1 ms), rights class and synthetic provenance.

Project-only, Reference-only or duplicate rows fail. This blocks dropping a difficult fixture from one side.

## Metric pairing

Within each paired row, W18 uses the W17 quality registry only. Context fields such as counts, limits, raw BPM, confidence, W14/W15 diagnostics, RSS and thermal metadata are not differential quality metrics.

Every observed quality metric must exist on both sides and have an externally supplied tolerance rule for the exact `domain + metric`. Required profile metrics must occur in the corpus. Omitting an unfavorable observed metric from the profile produces `MISSING_TOLERANCE_RULE` rather than hiding it.

## Direction normalization

For `HIGHER_IS_BETTER`:

`signed_quality_delta = project - reference`

For `LOWER_IS_BETTER`:

`signed_quality_delta = reference - project`

Therefore positive always means Project-favorable.

`regression = max(0, -signed_quality_delta)`

A pair is inside the supplied margin only when `regression <= maximum_regression`. W18 never guesses the margin.

## W19 Reference provenance prerequisite

Before a Reference report is admitted to W18, W19 requires an HQ policy that binds:

- current Reference epoch;
- Moises product/app/build version;
- exact iPhone model and iOS version;
- locale and account tier;
- exact rights-cleared source manifest ID and SHA-256;
- at least two repeated capture runs;
- HQ-supplied repeatability spread rules for all captured W17 quality metrics.

Every run also records operator identity, observation method, SHA-bound evidence artifacts and the complete fixture/domain/metric set.

W19 fails closed on stale/future capture, mixed build/device/OS/tier/corpus, row or metric cherry-picking, synthetic rows, missing artifact bindings, missing repeatability rules or excessive repeated-observation spread.

Only `STABLE_REFERENCE_CAPTURE_PENDING_HQ` may be compiled into the Reference audited report. That status is not PARITY.

See `REFERENCE_CAPTURE_RUNBOOK.md` for the complete capture/provenance procedure.

## Evidence eligibility

A W18 metric pair is `parityCandidateEvidence=true` only when both rows are metadata-compatible, evaluator-accepted, audited-report eligible and non-synthetic. W19 provenance validation is an additional prerequisite on the Reference side.

Synthetic/unit fixtures may exercise W18/W19 but cannot become PARITY evidence.

## W18 output statuses

- `INVALID_PROFILE`: profile/engine metadata invalid.
- `INCOMPLETE_PAIRING`: same-corpus or metric pairing incomplete.
- `OUTSIDE_SUPPLIED_TOLERANCE`: at least one paired quality regression exceeds the supplied margin.
- `WITHIN_TOLERANCE_NON_PARITY_EVIDENCE`: inside margins, but evidence is not eligible real-audio PARITY-candidate evidence.
- `WITHIN_SUPPLIED_TOLERANCE_PENDING_HQ`: all paired evidence is eligible and inside supplied margins. **Still not PARITY.** Final authority remains `HQ_LATE_INTEGRATION`.

## Anti-masking output

Every paired metric stores fixture/domain/genre, direction, both values, signed delta, regression, supplied maximum regression, within-tolerance result and evidence eligibility. Per domain+metric, the report stores counts and the worst regression fixture so an aggregate mean cannot hide a catastrophic case.

## Required HQ sequence after W19

1. Freeze the rights-cleared corpus and exact manifest bytes.
2. Hash those exact bytes and approve the W19 Reference capture policy for the current Moises app/build/device/iOS/tier epoch.
3. Produce the Project report with `runProductAlignedAudited`.
4. Perform the required repeated current-iPhone Moises capture runs against the exact same corpus.
5. Validate the full W19 capture set and archive every SHA-bound evidence artifact.
6. Compile the W19 capture set into the audited Reference report only if comparison-ready.
7. Obtain a separate HQ-approved W18 non-inferiority tolerance profile.
8. Run `AnalysisPairedDifferentialComparator.compare(...)`.
9. Preserve Project report, W19 policy/capture/validation/artifacts, compiled Reference report, W18 tolerance profile and paired differential report together.
10. Investigate every issue, repeatability excursion and worst-regression fixture.
11. HQ performs final PARITY judgment and updates `PARITY_MATRIX.json` only after all relevant product/device gates are also satisfied.

## NON-PARITY warning

W18/W19 portable tests validate comparator and Reference-capture integrity only. They do not establish MOI-P009, MOI-P011, MOI-P013, MOI-P016 or MOI-P021 PARITY.
