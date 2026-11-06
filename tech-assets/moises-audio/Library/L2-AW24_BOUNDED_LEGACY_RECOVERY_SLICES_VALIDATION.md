# L2-AW24 Bounded Legacy Recovery Slices Validation

Result: `COMPLETED_NON_PARITY`

## Scope

Lane 2 only. AW23 removed legacy tombstone N+1 discovery from canonical startup, but its one-time scanner still materialized every tombstone root and then CrashSafe recovery could compact the entire indexed backlog in one launch. AW24 bounds the canonical journal-less legacy workload per launch while preserving AW21/AW22 deletion ownership, journal validation, live-reference retention and crash recovery.

Fresh canonical state at wave start:
- assignment epoch: `2`
- planning revision: `4`
- integration epoch: `18`
- Worker branch/status start: `cd5f11d71612abd1a4052d119e981ea9756a86b0`
- prior status blob: `ea7641413b540e21b6a3e87cdf68733b8385b164`
- resource lock SHA: `c7ce95cb0a0f1eb245010acbbff3cacdf3f4cbec`
- PARITY SHA: `db98892a379180c25ffeb3586a7c3353620a2d5d`

## Bounded state

`LegacyRecoverySliceState.swift` adds a durable hidden marker:

`.LibraryRecovery/DeleteOwnership/.legacy-bounded-v2-active`

The marker is written atomically before AW24 intentionally writes the older `.legacy-scan-v1-complete` marker. The older marker suppresses the unbounded AW22 fallback; the stronger AW24 active marker tells canonical open paths that bounded compatibility work still remains. A crash between those writes is safe because the active marker survives and the next canonical open re-enters AW24 preparation.

Default journal-less legacy budget is 64 projects/launch, clamped to 8...256. Root discovery uses `fetchLimit = budget + 1`, so the default root materialization is at most 65 tombstone rows per canonical launch. Asset and Stem projection remain batched for only the selected slice.

## Recovery behavior

For normal historical tombstones:
1. activate bounded mode durably;
2. suppress the old global fallback marker;
3. open compatible L2-V1 SQLite read-only after model-hash validation;
4. fetch at most N+1 journal-less tombstone roots;
5. persist AW22 ownership for at most N selected roots;
6. return to existing CrashSafe recovery, which processes those indexed projects through AW21 artifact deletion + metadata compaction;
7. if more roots remain, keep the active marker so the next launch repeats on the remaining tombstones;
8. on the final slice, remove the active marker after all remaining roots have durable ownership. If the process dies before final CrashSafe compaction, those ownership records still drive recovery on the next launch.

A process death after ownership persistence but before recovery does not advance to another slice: the same tombstone rows remain in SQLite, so the next bounded scan re-selects the same rows and ownership persistence is idempotent.

Pre-AW22 PREPARED/COMMITTED deletion journals without ownership are correctness-critical and are prioritized outside the normal journal-less slice budget so they cannot force CrashSafe recovery back into the old global N+1 candidate scanner. `ARTIFACTS_DELETED` journals do not need ownership for destructive authorization and are excluded from this priority set.

## Canonical routes

Both approved construction routes now call AW24 before CrashSafe recovery:
- `openPreservingUserData(...)`
- `openBulkPrepared(...)`

Legacy `CrashSafeProjectLibraryStore.open(...)` and raw `CoreDataProjectLibraryStore` remain unapproved App integration routes.

## Validation

Swift 6.2.1 Linux:
- `LegacyRecoverySliceState.swift` strict-concurrency + warnings-as-errors module compile: PASS.
- `LegacyRecoverySliceStateTests.swift` strict XCTest typecheck: PASS.
- AW24 Core Data migrator / Apple-gated tests / canonical open files syntax parse: PASS on locally validated source.
- static wiring/recovery audit: `L2_AW24_STATIC_AUDIT_PASS checks=16/16`.
- exact committed portable state blob: `7a229f9cd1d7a3a0d99b09199055bbc6ee855351`.
- exact committed self-check blob: `75afd8f5db045d75d042feb4462bc22ce87b8a07`.
- production bounded migrator remote blob: `02d4d7d7f46f1e4539defaa0dbdff6e0979f6358`.
- Apple-gated bounded tests remote blob: `62e44b54cdf8bd29866dc5f9fd01e834145a2c85`.
- preserving-open blob: `0db3595bdd37da55cf1ab5b98009384aba79cdc4`.
- bulk-open blob: `2d8b1ea64ec1065157a52236d647a5c16a37c0a4`.
- exact committed portable rerun:
  `L2_AW24_SELF_TEST_PASS scenarios=6 projects=100000 budget=64 launches=1563 root_rows_per_launch=65 logical_fetch_upper_bound_per_launch=3 old_root_rows=100000 elapsed_seconds=0.000021`

This timing is a Linux integer/state-machine microbenchmark, not SQLite/APFS/iPhone performance evidence.

## Apple-gated tests prepared

`LegacyTombstoneBoundedMigratorTests.swift` prepares:
1. 130 historical tombstones with budget 32; expected convergence across 5 launches, each ordinary root materialization <=33 rows, final ownership index empty and bounded marker cleared after CrashSafe recovery;
2. process death after indexing an 8-project slice but before CrashSafe recovery; a second preparation must still expose only the same 8 ownership records rather than advancing to a second slice.

Actual Apple Core Data execution is pending and is not counted as PASS.

## Remaining gates

- actual Apple compile/run of AW24 and observed SQLite query/RSS/startup measurements;
- physical iPhone force termination around active marker, old compatibility marker, ownership writes and final-slice transition;
- APFS/ENOSPC durability for marker/index writes;
- correctness-critical outstanding old destructive journals are intentionally not constrained by the normal 64-project budget;
- a pre-existing AW23 state where a huge backlog was already fully indexed before upgrading to AW24 can still make current CrashSafe recovery process many ownership records in one launch; bounding arbitrary already-indexed recovery is a separate follow-up;
- per-project Core Data physical compaction remains individually atomic rather than one bulk SQL delete, by design for crash isolation;
- MOI-P017/MOI-P024 and all Lane-2 PARITY rows remain HQ-owned and `MISSING` until device/integration/reference gates pass.

No Shared/App/PARITY or Core Data model schema was changed.
