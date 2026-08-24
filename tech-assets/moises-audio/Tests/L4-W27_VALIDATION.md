# L4-W27 Validation — Physical Evidence Archive Integrity

## Scope

W27 hardens the MOI-P021 evidence chain after W22/W26/W23/W25/W24 by making archived artifact replacement, omission, role swapping and run-inventory manipulation detectable against a deterministic archive root.

This wave is **NON_PARITY**. No physical iPhone was executed.

## Production implementation

Added:

- `Analysis/AnalysisPhysicalEvidenceArchiveModels.swift`
- `Analysis/AnalysisPhysicalEvidenceArchiveValidation.swift`
- `Analysis/AnalysisPhysicalEvidenceArchiveContentValidation.swift`

Package registration was added in `Package.swift`.

The implementation requires 11 singleton artifact roles and four artifact roles for every exact W24 predeclared run. Each entry binds role, optional run ID, normalized relative path, SHA-256 and byte length.

The archive root additionally binds the Golden manifest, W22 coverage policy, W26 selection policy, W24 profile/batch, W25 workload/build identity, physical device model and iOS version.

Role files are decoded during verification. A valid hash with a false role is therefore not sufficient: W22/W26/W24/W25 IDs and W23/W25 run/fixture/device/build/analyzer relationships must also match.

## Portable typecheck

Environment:

- Swift 6.2.1
- x86_64 Linux
- `-swift-version 6 -strict-concurrency=complete`

The W27 production source split was source-shaped typechecked against public-surface stubs for the existing W22/W23/W24/W25/W26 models.

Result: **PASS**.

This does not replace canonical SwiftPM/Xcode execution on the integrated checkout.

## Adversarial harness

Five clean optimized processes were executed.

Result in every process:

- `24/24 PASS`

Covered conditions include:

- exact valid archive
- deterministic root independent of input entry order
- artifact byte/hash/length mutation
- declared-root mutation
- missing/duplicate singleton role
- missing per-run artifact
- unexpected run artifact
- traversal path
- unmanifested verification bytes
- role/content swap
- W23 telemetry run swap
- W25 workload fixture swap
- build mismatch
- simulator/nonphysical device corroboration
- W24 run-inventory mismatch
- duplicate archive path
- invalid archive authority
- deterministic codec
- SHA-256 known vector

Small-harness process wall time was approximately `0.02–0.03 s`, with RSS approximately `21 MB`.

## Stress validation

Each clean process used:

- 10,000 predeclared runs
- four required per-run artifacts each
- 11 required singleton artifacts
- 40,011 total archive entries
- full SHA-256/byte-length verification
- full role JSON decoding and cross-binding
- deterministic root recomputation

Five clean runs all returned:

`TAMPER_EVIDENT_ARCHIVE_ROOT_CONSISTENT_PENDING_HQ`

with zero issues.

Internal validator seconds:

- 3.008903
- 2.603686
- 2.602178
- 2.589695
- 2.634628

Process wall seconds:

- 5.71
- 5.01
- 5.00
- 5.12
- 5.09

Max RSS kB:

- 82728
- 82760
- 82700
- 82692
- 82660

These measurements are archive-validator overhead only. They are **not** physical-iPhone Analysis performance evidence.

## Integrity boundary

W27 deliberately does not claim cryptographic authenticity.

A deterministic root can detect later replacement only after that root is independently fixed/compared. If an actor can replace both the artifacts and the unanchored archive manifest, the actor can compute a new internally consistent root.

Therefore W27 explicitly does not claim:

- secret-key signing
- Secure Enclave signing
- Apple hardware/device attestation
- trusted timestamps
- proof that self-declared device JSON was honestly captured

HQ must independently archive/anchor the final W27 root outside the mutable evidence bundle.

## Remaining gates

- actual integrated Apple/Xcode compile and XCTest
- actual physical-iPhone execution
- HQ-approved W22/W26/W24 production policy values
- actual rights-cleared source files and Lane-2 loader/source provenance
- independent final-root anchoring / stronger provenance mechanism if HQ requires one
- actual current-iPhone Moises differential evidence for MOI-P009/P011/P013/P016
- final MOI-P021 and PARITY_MATRIX decision by HQ Late Integration

W27 does not change any PARITY state.
