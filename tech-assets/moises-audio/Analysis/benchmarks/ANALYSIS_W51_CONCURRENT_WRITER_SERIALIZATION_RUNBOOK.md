# L4-W51｜Concurrent W50 secure-ledger writer serialization runbook

## Purpose

W51 is a NON_PARITY custody/durability hardening layer over the W49/W50 bridge-certificate consumption ledger. It prevents two cooperating writers from publishing different candidates from one predecessor state.

## Canonical prerequisites

- HQ canonical Lane 4 must include W50 secure filesystem/recovery semantics.
- At Epoch 41 the canonical W50 integration is `b90defce6f3f84a188037cfa8df0c6f3b0f1186e` and HQ Run `33026135591` passed SwiftPM 446/446.
- Production callers must not bypass W50/W51 with permissive legacy W49 filesystem writes.

## Write protocol

1. Call `AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.observeAppendCAS` for the target ledger.
2. The observation acquires the same authoritative writer serialization used for writes, resolves any unambiguous W50 pending state, securely reopens the ledger, and returns the exact predecessor `(sequence, ledgerRoot, latestRecordRoot)`.
3. Prepare the W48 bridge certificate/custody metadata without modifying the ledger.
4. Call `AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.append` with the exact observed CAS.
5. W51 acquires the in-process lock and OS `flock`, verifies lock inode/token continuity, recovers W50 state, reopens the predecessor and compares the actual CAS.
6. If any predecessor field changed, stop with `staleWriterCAS`. Re-observe explicitly; do not silently retry an old decision.
7. If unchanged, W50 publishes pending → record → head → pending removal while W51 retains the writer lease.
8. W51 verifies the appended record against certificate identity, recomputes the predecessor prefix root, and securely reopens the final head before returning.

## Lock semantics

- Lock path: `w49-bridge-consumption/.writer-locks/<ledgerID>.lock`.
- The lock file is persistent. Do not delete it merely because its token is old.
- Kernel `flock` ownership, not lock-file age/text, defines an active writer. Process termination releases the kernel lock automatically.
- Each acquisition overwrites the payload with a new UUID token and checks descriptor/path device+inode identity.
- If the lock path is unlinked/replaced during an active lease, fail closed with `lockTokenMismatch`.
- `.writer-locks` must remain a real non-symlink directory under the selected bridge root.

## Interrupted writer handling

### Pending marker only

W50 recovery removes the uncommitted marker. The original CAS remains valid; a second writer using that same CAS may proceed.

### Record written, old head

W50 recovery rolls the exact pending record forward into the head before W51 compares CAS. A second writer carrying the pre-interruption CAS therefore fails `staleWriterCAS` and must re-observe.

### Head written, pending marker remains

W50 confirms the exact record/head relationship and removes only the stale marker. CAS then reflects the committed writer.

### Corrupt/ambiguous pending state

Fail closed. W51 does not use concurrency serialization to guess which candidate should win.

## Race acceptance criteria

For N contenders all using one predecessor CAS:

- exactly one candidate may commit;
- all later contenders must observe a stale CAS or an already-committed duplicate identity;
- the ledger sequence advances by exactly one;
- no orphan/fork record is accepted;
- the resulting W49/W50 ledger root must be identical to a non-concurrent W50 append of the same certificate/custody from the same predecessor.

## Validation performed in W51

- Standalone writer lock compiled with Swift 6.2.1 and warnings-as-errors.
- Concurrent store production source typechecked with contract-shaped stubs and warnings-as-errors.
- Same-process live stress: 100 waves × 24 contenders = 2,400 attempts; 100 commits, 2,300 stale, 0 other errors, final sequence 100.
- Cross-process live stress: abandoned lock-file recovery PASS, then 80 waves × 12 processes = 960 race attempts; 80 commits, 880 stale, 0 lost updates; final sequence 81 including seed.
- Lock-path substitution failed closed with token/inode mismatch.
- CAS/post-commit mutation mirror: 200,000/200,000 detected across eight mutation classes.

The Worker container could not execute the exact repository SwiftPM suite because `git ls-remote` failed with `Could not resolve host: github.com`. HQ must run canonical SwiftPM/XCTest after W51 semantic integration.

## External gates not satisfied

W51 does not prove physical-iPhone/APFS power-loss durability, Apple attestation, rights-cleared real-audio execution, genuine Lane-2 decode integration, current-iPhone Moises reference/differential evidence, blind review, or final PARITY_MATRIX judgment.
