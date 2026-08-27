# W44｜External W43 Ledger Checkpoint Verification Runbook

## Purpose

W43 detects corruption, fork and rollback while the current local ledger state is available, but an attacker or operator error can replace the entire ledger directory with an older copy that is still internally valid. W44 closes that local-only gap by requiring an expectation preserved independently from the ledger being verified.

This is integrity engineering evidence only. It is not PARITY, device attestation, a signature or a trusted timestamp.

## External expectation

`AnalysisPhysicalEvidenceLedgerCheckpointExpectation` must be supplied independently from `anchor-ledgers/<ledgerID>/`. It pins:

- checkpoint ID and checkpoint sequence;
- authority `HQ_LATE_INTEGRATION` and an approval reference;
- exact ledger ID and anchor ID;
- minimum accepted W43 ledger sequence;
- exact latest W43 ledger sequence;
- exact latest W42 anchor-receipt root;
- exact W43 ledger root;
- for checkpoint sequence > 1, exact predecessor W44 checkpoint-certificate root.

Do not generate the expectation by opening the ledger at the verification destination. Doing so defeats whole-ledger rollback detection.

## Verification

Call:

```swift
let certificate = try AnalysisPhysicalEvidenceLedgerCheckpointVerifier.verifyLedger(
    rootURL: evidenceRoot,
    expectation: externallyPreservedExpectation
)
```

The verifier:

1. validates the external expectation before ledger access;
2. opens only the ledger ID named by the expectation;
3. calls W43 `exportSnapshot`, which performs pending recovery when unambiguous and revalidates every committed W42 receipt/certificate record, both predecessor chains, exact file inventory and the W43 ledger root;
4. compares the reopened ledger ID and anchor ID with the external expectation;
5. requires the actual latest ledger sequence to meet the minimum and exactly equal the externally pinned latest sequence;
6. requires the actual latest W42 receipt root to equal the externally pinned receipt root;
7. requires the recomputed W43 ledger root to equal the externally pinned ledger root;
8. emits a deterministic W44 checkpoint certificate containing both expected and observed values.

Production verification does not accept a cached W43 snapshot. `verifyAlreadyValidatedSnapshot` is module-internal and exists only for adversarial XCTest.

## Whole-ledger rollback test

The key negative scenario is:

1. build a valid W43 ledger at sequence 1;
2. copy the entire ledger directory;
3. advance the live ledger to sequence 2;
4. preserve the sequence-2 W44 expectation externally;
5. replace the live ledger directory with the copied sequence-1 directory;
6. run W44 verification using the still-current sequence-2 expectation.

The old ledger passes W43 internal validation, but W44 rejects it because its latest sequence/root set no longer matches the independently preserved expectation.

## Checkpoint replay

A W44 certificate commits the exact external expectation root. A later checkpoint may reuse the same checkpoint stream ID, but must increment `checkpointSequence` and include the prior W44 certificate root as its predecessor. A stale certificate fails validation against the current expectation. A stale expectation against a newer ledger fails exact sequence/root comparison.

A coordinated rollback of both the local ledger and the externally preserved expectation remains outside W44's local trust boundary. HQ should preserve the current W44 expectation or certificate root in an independent store and preferably sign or trusted-timestamp it.

## Fail-closed cases

W44 rejects:

- invalid authority, ID, SHA or sequence bounds;
- checkpoint sequence > 1 without a predecessor checkpoint certificate root;
- missing/corrupt W43 ledger;
- ledger-ID substitution;
- anchor-ID substitution;
- older ledger below the external minimum;
- exact-sequence mismatch;
- latest W42 receipt-root substitution;
- W43 ledger-root substitution;
- mixed sequence/root sets;
- stale cached snapshot when tested against the current expectation;
- stale/replayed W44 certificate against a newer expectation;
- forged W44 certificate root.

## Evidence limits

W44 does not prove:

- physical iPhone execution;
- APFS/power-loss durability;
- genuine Lane-2 bounded decoding;
- RSS, thermal, battery or cancellation acceptance;
- current-Moises differential parity;
- device origin, trusted time or cryptographic signer identity.

Keep MOI-P009, P011, P013, P016 and P021 MISSING until their real gates pass.
