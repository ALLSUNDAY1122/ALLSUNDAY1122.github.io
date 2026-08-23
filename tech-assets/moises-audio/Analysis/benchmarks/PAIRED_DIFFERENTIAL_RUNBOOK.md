# Lane 4 Paired Project-vs-Reference Differential Runbook

## Purpose

This runbook defines the W18 machine-enforced pairing gate for future HQ comparison of the Project Analysis implementation against the **current iPhone Moises reference**.

W18 does not define product-quality thresholds and does not declare PARITY. W19-W22 harden the Reference/corpus evidence chain so stale capture, manual metric math, transcription error, copied review and trivial/biased corpora cannot silently become the comparator baseline.

## Canonical inputs after W22

HQ Late Integration supplies:

1. Project `AnalysisAuditedRealAudioBenchmarkReport` produced from the W17 audited path.
2. Reference `AnalysisAuditedRealAudioBenchmarkReport` produced only through the W21 -> W20 -> W19 chain from current-iPhone evidence.
3. `AnalysisDifferentialToleranceProfile` approved outside Worker 4.
4. W22 `AnalysisCorpusCoverageReport` for the exact manifest, with `comparisonCorpusReady == true` under an HQ-approved `AnalysisCorpusCoveragePolicy`.

The exact source manifest bytes/hash, W22 policy/report, W19 capture set/policy/validation, W21 review set/policy/report, W20 raw derivation, all SHA-bound evidence artifacts and both audited reports must be archived together. A compiled median Reference report alone is insufficient provenance.

The W18 tolerance profile contains a durable HQ approval reference, expected Project/Reference engines, and explicit `(domain, metric, maximumRegression, required)` rules. Worker 4 ships no production maximum-regression numbers.

## W22 corpus sufficiency prerequisite

Before any expensive current-iPhone Reference capture is accepted for final differential use, run:

```swift
let coverage = AnalysisCorpusCoverageValidator.validate(
    manifest: goldenManifest,
    manifestSHA256: exactManifestSHA256,
    policy: hqApprovedCoveragePolicy
)
```

W22 requires the policy to bind the exact manifest ID/SHA and define positive global minimums plus minimum count/duration for all five Analysis domains: `tempo`, `beat`, `key`, `chord`, `structure`.

HQ also supplies semantic strata. W22 derives their membership from Golden annotations rather than manual tags. Supported dimensions include genre, tempo bands, key mode, canonical chord quality, inversion, no-chord, chord-label diversity, section count/diversity, functional labels and repeated structural labels.

Synthetic fixtures and fixtures without `DIFFERENTIAL_REFERENCE` rights cannot pad coverage. Missing/duplicate domain definitions, duplicate strata, underfilled strata and corpus swaps fail closed.

Only `SUFFICIENT_CORPUS_PENDING_HQ` may proceed as the final comparison corpus. This is an evidence-sufficiency state, not PARITY. See `ANALYSIS_CORPUS_COVERAGE_RUNBOOK.md`.

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

## W19-W21 Reference integrity prerequisites

W19 requires an HQ capture policy binding current Reference epoch, Moises app/build, exact iPhone/iOS, locale/tier and exact source manifest. It requires repeated runs and SHA-bound artifacts and fails closed on stale/mixed/cherry-picked captures.

W21 sits before W20 for human-transcribed observations. Every raw claim must be bound to an artifact-local anchor and independently reviewed. One-reviewer capture, duplicate reviewer identity, obvious copied-review signals, invalid anchors and unresolved reviewer disagreement cannot become a scoreable raw observation.

W20 then ignores operator-calculated quality metrics as authority and deterministically recomputes canonical W17 quality metrics from reviewed raw BPM/beat/key/chord/section observations plus the same Golden annotations used by Project scoring. `UNSUPPORTED` and `UNSCORABLE` remain fail-closed rather than being converted to zero scores.

W19 finally validates repeatability on the W20-derived metrics and compiles the audited Reference report only when comparison-ready.

None of these evidence-integrity states is PARITY.

## Evidence eligibility

A W18 metric pair is `parityCandidateEvidence=true` only when both rows are metadata-compatible, evaluator-accepted, audited-report eligible and non-synthetic. W19-W22 integrity/sufficiency gates are additional prerequisites on the Reference/corpus side.

Synthetic/unit fixtures may exercise W18-W22 but cannot become PARITY evidence.

## W18 output statuses

- `INVALID_PROFILE`: profile/engine metadata invalid.
- `INCOMPLETE_PAIRING`: same-corpus or metric pairing incomplete.
- `OUTSIDE_SUPPLIED_TOLERANCE`: at least one paired quality regression exceeds the supplied margin.
- `WITHIN_TOLERANCE_NON_PARITY_EVIDENCE`: inside margins, but evidence is not eligible real-audio PARITY-candidate evidence.
- `WITHIN_SUPPLIED_TOLERANCE_PENDING_HQ`: all paired evidence is eligible and inside supplied margins. **Still not PARITY.** Final authority remains `HQ_LATE_INTEGRATION`.

## Anti-masking output

Every paired metric stores fixture/domain/genre, direction, both values, signed delta, regression, supplied maximum regression, within-tolerance result and evidence eligibility. Per domain+metric, the report stores counts and the worst regression fixture so an aggregate mean cannot hide a catastrophic case.

## Required HQ sequence after W22

1. Freeze the rights-cleared Golden corpus and exact manifest bytes.
2. Hash those exact bytes and obtain an HQ-approved W22 coverage policy.
3. Run W22 and stop if corpus coverage/sufficiency is not comparison-ready.
4. Produce the Project report with `runProductAlignedAudited` against that exact manifest.
5. Approve W19 capture policy for the current Moises app/build/device/iOS/tier epoch and exact same manifest.
6. Perform repeated current-iPhone Moises capture runs and archive SHA-bound artifacts.
7. For human transcription, run W21 independent artifact-anchored review consensus.
8. Run W20 deterministic raw re-scoring against the same Golden annotations.
9. Run W19 provenance/repeatability validation on the W20-derived capture set and compile the audited Reference only if comparison-ready.
10. Rerun W22 if any manifest/corpus binding changed after capture began.
11. Obtain a separate HQ-approved W18 non-inferiority tolerance profile.
12. Run `AnalysisPairedDifferentialComparator.compare(...)`.
13. Preserve W22 coverage evidence, Project report, W19-W21/W20 Reference evidence, W18 profile and paired differential report together.
14. Investigate every coverage deficit, review disagreement, repeatability excursion and worst-regression fixture.
15. HQ performs final PARITY judgment and updates `PARITY_MATRIX.json` only after all relevant product/device gates are also satisfied.

## NON-PARITY warning

W18-W22 portable tests validate comparator, Reference-evidence integrity and corpus-sufficiency machinery only. They do not establish MOI-P009, MOI-P011, MOI-P013, MOI-P016 or MOI-P021 PARITY.
