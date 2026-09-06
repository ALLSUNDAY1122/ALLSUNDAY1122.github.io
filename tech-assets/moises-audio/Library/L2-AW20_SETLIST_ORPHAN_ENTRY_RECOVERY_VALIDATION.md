# L2-AW20 Low-Level Setlist Orphan Entry Recovery Validation

Result: `COMPLETED_NON_PARITY`

## Scope

Lane 2 only. This wave closes the AW18 residual gap where a raw Core Data `SetlistEntryRecord` can survive while its owning `SetlistRecord` no longer exists. Such rows are invisible to the frozen `ProjectLibraryPersisting.listSetlists()` snapshot and therefore could not be repaired by AW18's public-surface reconciler.

No `Shared/**`, `App/**`, `PARITY_MATRIX.json`, Queue, work-package, lane-plan, resource-lock, Core Data model-version, or migration schema change is made.

## Fresh canonical state

Before selection the Worker re-read:

- Notion Moises v4 canonical;
- Worker contract SHA `c9e8ec5d191108db6eb20fbd40db0dab3c46b725`;
- Work Package SHA `aad7983bdaf315a996dce1496ed245008085c712`;
- Lane Plan SHA `10b595b47e5a71278bde32e8656bd284e14e62eb`;
- Worker-2 status blob `de4d397f4ecbbbeff0ffb36dd6f9c2f2f5338c4f`;
- Resource Lock SHA `0c303a05ffcc21aa5d2a237cff75619010afdc46` at integration epoch 14 / assignment epoch 2;
- PARITY ledger SHA `db98892a379180c25ffeb3586a7c3353620a2d5d`;
- Worker branch head `44d2d658aeaab8f052551259fb7691b884749300`, identical to the AW19 status commit.

`MOI-P018` remained `MISSING`; portable/store hardening is not final setlist parity.

## Problem confirmed

AW18 repairs visible setlists by removing dead-project references and normalizing positions. However, `listSetlists()` starts from `SetlistRecord` rows and fetches only entries for those IDs. If an old/migrated/abnormal database contains a `SetlistEntryRecord` whose `setlistUUID` has no parent `SetlistRecord`, that row is not represented in any public `SetlistSnapshot` and AW18 cannot see it.

The normal current delete path already deletes entries before deleting a setlist. AW20 therefore treats this as legacy/abnormal-state convergence, not as a replacement for the normal transaction.

## Production change

### Portable ownership policy

`SetlistOrphanEntryRecovery.swift` adds a Foundation-only policy over `(entryUUID, setlistUUID)` ownership pairs.

It:

- selects only entries whose `setlistUUID` is absent from the live setlist-ID set;
- preserves every entry owned by an existing setlist;
- does not inspect/project-deduplicate repeated songs;
- fails closed on duplicate entry identity;
- provides an explicit post-repair convergence check.

Ordering, dead-project cleanup, and position normalization remain AW18 responsibilities.

### Core Data low-level pass

`CoreDataProjectLibraryStore.reconcileOrphanSetlistEntries()` runs on the existing private writer context:

1. fetch all `SetlistRecord` identities with the existing enumeration batch policy;
2. fail closed if parent identity itself is ambiguous;
3. fetch raw `SetlistEntryRecord` rows, including rows invisible to public setlist snapshots;
4. build the portable ownership plan;
5. delete only exact orphan `entryUUID` rows;
6. save once through the existing Core Data transaction path;
7. re-fetch raw entries and require convergence before reporting success.

Malformed UUID values or ambiguous entry identities throw before destructive repair. The Core Data model remains `L2-V1`.

### Canonical startup ordering

`CrashSafeProjectLibraryStore.openPreservingUserData(...)` now orders recovery as:

1. preserving Core Data open/migration;
2. interrupted project-delete recovery;
3. AW20 raw orphan-setlist-entry cleanup;
4. AW18 visible setlist dead-project/position reconciliation;
5. expose the opened Library.

The ordering matters: delete recovery establishes the canonical project state first; AW20 removes rows with no setlist parent; AW18 then repairs semantics on only visible surviving setlists.

## Negative / recovery invariants

