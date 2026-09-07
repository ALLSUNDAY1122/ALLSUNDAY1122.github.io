# L2-AW22 Deletion Ownership Index / Steady-State Tombstone Scan Elision Validation

Result: `COMPLETED_NON_PARITY`

## Scope

Lane 2 only. AW21 made deleted-project artifact cleanup and physical Core Data compaction crash-safe, but canonical recovery still called `listTombstonedProjectCompactionCandidates()` on every launch. That method first fetched all tombstoned projects and then fetched each tombstone's source `AssetRecord` and `StemRecord` rows individually, creating an approximately `1 + 2N` candidate-materialization fetch pattern for `N` tombstones.

AW22 removes that global N+1 path from steady-state recovery without weakening AW21 deletion authorization. No `Shared/**`, `App/**`, `PARITY_MATRIX.json`, Queue, work-package, lane-plan, resource-lock, Core Data model version, or migration schema was changed.

## Fresh canonical state

The wave re-read the canonical Notion page, Worker v4 contract, work package, lane plan, Worker-2 status, resource locks, PARITY matrix and actual Worker branch before selection.

- assignment epoch: `2`
- planning revision: `4`
- integration epoch: `17`
- Worker branch start HEAD: `f27d20661fa901749e3e236f227ace6c25b47fdf`
- prior Worker status blob: `5a01eaba47276d18f6625905b0719496144b29cf`
- resource-lock SHA: `8ddd631bd0a5deb47cfad64e8d03e41c5712bad9`
- PARITY SHA: `db98892a379180c25ffeb3586a7c3353620a2d5d`
- MOI-P017 and MOI-P024 remain `MISSING`; final PARITY stays HQ-owned.

## Durable deletion ownership index

`DeletionOwnershipIndex.swift` adds one atomic record per in-flight project deletion under:

`.LibraryRecovery/DeleteOwnership/<projectUUID>.json`

The record is written before the PREPARED delete journal and before Core Data tombstoning. It stores only:

- schema version;
- project UUID;
- source asset UUID;
- validated app-owned source/stem paths;
- creation time.

Every stored path is validated through the existing AW21 compaction policy. `Exports/**`, `Staging/**`, `.LibraryRecovery/**`, traversal, absolute paths and malformed roots are rejected. Existing records are idempotently reused only when project, source asset and owned paths match exactly; conflicting reuse fails closed. Corrupt or unsupported records also fail closed.

The ownership record is removed only after the delete is rolled back while the project is still live, or after artifact deletion + Core Data compaction + journal retirement completes.

## Crash boundaries added by AW22

Because ownership is durable before the journal:

1. ownership persisted, journal missing, project still live -> ownership is discarded; user content remains;
2. ownership + PREPARED, project still live -> journal and ownership are discarded;
3. ownership + PREPARED, tombstone durable -> ownership authorizes the same AW21 journal validation and recovery continues;
4. ownership present, journal lost, project tombstoned -> AW22 reconstructs a conservative COMMITTED journal from the indexed owned paths minus current live references;
5. COMMITTED or ARTIFACTS_DELETED -> AW21 artifact/metadata compaction continues and the ownership record is retired last.

The AW21 mutation gate remains in force, so `createProject`, `recordStems`, delete/recovery and orphan sweep cannot race a live-reference snapshot inside the approved product facade.

## Steady-state scan behavior

After the one-time compatibility marker is durable:

- no pending delete journal + no ownership record -> recovery returns before any Core Data maintenance query;
- an AW22-indexed interrupted delete -> recovery uses the index and current live-reference projection; it does not call the global tombstone candidate scan;
- an `ARTIFACTS_DELETED` journal does not require candidate ownership because destructive file deletion is already durably complete; only metadata compaction/journal retirement remains.

The old global candidate scan remains only for:

1. the first successful AW22 compatibility pass, to recover journal-less tombstones created by older builds; or
2. a PREPARED/COMMITTED journal that predates AW22 and therefore lacks an ownership index.

After a successful compatibility pass, `.LibraryRecovery/DeleteOwnership/.legacy-scan-v1-complete` is written atomically. A crash before the marker simply repeats the compatibility scan on the next launch; processed tombstones are idempotently absent. A missing ownership record on a later old destructive journal still forces compatibility fallback even when the marker exists.

This means AW22 eliminates the N+1 scan from steady-state startup, not from the intentional one-time legacy migration. Actual legacy backlog cost remains an Apple performance gate.

## Portable validation

Executed with Swift 6.2.1 Linux:

- `DeletionOwnershipIndex.swift` + AW21 compaction policy strict-concurrency, warnings-as-errors module compile: PASS.
- `DeletionOwnershipIndexTests.swift` strict XCTest typecheck: PASS.
- exact AW22 CrashSafe facade compiled against contract-equivalent Core Data/Library stubs with strict-concurrency + warnings-as-errors: PASS.
- production CrashSafe and Apple-gated recovery tests syntax parse: PASS.
- static production wiring audit: `L2_AW22_STATIC_AUDIT_PASS checks=12/12`.
- production index blob: `111e390a3337fc9a85020f2c29a33bf45b467b22`.
- production CrashSafe blob: `df6a480d5faaa43e6e83774cd2ed0a82a129a98d`.
- portable tests blob: `968469df842d4ee6b149fa7aa39dd2737c14f843`.
- Apple-gated recovery tests blob: `32957f3da34ccc179ff998747196a29c0570e1c4`.
- committed self-check blob: `1fbc4eca95be7f2bb4650c8f78e1d96663b6fe10`.
- exact committed self-check rerun:
  `L2_AW22_SELF_TEST_PASS scenarios=8 ownership_records=2000 elapsed_seconds=1.916253`

The self-check covers durable round-trip, idempotent persist, identity conflict refusal, unsafe-root refusal, live-reference retention planning, legacy marker persistence, idempotent removal and a 2,000-record filesystem stress inventory. The 1.916253-second value is a Linux filesystem microbenchmark only. It is not iPhone/APFS or SQLite performance evidence. Normal product operation serializes project/artifact mutations and should not accumulate 2,000 simultaneous ownership records.

## Apple-gated recovery tests prepared

`DeletionOwnershipRecoveryTests.swift` prepares Apple runtime coverage for:

1. ownership persisted without a journal while the project is still live -> ownership is discarded and the source file remains;
2. legacy marker already complete + ownership + PREPARED + durable tombstone -> recovery completes without depending on the global legacy candidate scan, then removes source artifact, physical metadata, journal and ownership record.

These tests were syntax-parsed here. Actual Apple Core Data/SQLite execution was unavailable in the Worker environment and is not counted as PASS.

## Remaining gates

- actual Apple execution proving the indexed recovery path does not invoke the global legacy scan after the marker;
- actual SQLite query counting before/after AW22, including a large pre-AW22 tombstone backlog during the one-time compatibility scan;
- iPhone startup latency and RSS for clean steady-state, one indexed interrupted delete and large legacy migration;
- force termination while writing/removing the ownership record or legacy marker;
- APFS durability/ENOSPC around ownership-index atomic writes;
- raw `CoreDataProjectLibraryStore` product use remains forbidden because it bypasses the facade mutation gate and ownership-index contract;
- current-Moises deletion/privacy differential and full MOI-P017/MOI-P024 device evidence.

Portable evidence does not promote any PARITY row. Final PARITY remains HQ-owned.
