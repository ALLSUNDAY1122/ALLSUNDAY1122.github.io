# L2-AW21 Crash-Safe Tombstoned Metadata Compaction Validation

Result: `COMPLETED_NON_PARITY`

## Scope

Lane 2 only. This wave closes the metadata-retention gap left after crash-safe project deletion: a deleted project could be hidden by a durable Core Data tombstone and have its artifacts removed, while `ProjectRecord`, `ProcessingRecord`, `StemRecord`, `ProjectEditRecord`, `StemMixRecord`, stray `SetlistEntryRecord`, and possibly the source `AssetRecord` remained physically retained indefinitely.

No `Shared/**`, `App/**`, `PARITY_MATRIX.json`, Queue, work-package, lane-plan, resource-lock, Core Data model version, or migration schema was changed. The model remains `L2-V1`.

## Fresh canonical state

The resumed wave re-read the canonical Notion page, Worker v4 contract, work package, lane plan, Worker-2 status, resource locks, PARITY matrix and actual Worker branch before continuing. At resume:

- assignment epoch: `2`
- planning revision: `4`
- integration epoch: `17`
- resource-lock SHA: `8ddd631bd0a5deb47cfad64e8d03e41c5712bad9`
- Worker branch HEAD: `cec7750e166e60385520b02b0a1001b0e5b7dd38`
- Worker status was still AW20, so AW21 was correctly treated as an unfinished partial wave rather than starting a second wave.
- MOI-P017 and MOI-P024 remained `MISSING`; final PARITY stays HQ-owned.

## Production state machine

Project deletion now retains one durable recovery signal through the entire destructive lifecycle:

1. `PREPARED` deletion journal is persisted before metadata deletion.
2. Core Data project tombstone commits.
3. Journal becomes `COMMITTED`.
4. Journal paths are re-authorized against the current tombstone and current live-project artifact references.
5. Artifacts are deleted idempotently.
6. Journal becomes `ARTIFACTS_DELETED` and remains durable.
7. Tombstoned Core Data project and project-owned children are physically compacted in one writer-context save.
8. The journal is retired only after metadata compaction has committed and converged.

Crash/relaunch boundaries therefore retain a recoverable state before artifact deletion, after partial artifact deletion, after complete artifact deletion, and after metadata compaction but before journal retirement.

## Historical tombstone recovery

Older builds can leave a physically retained tombstone without a deletion journal. AW21 enumerates such tombstones and rebuilds a `COMMITTED` intent only from currently validated tombstone source/stem paths that are not referenced by any live project. It then executes the same `COMMITTED -> ARTIFACTS_DELETED -> metadata compaction -> journal retire` flow.

Historical metadata is not trusted to authorize arbitrary deletion. Tombstone cleanup accepts only normalized `Imports/**` and `Stems/**` paths. `Exports/**`, `Staging/**`, `.LibraryRecovery/**`, traversal, absolute paths, backslash-normalized surprises and unrelated journal paths fail closed.

## Journal re-authorization

An existing durable journal is also not blindly trusted on relaunch. Before destructive work it must satisfy all of the following:

- every path is still attributable to the target tombstoned project's source/stem projection;
- no path is referenced by a currently live project;
- every path is under the explicitly authorized `Imports/**` or `Stems/**` roots.

A `PREPARED` or `COMMITTED` journal whose tombstone candidate is missing fails closed because ownership can no longer be proven. The only missing-candidate state accepted is `ARTIFACTS_DELETED`, where file deletion has already durably completed and the remaining operation is journal retirement after an already-completed metadata save.

## Core Data compaction

`CoreDataProjectLibraryStore` now exposes a lane-local tombstone projection and an exact compaction operation. For one tombstoned project the writer context removes:

- `ProcessingRecord`
- `StemRecord`
- `ProjectEditRecord`
- `StemMixRecord`
- any remaining `SetlistEntryRecord` referencing the project
- the tombstoned `ProjectRecord`