Validated in portable policy/tests:

- clean entries produce no repair;
- missing-parent entries are selected exactly;
- zero live setlists makes all existing entries orphan candidates;
- duplicate `entryUUID` fails closed;
- post-repair convergence rejects any remaining orphan;
- multiple entries pointing to the same valid setlist are preserved;
- 100,000-entry / 10,000-setlist planning with 5,000 orphan entries converges.

The actual Core Data method additionally read-backs after save instead of trusting the requested deletion.

## Portable execution

Environment: Swift 6.2.1 Linux.

PASS:

- `SetlistOrphanEntryRecovery.swift` strict-concurrency + warnings-as-errors module compile;
- `SetlistOrphanEntryRecoveryTests.swift` strict XCTest typecheck;
- exact production Core Data method shape strict-typechecked against contract-equivalent Core Data stubs;
- `CrashSafeProjectLibraryStore+Recovery.swift` syntax parse;
- startup ordering audit: `L2_AW20_STARTUP_AUDIT_PASS checks=4/4`;
- exact committed self-check source blob `e9047ae2e2a5e50252b02afbac46e966d74b682a` rerun: `L2_AW20_SELF_TEST_PASS scenarios=8 entries=100000 setlists=10000 orphans=5000 elapsed_seconds=0.248722`.

The 0.248722 s result is a Linux in-memory policy benchmark, not SQLite/Core Data/iPhone performance.

Apple-gated `CoreDataSetlistOrphanEntryRecoveryTests.swift` was added for in-memory Core Data execution when an Apple test environment is available. It verifies the no-op/idempotent path and preservation of repeated valid entries, but it was not executed on Linux because Core Data is unavailable there.

## Remote read-back

Validated Git blobs:

- portable policy: `bea2361a994e4288a6782ec83ba312e084cc0901`;
- portable XCTest: `e3ba792bef15f477f9218cd7e277734d38e6e49c`;
- self-check: `e9047ae2e2a5e50252b02afbac46e966d74b682a`;
- Core Data production store: `ffb787c2a533663414340b4c7092b3cc59d95fc8`;
- canonical startup wiring: `05d898345319a3f38d551548efe8c76bbba099f2`;
- Apple-gated Core Data tests: `247f6d647c1afb3aab2f54b6fa073f24e6812792`.

The Core Data production commit diff was inspected and contained only the AW20 method insertion; no unrelated portion of the 45 KB store was rewritten semantically.

## Important boundaries

- Real Apple Core Data/SQLite execution of an intentionally corrupted store containing a true orphan `SetlistEntryRecord` remains unverified. Producing such a fixture safely requires Apple/Core Data execution; Linux portable evidence is not counted as that gate.
- The startup pass assumes canonical open completes before interactive setlist editing is exposed. Multi-process/extension concurrent mutation during the recovery transaction is not claimed as validated.
- The current implementation materializes raw entry object references plus ownership pairs for the startup pass. `fetchBatchSize` controls Core Data fault loading but is not a proof of bounded O(1) memory; real large-library RSS remains an Apple benchmark gate.
- AW18 still needs real SQLite reopen and forced-termination evidence for ordering/dead-project repair.
- No PARITY row is promoted by AW20. Current-Moises create/reorder/use flow and integrated iPhone evidence remain HQ-owned gates for `MOI-P018`.

## HQ integration requirements

1. Keep `CrashSafeProjectLibraryStore.openPreservingUserData(...)` as the canonical startup path and do not expose setlist editing until the full recovery chain completes.
2. On Apple, build a controlled SQLite/Core Data fixture with a valid setlist plus a raw entry whose `setlistUUID` has no parent; verify AW20 removes only the orphan and survives reopen.
3. Force terminate around startup repair/save/reopen and verify idempotent convergence.
4. Measure startup time/RSS with representative 1k/10k+ projects and high setlist-entry counts; do not interpret the Linux 100k policy benchmark as device performance.
5. Preserve repeated project references in setlists unless current-iPhone Reference proves a different product rule.
6. Do not promote `MOI-P018` from AW20 portable evidence; final PARITY remains HQ-owned.
