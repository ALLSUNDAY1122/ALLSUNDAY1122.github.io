# W52 Quiescent custody runbook

W52 is a NON_PARITY custody-hardening layer over the W49-W51 bridge-consumption ledger. It does not change W49/W50 record, ledger, checkpoint or handoff root formats.

## Required production flow

1. Call `AnalysisPhysicalRealAudioBridgeConsumptionQuiescentCustodyManager.observeSnapshot(ledgerID:rootURL:)`.
2. Persist or transmit the returned snapshot root with the HQ authorization decision. The snapshot commits the exact ledger sequence/root/latest-record root and the complete consumed W47 package-root inventory.
3. If a writer is to append from that exact state, derive the W51 token with `appendCAS(for:)`; do not manually transcribe the predecessor roots.
4. For checkpoint/handoff custody, call `makeCustodyBundle` with the exact previously observed `expectedSnapshot`.
5. W52 acquires the same W51 per-ledger writer lease, performs W50 recovery + secure reopen, and compares the current snapshot to the supplied token before constructing any checkpoint.
6. If the snapshot changed, treat `staleSnapshotCAS` as a failed authorization. Do not silently retry. Re-observe the ledger and re-authorize the new snapshot explicitly.
7. On success, archive all four returned objects together: snapshot, existing-format checkpoint, existing-format external-anchor handoff, and W52 custody receipt.
8. Store at minimum the latest handoff root and W52 receipt root outside the mutable ledger directory. The local receipt alone is not an external anchor.

## Race semantics

A cooperating W51 writer and a W52 custody transaction use the same OS/in-process writer barrier.

- If custody obtains the lease first, it may emit an exact pre-append snapshot/checkpoint/handoff/receipt bundle. The writer can append only after custody releases the lease.
- If the writer obtains the lease first and commits, a custody call carrying the old snapshot fails `staleSnapshotCAS` before checkpoint construction.
- If a writer crashed after the record became durable but before the head update, W50 recovery rolls the record forward before W52 compares the snapshot, so the old token is stale.
- If a writer stopped after only the pending marker, W50 recovery removes the uncommitted marker and the unchanged snapshot remains valid.
- Mixed `inventory from state N / head from state N+1` custody objects are not an accepted outcome.

## Checkpoint chain

For checkpoint sequence > 1, supply the prior checkpoint and prior handoff. Existing W49 strict-prefix rules still apply. W52 additionally requires the new checkpoint to match the exact W52 snapshot used by the custody transaction.

The W52 receipt binds:

- snapshot root;
- checkpoint root;
- handoff root;
- ledger sequence/root/latest-record root;
- consumed W47 inventory root;
- predecessor checkpoint root;
- predecessor handoff root;
- HQ authority/approval references;
- NON_PARITY limitations.

Validate a retained bundle with `validateSnapshot` and `validateReceipt`. For a checkpoint that is supposed to describe the current ledger, use `verifyCurrentLedgerStrict(checkpoint:expectedSnapshot:...)`, which takes the same W51 writer barrier before verification.

## Fail-closed rules

Reject and do not auto-repair:

- malformed snapshot root;
- wrong ledger ID;
- stale sequence/root/latest-record identity;
- inventory substitution;
- checkpoint root not matching the snapshot;
- handoff root not matching the checkpoint/snapshot;
- receipt mutation;
- predecessor checkpoint/handoff mismatch;
- W51 lock topology/token failure;
- W50 secure-reopen failure.

## Evidence boundary

W52 does not establish product PARITY, Apple filesystem durability, current-Moises reference evidence, real-audio differential quality, physical-iPhone performance, rights clearance, trusted timestamps, signatures or device attestation. HQ Late Integration remains responsible for canonical SwiftPM/Xcode execution, external anchor custody and final PARITY_MATRIX judgment.
