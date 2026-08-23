# L2-M02 — Library destructive-operation / crash-safety validation

Captured: 2026-08-22 JST
Lane: `LANE-2-IO-LIBRARY`
Bundle: `L2-M02`
Frozen epoch-2 integration contract: `a5389c8ffba6c1186a076b0c0ab3ee560aad5c8f`

## Result

L2-M02 implements a crash-safe file lifecycle around the L2-M01 Core Data adapter without editing Shared/App/Queue/PARITY or another Lane.

The production composition is `CrashSafeProjectLibraryStore` wrapping `CoreDataProjectLibraryStore` plus `LibraryArtifactLifecycle`.

## Delete protocol

Deletion uses four ordered phases:

1. persist a durable **PREPARED** JSON deletion journal containing only the project UUID and app-owned relative artifact paths;
2. commit the existing Core Data project tombstone transaction, which immediately removes the project from live list/load and removes its setlist entries;
3. atomically rewrite the journal to **COMMITTED**;
4. idempotently delete app-owned artifacts and remove the journal only after every file cleanup succeeds.

No file is deleted from a PREPARED journal. This prevents a crash before the metadata tombstone from deleting a still-live project's files.

On relaunch:
- PREPARED + project still live => discard the deletion intent and retain artifacts;
- PREPARED + project no longer live => infer that the tombstone committed, promote journal to COMMITTED, and finish cleanup;
- COMMITTED => finish cleanup idempotently;
- missing files are treated as already-clean;
- malformed journals fail closed and remain available for diagnosis.

## Artifact atomicity

`LibraryArtifactLifecycle.promoteReadyArtifact` requires a non-empty regular staging file, refuses overwrite of an existing final path, creates the final parent directory, moves the ready artifact to its final app-owned relative path, and re-validates it after the move.

`CrashSafeProjectLibraryStore` refuses `createProject` or `recordStems` when the source/stem final artifact is missing or empty. Therefore the crash-safe facade does not commit new metadata that points at an incomplete result artifact.

The underlying L2-M01 adapter remains unchanged and can still be tested independently. Late integration should compose the crash-safe facade for production Library use.

## Shared-reference safety

Before deleting project files, the facade enumerates other live project snapshots and excludes any source/stem relative path still referenced by another live project. Deleting one project therefore cannot remove a shared imported source used by another live project.

## Orphan sweep

The file lifecycle provides a grace-period orphan sweep restricted to app-owned managed roots (`Imports`, `Stems`, `Exports`). It removes only files that:
- are not referenced by any live project metadata;
- are regular files;
- are older than the configured grace period.

Referenced files, young files, recovery journals, and paths outside managed roots are retained.

## Negative / edge coverage

Committed tests cover:
- PREPARED journal cannot delete;
- COMMITTED journal survives reconstruction/relaunch;
- repeated cleanup is idempotent;
- PREPARED intent can be discarded while retaining a live artifact;
- empty staging result cannot be promoted or exposed;
- existing final artifact cannot be overwritten silently;
- path traversal is rejected for read/delete/promote lifecycle operations;
- old orphan removal retains referenced and young files;
- tombstone committed while journal is still PREPARED is recovered on reopen;
- partial file cleanup with a COMMITTED journal resumes on reopen;
- missing source/stem artifacts are rejected before metadata commit;
- deleting one of two projects sharing the same source keeps the surviving project's file.

## Executed evidence in current environment

Current environment: Swift 6.2.1, x86_64 Linux.

Executed:
- `swiftc -typecheck LibraryArtifactLifecycle.swift` => PASS
- `swiftc -typecheck LibraryArtifactLifecycle.swift CrashSafeProjectLibraryStore.swift LibraryArtifactLifecycleTests.swift CrashSafeProjectLibraryStoreTests.swift` => PASS for the portable surface / conditional source parse
- executable filesystem self-check covering traversal rejection, empty-result rejection, no-overwrite promotion, PREPARED non-deletion, COMMITTED relaunch cleanup, idempotent cleanup, live-intent discard, orphan grace/reference behavior, unmanaged-root retention, and corrupt-journal fail-closed behavior => **PASS**
- static scan of `CrashSafeProjectLibraryStore` => all 13 frozen `ProjectLibraryPersisting` methods are present

## Apple-runtime evidence committed but not executed here

`Library/Tests/CrashSafeProjectLibraryStoreTests.swift` uses a real Core Data SQLite store plus a real temporary artifact directory to simulate:
- crash before tombstone (PREPARED + live metadata);
- crash after tombstone but before journal commit;
- crash during partial artifact cleanup;
- metadata visibility rejection for missing artifact files;
- shared-source deletion protection.

Core Data is unavailable in the current Linux environment, so these Apple-runtime tests are committed but not claimed as executed. HQ late integration must run them with the supported Apple SDK / iOS host.

## Metadata tombstone note

The frozen L2-M01 adapter intentionally retains the Core Data tombstone row after file cleanup. The project is not returned by `listProjects` / `loadProject`, and setlist entries are removed. Physical tombstone-row compaction is not required for L2-M02 crash safety and must not occur before cleanup evidence exists; any later privacy-oriented hard purge must preserve the same crash ordering.

## PARITY

No PARITY state is changed by this bundle.

`MOI-P017`, `MOI-P018`, and `MOI-P020` remain `MISSING` until Apple-runtime interruption evidence, integrated iPhone lifecycle evidence, and all corresponding product gates are satisfied.

## L2-M02 commits before this evidence commit

- `bf86b43cd242e9a2aef1b3f71408d394f300670d` — artifact lifecycle
- `5bdf9fca5d48190e07f562844731bda92dacab3d` — crash-safe persistence facade
- `6d986a9e0adb12b1ef0bf7e79692ca63c45509b0` — portable lifecycle interruption tests
- `276463eb3ab84422865acf92ee7720cb7bc12e0e` — Core Data crash/relaunch tests
- `6e534ec93dff64137ccdf81dbe7476a95e6a2c1a` — shared artifact reference protection
- `d23eac193ba6067b9d562294b76e410b685e474d` — shared-reference regression test

## Next bundle

`L2-M03` owns versioned migration, migration-failure preservation, corruption detection/recovery/export path, relaunch recovery-plan generation, and the explicit prohibition of silent destructive reset.
