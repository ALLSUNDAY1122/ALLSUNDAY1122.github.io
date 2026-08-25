# Analysis Physical Evidence External Anchor Runbook｜L4-W42

## Purpose

W41 transfer package is internally tamper-evident, but an entirely unanchored evidence tree can be rewritten into another internally consistent package. W42 closes that specific gap by comparing a destination W41 package with a root set that HQ has preserved independently from the package.

This is an integrity and rollback/replay gate only. It is **NON_PARITY** and is not a signature, trusted timestamp, Secure Enclave proof, Apple attestation, or device-origin proof.

## Required inputs

HQ must hold three logically separate objects:

1. The W41 transfer directory.
2. `AnalysisPhysicalEvidenceAnchorReceipt`, containing the externally selected identities and roots.
3. `AnalysisPhysicalEvidenceAnchorExpectation`, preserved independently from the W41 package and from the receipt payload being checked.

The expectation must contain the current expected anchor ID, minimum acceptable sequence, exact anchor-receipt root, exact publication ID, exact transfer ID, and the expected predecessor receipt root when a chain is in use.

Do not reconstruct the expectation from the destination package. Doing so would remove the rollback/replay protection that W42 is intended to provide.

## Anchor contents

`AnalysisPhysicalEvidenceExternalRootAnchor` pins:

- `anchorID`
- monotonically managed `anchorSequence`
- `authority == HQ_LATE_INTEGRATION`
- non-empty HQ approval reference
- exact W40 publication ID
- exact W41 transfer ID
- exact W27 root
- exact W38 root
- exact W40 root
- exact W41 transfer root
- exact sorted W39 run inventory, including for every run:
  - run ID
  - W36 workload execution ID
  - W39 bundle root
- optional predecessor anchor-receipt root

Run IDs and workload execution IDs must both be unique.

## Issuing a receipt

After HQ has independently selected and recorded the expected root set, construct an `AnalysisPhysicalEvidenceExternalRootAnchor` and call:

`AnalysisPhysicalEvidenceAnchorReceiptIssuer.issue(anchor:)`

The receipt root is a deterministic SHA-256 commitment over the canonical anchor fields. HQ must preserve the resulting receipt root outside the W41 package. If stronger authority is required, sign or trusted-timestamp this independently preserved root using an external system; W42 itself intentionally does not claim such authority.

## Destination verification

At the destination call:

`AnalysisPhysicalEvidenceDestinationAnchorVerifier.verifyDestination(transferDirectoryURL:anchorReceipt:expectation:)`

The order is deliberate:

1. Validate the caller-supplied expectation.
2. Recompute the anchor receipt root.
3. Reject an anchor whose sequence is below the externally required minimum.
4. Require the exact externally pinned receipt root.
5. Require exact anchor/publication/transfer/predecessor identities.
6. Run the complete W41 destination verifier.
7. W41 independently verifies physical file inventory and recomputes W39 → W27 → W38 → W40 → W41.
8. Compare the destination's exact run/execution/W39 inventory and W27/W38/W40/W41 roots with the externally supplied anchor.
9. Only then emit a deterministic destination certificate.

## Rollback and replay behavior

The following must fail closed:

- an older anchor receipt whose sequence is below the independently required minimum;
- any receipt whose root differs from the independently preserved receipt root;
- same transfer ID but an older internally valid W41 root;
- a different transfer ID replayed against the current anchor;
- publication ID substitution;
- missing, additional, or replaced W39 run;
- workload execution ID substitution for an existing run ID;
- W39 bundle-root substitution;
- mixing W27, W38, W40, or W41 roots from different packages;
- predecessor receipt-chain mismatch;
- forged receipt root;
- any W41 payload/path/hash/truncation/symlink/extra-file failure already rejected by W41.

An exact byte-for-byte re-copy of the currently anchored W41 package is intentionally accepted. W42 prevents stale/different package substitution; it does not prohibit legitimate copying of the exact anchored bytes.

## Destination certificate

A successful verification returns `AnalysisPhysicalEvidenceDestinationVerificationCertificate` with:

- status `VERIFIED_AGAINST_EXTERNAL_ANCHOR_NON_PARITY`;
- anchor ID and sequence;
- anchor receipt root;
- publication and transfer IDs;
- expected W27/W38/W40/W41 roots from the external anchor;
- independently verified destination W27/W38/W40/W41 roots;
- exact run/execution/W39 inventory;
- explicit NON_PARITY / non-signature limitations;
- deterministic certificate SHA-256 root.

The certificate intentionally has no generated-at timestamp so that identical verified inputs produce identical bytes/root.

## Sequence and predecessor operation

W42 validates sequence and predecessor values supplied by HQ, but it does not maintain a globally authoritative monotonic database. Operationally:

1. HQ chooses the next sequence outside the transfer package.
2. HQ preserves the current receipt root and minimum acceptable sequence externally.
3. If chaining receipts, the next anchor records the previous receipt root.
4. A verifier receives the current expectation independently.
5. Never accept a package-provided expectation as authority.

A future local journal may improve operator ergonomics, but it cannot replace an independently controlled external root/signature/timestamp authority.

## Validation boundary

W42 portable validation proves deterministic metadata/root behavior and rollback/replay rejection. It does not prove:

- physical iPhone origin;
- Apple/APFS durability;
- genuine bounded Lane-2 decode behavior;
- real RSS / physical footprint / thermal / battery / cancellation values;
- rights-cleared real-audio/current-Moises differential;
- P009/P011/P013/P016/P021 PARITY.

Keep those PARITY rows MISSING until HQ completes their real-device/real-audio gates.
