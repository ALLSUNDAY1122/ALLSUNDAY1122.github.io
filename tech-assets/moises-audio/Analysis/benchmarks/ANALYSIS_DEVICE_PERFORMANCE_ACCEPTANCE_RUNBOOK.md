# W24 Physical-iPhone Analysis Performance Acceptance Runbook

Purpose: prevent a single favorable W23 physical-iPhone run, a favorable mean, or a cherry-picked subset of runs from becoming MOI-P021 evidence.

W24 does not execute the device benchmark, does not choose production thresholds, and does not declare PARITY. HQ Late Integration owns the physical-iPhone run, threshold approval, archive and final PARITY decision.

## 0. Pass W22 and W26 before approving W24

Before creating the W24 run plan, freeze the exact rights-cleared manifest and run W22 corpus coverage. Then run W26 physical corpus selection against the same manifest and W22 policy.

W24 `requiredFixtureIDs` and `expectedFixtureDurationsSeconds` must exactly equal the W26 selected fixture inventory. Do not approve W24 from an easier fixture subset that was not accepted by W26. If W22 or W26 changes, issue a new W24 profile/batch rather than reusing the previous plan.

## 1. Approve the profile before running

Start from `ANALYSIS_DEVICE_PERFORMANCE_ACCEPTANCE_PROFILE_TEMPLATE.json`.

The template is intentionally invalid. HQ must fill and approve all binding and limit fields before capture:

- `profileID` and `approvalReference`
- exact `expectedBatchID`
- exact iPhone model, iOS version, bundle ID, app version and build version
- exact W22/W26/W23 manifest ID and SHA-256
- exact W26-approved required fixture IDs and expected durations
- minimum complete-analysis repetitions per fixture
- minimum cancellation-probe repetitions per fixture
- exact `plannedRuns` with predeclared run IDs, fixture IDs and run kinds
- maximum complete-analysis wall time
- maximum peak resident memory
- maximum peak physical footprint
- maximum allowed starting thermal state
- maximum allowed worst thermal state
- maximum battery drain fraction
- maximum memory-pressure event count
- maximum cancellation latency
- whether complete runs must remain unplugged

The evaluator requires at least two complete runs and two cancellation probes per fixture. HQ may approve higher counts.

The exact run IDs are predeclared so an unfavorable planned run cannot later be omitted while retaining only enough favorable runs to satisfy a minimum-count rule.

## 2. Keep the W23 run contract

Every submitted run must first satisfy W23 structural validation:

`PHYSICAL_DEVICE_EVIDENCE_STRUCTURALLY_COMPLETE_PENDING_HQ`

W24 rejects:

- simulator or portable runs
- unavailable required telemetry
- invalid/corrupt W23 records
- mixed app builds
- mixed device models
- mixed iOS versions
- different manifest ID/SHA
- fixture-duration mismatch beyond 1 ms
- failed complete-analysis runs
- missing, duplicate or unexpected run IDs

Complete-analysis runs can additionally require all usable battery samples to remain `UNPLUGGED`. Starting thermal state must be no worse than the HQ-approved precondition.

## 3. Submit the exact batch

Create one `AnalysisDevicePerformanceEvidenceBatch` using the exact approved `batchID` and `profileID`.

The submitted run-ID set must exactly equal the predeclared run-ID set. No planned run may be absent and no post-hoc replacement run may be inserted unless HQ approves a new profile/batch before rerunning the gate.

If the build, device, iOS version, W22/W26 corpus selection, manifest, run plan or approved thresholds change, create a new profile and new batch ID. Do not combine epochs.

## 4. Worst-case acceptance semantics

W24 does not average away bad runs. For every required fixture it records the worst observed run and its run ID for seven metrics:

1. complete-analysis wall seconds
2. peak resident bytes
3. peak physical-footprint bytes
4. worst thermal-state rank
5. battery drain fraction
6. memory-pressure event count
7. cancellation latency seconds

Higher values are worse for all seven W24 performance metrics. Equal worst values use the lexicographically smaller run ID so output is deterministic.

The fixture passes the supplied limits only when every required worst metric is present and within the HQ-approved limit.

A low mean cannot offset a single approved-limit breach.

## 5. Status meanings

`INVALID_PROFILE`
: the approval/profile itself is incomplete or internally inconsistent. Do not run acceptance.

`INCOMPLETE_PHYSICAL_DEVICE_EVIDENCE`
: the run set or W23 telemetry is incomplete, mixed, nonphysical, failed, or violates the approved preconditions. This is not a performance failure; it is invalid evidence.

`OUTSIDE_HQ_APPROVED_LIMITS`
: the exact complete physical-device run set is valid, but at least one worst-case metric exceeds an HQ-approved limit.

`WITHIN_HQ_APPROVED_LIMITS_PENDING_HQ`
: the exact repeated run set is structurally valid and all worst-case values are inside the supplied limits. This is still not PARITY. HQ must corroborate device/build provenance, archive the evidence and combine it with the remaining product gates.

## 6. Required archive

Archive together:

- approved W22 corpus-coverage policy/report
- approved W26 physical corpus-selection policy/report
- approved W24 profile
- exact W24 evidence batch
- every W23 raw run JSON
- every W23 validation report
- W25 workload policy/receipts/reports
- W24 acceptance report
- exact manifest bytes and SHA-256
- integrated app build identifier and build artifact evidence
- physical-device/iOS evidence sufficient for HQ to corroborate the declared environment
- operator notes for any interrupted or replaced capture attempt

Do not silently delete failed or aborted planned attempts. If the predeclared run plan cannot be completed, W24 should remain incomplete or HQ should issue a new explicitly approved batch/profile.

## 7. MOI-P021 boundary

W24 closes the software-side repeatability and anti-cherry-picking gap around W23. W26 additionally prevents choosing an unrepresentatively easy physical fixture subset relative to the HQ-approved W22 corpus. These gates do not themselves supply:

- a real iPhone execution
- production thresholds
- battery/thermal laboratory controls
- evidence that declared physical-device JSON was honestly captured
- final MOI-P021 PARITY

Those remain HQ Late Integration responsibilities.
