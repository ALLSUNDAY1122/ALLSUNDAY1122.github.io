# L1-A14 Validation — Atomic Multi-Stem Result Transaction

Captured: 2026-08-23 JST  
Worker: `Moises-Worker-1`  
Branch: `moises/wp1-separation-processing`  
Result: `COMPLETE_NON_PARITY`

## Goal

Prevent a partial, stale, corrupted or ambiguously promoted stem set from becoming project-visible as a completed separation result. A project result is committed only after every required stem has been downloaded/verified, bound to an exact role-to-SHA set, atomically promoted, re-verified in the final directory and durably represented by a committed ledger.

## Reused foundation

A14 deliberately extends rather than replaces the existing M03/A13 assurance path:

- M03 already downloads provider outputs into project-controlled staging.
- M03 binds sample metadata, size and SHA-256 to `VerifiedSeparationOutput`.
- A13 performs deep WAV/container/sample and cross-stem integrity validation.
- Existing result commit already used an incoming/final/backup directory swap.

The missing production-hardening gap was the transaction window around that swap: a process crash could leave a complete new final directory while the ledger still said `prepared`, scratch recovery was not phase-bound, and a verified local set could incorrectly become dependent on an expired signed provider URL during later commit.

## Implementation

### `Separation/Sources/SeparationCommitTransaction.swift`

Adds a durable transaction journal with these phases:

1. `assemblingIncoming`
2. `incomingVerified`
3. `promotionReady`
4. `finalPromoted`

The journal binds:

- project ID
- processing job ID
- exact expected filenames
- exact SHA-256 per filename
- creation/update timestamps

The transaction does not touch an existing project final until the entire incoming directory exactly matches the expected filename/hash set. Missing files, extra files, hash mismatches, symlinks or journal identity mismatch fail closed.

Relaunch recovery is state-driven:

- complete final + `prepared` ledger -> verify exact hashes and finish ledger commit;
- complete incoming + `prepared` ledger -> promote without provider re-download;
- incomplete incoming + protected backup -> restore previous final and keep verified staging for retry;
- committed ledger -> final must still exactly match before stale scratch is removed;
- deleted ledger + backup -> fail closed rather than resurrecting or destroying ambiguous user data;
- no ledger + no backup -> orphan staging/incoming/journal are removed;
- no ledger + backup -> backup is preserved and recovery fails closed.

### `Separation/Sources/SeparationOutputAssurance.swift`

`commit()` now performs:

`recover -> prepared ledger verification -> exact incoming assembly -> journal -> incoming hash-set verification -> protected old-final backup -> final promotion -> final hash-set verification -> committed ledger save -> scratch cleanup`

The committed ledger is therefore the publication point. A filesystem directory appearing before that ledger save is not treated as a completed project result.

### Signed URL expiry boundary

A14 separates remote acquisition validity from local commit validity.

- Before download, `validateManifest(... requireFreshOutputURLs: true)` remains mandatory.
- After every stem has already been downloaded and verified into the durable `prepared` set, commit uses `requireFreshOutputURLs: false` while retaining all non-expiry schema/provider/cost/retention/audio metadata checks.

This avoids a false dependency on an already-expired signed vendor URL when the complete verified local bytes are present. Conversely, if no trusted local verified set exists, an expiring/expired remote URL still fails before download with `SEP_OUTPUT_URL_EXPIRING` and must be refreshed/re-fetched through provider semantics.

### `Separation/Sources/AssuredSeparationProvider.swift`

`result()` now checks trusted local identity, performs transaction recovery, and consumes a recovered/committed/prepared local set before requiring fresh remote URLs. Provider/model/role/stem identity mismatch is still rejected before recovery can mutate local state.

### Deletion/privacy preservation

A14 introduces new scratch locations, so it also preserves the earlier A09 privacy guarantees:

- orphan job staging is cleaned when no ledger exists;
- committed deletion removes transaction scratch only after final hash-set identity is proven;
- prepared deletion restores a job-specific protected previous final if one was displaced;
- if no previous final exists, an exact-hash uncommitted candidate final is removed;
- staging/incoming/journal are then removed before the ledger is marked deleted.

Implementation: `Separation/Sources/SeparationTransactionDeletion.swift`.

## Fault / recovery verification

Swift 6.2.1 (`x86_64-unknown-linux-gnu`) lane-local strict-concurrency fault harnesses were run against the A14 transaction semantics.

- Atomic transaction/relaunch fault model: **14/14 PASS**
- Local-verified vs signed-URL-expiry boundary: **2/2 PASS**
- Prepared-transaction deletion/backup preservation: **2/2 PASS**
- Total executed scenarios: **18/18 PASS**

Coverage includes:

- happy exact multi-stem commit;
- crash/failure after final promotion but before committed-ledger save;
- complete incoming recovery after staging loss;
- incomplete incoming rollback to the protected prior final;
- extra incoming file rejection;
- journal corruption/identity mismatch;
- orphan scratch cleanup and orphan backup protection;
- committed final tamper rejection;
- deleted-state backup ambiguity protection;
- replacement of an existing final only after complete incoming verification;
- successful local commit after signed provider URL expiry when every stem is already verified;
- pre-download expiry rejection when no local verified set exists;
- prepared transaction deletion restoring an old final;
- prepared transaction deletion removing an uncommitted new final when no old final exists.

The repository also contains a focused durable regression harness:

`Separation/Tests/L1_A14_AtomicTransactionSelfTest.swift`

It records ten critical scenarios using the real Lane 1 interfaces. The broader standalone fault models above were used for the executed Swift 6 stress matrix in this Wave; the checked-in test remains available for the repository's Apple/Swift integration harness without requiring Worker 1 to modify Worker 4-owned `Package.swift`.

Machine-readable specification/evidence:

`Processing/Tests/L1-A14_ATOMIC_TRANSACTION_MATRIX.json`

## What A14 does not prove

A14 is not real-device or real-provider PARITY evidence. Remaining external/next-wave checks include:

- actual iPhone process kill / OS termination / device power-loss during filesystem rename and atomic ledger write windows;
- disk-full behavior with genuinely large multi-stem payloads (continued in A15/A17);
- real provider output URL refresh/re-sign behavior when a local complete set does not exist;
- actual multi-genre separation quality and current-iPhone Moises differential listening;
- cross-lane App/Library publication semantics after HQ Late Integration.

## PARITY

`parity_state = NON_PARITY_EVIDENCE_ONLY`.

P003/P004/P005/P020/P021 remain unchanged. A14 closes the Lane 1 atomicity/relaunch transaction design gap; it does not supply the real provider/audio/device evidence required for HQ PARITY promotion.
