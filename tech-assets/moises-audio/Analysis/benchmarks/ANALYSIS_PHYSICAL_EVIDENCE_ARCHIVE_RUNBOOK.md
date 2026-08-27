# W27 Physical Analysis Evidence Archive Runbook

Purpose: make post-capture replacement, omission, role swapping and run-inventory manipulation detectable across the W22 -> W26 -> W23/W25 -> W24 physical-performance evidence chain.

W27 is an integrity/archive layer only. It does not execute the physical-device benchmark, choose production thresholds or declare MOI-P021 PARITY.

## 1. Freeze the W27 policy before final archive assembly

Start from `ANALYSIS_PHYSICAL_EVIDENCE_ARCHIVE_POLICY_TEMPLATE.json`.

The template is intentionally fail-closed. HQ must fill and approve:

- archive policy ID and approval reference
- exact archive ID
- exact Golden manifest ID and SHA-256
- exact W22 coverage-policy ID
- exact W26 selection-policy ID
- exact W24 performance-profile ID and batch ID
- exact W25 workload approval reference and build identity
- exact physical iPhone model and iOS version
- exact W24 predeclared run-ID inventory

The W27 validator cross-checks those values against the canonical W22/W26/W24/W25 policy objects supplied to validation. The W27 run inventory must exactly equal W24 `plannedRuns`; a smaller favorable subset is invalid.

## 2. Required singleton artifacts

Exactly one of each role is required:

1. `GOLDEN_MANIFEST`
2. `W22_COVERAGE_POLICY`
3. `W22_COVERAGE_REPORT`
4. `W26_SELECTION_POLICY`
5. `W26_SELECTION_REPORT`
6. `W24_PERFORMANCE_PROFILE`
7. `W24_PERFORMANCE_BATCH`
8. `W24_ACCEPTANCE_REPORT`
9. `W25_WORKLOAD_POLICY`
10. `BUILD_CORROBORATION`
11. `DEVICE_CORROBORATION`

Every artifact entry records exact relative path, SHA-256 and byte length.

`BUILD_CORROBORATION` must decode as `AnalysisPhysicalEvidenceBuildCorroboration` and match W24 bundle/app/build plus the W25 build identity. `DEVICE_CORROBORATION` must decode as `AnalysisPhysicalEvidenceDeviceCorroboration`, claim a physical iOS runtime and match the approved device model/iOS version.

These corroboration records are consistency evidence. They are not cryptographic device attestation.

## 3. Required artifacts for every W24 planned run

For every exact predeclared run ID, archive exactly one of each:

- `W23_RAW_TELEMETRY`
- `W23_VALIDATION_REPORT`
- `W25_WORKLOAD_RECEIPT`
- `W25_WORKLOAD_VALIDATION_REPORT`

W27 rejects missing, duplicate or unexpected run artifacts.

The raw W23 record is decoded and checked against the W24 run kind/fixture plus exact manifest/device/iOS/build binding. The W25 receipt is decoded and checked against the same run/fixture, exact manifest and W25 analyzer identity.

A file with a valid hash but the wrong declared role therefore still fails content cross-binding.

## 4. Exact byte verification

Construct each `AnalysisPhysicalEvidenceArchiveEntry` from the final archived bytes using `AnalysisPhysicalEvidenceArchiveBuilder.entry(...)`.

During verification, provide the exact archived evidence files as `artifactBytesByPath`.

W27 rejects:

- missing declared bytes
- extra unmanifested bytes in the verification input
- zero-length entries
- SHA-256 mismatch
- byte-length mismatch
- absolute, traversal, backslash or non-normalized paths
- duplicate paths
- duplicate singleton roles
- singleton roles carrying run IDs
- per-run roles without run IDs

Do not regenerate JSON after recording its archive entry. Formatting changes alter exact bytes and therefore the artifact SHA-256.

## 5. Deterministic archive root

Build the manifest with `AnalysisPhysicalEvidenceArchiveBuilder.manifest(...)`.

The root covers, in deterministic sorted form:

- archive schema/version
- archive ID
- W27 policy ID
- exact manifest/coverage/selection/profile/batch/workload/build/device binding
- every artifact role
- every artifact run ID where applicable
- every relative path
- every artifact SHA-256
- every artifact byte length

Input entry order does not change the root. Changing a role, run ID, path, byte length, artifact hash, build binding or device binding does change the root.

## 6. External anchoring requirement

`TAMPER_EVIDENT_ARCHIVE_ROOT_CONSISTENT_PENDING_HQ` means only that the archive is internally complete and consistent with the supplied root and policies.

The root is not a digital signature.

An actor able to replace both the evidence files and the unanchored archive manifest can recompute a new internally consistent root. Therefore HQ must independently fix/archive the final root outside the mutable evidence bundle, for example in the integration evidence ledger/review record controlled by HQ.

W27 does **not** claim any of the following unless HQ separately supplies and validates them:

- secret-key signing
- Secure Enclave signing
- Apple App Attest / DeviceCheck proof
- trusted timestamping
- hardware-origin attestation
- proof that a self-declared physical-device JSON was honestly captured

## 7. Status meanings

`INVALID_ARCHIVE_POLICY`
: HQ approval/bindings/run inventory are absent or inconsistent.

`ARCHIVE_INCOMPLETE_OR_TAMPERED`
: required artifacts/bytes/content/root are incomplete or inconsistent. This status does not distinguish malicious tampering from accidental archive corruption.

`TAMPER_EVIDENT_ARCHIVE_ROOT_CONSISTENT_PENDING_HQ`
: exact inventory, bytes, decoded cross-bindings and deterministic root are consistent. This is still NON_PARITY and still requires HQ physical-device provenance review plus independent root anchoring.

## 8. Required HQ archive sequence

1. Freeze exact rights-cleared Golden manifest bytes and SHA.
2. Approve/run W22 corpus coverage.
3. Approve/run W26 physical fixture selection.
4. Approve W24 performance profile and exact run plan.
5. Execute W23 physical telemetry and W25 canonical workload receipts for every planned run.
6. Produce W24 worst-case acceptance report.
7. Create build/device corroboration records from the integrated capture environment.
8. Build W27 entries from the final immutable artifact bytes.
9. Compute W27 deterministic root.
10. Re-read all archived bytes and run W27 validation.
11. Independently record the final root through HQ-controlled evidence handling.
12. Only then use the archive as one input to the HQ MOI-P021/PARITY decision.

If any upstream artifact is regenerated, edited or replaced, rebuild the archive under a newly approved archive epoch/root rather than silently updating individual hashes.
