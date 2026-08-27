# L4-W51 Validation｜Concurrent W50 secure-ledger writer serialization

## Result

W51 closes the known W50 same-ledger multi-writer race for cooperating writers by adding two independent controls:

1. an authoritative writer lease combining same-process serialization and OS advisory `flock`; and
2. an append CAS that pins the exact predecessor sequence, ledger root, and latest record root.

A writer that waited behind another writer does not continue from its old view. After acquiring the lease it recovers/reopens W50 state and must match the exact predecessor CAS or fail `staleWriterCAS` before any new pending candidate is published.

## Canonical context refreshed before work

Notion and integration PR #4431 show HQ Canonical Epoch 41 as `L1 A23 / L2 AW47 / L3 AW47 / L4 W50`. W50 was already semantic-integrated at `b90defce6f3f84a188037cfa8df0c6f3b0f1186e`; HQ Run `33026135591` passed SwiftPM 446/446. Therefore W51 is built on a canonically tested W50 base rather than treating the Worker container's earlier DNS limitation as a W50 product failure.

## Production implementation

### `AnalysisPhysicalRealAudioBridgeConsumptionWriterLock.swift`

- per-root/per-ledger in-process `NSLock` registry;
- blocking cross-process `flock`;
- `O_NOFOLLOW | O_CLOEXEC` lock open;
- persistent lock file so process crash does not require a stale-file deletion protocol;
- per-acquisition UUID token;
- descriptor/path device + inode continuity checks;
- token validation before/after the critical section and again while propagating body errors;
- lock directory root-confinement and no-symlink validation.

### `AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.swift`

- `observeAppendCAS` serializes recovery + secure reopen before returning the predecessor token;
- `append` requires a well-formed CAS for the exact ledger;
- after lock acquisition, W50 recovery occurs before CAS comparison;
- any predecessor change fails `staleWriterCAS` before publication;
- successful append must advance exactly one sequence;
- predecessor prefix ledger root and predecessor record root are recomputed/checked;
- bridge ID, W48 certificate root, W47 package root and W46 adjudication report root are checked against the appended record;
- final W50 secure reopen must equal the returned head;
- serialized consumed-root inventory is available for future W48 expectation construction.

W51 does not change W49/W50 ledger record/root formats. The lock file lives outside each ledger directory under `.writer-locks`, so evidence roots remain stable.

## Durable XCTest source

`AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStoreTests.swift` covers:

- two simultaneous different writers sharing one CAS → exactly one commit and one stale writer;
- duplicate certificate rejection remains active when using a fresh CAS;
- interrupted writer after record publication is recovered first, causing a second writer with the old CAS to fail stale;
- pending-only interrupted writer rolls back, allowing an unchanged CAS to proceed;
- abandoned but unlocked lock-file payload is reusable;
- lock pathname/inode substitution while the lease is held fails closed;
- W51 serialized append produces the exact same W49/W50 on-disk head/root as direct W50 append;
- malformed CAS is rejected before ledger publication.

## Executed validation

### Canonical Worker SwiftPM/XCTest

`NOT_OBSERVED` in this Worker container. `git ls-remote https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io.git HEAD` failed before SwiftPM with `Could not resolve host: github.com`.

This does not invalidate the already integrated W50 result, and it is not counted as a W51 PASS. HQ must execute the full exact W51 suite after semantic integration.

### Source-shaped Swift type validation

Swift 6.2.1:

- full W51 writer-lock source compiled with `-warnings-as-errors`: PASS;
- W51 writer-lock + concurrent-store production source typechecked against contract-shaped W49/W50 stubs with `-warnings-as-errors`: PASS;
- W51 XCTest source parsed successfully.

### Same-process live concurrency stress

100 waves × 24 concurrent contenders using one predecessor value per wave:

- attempts: 2,400
- commits: 100
- stale: 2,300
- other errors: 0
- final sequence: 100
- lost updates: 0

### Cross-process live concurrency stress

First, an abandoned lock-file payload with no kernel lock was created. The next process acquired the same persistent lock file and committed successfully.

Then 80 waves × 12 processes raced with one expected predecessor per wave:

- race attempts: 960
- commits: 80
- stale: 880
- lost updates: 0
- final sequence: 81 including the abandoned-file seed commit

A process that unlinked/replaced the lock pathname while holding the original descriptor failed closed with `TOKEN_MISMATCH`.

### Adversarial CAS/post-commit mirror

200,000/200,000 mutations detected, 0 undetected. Eight equal classes of 25,000 checks covered:

- ledger ID substitution;
- sequence substitution;
- ledger-root substitution;
- latest-record-root substitution;
- invalid nil/non-nil root shape;
- cross-root substitution;
- post-commit predecessor substitution;
- appended certificate identity substitution.

## Remaining limitations

- W51 is NON_PARITY custody/concurrency hardening.
- Portable `flock` stress does not prove selected-iPhone/APFS power-loss or fsync durability.
- Advisory locking protects cooperating writers; external checkpoint/root validation remains necessary against a writer that intentionally ignores the protocol.
- Whole-directory rollback still depends on HQ retaining the latest checkpoint/handoff root outside the mutable ledger directory.
- W51 does not supply the HQ-approved rights-cleared corpus, genuine integrated Lane-2 bounded decoder, selected physical iPhone, current-iPhone Moises reference/differential, physical performance evidence, or final HQ review required for P009/P011/P013/P016/P021.
