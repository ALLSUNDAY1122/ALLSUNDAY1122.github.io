# Analysis physical capture artifact materialization runbook｜L4-W39

Status: Worker-4 engineering runbook. **NON_PARITY**.

## Purpose

W37 can return one structurally complete physical-iPhone capture in memory. W38 defines how W35-W37 evidence must be chained into the legacy W27 archive. W39 removes manual copy/rename assembly between those two stages.

The supported flow is:

1. execute one HQ-approved W37 capture;
2. require `PHYSICAL_CAPTURE_STRUCTURALLY_COMPLETE_PENDING_HQ` with no W37 issues;
3. deterministically materialize the exact W23/W25/W35/W36/W37 evidence objects into nine JSON artifacts;
4. derive the four legacy W27 per-run entries and five W38 per-run entries from those exact bytes;
5. validate the prepared bundle root/projections again at the publication boundary;
6. write to a hidden same-parent staging directory;
7. verify every staged artifact by byte length and SHA-256;
8. mark the stage READY;
9. publish the run directory with one `FileManager.moveItem` from the hidden staging directory to `runs/<runID>`;
10. verify the published bytes again.

W39 does not choose device thresholds, fixture rights, run IDs, cancellation timing, or PARITY. Those remain HQ inputs/judgments.

## Required W37 input

The Apple bridge is `AnalysisIOSPhysicalCaptureArtifactMaterializer`.

It rejects a capture unless all of the following are present:

- status is `PHYSICAL_CAPTURE_STRUCTURALLY_COMPLETE_PENDING_HQ`;
- `issues` is empty;
- W23 performance evidence and validation report;
- W36 workload execution and W25 validation report;
- W35 algorithm evidence;
- W37 execution-integrity evidence and report.

It then derives the W36 archive provenance with `AnalysisCurrentDeviceWorkloadArchiveEvidenceBuilder` and passes only portable values into `AnalysisPhysicalCaptureArtifactMaterializer`.

## Exact nine materialized artifacts

For run `<runID>`:

- `runs/<runID>/w23/performance-evidence.json`
- `runs/<runID>/w23/performance-validation.json`
- `runs/<runID>/w25/workload-receipt.json`
- `runs/<runID>/w25/workload-validation.json`
- `runs/<runID>/w35/algorithm-evidence.json`
- `runs/<runID>/w36/current-runtime-evidence.json`
- `runs/<runID>/w37/capture-plan.json`
- `runs/<runID>/w37/execution-integrity-evidence.json`
- `runs/<runID>/w37/execution-integrity-report.json`

No operator should hand-edit, rename, or regenerate an individual artifact after materialization.

## Validation before encoding

`AnalysisPhysicalCaptureArtifactMaterializer` replays the relevant validators rather than trusting the W37 container blindly.

It requires:

- the HQ W37 plan still validates against the supplied W24 profile and W25 policy;
- W23 validation can be reproduced at the original report `generatedAt` timestamp;
- W23 status is structurally complete physical evidence;
- W25 receipt/report validation reproduces exactly;
- W37 execution-integrity validation reproduces exactly and remains valid;
- W35, W36 and W37 all declare `BOUNDED_PULL_CONTRACT`;
- W23/W25/W35/W36/W37 carry one run ID;
- W25/W35/W36/W37 carry one W36 workload execution ID;
- complete and cancellation runs keep their distinct terminal semantics.

A filesystem-unsafe run ID is rejected before artifact encoding.

## W27 and W38 projections

The exact materialized bytes generate two projections automatically.

### Legacy W27 per-run entries

- W23 raw telemetry
- W23 validation report
- W25 workload receipt
- W25 workload validation report

### W38 per-run entries

- W35 runtime-algorithm evidence
- W36 current-runtime evidence
- W37 capture plan
- W37 execution-integrity evidence
- W37 execution-integrity report

The projections reuse the same path, SHA-256 and byte length as the nine materialized artifacts. They are not independently encoded copies.

## W39 bundle root

`AnalysisPhysicalCaptureArtifactBundle` has a deterministic SHA-256 root over:

- schema version;
- run ID;
- W36 workload execution ID;
- the sorted nine tuples `(role, relativePath, artifactSHA256, byteLength)`.

