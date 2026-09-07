# MOI-LIB-R001 — Project / Library / Setlist / Resume persistence decision

Captured: 2026-08-22 JST
Worker: Moises-Worker-1
Attempt: `task/MOI-LIB-R001/attempt-1`
Scope: research/architecture evidence only. No Shared/App contract was modified.

## Acceptance target

This decision must support:
- durable project/library persistence and relaunch resume;
- setlist create/reorder/use semantics;
- processing snapshots and stem references surviving interruption;
- user-edit persistence without storing opaque engine objects;
- explicit migration, corruption, deletion and interrupted-write recovery;
- a native/commercially shippable iPhone path.

It does **not** claim MOI-P017/P018/P020 parity. Real app/device failure tests remain required.

## Existing HQ contract constraints

The HQ-fixed `Shared/DomainContracts.swift` already gives persistence-safe identifiers and value objects:
- `ProjectID`, `AssetID`, `ProcessingJobID`, `StemID`;
- `LocalAudioAsset` with durable app-owned `relativePath`;
- `ProcessingSnapshot` with stable phase/progress/retry/error fields;
- `StemArtifact` with explicit path/sample-rate/channel/frame/time-origin fields;
- `ProjectPersisting.createProject`, `recordProcessing`, `recordStems`.

The library layer must therefore persist **domain primitives and durable relative paths**, not AVFoundation objects, model/runtime instances, task handles, file-provider URLs, security-scoped bookmarks from transient import flows, or live engine objects.

## Options compared

Scoring: 1 = poor, 5 = strong. Weighting emphasizes crash/recovery and schema evolution over convenience.

| Option | Reliability / atomic metadata | Migration control | iOS fit / lifecycle | Domain isolation | Query / setlist ordering | Ops / testability | Result |
|---|---:|---:|---:|---:|---:|---:|---|
| **Core Data + SQLite store** | 5 | 5 | 5 | 5 with adapter | 5 | 4 | **SELECTED** |
| SwiftData | 4 | 4 | 5 | 3-4 with adapter | 5 | 4 | viable later, not baseline |
| Direct SQLite | 5 | 5 | 4 | 5 | 5 | 4 | strong but excess low-level burden |
| File-backed JSON/plist only | 3 | 2 | 5 | 5 | 2 | 3 | supplementary only |

### SwiftData

Strengths:
- Apple-native Swift persistence;
- `ModelContainer` manages schema/storage and coordinates reads/writes;
- versioned schemas and `SchemaMigrationPlan` support explicit migration stages;
- natural SwiftUI integration.

Why not selected for the first parity path:
- the current HQ boundary is intentionally plain `Codable` / `Sendable` value types, while SwiftData encourages persistence model classes; an adapter is still required to avoid coupling feature contracts to persistence annotations;
- the project needs deterministic recovery/migration behavior before UI convenience;
- Core Data exposes a longer-established migration surface including lightweight, staged and manual migration paths.

SwiftData remains a reasonable future simplification if deployment-target and migration validation prove equivalent.

### Core Data + SQLite persistent store — selected

Strengths:
- Apple-native, no third-party distribution licence;
- SQLite persistent store available on iOS;
- background/private managed-object contexts and queue-confined access are documented;
- automatic lightweight migrations cover common schema changes;
- staged/manual migration paths exist when lightweight migration cannot represent the change;
- persistence entities can stay private behind a `ProjectPersisting` adapter, preserving Shared domain isolation.

Selected operating rule:
- one persistence actor owns write sequencing;
- write work executes on a private/background Core Data context;
- one logical library mutation is saved as one context transaction;
- UI/read contexts observe merged committed state, never half-applied writer state.

### Direct SQLite

Strengths:
- explicit schema, transactions, indexes, constraints and migration numbering;
- excellent fit for relational setlist ordering and project queries;
- SQLite documents atomic commit/recovery semantics.

Why not baseline:
- it duplicates concurrency, migration, observation and object mapping infrastructure Core Data already supplies;
- WAL operation needs explicit checkpoint/concurrency discipline;
- SQLite disclosed a 2026 WAL-reset race fixed upstream in 3.51.3 (and selected backports). The exact SQLite version/backports present on each supported iOS release must not be assumed. A direct-SQLite implementation would therefore require an OS/runtime version probe plus a serialized-writer design before production approval.

This does not imply Core Data is magically immune to storage defects; it means the project should prefer the OS-managed persistence framework rather than create its own multi-connection WAL policy without need.

