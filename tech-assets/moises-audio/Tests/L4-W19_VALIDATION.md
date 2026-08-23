# L4-W19 Validation — Current-iPhone Reference Capture Provenance / Repeatability

## Scope

W19 hardens the future current-iPhone Moises Analysis Reference capture path. It does **not** capture Moises, select the current app/build on behalf of HQ, choose production repeatability tolerances, or declare PARITY.

The problem addressed is evidence integrity: W18 could pair Project and Reference rows correctly, but an externally created Reference report could still be stale, mixed across app/device/corpus versions, based on one manual run, or have unstable observations hidden behind a single number.

## Implementation

### `AnalysisReferenceCapture.swift`

Adds:

- `AnalysisReferenceCaptureEnvironment`
- exact source-manifest binding with SHA-256
- SHA-bound capture artifacts
- per-run operator/timestamp/observation-method provenance
- per-fixture/domain W17 quality rows
- HQ-owned `AnalysisReferenceCapturePolicy`
- externally supplied repeatability spread rules
- structured validation issues
- per-fixture/domain/metric repeatability diagnostics
- fail-closed audited Reference report compiler
- ISO-8601 / sorted-key capture, policy and validation-report codec

### Current-Reference policy bindings

A valid policy requires:

- `authority == HQ_LATE_INTEGRATION`
- durable non-empty approval reference
- current Reference epoch lower bound
- expected product/app/build
- exact device model / iOS version
- locale / account tier
- exact source manifest ID and 64-hex SHA-256
- at least two repeat runs
- non-empty repeatability rules
- finite, non-negative spread limits
- W17-known metric names
- no duplicate rules

Worker 4 intentionally provides no production spread thresholds.

## Fail-closed capture gates

Validation rejects:

1. stale capture before the HQ epoch;
2. future-dated capture;
3. wrong/mixed app build, device, OS, locale or tier;
4. wrong/mixed source-manifest ID/hash;
5. duplicate/empty run IDs;
6. missing operator ID;
7. missing, duplicate or invalid evidence artifact identity/hash;
8. duplicate fixture/domain rows;
9. changed fixture/domain row set between repeat runs;
10. changed row metadata between repeat runs;
11. changed quality-metric set between repeat runs;
12. non-finite metrics;
13. metrics outside the W17 quality registry;
14. observed metrics without an HQ repeatability rule;
15. required rules absent from the captured corpus;
16. synthetic capture rows;
17. rows not bound to evidence artifacts in the same run;
18. repeated-observation absolute spread exceeding the supplied rule.

No incomplete capture is truncated or averaged into a valid Reference.

## Repeatability diagnostics

For every fixture/domain/metric, validation records:

- run count
- minimum
- maximum
- mean
- median
- absolute spread
- supplied maximum spread
- exact agreement
- within-supplied-repeatability result

The Reference report compiler runs only when validation has no issues and at least one diagnostic.

## Consensus compilation

When a capture set is comparison-ready:

- each metric is compiled from the deterministic median of all repeat runs;
- manifest identity comes from the approved HQ capture policy;
- engine defaults to `current-iphone-moises-reference`;
- app/build/device/iOS/capture-set identity is embedded into `engineVersion`;
- W17 domain/genre summaries are rebuilt from the compiled rows;
- Reference wall time, RSS and thermal values are not fabricated;
- the full capture set/validation/artifacts remain separate required evidence and must be archived with the compiled report.

`STABLE_REFERENCE_CAPTURE_PENDING_HQ` is only a Reference-capture integrity state. It is not product PARITY.

## Source-shaped Swift validation

Environment:

- Swift 6.2.1
- x86_64 Linux

Results:

- production `AnalysisReferenceCapture.swift` typecheck: PASS
- committed `AnalysisReferenceCaptureTests.swift` source-shaped typecheck: PASS

Canonical SwiftPM/Xcode XCTest execution remains an HQ integrated-checkout gate.

## Portable adversarial harness

Five clean complete runs; every run: **15/15 PASS**.

Covered behaviors:

- stable repeated capture accepted
- consensus median compiled correctly
- stale capture rejected
- mixed build rejected
- mixed source manifest rejected
- row-set cherry-pick rejected
- metric-set cherry-pick rejected
- missing repeatability rule rejected
- repeatability excursion rejected
- synthetic Reference rejected
- missing evidence-artifact binding rejected
- future capture rejected
- HQ authority enforced
- minimum repeat-run count enforced
- codec round-trip succeeds

## 50,000-fixture repeatability stress

Two repeat runs, one W17 quality metric per fixture, 50,000 expected diagnostics.

All five runs produced exactly 50,000 diagnostics and remained comparison-ready.

Internal elapsed seconds:

- 0.496347
- 0.471309
- 0.533963
- 0.465598
- 0.492090

Process wall seconds:

- 0.52
- 0.49
- 0.56
- 0.49
- 0.52

Maximum RSS kB:

- 99,820
- 99,832
- 99,680
- 99,632
- 99,764

Worst internal elapsed: 0.533963 s. Maximum observed RSS: 99,832 kB.

These are portable Linux validator measurements, not physical-iPhone performance claims.

## Durable artifacts

- `Analysis/AnalysisReferenceCapture.swift`
- `Tests/MoisesAudioCoreTests/AnalysisReferenceCaptureTests.swift`
- `Analysis/benchmarks/REFERENCE_CAPTURE_POLICY_TEMPLATE.json`
- `Analysis/benchmarks/REFERENCE_CAPTURE_SET_TEMPLATE.json`
- `Analysis/benchmarks/REFERENCE_CAPTURE_RUNBOOK.md`
- `Analysis/benchmarks/PAIRED_DIFFERENTIAL_RUNBOOK.md`
- `Analysis/benchmarks/L4-W19_REFERENCE_CAPTURE_PROVENANCE.json`

Both JSON templates intentionally fail closed until HQ supplies real approved metadata/rules and real capture runs.

## Remaining external gates

W19 does not satisfy MOI-P009/P011/P013/P016/P021. Remaining required evidence includes:

- rights-cleared varied real audio;
- actual current-iPhone Moises observations;
- current app/build selection by HQ;
- actual iPhone model/iOS capture evidence;
- HQ-approved repeatability rules;
- W18 HQ-approved Project-vs-Reference non-inferiority profile;
- physical-iPhone Project measurements;
- final HQ PARITY_MATRIX judgment.

## Newly exposed next integrity gap

W19 captures/evaluates W17 **quality metric values** with strong provenance, but those metric values may still be manually transcribed from current-Moises observations. A stronger chain would preserve raw Moises Analysis observations (tempo/beat/key/chord/section outputs) and independently re-derive W17 quality metrics from the same ground-truth annotations, so an incorrect hand-calculated metric cannot become the Reference baseline.

This is the proposed L4-W20 focus.

## Conclusion

W19 closes the stale/mixed-corpus/one-off/unstable Reference-capture gap and makes future W18 input reproducible and machine-auditable. Evidence remains **NON-PARITY** until HQ supplies and validates the actual current-iPhone Moises capture corpus and completes the remaining product/device gates.
