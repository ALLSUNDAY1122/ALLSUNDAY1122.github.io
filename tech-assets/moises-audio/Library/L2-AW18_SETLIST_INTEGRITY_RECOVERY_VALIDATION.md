# L2-AW18 Setlist Integrity Recovery Validation

Result: `COMPLETED_NON_PARITY`

## Scope

Lane 2 only. This wave hardens MOI-P018 setlist persistence/relaunch behavior without changing `Shared/**`, `App/**`, or `PARITY_MATRIX.json`.

## Audit result

The existing Core Data implementation already gives ordinary setlist mutation useful atomicity:

- `replaceSetlistEntries(...)` validates referenced live projects before deleting old entries;
- one private writer context serializes same-store mutations;
- old entries are deleted, new positions `0...N-1` are inserted, and one Core Data save commits the replacement;
- duplicate project references are intentional and covered by the existing `CoreDataProjectLibraryStoreTests` contract;
- `deleteProject(...)` removes affected setlist entries and compacts survivors in the same metadata transaction.

The remaining Lane-local gap was relaunch convergence when legacy/migrated/abnormal metadata contains a setlist entry pointing at a non-live project or non-canonical positions such as gaps, collisions, or negative values. Before AW18 there was no startup repair pass for that state.

## Production change

### Portable deterministic policy

Added `SetlistIntegrityRecovery.swift` with:

- `Lane2SetlistIntegrityPolicy`;
- `Lane2SetlistIntegrityReconciler`;
- portable snapshot/entry/report types;
- a narrow `Lane2SetlistIntegrityStore` adapter protocol.

Policy rules:

1. repeated `projectUUID` values are preserved; repeated songs are valid setlist content;
2. duplicate `entryUUID` is ambiguous corruption and fails closed;
3. dead/non-live project references are removed;
4. surviving entries are deterministically sorted by stored `position`, then `entryUUID` as a stable tie-breaker;
5. positions are rewritten to contiguous `0...N-1`;
6. after any rewrite, the reconciler re-reads live projects and setlists and requires every surviving entry to be live and canonically positioned.

Each setlist replacement remains one existing atomic Core Data mutation. A process death between repair of two different setlists can leave a partially repaired library, but the next startup safely repeats the idempotent reconciliation.

### Production adapter

Added `CrashSafeProjectLibraryStore+SetlistIntegrity.swift` to adapt the frozen `ProjectLibraryPersisting` surface into UUID-only reconciliation inputs and call the existing `replaceSetlistEntries(...)` mutation.

No Shared protocol change was required.

### Canonical startup wiring

Updated `CrashSafeProjectLibraryStore.openPreservingUserData(...)` ordering to:

1. preserving Core Data open/migration;
2. interrupted project-delete recovery;
3. setlist integrity reconciliation against the resulting live-project set;
4. return the production library.

Delete recovery intentionally runs first so a project whose tombstone becomes authoritative during recovery is removed from setlists in the following reconciliation pass.

## Negative / recovery cases validated

- duplicate project references remain unchanged;
- dead project reference is removed and survivors compact;
- negative/gapped positions normalize;
- equal positions use deterministic entry identity tie-break;
- duplicate entry identity fails closed;
- canonical verification rejects gaps and dead references;
- full reconciler rewrites and then read-backs/verifies the persisted shape;
- duplicate setlist identity in an adapter snapshot fails closed;
- 100,000-entry planning benchmark completes without quadratic behavior.

## Portable execution

Environment: Swift 6.2.1 Linux.

PASS:

- `SetlistIntegrityRecovery.swift` strict-concurrency/warnings-as-errors compile;
- `SetlistIntegrityRecoveryTests.swift` strict XCTest typecheck;
- CoreData-gated adapter/startup files syntax parse;
- startup static wiring audit `4/4` PASS;
- executable self-check: `L2_AW18_SELF_TEST_PASS scenarios=8 entries=100000 elapsed_seconds=1.751035`.

The benchmark is a Linux CPU/memory planning measurement over UUID records. It is not SQLite/Core Data/iPhone performance evidence.

## Important boundaries

- Linux cannot execute Core Data; actual SQLite transaction/reopen behavior remains an Apple runtime gate.
- `openPreservingUserData(...)` is the canonical production startup path that receives AW18 repair. Legacy/non-preserving construction paths do not automatically run this new pass.
- The recovery pass is intended before the library is exposed to interactive UI mutation. It does not add a cross-process compare-and-swap revision token for multiple independent Core Data coordinators.
- Arbitrary low-level database corruption that creates a `SetlistEntryRecord` whose `setlistUUID` has no corresponding setlist is not discoverable through the frozen public setlist snapshot contract and remains an Apple/CoreData low-level recovery candidate.
- MOI-P018 remains `MISSING`. Portable persistence/recovery evidence does not establish current-iPhone comparable setlist UX or differential parity.

## HQ integration requirements

1. Keep `CrashSafeProjectLibraryStore.openPreservingUserData(...)` as the production startup path.
2. Run the Core Data tests on Apple and add explicit reopen tests for dead-reference/gap repair.
3. On iPhone force-terminate around project delete/reopen and setlist repair; verify repeated songs remain repeated and survivor ordering converges.
4. Verify actual current-Moises setlist create/reorder/use behavior and operation count before promoting MOI-P018.
5. Do not run startup reconciliation concurrently with an already-exposed interactive setlist editor.
6. Do not promote MOI-P018 from Lane-2 portable evidence alone.
