# L2-M01 — Core Data persistence adapter validation

Captured: 2026-08-22 JST
Lane: `LANE-2-IO-LIBRARY`
Branch: `moises/wp2-io-library`
Frozen epoch contract: `a5389c8ffba6c1186a076b0c0ab3ee560aad5c8f`
Frozen Shared library contract blob: `908cf757ba18d9cc813d9edf063076d775c7c240`

## Macro Bundle goal

Implement the complete Core Data persistence adapter behind the frozen HQ `ProjectLibraryPersisting` contract without editing Shared/App/Queue/PARITY or another Lane.

## Implemented

`Library/Sources/CoreDataProjectLibraryStore.swift`

- programmatic versioned Core Data model (`L2-V1`), so Lane 2 owns the persistence schema without requiring Package/App edits;
- SQLite production store plus in-memory test store;
- serialized private-queue Core Data context; `NSManagedObject` never crosses the adapter boundary;
- project create/list/load mapping;
- processing snapshot upsert and recovery mapping;
- atomic replace of a project's stem metadata set;
- user edit persistence including tempo, pitch, metronome, count-in, loop bounds and ordered stem mix rows;
- setlist create/rename/list/ordered replace/delete;
- contract-level idempotent project tombstone and setlist compaction. Artifact cleanup/orphan recovery is intentionally extended in `L2-M02`;
- only UUIDs, scalar values, timestamps and app-owned relative paths are persisted. No AVFoundation objects, security-scoped URLs, live task handles, model/runtime objects, opaque archive blobs or absolute external URLs are stored.

Private Core Data records:

- `ProjectRecord`
- `AssetRecord`
- `ProcessingRecord`
- `StemRecord`
- `ProjectEditRecord`
- `StemMixRecord`
- `SetlistRecord`
- `SetlistEntryRecord`

`Library/Sources/LibraryPersistencePolicy.swift`

- rejects empty, absolute, traversal, dot-component, duplicate-component and NUL-containing relative paths;
- rejects source/stem scalar corruption;
- rejects cross-project stems and duplicate stem identities;
- rejects duplicate stem-mix identities;
- trims setlist names and rejects blank names;
- maps queued/uploading/separating/finalizing to `resume(jobID:)`, ready to `.none`, cancelled/failed to `.retryRequired`.

## Contract surface coverage

Frozen `ProjectLibraryPersisting` methods implemented:

1. `createProject`
2. `recordProcessing`
3. `recordStems`
4. `listProjects`
5. `loadProject`
6. `saveUserEdits`
7. `createSetlist`
8. `renameSetlist`
9. `listSetlists`
10. `replaceSetlistEntries`
11. `deleteSetlist`
12. `deleteProject`
13. `recoveryPlan`

A source-level surface check confirmed all 13 are present and that the adapter does not use `JSONEncoder`, `NSKeyedArchiver`, bookmark blobs or generic `Data` payload persistence.

## Tests added

`Library/Tests/LibraryPersistencePolicyTests.swift`

- path traversal/absolute/empty rejection;
- cross-project and duplicate stem rejection;
- duplicate stem-mix identity rejection;
- interrupted/ready/cancelled/failed recovery policy;
- blank/trimmed setlist name behavior.

`Library/Tests/CoreDataProjectLibraryStoreTests.swift`

- full project source + processing + stems + edits round-trip;
- isolated SQLite store close/reopen preserving project, processing recovery state and setlist;
- setlist create/rename/ordered replacement/duplicate occurrence/delete;
- invalid path, cross-project stem and asset-identity conflict rejection;
- recovery plan transitions across finalizing -> failed -> ready;
- idempotent project delete plus setlist position compaction.

## Executed evidence in current environment

Environment: Swift 6.2.1, Linux.

- `swiftc -typecheck` on `LibraryPersistencePolicy.swift` with frozen-contract-equivalent stubs: PASS.
- `swiftc -typecheck` on `LibraryPersistencePolicyTests.swift` with frozen-contract-equivalent stubs and XCTest: PASS.
- executable policy self-check: `PASS L2-M01 policy path/recovery/stem invariants`.
- source-level frozen contract surface scan: PASS, all 13 required methods present; no opaque blob/archive persistence detected.
- `CoreDataProjectLibraryStore.swift` and Core Data tests parse/typecheck on Linux with the `canImport(CoreData)` branch excluded. Linux cannot execute or compile Apple's Core Data framework body.

## Apple-runtime evidence still required at late integration

The following are not falsely claimed as executed here:

- actual Core Data compilation against the supported iOS/macOS SDK;
- execution of the in-memory and SQLite reopen XCTest suite on Apple Core Data;
- integration into Worker 4's Package/iOS host;
- physical-device relaunch/background/storage-pressure behavior;
- actual artifact cleanup and interrupted deletion recovery, which is the next Lane 2 bundle (`L2-M02`).

These are late-integration or next-bundle gates, not reasons to weaken the adapter implementation.

## PARITY

No PARITY change is claimed. `MOI-P017`, `MOI-P018` and `MOI-P020` remain `MISSING` until later Apple runtime, interruption, device and integrated evidence satisfies their full gates.

## L2-M01 done_when assessment

`ProjectLibraryPersisting` behavior is implemented across the full frozen contract surface, edge/negative handling is present, in-memory/isolated-SQLite contract tests are committed, portable policy tests execute in the available environment, and durable evidence is stored. L2-M01 is complete for Lane execution and the next bundle is `L2-M02`.
