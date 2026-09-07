# L2-AW12 Library Maintenance Projection Validation

## Scope

Worker 2 lane-local hardening only. This wave does **not** claim Moises PARITY and does not modify Shared/App/PARITY/Queue/Work Packages/Lane Plan/Resource Locks.

Selected after re-reading the current Notion v4 canonical, Worker contract, Work Package, Lane Plan, Worker 2 status, Resource Locks and PARITY ledger. Resource-lock ownership remained unchanged while HQ integration epoch advanced to 8. MOI-P017/P018/P019 remained MISSING.

After AW11 removed N+1 fetches from user-facing complete project/setlist enumeration, the next highest-value gap was maintenance work that still materialized complete `PersistedProjectSnapshot` values only to answer narrower questions such as "which projects are live?" and "which source/stem paths are referenced?".

## Problem found

Before AW12:

- `CrashSafeProjectLibraryStore.deleteProject(...)` loaded the target full snapshot and then called `listProjects()` for every other live project to calculate shared artifact references.
- `CrashSafeProjectLibraryStore.recoverInterruptedOperations()` called `loadProject(...)` once per pending deletion journal just to decide live/tombstoned state.
- `CrashSafeProjectLibraryStore.sweepOrphanArtifacts()` called `listProjects()` even though it only needs source/stem paths.
- `Lane2DurableLifecycleCoordinator.reconcileDeletedProjectArtifacts()` called the frozen contract `listProjects()` only to obtain live IDs.
- `reconcileProjectOwnership()` and `sweepOrphans()` also materialized processing/edit/mix state that they do not consume.

AW11 made those complete enumerations bounded, but their semantic payload was still wider than the maintenance operation required.

## Production change

### Lane-local projection contract

`LibraryMaintenanceProjection.swift` adds a Worker-2-owned contract without changing frozen Shared types:

- `LibraryMaintenanceProject`
  - project ID
  - source asset ID
  - source relative path
  - stem relative paths
- `LibraryMaintenanceProjectProviding`
  - `listMaintenanceProjects()`
  - `listLiveProjectIDs()`
  - `containsLiveProject(projectID:)`

The projection rejects empty, absolute, traversal, NUL-containing and malformed relative paths. Duplicate project IDs fail closed. `artifactRelativePaths` deduplicates repeated paths within one project before destructive reference decisions.

### Core Data implementation

`CoreDataProjectLibraryStore` now conforms to the lane-local projection provider.

`listMaintenanceProjects()`:

1. fetches the same live `ProjectRecord` roots with AW11 bounded faulting;
2. processes roots in bounded ranges;
3. fetches only source `AssetRecord` rows and `StemRecord` rows for each range;
4. does **not** fetch `ProcessingRecord`, `ProjectEditRecord` or `StemMixRecord`;
5. validates the resulting lightweight projection before returning it.

`listLiveProjectIDs()` performs only the live root ProjectRecord enumeration and UUID extraction.

`containsLiveProject(projectID:)` uses the existing point ProjectRecord lookup and tombstone flag without constructing a snapshot.

No entity, attribute, uniqueness constraint or model version changed. `L2-V1` remains unchanged; AW12 introduces no Core Data schema migration.

### Crash-safe maintenance paths

`CrashSafeProjectLibraryStore` now also conforms to `LibraryMaintenanceProjectProviding`.

- delete reference calculation uses the lightweight projection rather than target full snapshot + all full snapshots;
- shared source/stem paths remain protected by reference-set exclusion;
- interrupted-delete recovery enumerates the live ID set once instead of constructing one complete snapshot per PREPARED journal;
- single-journal reconciliation uses `containsLiveProject`;
- orphan sweep uses only source/stem maintenance paths.

### Lane-2 coordinator paths

`Lane2DurableLifecycleCoordinator` dynamically consumes `LibraryMaintenanceProjectProviding` when the concrete Library implementation supports it.

Production `CrashSafeProjectLibraryStore` does support it, so:

- deleted-project reconciliation uses live IDs only;
- ownership reconciliation uses project/source ownership projection only;
- orphan sweep uses source/stem projection only.

A frozen-contract fallback to `ProjectLibraryPersisting.listProjects()` is intentionally retained for alternative Library implementations that do not adopt the lane-local provider. This preserves compatibility without modifying Shared.

## Query/materialization shape

