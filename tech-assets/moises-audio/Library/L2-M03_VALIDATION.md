# L2-M03 Validation — migration / corruption / user-data preservation

Captured: 2026-08-22 JST  
Lane: `LANE-2-IO-LIBRARY`  
Branch: `moises/wp2-io-library`  
Frozen epoch contract: `a5389c8ffba6c1186a076b0c0ab3ee560aad5c8f`

## Bundle goal

Implement migration/corruption recovery with an explicit invariant: **an existing user metadata store is never silently destroyed, replaced with an empty store, or migrated in-place as the only copy.**

L2-M03 does not claim MOI-P017/P018/P020 PARITY. Apple Core Data runtime and integrated iPhone interruption evidence remain later gates.

## Implementation

### `LibraryStoreRecovery.swift`

Foundation-only recovery layer:

- inspects the main SQLite header before Core Data open;
- generates machine-readable `LibraryStoreRecoveryPlan` with `destructiveResetAllowed = false` in every state;
- snapshots the complete known store family (`.sqlite`, `-wal`, `-shm`, `-journal`) before migration;
- writes a versioned manifest containing byte counts and deterministic FNV-1a content fingerprints;
- validates snapshot integrity before it can become a migration source;
- creates an isolated working copy for migration;
- exports a corruption recovery package by **copy**, never move/delete;
- activates a successful migrated generation through `Recovery/active-store.json` rather than overwriting the preserved original;
- validates active-store paths remain under the recovery root.

The recovery manager intentionally exposes no API for destructive reset of the original store.

### `PreservingCoreDataStoreOpener.swift`

Apple/Core Data safe-open policy:

1. If a verified active generation exists, open and validate it.
2. If no original store exists, create the first store normally.
3. If the original header is corrupt/unreadable, export the original store family and return an explicit recovery failure. Do not create a replacement database.
4. If an original store exists:
   - snapshot original;
   - clone snapshot to working copy;
   - let Core Data perform inferred migration on the working copy only;
   - read the migrated project/setlist surfaces as validation;
   - close the working coordinator;
   - activate a copied generation and atomically write only the active-pointer manifest;
   - retain the original and the pre-migration snapshot.
5. If working-copy migration fails, return `migrationFailed` with paths to the preserved snapshot and failed candidate. The original is unchanged.

### `CrashSafeProjectLibraryStore+Recovery.swift`

Adds the production composition entry point:

`CrashSafeProjectLibraryStore.openPreservingUserData(...)`

This composes the L2-M03 preserving metadata open with the L2-M02 tombstone/artifact recovery facade, so library startup does not require Shared/App changes.

## Versioned migration fixture

`PreservingCoreDataStoreOpenerTests.swift` defines `LegacyV0Fixture` with version identifier `L2-V0-legacy-fixture` and a reduced historical schema. The Apple test creates real Core Data SQLite metadata with a project/source, then opens it through the preserving path and verifies:

- migrated data is readable under the current L2 model;
- the active store path is a recovery generation, not the original path;
- original bytes remain unchanged;
- the pre-migration snapshot remains available.

This fixture is Apple/Core Data gated and must be executed by late integration in an Apple SDK environment.

## Corruption / migration failure fixtures

Apple-gated tests also cover:

- valid SQLite header + invalid database body -> migration failure, original bytes preserved;
- invalid header -> recovery package exported, no empty replacement store created.

Portable tests cover:

- migration candidate mutation never changes original bytes;
- active-pointer promotion preserves original bytes and store family;
- corruption export preserves original and yields a verifiable package;
- tampered recovery snapshot fails closed;
- recovery plans never authorize destructive reset.

## Executed evidence in current environment

Environment: Swift 6.2.1, x86_64 Linux.

PASS:

- `swiftc -typecheck LibraryStoreRecovery.swift`
- `swiftc -typecheck LibraryStoreRecovery.swift LibraryStoreRecoveryTests.swift -module-name MoisesLibraryRecoveryTests`
- executable filesystem self-check covering missing/current/corrupt plans, store-family snapshot, working-copy failure preservation, active-generation pointer, corruption export, tampered-snapshot rejection
- conditional parse/typecheck of preserving Core Data opener, crash-safe recovery composition, and Core Data fixture tests on Linux (`#if canImport(CoreData)` body not executed)
- static destructive-reset scan: no `destroyPersistentStore`, no original `removeItem(at: storeURL)`, no original-path replacement API in L2-M03 sources

Self-check result:

`L2-M03 recovery self-check PASS`

Static policy result:

`L2-M03 destructive-reset static scan PASS`

## Explicitly not claimed

- Apple Core Data legacy migration runtime PASS is not claimed on Linux.
- iOS termination during Core Data migration is not yet device-tested.
- user-facing recovery/export UI belongs to App/iOS late integration; Lane 2 exposes deterministic recovery paths and package locations only.
- a cryptographic digest is not claimed; FNV-1a is used only as a deterministic accidental-corruption/tamper fingerprint for local recovery package validation.
- no PARITY state is changed by this bundle.

## Destructive reset policy

Forbidden automatically:

- deleting a corrupt store and silently creating a new empty store;
- deleting an old store because migration inference fails;
- moving the only user store into quarantine without leaving the original in place;
- overwriting the original store with the migration candidate before candidate validation;
- clearing recovery snapshots merely because the app can open a fresh database.

A future explicit user-initiated reset/recovery UX may be designed by HQ/App, but L2 persistence code must never perform it silently.

## Scope audit

L2-M03 implementation/test/evidence changes are under `tech-assets/moises-audio/Library/**` only. Worker status is the only permitted non-Library file updated at bundle completion.
