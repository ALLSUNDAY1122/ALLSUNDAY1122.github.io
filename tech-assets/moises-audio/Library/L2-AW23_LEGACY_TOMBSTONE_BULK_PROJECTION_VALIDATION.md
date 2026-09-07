# L2-AW23 Legacy Tombstone Bulk Projection Validation

Result: `COMPLETED_NON_PARITY`

## Scope

Lane 2 only. AW22 removed the global tombstone candidate scan from steady-state recovery, but the first pre-AW22 compatibility pass still used `CoreDataProjectLibraryStore.listTombstonedProjectCompactionCandidates()`, whose legacy implementation performs one root tombstone fetch plus one source-asset fetch and one stem fetch per tombstoned project (`~1 + 2N`). AW23 removes that N+1 pattern from the canonical compatibility-open routes without changing deletion semantics, Core Data schema, Shared/App contracts, or PARITY.

Fresh canonical state at wave start:

- assignment epoch: `2`
- planning revision: `4`
- integration epoch: `18`
- Worker branch start/status commit: `aff34690293954c43c38571ac8f96822ae26be5a`
- prior Worker status blob: `3d9685b9f05f6ef394934076a052087ae7038cd6`
- resource-lock SHA: `c7ce95cb0a0f1eb245010acbbff3cacdf3f4cbec`
- PARITY SHA: `db98892a379180c25ffeb3586a7c3353620a2d5d`
- MOI-P017/MOI-P024 and all other Lane-2 PARITY rows remain `MISSING`.

## Portable projection policy

`LegacyTombstoneProjection.swift` defines the pure bulk materialization shape. For each `LibraryEnumerationPolicy` batch it receives project identity/source-asset rows, source assets, and stem paths, then reconstructs the exact existing `Lane2TombstonedProjectCompactionCandidate` semantics. Missing source assets and duplicate asset identity fail closed.

Logical fetch-call upper bound for `N` tombstones and batch size `B` is:

`1 + 2 * ceil(N / B)`

instead of the old compatibility shape:

`1 + 2N`.

With the default `B=128`, 100,000 tombstones have a structural upper bound of 1,565 logical Core Data fetch calls instead of 200,001. This is a code-shape bound, not an observed SQLite query count.

## Read-only bulk compatibility migrator

`LegacyTombstoneBulkMigrator.swift` prepares AW22 ownership evidence before destructive recovery:

1. If `.LibraryRecovery/DeleteOwnership/.legacy-scan-v1-complete` already exists, return immediately.
2. Reconstruct the current `L2-V1` managed-object model and compare `entityVersionHashesByName` against `NSStoreModelVersionHashesKey` from the SQLite store. A mismatch fails closed.
3. Open the SQLite store read-only.
4. Dictionary-fetch tombstoned `projectUUID/sourceAssetUUID` fields once.
5. Process those rows in bounded `LibraryEnumerationPolicy` batches.
6. Per batch, fetch required `AssetRecord` rows once and `StemRecord` rows once using `IN` predicates.
7. Materialize existing tombstone-compaction candidates and atomically persist AW22 `DeletionOwnershipIndex` records.
8. Write the existing legacy-complete marker only after every tombstone received durable ownership evidence.

A crash before step 8 causes a safe idempotent retry. Identity conflicts, corrupt values, model-hash mismatch, unsafe paths, or missing source assets prevent the completion marker.

The bulk scanner is read-only with respect to Core Data. Destructive file/metadata cleanup remains the existing AW21/AW22 crash-safe state machine after ownership indexing.

## Canonical opening routes

`openPreservingUserData(...)` now performs:

`preserving Core Data open/migration -> AW23 bulk legacy ownership preparation -> AW22/AW21 delete recovery -> AW20 raw setlist orphan repair -> AW18 visible setlist repair`.

For callers that do not use `PreservingCoreDataStoreOpener`, AW23 adds `openBulkPrepared(...)`, which opens Core Data, performs the same bulk compatibility preparation using that configuration's enumeration batch size, and only then enters CrashSafe delete recovery.

The older `CrashSafeProjectLibraryStore.open(...)` signature and the old per-project Core Data candidate method remain for source compatibility/defensive fallback. They are not the approved product integration path after AW23. HQ/App must use `openPreservingUserData(...)` or `openBulkPrepared(...)`.

## Validation

Portable / Linux validation:

- `LegacyTombstoneProjection.swift` Swift 6 strict-concurrency + warnings-as-errors compile: PASS.
- `LegacyTombstoneProjectionTests.swift` strict XCTest typecheck: PASS.
- `LegacyTombstoneBulkMigrator.swift` syntax parse: PASS. Its Core Data branch cannot be executed on Linux.
- `LegacyTombstoneBulkMigratorTests.swift` Apple-gated syntax parse: PASS; actual Core Data execution is not counted as PASS.
- production wiring/static audit: `L2_AW23_STATIC_AUDIT_PASS checks=12/12`.
- exact committed projection blob: `f4f2f791d99be8e4fe9d360beea5782084129761`.
- exact committed bulk migrator blob: `a4ee00e3d8cdb9f9416265652308c372e907ce67`.
- exact committed self-check blob: `e74c9a8708a1f967c358418052e89cf14f41321e`.
- exact committed self-check rerun:
  `L2_AW23_SELF_TEST_PASS scenarios=5 projects=100000 batch_size=128 logical_fetch_upper_bound=1565 legacy_n_plus_one=200001 elapsed_seconds=0.511922`.

The 0.511922-second value is a Linux in-memory projection microbenchmark only. It is not SQLite, APFS, iPhone launch, RSS, thermal, or battery evidence.

## Apple-gated tests prepared

`LegacyTombstoneBulkMigratorTests.swift` prepares actual Apple coverage for:

1. 40 pre-AW22-style tombstones across three 16-project batches, including one source `AssetRecord` shared by all projects and two stems/project; expected logical fetch bound `7` versus legacy `81`, 40 ownership records, then durable completion marker and idempotent skip on the second call.
2. A conflicting pre-existing ownership record must throw and must not write the legacy-complete marker.

Actual Apple Core Data/SQLite compile and execution remain pending and are not represented as PASS.

## Remaining gates

- Apple compile/run of the read-only duplicate-model scanner and `NSStoreModelVersionHashesKey` equality check against a real `L2-V1` store;
- observed SQLite fetch/query count before/after AW23 on a large pre-AW22 tombstone backlog;
- iPhone launch latency and RSS for the first compatibility pass;
- force termination during batch ownership writes and immediately before/after the completion marker;
- APFS durability and ENOSPC during ownership-index writes;
- bulk scanner currently materializes the root tombstone dictionary array before per-related-record batching; extremely large historical backlogs still require Apple RSS evidence;
- physical metadata compaction after indexing is still per-project and can dominate a very large one-time migration even though candidate discovery is now batch-bounded;
- direct use of legacy `CrashSafeProjectLibraryStore.open(...)` or raw `CoreDataProjectLibraryStore` is not an approved App route;
- current-Moises deletion/privacy differential and full device evidence remain HQ gates.

No PARITY row is promoted from AW23 portable evidence. Final PARITY remains HQ-owned.
