# L4-W48 Validation｜Externally pinned W47 → W46 Project provenance bridge

## Result

`L4-W48` implements the missing first-class custody bridge between the W47 physical real-audio Project package and the W46 canonical Analysis adjudication entry.

This result is **NON-PARITY**. Worker 4 does not promote `MOI-P009`, `MOI-P011`, `MOI-P013` or `MOI-P016`.

## Implemented

- Added `AnalysisPhysicalRealAudioParityBridgeExpectation` as the independent HQ-supplied expectation.
- Pin exact W47 canonical package root and exact retained package-byte SHA-256.
- Pin canonical manifest ID/root, W47 runtime-binding root, physical-session ID and audited Project report root.
- Pin exact W46 evidence-binding root.
- Reopen W47 from retained bytes and require the package bytes to be canonical.
- Require zero W47 reopen issues before entering W46.
- Require every W46 Project field to equal the reopened W47 runtime/report values.
- Require coverage/capture/review/tolerance objects to equal W46-pinned roots and to reference the same manifest.
- Reject a W47 package root present in the HQ-supplied prior-consumed root inventory.
- Invoke the W46 canonical byte-entry adjudicator through one W48 API.
- Validate the W46 returned report before creating a certificate.
- Emit a deterministic `NON_PARITY_W47_W46_BRIDGE_EXECUTED_PENDING_HQ_JUDGMENT` certificate binding the expectation, W47 package, W46 binding and W46 report roots.

## Durable XCTest source

`Tests/MoisesAudioCoreTests/AnalysisPhysicalRealAudioParityBridgeTests.swift` covers:

1. exact pinned W47 package → W46 handoff and deterministic NON_PARITY certificate;
2. different package-byte SHA rejection;
3. prior-consumed W47 package-root replay rejection;
4. manifest-root substitution rejection;
5. runtime-root and physical-session substitution rejection;
6. W46 Project session substitution rejection;
7. W46 Project report-root substitution rejection;
8. mixed review-policy/root rejection before W46.

The successful fixture intentionally has no completed current-Moises review package, so W46 remains `NOT_READY_FOR_HQ_ANALYSIS_PARITY_JUDGMENT`. This verifies that W48 does not manufacture a PARITY-ready state from Project provenance alone.

## Execution observation

A fresh Worker-branch checkout was attempted before running the W48 SwiftPM tests. Checkout failed with:

`Could not resolve host: github.com`

Therefore fresh canonical Worker-branch `swift test` for W48 is **NOT_OBSERVED** in this runtime. It is not reported as PASS.

Canonical XCTest must be executed by HQ/GitHub Actions or another environment that can fetch the exact Worker branch after semantic integration.

## Adversarial mirror

A separate deterministic protocol-level mirror exercised 240,000 mutations across 12 binding classes:

- package root
- package-byte SHA
- manifest ID
- manifest SHA
- runtime-binding SHA
- physical-session ID
- Project report SHA
- W46 binding SHA
- Project engine
- Project build identity
- Project device model
- consumed-package-root replay

Result: **240,000 detected / 0 undetected**.

This mirror validates the intended fail-closed invariant independently but is not a substitute for compiling or executing the canonical Swift implementation.

Machine-readable evidence: `Analysis/benchmarks/L4-W48_W47_W46_PROVENANCE_BRIDGE.json`.

## Remaining external / Late Integration gates

- W47 still needs an HQ-approved rights-cleared real-audio corpus, genuine integrated Lane-2 bounded decoder and selected physical iPhone execution.
- W46 still needs current-iPhone Moises W19-W21 Reference capture/review and paired differential evidence.
- W48 replay prevention still depends on HQ durably retaining the prior-consumed W47 package-root inventory; W48 is not itself a trusted global ledger.
- Runtime/device/build/session values remain SHA-bound metadata unless independently attested/signed/timestamped.
- Full canonical Worker-branch SwiftPM/XCTest and selected Xcode/iphoneos compilation/execution remain unobserved for W48.
- `PARITY_MATRIX.json` remains HQ-owned and unchanged.

## HQ handoff

Semantic-integrate the exact W47 + W48 Worker-4 owned files before using this bridge for a real Analysis judgment. For a real run, archive the exact W47 bytes, W48 expectation, W46 binding, W46 report and W48 certificate together, then persist the consumed W47 package root in HQ's external custody ledger before any subsequent run.
