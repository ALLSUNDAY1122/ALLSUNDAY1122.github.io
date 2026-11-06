# L2-AW11 Core Data Large-Library Bounded Enumeration Validation

## Scope

Worker 2 lane-local hardening only. This wave does **not** claim Moises PARITY and does not modify Shared/App/PARITY/Queue/Work Packages/Lane Plan/Resource Locks.

Selected after re-reading the current Notion v4 canonical, Worker contract, Work Package, Lane Plan, Worker 2 status, Resource Locks and PARITY ledger. Resource-lock ownership remained unchanged while HQ integration epoch advanced to 7. MOI-P017/P018/P019 remained MISSING. After AW10 closed the export-registration relaunch gap, the highest-value lane-local gap was Core Data large-library enumeration shape.

## Problem found

Before AW11:

- `listProjects()` fetched all live `ProjectRecord` objects and then called `StoreMapper.projectSnapshot(...)` once per project.
- Each project snapshot independently fetched source asset, processing record, stems, edit record and stem-mix rows.
- At the Core Data fetch-request dispatch level this is approximately `1 + 5N` for a project list containing all optional related groups.
- `listSetlists()` similarly performed one `SetlistEntryRecord` fetch per setlist after the root setlist fetch.

This N+1 shape is unnecessary and becomes increasingly expensive as a library grows.

## Production change

`LibraryEnumerationPolicy` adds one lane-local bounded-enumeration policy:

- default related-record batch size: 128;
- minimum: 16;
- maximum: 1024;
- deterministic non-overlapping ranges;
- informational fetch-dispatch estimators used only for evidence/testing.

`CoreDataProjectLibraryStore.Configuration` now accepts `enumerationBatchSize` without changing existing call sites because the parameter has a default value.

`listProjects()` now:

1. fetches live `ProjectRecord` objects with `fetchBatchSize` and faulting enabled;
2. processes project records in bounded ranges;
3. collects the project/source UUIDs for only the current range;
4. performs set-based `IN` fetches for assets, processing rows, stems, edits and stem-mix rows;
5. groups those records in memory for the current batch;
6. builds frozen-contract `PersistedProjectSnapshot` values without per-project relationship fetches;
7. rejects duplicate records for unique-key groups as corruption instead of allowing `Dictionary(uniqueKeysWithValues:)` to trap.

`listSetlists()` now:

1. fetches `SetlistRecord` objects with `fetchBatchSize` and faults;
2. processes setlists in bounded ranges;
3. performs one set-based `SetlistEntryRecord` fetch per range;
4. groups entries by setlist UUID while preserving the position-sorted result order.

Single-project `loadProject(...)` and targeted mutation paths intentionally retain their small point-query behavior; the optimization is for large complete enumerations.

No managed-object entity, attribute, uniqueness constraint or model version identifier was changed in AW11. No schema migration is introduced by this wave.

## Query-shape bound

With default batch size 128 and 10,000 projects:

- prior project list shape: approximately `1 + 5 * 10,000 = 50,001` Core Data fetch-request dispatches;
- AW11 project list shape: `1 + 5 * ceil(10,000 / 128) = 396` dispatches;
- reduction in code-level fetch dispatch count: about 126x.

With 10,000 setlists:

- prior shape: about 10,001 fetch-request dispatches;
- AW11 shape: `1 + ceil(10,000 / 128) = 80` dispatches.

These figures describe the application-level Core Data fetch-request shape. They are **not** claims about the exact number of SQLite statements because Core Data may internally page/fault based on `fetchBatchSize`.

The frozen Shared contract still returns complete arrays, so final returned snapshot memory remains O(N). AW11 bounds related-record materialization and removes N+1 fetch dispatching; it does not claim fully streaming UI pagination.

## Executed portable validation

Environment: Swift 6.2.1, Linux x86_64.

Executed in this Worker session:

- `LibraryEnumerationPolicy.swift` strict-concurrency / warnings-as-errors compile: PASS.
- `LibraryEnumerationPolicyTests.swift` strict-concurrency / warnings-as-errors XCTest typecheck: PASS.
- executable batching self-check: PASS, marker `L2_AW11_SELF_TEST_PASS scenarios=6`.
- self-check covers lower/upper batch-size clamping, exact non-overlapping range coverage, 10,000-project fetch bound, 10,000-setlist fetch bound and 1,000,000-item bounded planning.
- 1,000,000-item range-planning run: `planning_s=0.001029` on this runner. This measures only the portable batching policy, not Core Data or iPhone performance.
- static production wiring audit: PASS 11 checks, marker `L2_AW11_STATIC_WIRING_PASS checks=11`; verified batched root fetches, all five project related-group set fetches, setlist-entry batching, `IN` predicate, faulting and unchanged `L2-V1` model identifier.
- updated `CoreDataProjectLibraryStore.swift` Linux syntax parse: PASS.
- `CoreDataLargeLibraryEnumerationTests.swift` Linux syntax parse: PASS.
- local Git blob SHA for the updated production source exactly matched the remote GitHub content SHA `6e14a8743706aecab8b9cc2c7a5cb69c945df674`.

## Apple test coverage committed

`CoreDataLargeLibraryEnumerationTests.swift` is Apple/Core Data gated and covers:

- 257 projects with batch size 17 crossing 16 materialization ranges;
- nested processing/stem/edit state on first/middle/last regions;
- post-tombstone enumeration exclusion;
- 70 setlists with repeated ordered entries across multiple batches;
- batch-size lower/upper clamping through `CoreDataProjectLibraryStore.Configuration`.

These tests are committed but are not marked runtime PASS until executed under the supported Apple SDK.

## Negative / corruption behavior

- Empty ID sets never issue a related fetch.
- Batch size is bounded before it reaches Core Data.
- Missing required source asset still fails as `corruptRecord`.
- Duplicate rows in groups that should be unique (asset UUID / processing project UUID / edit project UUID) fail as corruption rather than trapping.
- Existing source/stem/edit validation remains active after batch materialization.
- Tombstoned projects remain excluded by the root predicate.
- Existing setlist position semantics are retained.

## Gates intentionally still open

The following remain unverified and are not marked PASS:

- actual Apple Core Data execution of AW11 and the earlier L2-M01/L2-M02/L2-M03 suites;
- actual SQLite/Core Data wall time, RSS, fault churn and responsiveness at 1k/10k+ projects on supported iPhone hardware;
- whether additional persistent-store fetch indexes are justified by measured Apple query plans; no unmeasured schema/index migration was introduced in this wave;
- physical-device storage pressure / forced termination gates from AW09/AW10;
- actual Files/iCloud/File Provider/camera-roll/direct URL flows;
- real MP3/WAV/FLAC/M4A/MP4/MOV/WMA fixture execution;
- production WMA compatibility decoder selection/license/package audit if native decoding is unavailable;
- AVFoundation M4A export/share/playback on device;
- Differential Moises and final PARITY judgment.

## PARITY statement

`COMPLETED_NON_PARITY` for L2-AW11. The wave materially removes large-library N+1 Core Data fetch dispatching and adds bounded related-record materialization plus Apple regression coverage, but MOI-P001/P002/P017/P018/P019/P020 remain HQ-owned PARITY decisions pending Apple/device/real-audio/integrated/differential gates.
