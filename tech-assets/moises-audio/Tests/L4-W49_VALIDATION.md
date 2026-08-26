# L4-W49 validation

## Result

`L4-W49｜Durable W48 bridge-certificate consumption ledger / monotonic checkpoint chain + fork/replay resistance` is implemented on `moises/wp4-analysis-platform` as NON_PARITY evidence infrastructure.

No PARITY row is promoted by this wave.

## Implemented invariants

- Each accepted W48 bridge certificate is assigned the next monotonic sequence by the store; callers do not provide the record sequence.
- Each record binds the W48 certificate root, W47 package root, W46 adjudication report root, expectation root, HQ custody metadata and predecessor record root.
- Reopen verifies the declared record root for every referenced record and recomputes the complete ledger root.
- Duplicate bridge IDs, W47 package roots and W48 certificate roots are rejected.
- The records directory must contain exactly the head-referenced immutable records, except for one explicitly recoverable pending candidate. Unreferenced records fail as forked history.
- Atomic pending-marker recovery distinguishes pending-only, record-written-before-head and head-written-before-marker-removal states; ambiguous state fails closed.
- `expectationUsingDurableConsumedInventory` supplies the consumed W47 package-root inventory directly to the next W48 expectation.
- Checkpoint roots bind the exact ledger sequence, ledger root, latest record root and complete consumed package inventory.
- `makeStrictCheckpoint` requires the previous checkpoint to be the exact prefix of the current validated ledger, not merely a valid checkpoint with a matching sequence number.
- `verifyCurrentLedgerStrict` rejects stale checkpoint replay after ledger advancement and rejects predecessor checkpoints from another fork.
- Strict external handoffs require their predecessor handoff to reference the checkpoint root named by the new checkpoint's predecessor chain.

## Durable XCTest source

Added:

- `Tests/MoisesAudioCoreTests/AnalysisPhysicalRealAudioBridgeConsumptionLedgerTests.swift`
- `Tests/MoisesAudioCoreTests/AnalysisPhysicalRealAudioBridgeConsumptionCheckpointStrictTests.swift`

Coverage includes:

- monotonic append and predecessor chaining;
- durable W48 replay inventory derivation;
- duplicate bridge/package rejection;
- record mutation rejection;
- unreferenced fork-record rejection;
- stale checkpoint replay rejection;
- checkpoint root mutation rejection;
- strict historical-prefix validation;
- strict external-handoff predecessor validation;
- 24-entry monotonic chain fixture with unique roots.

## Independent adversarial protocol mirror

A separate canonical-JSON/SHA-256 protocol mirror executed 120,000 mutations across 12 classes:

- record payload mutation;
- sequence gap;
- predecessor-root substitution;
- duplicate bridge ID;
- duplicate W47 package root;
- duplicate W48 certificate root;
- ledger-root substitution;
- unreferenced fork record;
- stale checkpoint replay;
- fork checkpoint with recomputed self-consistent checkpoint root;
- checkpoint mutation retaining the old declared root;
- handoff predecessor substitution.

Result: `120000 / 120000 detected`, `0 undetected`, approximately `5.43 s` in the independent mirror runtime.

This is protocol evidence only. It is not a SwiftPM/XCTest substitute.

## Canonical SwiftPM/XCTest

Fresh Worker-branch execution remains `NOT_OBSERVED` in this runtime.

Attempt:

`git ls-remote https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io.git refs/heads/moises/wp4-analysis-platform`

failed before Swift execution with:

`Could not resolve host: github.com`

Therefore W49 does **not** claim canonical Swift compilation or XCTest PASS. HQ must run canonical SwiftPM/XCTest on the exact semantic-integrated W49 sources.

## Remaining limitations / external gates

- W49 is a local SHA-256 hash chain, not a signature, trusted timestamp, Secure Enclave proof or Apple attestation.
- Whole-directory rollback/fork resistance depends on HQ retaining the latest checkpoint/handoff root outside the mutable ledger directory.
- File-system symlink/non-regular-file hardening and injected crash/fault durability remain follow-up hardening work; the current W49 store focuses on chain semantics and atomic pending-state recovery.
- No genuine selected physical-iPhone W47 full-corpus package was available in this Worker runtime.
- Current-iPhone Moises W19-W21 Reference evidence, rights clearance, W46 paired differential evidence and independent HQ judgment remain required for MOI-P009/P011/P013/P016.
- MOI-P021 remains gated by genuine physical iPhone performance evidence from the W45 path.