### File-backed JSON/plist only

Strengths:
- simple Codable mapping;
- Foundation supports auxiliary-file-then-replace atomic data writes;
- useful for manifests, diagnostics and large artifact sidecars.

Why not canonical metadata store:
- cross-file project/setlist consistency is difficult;
- relational ordering/querying becomes application-managed;
- multi-record migration and referential integrity are weaker;
- recovery from one partially updated project directory becomes a custom database implementation.

File-backed storage remains **required for large audio/stem artifacts**, but not as the canonical project metadata database.

## Selected architecture

### 1. Metadata store

Use one local Core Data SQLite store for structured metadata.

Proposed private persistence records (names are implementation-local, not Shared contracts):

`ProjectRecord`
- project UUID;
- source asset UUID;
- created / updated timestamps;
- display name if/when product contract requires it;
- lifecycle/tombstone state.

`AssetRecord`
- asset UUID;
- app-owned relative path;
- media kind;
- duration when known;
- readiness (`staging`, `ready`, `missing`, `tombstoned`);
- optional byte length/hash for integrity checks.

`ProcessingRecord`
- project UUID, unique;
- stable processing job UUID;
- phase;
- fraction complete;
- retryable flag;
- stable error code;
- updated timestamp.

`StemRecord`
- stem UUID;
- project UUID;
- role string;
- durable relative path;
- sample rate / channels / frame count / start time;
- readiness/integrity state.

`ProjectEditRecord`
- project UUID, unique;
- schema version;
- explicit primitive user-edit fields required by the verified product contract (tempo ratio, pitch semitones, metronome/count-in state, loop/trim bounds and mixer state as those contracts become fixed).

Do not archive an engine/runtime object into a blob. If a future edit family is represented as encoded data, it must have its own documented versioned DTO schema and migration path.

`SetlistRecord`
- setlist UUID;
- name;
- created / updated timestamps.

`SetlistEntryRecord`
- setlist UUID;
- project UUID;
- stable ordering index;
- uniqueness constraint for one project occurrence if product behavior requires uniqueness; otherwise explicit entry UUID permits duplicates.

### 2. Large artifact store

Audio source/stem/export files remain app-owned files outside Core Data. Core Data stores only IDs, metadata and relative paths.

Reason:
- avoids loading large binary audio through database objects;
- aligns with existing `LocalAudioAsset` / `StemArtifact` contracts;
- enables independent storage-pressure checks and orphan cleanup.

### 3. File + database commit protocol

There is no single ACID transaction spanning Core Data and arbitrary files, so use an explicit two-phase discipline.

For a newly created asset/stem:
1. write into a unique app-owned staging path on the same filesystem/container;
2. validate existence, size and basic media integrity;
3. atomically replace/move into the final UUID-based relative path;
4. save the Core Data transaction that exposes the final relative path as `ready`;
5. if step 4 fails, leave an unreferenced final file that startup garbage collection can remove; never expose a DB row pointing at a staging path.

Foundation documents atomic data writes as writing an auxiliary file first and replacing the original on completion, and `FileManager.replaceItem` as replacement intended to avoid data loss.

For deletion:
1. transactionally mark project/artifacts tombstoned;
2. commit so no live query returns them;
3. delete referenced files;
4. hard-delete tombstoned metadata after file cleanup;
5. on relaunch, resume any incomplete tombstone cleanup.

This makes interruption converge toward either a live fully referenced object or a cleanupable orphan/tombstone, not a half-visible project.

## Relaunch / interruption reconstruction

On launch after the persistent store and migrations are ready:
1. enumerate non-tombstoned projects;
2. verify source/stem relative paths are inside the app-owned root and still exist;
3. reconstruct `ProcessingSnapshot` from explicit primitive columns;
4. reconstruct stem descriptors only from `ready` rows whose files pass minimum integrity checks;
5. if a processing phase was nonterminal at termination, use the stable `ProcessingJobID` to query the separation provider when that backend supports durable jobs;
6. if the provider cannot resume/locate the job, keep the project and source intact and surface a stable retry/recovery state rather than deleting the project;
7. rebuild playback only from persisted DTOs/artifacts; never deserialize a live playback or ML engine instance.

### Partial-failure examples

