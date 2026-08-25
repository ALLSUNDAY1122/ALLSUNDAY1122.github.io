# L4-W44 Validation

## Scope

W44 adds an external checkpoint above the W43 local anchor ledger. The goal is to detect a coordinated replacement of the complete local W43 ledger by an older copy that remains internally valid.

No PARITY claim is made.

## Canonical refresh

At W44 start:

- Notion still defines v4 four autonomous independent lanes / late integration.
- Worker 4 status selected W44 as the next priority.
- Worker 4 write scope remains `Analysis/**`, `Package.swift`, `Tests/**`, `iOS/**` plus its own status file.
- PARITY rows MOI-P009/P011/P013/P016/P021 remain MISSING.
- HQ advanced to Epoch 29 and canonicalized Lane 4 W41-W42.
- Integration Run #216 / `32878652158` is SUCCESS 350/350.
- W43+ remains post-Epoch29.
- Worker branch was identical to W43 status commit `c7ff33f65b38b6f791e5dd1bd68eaa41d7bc5c9b` before W44 writes.

## Implementation checks

W44 production entrypoint `AnalysisPhysicalEvidenceLedgerCheckpointVerifier.verifyLedger` accepts only a caller-supplied external expectation and a root directory. It does not accept a pre-exported W43 snapshot.

The verifier first validates the external expectation, then invokes W43 `exportSnapshot`, which reopens and validates the local ledger. W44 subsequently requires exact matches for:

- ledger ID;
- anchor ID;
- minimum sequence;
- exact latest sequence;
- latest W42 anchor-receipt root;
- W43 ledger root.

The expectation also commits a W44 checkpoint sequence and, after genesis, a predecessor W44 checkpoint-certificate root.

The deterministic W44 certificate records expected and observed values separately and has its own SHA-256 canonical root.

## Durable XCTest source

Added:

`Tests/MoisesAudioCoreTests/AnalysisPhysicalEvidenceAnchorLedgerCheckpointTests.swift`

Cases cover:

1. deterministic current-ledger verification and certificate encoding;
2. whole-ledger rollback to an old internally valid directory;
3. stale cached snapshot rejection;
4. current sequence mixed with old ledger root;
5. current sequence mixed with old latest receipt root;
6. ledger-ID substitution;
7. anchor-ID substitution;
8. stale checkpoint certificate replay against the current expectation;
9. predecessor checkpoint chain mismatch;
10. forged W44 certificate root;
11. invalid expectation bounds/chain.

The whole-ledger rollback case saves the complete valid sequence-1 W43 ledger directory, advances the live ledger to sequence 2, creates a sequence-2 external expectation, replaces the live directory with the saved sequence-1 directory, and requires W44 to reject it.

## Fresh full Worker checkout

Command attempted:

`git ls-remote https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io.git refs/heads/moises/wp4-analysis-platform`

Observed:

`fatal: unable to access ... Could not resolve host: github.com`

Therefore fresh full Worker SwiftPM/XCTest is **NOT_OBSERVED** and is not counted as a pass.

## Swift source-shaped filesystem mirror

Environment:

- Swift 6.2.1
- x86_64 Linux
- compile flag `-warnings-as-errors`

Observed:

- compile: PASS
- compile elapsed: approximately 0.49 s
- compile max RSS: approximately 154064 kB
- runtime: PASS
- checks: 960
- runtime elapsed: approximately 1.01 s
- runtime max RSS: approximately 19860 kB

The mirror exercised current-state acceptance, whole-ledger rollback, ledger/anchor substitution, latest receipt/root mixing, stale snapshot and invalid checkpoint-chain rejection.

This is source-shaped NON_PARITY engineering evidence, not canonical package execution.

## SHA-256 determinism mirror

Python canonical-JSON SHA-256 mirror:

- checkpoint packages: 30,000
- field mutations: 450,000
- result: PASS
- elapsed: approximately 5.453 s
- max RSS: approximately 159496 kB

Expectation mutations covered checkpoint sequence, ledger ID, anchor ID, latest ledger sequence, latest W42 receipt root, W43 ledger root and predecessor W44 certificate root.

Certificate mutations covered expectation root, observed sequence, observed receipt root, observed ledger root, latest W42 certificate root, latest W43 record root, record count and predecessor W44 certificate root.

## Limitations

W44 does not prove:

- selected Xcode / Apple ARM compilation;
- physical iPhone or APFS behavior;
- power-loss durability;
- genuine bounded Lane-2 decoder behavior;
- physical RSS, thermal, battery or cancellation thresholds;
- current-Moises differential results;
- signer identity, trusted timestamp or Apple/device attestation.

A coordinated rollback of both the local W43 ledger and the externally preserved W44 expectation remains possible if the independent authority/store is compromised. The expected root must not be reconstructed from the ledger under verification.

## PARITY

No `PARITY_MATRIX.json` edit was made. MOI-P009/P011/P013/P016/P021 remain MISSING.