Using AW11 default batch size 128 and 10,000 live projects:

- complete project snapshot application-level fetch-request estimate: `396`
  - 1 root fetch + 5 related groups per 79 batches;
- AW12 maintenance projection estimate: `159`
  - 1 root fetch + 2 related groups per 79 batches;
- live-ID-only maintenance path: one application-level root fetch request.

These are code-level Core Data fetch-request shapes, not exact SQLite statement counts. Core Data may fault/page internally.

The more important reduction is payload: maintenance no longer loads processing records, edit records, stem-mix records, or constructs full persisted snapshots when they are not needed.

## Executed portable validation

Environment: Swift 6.2.1, Linux x86_64.

Executed in this Worker session:

- `LibraryMaintenanceProjection.swift` strict-concurrency / warnings-as-errors compile against contract-equivalent ProjectID/AssetID stubs: PASS.
- `LibraryMaintenanceProjectionTests.swift` strict-concurrency / warnings-as-errors XCTest typecheck against the same stubs: PASS.
- `CoreDataProjectLibraryStore.swift` Linux syntax parse: PASS.
- `CrashSafeProjectLibraryStore.swift` Linux syntax parse: PASS.
- `Lane2DurableLifecycleCoordinator.swift` Linux syntax parse: PASS.
- `CoreDataMaintenanceProjectionTests.swift` Linux syntax parse: PASS.
- production wiring static audit: PASS 13 checks.
- executable projection self-check: PASS, marker:
  `L2_AW12_SELF_TEST_PASS scenarios=6 projects=25000 referenced=75000 full_fetch_estimate=396 maintenance_fetch_estimate=159 elapsed_seconds=0.652572`
- self-check covers:
  - within-project path deduplication;
  - shared-reference exclusion;
  - invalid path rejection;
  - duplicate-project fail-closed behavior;
  - 10,000-project query-shape bounds;
  - 25,000-project / 75,000-path portable reference-set construction.

The `0.652572 s` number measures Swift value/path-set construction on this Linux runner only. It is not Core Data, SQLite, iPhone RSS or device performance evidence.

## Apple test coverage committed

`CoreDataMaintenanceProjectionTests.swift` is Apple/Core Data gated and covers:

- 257 projects with batch size 17 crossing multiple projection batches;
- source/stem projection presence while processing records also exist;
- live-ID enumeration;
- `containsLiveProject`;
- tombstone exclusion;
- CrashSafe deletion with two projects sharing one source path, ensuring the shared source survives while the deleted project’s unique stem is removed.

These tests are committed but are not marked runtime PASS until executed under the supported Apple SDK.

## Negative / recovery invariants

- maintenance path validation fails before destructive reference decisions when persisted paths are malformed;
- duplicate project projections fail closed;
- deletion never removes a path still referenced by another live projected project;
- PREPARED deletion recovery treats canonical live IDs as authority;
- tombstoned projects are excluded from live-ID and maintenance projections;
- projection-aware coordinator paths fall back to the frozen Shared contract rather than requiring a Shared change;
- no processing/edit/mix value is needed to determine live IDs or source/stem ownership;
- all pre-existing AW09/AW10 export-registration and compensation ordering remains unchanged.

## Gates intentionally still open

The following remain unverified and are not marked PASS:

- actual Apple Core Data execution of AW12 and earlier Core Data suites;
- actual SQLite/Core Data wall time, RSS, fault churn and query plans at 1k/10k+ projects on supported iPhone hardware;
- whether persistent-store indexes are justified by measured Apple query plans;
- APFS forced-termination and ENOSPC timing from AW09/AW10;
- actual Files/iCloud/File Provider/camera-roll/direct URL flows;
- real MP3/WAV/FLAC/M4A/MP4/MOV/WMA fixture execution;
- production WMA compatibility decoder selection/license/package audit if native decoding is unavailable;
- AVFoundation M4A export/share/playback on device;
- integrated App recovery UX;
- Differential Moises and final PARITY judgment.

## PARITY statement

`COMPLETED_NON_PARITY` for L2-AW12.

The wave reduces maintenance-time Core Data materialization and makes deletion/orphan/reconciliation paths consume the minimum lane-local canonical projection available, but MOI-P001/P002/P017/P018/P019/P020 remain HQ-owned PARITY decisions pending Apple/device/real-audio/integrated/differential gates.
