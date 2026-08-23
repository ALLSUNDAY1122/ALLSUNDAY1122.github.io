# Current-iPhone Moises Reference Capture Runbook

Purpose: produce a machine-auditable current-iPhone Moises Analysis reference without allowing stale app builds, mixed devices/OS/tier, mixed source corpora, one-off manual observations, synthetic fixtures, missing artifacts, or cherry-picked rows/metrics to silently become the W18 comparison baseline.

This runbook does **not** authorize Worker 4 to perform the current-Moises capture, choose production repeatability tolerances, or declare PARITY. Those remain HQ Late Integration responsibilities.

## 1. Freeze the HQ capture policy first

Start from `REFERENCE_CAPTURE_POLICY_TEMPLATE.json`, then have HQ replace every placeholder and approve the policy.

Required bindings:

- `authority == HQ_LATE_INTEGRATION`;
- non-empty HQ `approvalReference`;
- `referenceEpochNotBefore` for the current Reference epoch;
- exact current-iPhone Moises product/app/build version to be tested;
- exact iPhone model identifier, iOS version, locale and account tier;
- exact rights-cleared source manifest ID;
- SHA-256 of the **exact bytes** of that source manifest;
- `minimumRepeatRuns >= 2`;
- one externally approved `maximumAbsoluteSpread` rule for every observed W17 quality metric.

Worker 4 intentionally ships no production repeatability spread values. An empty `repeatabilityRules` list is invalid.

## 2. Hash and bind the exact corpus

The policy and every capture run must carry the same `manifestID` and `manifestSHA256`.

Do not hash a later reserialization and assume it is equivalent. Archive the exact manifest bytes used to select the fixtures and hash those bytes. Any changed fixture, rights record, annotation, ordering-sensitive artifact or manifest file requires a new hash and therefore a new capture set/policy binding.

## 3. Perform repeated HQ capture runs

Each run records:

- unique `runID`;
- non-empty `operatorID`;
- `capturedAt`;
- product/app/build/device/iOS/locale/account tier;
- exact source-manifest binding;
- observation method;
- evidence artifacts with artifact ID, media type and SHA-256;
- one row per fixture/domain;
- only W17 quality metrics in `qualityMetrics`;
- evidence artifact IDs for every row.

Allowed observation methods are encoded by `AnalysisReferenceCaptureObservationMethod` and include direct UI observation, screen-recording review, exported-artifact measurement and instrumented measurement.

All repeat runs must use the same policy environment and exact corpus. A mixed app build, device/OS, locale/tier or manifest binding fails closed instead of being averaged together.

## 4. Repeatability and anti-cherry-pick gates

`AnalysisReferenceCaptureValidator.validate(...)` rejects:

- stale or future-dated runs;
- wrong app/build/device/iOS/locale/tier;
- mixed or invalid source-manifest SHA;
- duplicate run IDs;
- missing operator identity;
- missing/invalid/duplicate evidence artifacts;
- duplicate fixture/domain rows;
- different row sets between repeats;
- changed row metadata between repeats;
- different metric sets between repeats;
- non-finite or non-W17 quality metrics;
- observed metrics without an HQ-supplied repeatability rule;
- required rules absent from the captured corpus;
- synthetic capture rows;
- rows that do not reference an artifact in the same run;
- any metric whose repeat-run absolute spread exceeds the externally supplied tolerance.

The validation report records, per fixture/domain/metric:

- run count;
- minimum / maximum;
- mean;
- median;
- absolute spread;
- supplied maximum spread;
- exact-agreement flag;
- tolerance result.

`STABLE_REFERENCE_CAPTURE_PENDING_HQ` means only that the capture provenance and repeated observations passed the supplied Reference-capture policy. It is not a PARITY decision.

## 5. Compile the W18-compatible Reference report

Only after validation is comparison-ready, call:

```swift
try AnalysisReferenceCaptureValidator.compileAuditedReferenceReport(
    captureSet: captureSet,
    policy: approvedPolicy
)
```

The compiler:

- refuses invalid capture sets;
- takes the median repeated value for each fixture/domain/metric;
- preserves the exact manifest ID;
- sets engine to `current-iphone-moises-reference` by default;
- embeds app/build/device/iOS/capture-set identity in `engineVersion`;
- emits W17 audited domain/genre summaries;
- leaves wall-time/device performance fields unclaimed because this capture path is for Analysis quality reference values.

Archive the following together:

1. approved capture policy JSON;
2. exact source manifest bytes and manifest SHA-256;
3. complete capture set JSON;
4. all referenced evidence artifacts and their hashes;
5. validation report JSON;
6. compiled audited Reference report JSON.

Do not keep only the compiled median report; that would discard the provenance and repeatability evidence that W19 adds.

## 6. Feed W18 paired differential gate

Use the W19-compiled audited Reference report as the Reference side of `AnalysisPairedDifferentialComparator` and the W17 audited project report as the Project side.

W18 still requires its separate HQ-approved non-inferiority tolerance profile. W19 repeatability spread rules and W18 Project-vs-Reference regression margins are different controls and must not be substituted for each other.

Even a W18 result of `WITHIN_SUPPLIED_TOLERANCE_PENDING_HQ` remains pending HQ final PARITY judgment.

## NON-PARITY notice

W19 portable fixtures and templates contain no real Moises observations and no rights-cleared production audio. They validate the capture/provenance machinery only. Actual current-iPhone capture, current app/build selection, device evidence, real-audio corpus, tolerance approval and PARITY_MATRIX changes remain HQ Late Integration gates.
