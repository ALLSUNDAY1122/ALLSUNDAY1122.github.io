# L2-AW39 | Crash-Safe Segmented Inventory Migration Validation

## Goal
Remove the write-time concentration pressure left by AW38 by introducing a durable migration substrate for AW29 v1 single-JSON managed-artifact shards.

## Fresh canonical state
- Operating model: FOUR_AUTONOMOUS_INDEPENDENT_LANES_LATE_INTEGRATION v4.
- Integration epoch: 26.
- Assignment epoch: 2.
- Planning revision: 4.
- Lane 2 ownership remains `IO/**` + `Library/**` and Worker-2 status only.
- HQ canonical checkpoint includes Lane 2 through AW37; AW38/AW39 remain post-checkpoint Worker work.
- PARITY promotion remains 0; Lane 2 rows remain MISSING.
- Wave start Worker branch HEAD: `54cbfd5cd931ea65367a444957245bed8935268f`.

## Implementation
Added `ManagedArtifactSegmentedShardStore.swift`.

The migration contract is generation based:
1. Keep the legacy v1 shard untouched.
2. Decode/validate the selected legacy shard.
3. Sort its entries deterministically.
4. Write a new generation as bounded segment JSON files, maximum 512 entries each.
5. Write a pending manifest.
6. Read back every segment and verify generation/shard/segment identity plus exact total entry count.
7. Atomically move the pending manifest to the committed manifest path last.
8. Only the committed manifest represents segmented authority.

A crash before step 7 leaves the legacy v1 shard intact and no committed segmented authority. A crash after step 7 leaves a read-back-verified committed generation while the legacy shard remains as rollback evidence. The migration is idempotent when a valid committed generation already exists.

`removeUncommittedGenerations` removes pending/stale generations without removing the currently committed generation.

## Negative / recovery coverage
`ManagedArtifactSegmentedMigrationTests.swift` covers:
- 1,300-entry legacy shard -> three bounded segments.
- legacy rollback bytes remain after migration.
- second migration call is idempotent.
- corrupt legacy shard fails closed without publishing a manifest.
- stale pending/uncommitted generation cleanup preserves the committed generation.

## Portable self-check
`L2AW39SegmentedMigrationSelfCheck.swift` was compiled with Swift strict-concurrency and warnings-as-errors and executed successfully:

`L2_AW39_SELF_TEST_PASS entries=1300 segments=3 legacy_preserved=true precommit_manifest_absent=true bounded=true`

This proves the interruption invariant at the authority boundary and the 512-entry segment bound in a Foundation-only environment.

## Scope / non-claims
This Wave introduces the crash-safe segmented migration substrate and regression surface. It does **not** yet claim that every AW29 runtime read/write call has switched to segmented authority; activation/routing of steady-state reads/writes remains the next Lane-2 hardening step. AW38's oversized-v1 preflight remains the current protection until that routing is completed.

No Shared/App/PARITY/Core Data schema or other Lane source was changed.

This is portable durability/scalability evidence only. It does not promote MOI-P017/MOI-P024 or any PARITY row. Physical iPhone/APFS/ENOSPC/force-termination evidence remains required.