The `AssetRecord` is removed only if no other `ProjectRecord`, whether live or tombstoned, still references the same `sourceAssetUUID`. After the save the store re-fetches project/children and verifies convergence; it separately verifies that a shared source asset survived or that a final unreferenced source asset disappeared as planned.

Before editing the 47 KB Core Data source, the current GitHub file was reconstructed from five read-back segments and its local Git blob was verified to equal the original remote blob `ffb787c2a533663414340b4c7092b3cc59d95fc8`. The AW21 production result then read back as blob `a404447c7050fcde6aba16f1bf05530f4a40094d`.

## Concurrent live-reference safety

A second correctness audit found a race: recovery could snapshot live artifact references, then another task could register the same source/stem path before deletion. AW21 added `Lane2LibraryMutationGate`, a FIFO async mutex, and routes `createProject`, `recordStems`, project deletion/recovery and orphan sweeping through the same gate. This preserves one coherent live-reference snapshot across awaited metadata/filesystem steps. Processing/edit/setlist mutations do not create artifact-path references and remain outside the gate.

Production App/HQ integration must use the crash-safe Library facade for these operations. Direct external use of the raw Core Data store would bypass the facade-level mutation gate and is not an approved product integration route.

## Portable validation

Executed with Swift 6.2.1 Linux strict concurrency where applicable:

- `TombstonedMetadataCompaction.swift` strict-concurrency + warnings-as-errors typecheck: PASS.
- `TombstonedMetadataCompactionTests.swift` strict XCTest typecheck: PASS.
- `LibraryMutationGate.swift` strict-concurrency + warnings-as-errors typecheck: PASS.
- `LibraryMutationGateTests.swift` strict XCTest typecheck: PASS.
- Updated `LibraryArtifactLifecycleTests.swift` strict typecheck against the exact AW21 lifecycle API contract: PASS.
- Core Data production source, crash-safe facade and Apple-gated Core Data tests syntax parse: PASS.
- Static production wiring audit: `L2_AW21_STATIC_AUDIT_PASS 24/24`.
- Final self-check source blob: `28390af6ed6dae96795017a9796ec7d88dc9eedb`.
- Final executed marker:
  `L2_AW21_SELF_TEST_PASS scenarios=9 projects=50000 artifact_paths=100000 gate_tasks=200 gate_peak=1 elapsed_seconds=0.722743`

The 50,000-project/100,000-path timing is a Linux policy microbenchmark only. It is not an iPhone Core Data, SQLite, APFS, memory or launch-time measurement.

The earlier AW21 filesystem validation of the unchanged `LibraryArtifactLifecycle.swift` blob `8ab582a2c767f4598b0ba473338c4db951580c09` also exercised the three-phase journal transitions, idempotent replay, historical committed backfill, mismatched-journal refusal, and refusal to retire a journal before `ARTIFACTS_DELETED`.

## Apple-gated tests prepared

`CoreDataTombstonedMetadataCompactionTests.swift` prepares Apple runtime coverage for:

1. physical child-record compaction while retaining an `AssetRecord` shared by another live project;
2. historical tombstone with no journal -> committed backfill -> artifact cleanup -> metadata compaction;
3. process interruption after artifact deletion has reached `ARTIFACTS_DELETED` -> metadata compaction and journal retirement on recovery.

These tests were syntax-parsed here. Actual Apple Core Data/SQLite execution was not available in this Worker environment and is not counted as PASS.

## Remaining gates

- actual Apple Core Data/SQLite execution and physical row-count verification;
- force termination at PREPARED/tombstone/COMMITTED/partial-delete/ARTIFACTS_DELETED/Core-Data-save/journal-retire boundaries;
- real APFS durability and ENOSPC behavior;
- high tombstone-backlog startup latency, SQLite query count and RSS on iPhone;
- multi-process/extension access if the final App architecture permits raw store access outside the crash-safe facade;
- current-Moises deletion/privacy behavior and full Differential PARITY evidence.

Portable evidence does not promote MOI-P017 or MOI-P024. Final PARITY remains HQ-owned.