`AnalysisPhysicalCaptureArtifactBundleValidator` independently recomputes this root and also verifies:

- exact 9-role inventory;
- unique paths;
- safe paths under exactly `runs/<runID>/`;
- artifact bytes ↔ byte length ↔ SHA-256;
- exact four W27 projections;
- exact five W38 projections.

Both the high-level publication gate and the low-level stager validate the bundle. A hand-constructed bundle cannot bypass root/projection validation by calling the stager directly.

## Staging and publication

For bundle root `<root>` the hidden stage is deterministic:

`runs/.w39-staging-<runID>-<first16(root)>/`

The stage starts with `W39_STAGING_MANIFEST.json` in state `STAGING`. After all nine evidence artifacts are written and read back successfully, the stage manifest changes to `READY_TO_PUBLISH` and the same ready manifest is also written as `W39_BUNDLE_MANIFEST.json`.

The final publication request moves the entire hidden directory to:

`runs/<runID>/`

The Worker portable Linux mirror verified this single-directory publication/recovery design. Actual APFS/iOS filesystem behavior remains an HQ device-environment check; W39 does not claim a hardware-level atomicity proof.

## Recovery rules

### Existing final directory

If `runs/<runID>/` already exists, stop with `existingTargetCollision`.

Never merge, overwrite, or delete an existing final physical evidence run automatically.

### Interrupted hidden stage with exact marker

If the deterministic hidden stage exists and its marker exactly matches:

- run ID;
- workload execution ID;
- bundle root;
- full artifact inventory/path/hash/length metadata,

it is treated as an interrupted attempt of the same bundle. The incomplete hidden stage is removed completely, then the bundle is restaged from authoritative in-memory bytes.

Partial files are never reused individually.

### Missing/corrupt/mismatched hidden-stage marker

Stop with `ambiguousRecoveryState` and leave the directory untouched for operator/HQ inspection.

Do not infer ownership from the directory name alone.

### Verification failure after publication

Stop fail-closed. The final run directory is not auto-deleted or overwritten. A subsequent attempt collides with the final path, forcing explicit HQ inspection/quarantine instead of silently replacing physical evidence.

## Control files are not W27/W38 evidence roles

The final run directory also contains W39 control metadata:

- `W39_STAGING_MANIFEST.json`
- `W39_BUNDLE_MANIFEST.json`

These are transaction/control files, not W27 or W38 evidence roles.

When constructing `artifactBytesByPath` for W27/W38 validation, use the paths declared by the W27/W38 entries. **Do not enumerate every file in the run directory blindly**, because the archive validators correctly reject unmanifested bytes.

## Observed Worker validation

Worker environment:

- Swift 6.2.1
- x86_64 Linux
- Python 3.13.5

Observed:

- Swift source-shaped transaction mirror compiled with `-warnings-as-errors`;
- 20,000/20,000 bundle/tamper validations passed;
- 200/200 real temporary-filesystem publication cases passed, including matching-marker interruption recovery and existing-final collision rejection;
- corrupt recovery marker remained on disk and failed as ambiguous;
- Python SHA-256 metadata/root mirror completed 200,000/200,000 cases and rejected artifact-hash/execution-root mutations;
- Apple-conditional source-shaped frontend parse passed.

An earlier intentionally larger Swift run (200,000 validations + 1,000 filesystem publications) exceeded the Worker command time limit after successful compilation and is **not** counted as a PASS.

## Not observed / NON_PARITY

The Worker container still cannot resolve `github.com`, so a fresh full Worker-branch SwiftPM/XCTest checkout/run is not claimed.

Also not observed here:

- selected Xcode / Apple ARM compile;
- APFS physical-iPhone publication behavior;
- genuine Lane-2 bounded decoder;
- physical W23/W36/W37 capture;
- real RSS / physical footprint / thermal / battery / cancellation timing;
- W24 repeated worst-case acceptance;
- HQ W27/W38 independent root anchoring;
- current-iPhone Moises differential.

A W39 published bundle is evidence-packaging readiness only. It cannot promote MOI-P021 or any other PARITY row by itself.