- **Crash after file finalization but before DB commit:** orphan file; startup sweep removes after grace period.
- **Crash before file finalization:** staging file; startup sweep removes/retries according to owner operation.
- **Crash after DB metadata commit:** DB points only at final path by protocol; verify file and mark recoverable-missing if external/device storage failure made it unavailable.
- **Interrupted processing:** retain source + job ID + snapshot; query/retry instead of corrupting project.
- **Interrupted setlist reorder:** one database transaction means old or new order, not a partial mixed order.

## Migration strategy

1. Maintain explicit Core Data model versions from the first production schema.
2. Use lightweight migration only for changes Core Data can infer safely.
3. Use staged migration for incompatible multi-step changes and manual migration for transformations beyond staged/lightweight support.
4. Treat migration failure as a recoverable storage event: never silently delete and recreate the user store.
5. Before a risky/custom migration, preserve a restorable metadata-store backup/quarantine according to the app backup policy.
6. Add migration fixtures for every released schema version once implementation starts.

## Corruption and recovery gates

Implementation cannot pass MOI-P017/P020 until all are exercised:
- force-terminate during project create/update;
- force-terminate while processing snapshot is being updated;
- force-terminate between artifact finalization and metadata save;
- force-terminate during setlist reorder;
- relaunch with leftover staging files;
- relaunch with orphan final files;
- relaunch with a referenced file deliberately removed;
- migration from every previously released schema fixture;
- simulated migration failure must preserve the original store and produce an explicit recoverable error;
- corrupt metadata store must not trigger an automatic destructive reset;
- project deletion interrupted between tombstone and file cleanup must complete on next launch.

## Concurrency rules

- Serialize persistence writes through a dedicated actor/service.
- Core Data context work remains on its assigned queue using `perform`/`performAndWait` semantics.
- Do not pass `NSManagedObject` instances across module boundaries; map to the existing value DTOs.
- Avoid multiple independent SQLite writers in app code.
- Any future CloudKit/sync feature is a separate contract and must not be silently enabled as part of local parity persistence.

## HQ contract requests — evidence only, no Shared edit

Current `ProjectPersisting` supports write-side create/process/stems only. Full MOI-P017/P018/P020 implementation will need HQ-owned read/delete/edit/setlist semantics. Recommended minimum semantic additions for HQ to decide:

1. **Project read/list contract**
   - list persisted projects;
   - load source, latest processing snapshot and ready stems for one project.
2. **User-edit persistence contract**
   - save/load product-level practice/mixer edits as versioned domain values.
3. **Setlist contract**
   - create/rename/delete setlist;
   - list/reorder entries atomically.
4. **Delete contract**
   - tombstone/delete a project with deterministic artifact cleanup semantics.
5. **Processing recovery contract**
   - distinguish a durable resumable job from an interrupted job that must be retried.
6. Optional later: analysis snapshot persistence if product relaunch parity requires immediate chord/BPM/key restoration without recomputation.

Worker does not define these Shared protocols unilaterally.

## Decision

**Selected production baseline: Core Data using a local SQLite persistent store + app-owned file artifacts, hidden behind a persistence adapter and serialized writer.**

Do not choose SwiftData merely for UI convenience until deployment-target/migration equivalence is validated. Do not choose direct SQLite unless a concrete Core Data limitation appears. Do not use file-only metadata as the canonical library.

## Sources

Apple — SwiftData ModelContainer:
https://developer.apple.com/documentation/swiftdata/modelcontainer

Apple — SwiftData SchemaMigrationPlan:
https://developer.apple.com/documentation/swiftdata/schemamigrationplan

Apple — Core Data persistent store types:
https://developer.apple.com/documentation/coredata/nspersistentstore

Apple — NSManagedObjectContext concurrency:
https://developer.apple.com/documentation/coredata/nsmanagedobjectcontext

Apple — automatic/lightweight Core Data migration:
https://developer.apple.com/documentation/coredata/migrating-your-data-model-automatically

Apple — staged migrations:
https://developer.apple.com/documentation/coredata/staged-migrations

Apple — FileManager replacement:
https://developer.apple.com/documentation/foundation/filemanager/replaceitem(at:withitemat:backupitemname:options:resultingitemurl:)

Apple — atomic Data writing:
https://developer.apple.com/documentation/foundation/nsdata/writingoptions/atomic

SQLite — atomic commit:
https://www.sqlite.org/atomiccommit.html

SQLite — WAL and current 2026 WAL-reset bug note:
https://www.sqlite.org/wal.html
