# L2-AW32 Sharded Deletion Ownership Index Validation

Result: `COMPLETED_NON_PARITY`

## Scope

Lane 2 only. AW25 bounded the number of ownership-only recovery records decoded and compacted per launch, but `Lane2DeletionOwnershipIndex.pendingRecordSlice()` still enumerated every flat `.LibraryRecovery/DeleteOwnership/<UUID>.json` filename to choose that bounded slice. AW32 removes that steady-state global filename walk by storing current ownership records in deterministic shard directories with a small active-shard manifest. Pre-AW32 flat ownership records are migrated in bounded slices.

## Fresh canonical state

At wave start:

- Notion canonical: `Moises技術同等化｜AI音源分離アプリ 正本`; v4 autonomous-lane contract unchanged.
- Worker contract SHA: `c9e8ec5d191108db6eb20fbd40db0dab3c46b725`.
- Work Package SHA: `aad7983bdaf315a996dce1496ed245008085c712`.
- Lane Plan SHA: `10b595b47e5a71278bde32e8656bd284e14e62eb`.
- Resource Lock SHA: `55b0056b5563c64515ddc74abd448c545c7c0bb4`, integration epoch 22, assignment epoch 2.
- Worker-2 prior status blob: `6fe5db781a0c9d96397717a01ed8e367c2fce027`.
- PARITY SHA: `db98892a379180c25ffeb3586a7c3353620a2d5d`.
- Worker status reported L2-AW31 `COMPLETED_NON_PARITY` with implementation/evidence head `8da84c0bfc891f519a12576b281a3f7ba1341677`; no Lane-2 PARITY row was promoted.

## Production design

### Current ownership records

New ownership evidence is written under:

`.LibraryRecovery/DeleteOwnership/Shards/<00...ff>/<projectUUID>.json`

`projectUUID.uuidString` is mapped to one of 256 shards with deterministic FNV-1a. The public ownership record format remains schema version 1 and existing artifact-path authorization rules are unchanged.

A small manifest records only shards that may contain ownership records:

`.LibraryRecovery/DeleteOwnership/.active-shards-v2.json`

Normal ownership-only recovery reads the manifest and visits at most four active shards per invocation. Journal-backed projects remain higher priority and are still looked up directly by project UUID through `record(projectUUID:)` rather than waiting for the ownership-only scheduler.

### Crash ordering

For a new sharded ownership record the durability order is:

1. atomically persist the active-shard signal;
2. create the deterministic shard directory;
3. atomically write the ownership record.

A kill between 1 and 3 can therefore leave an empty active-shard signal, but cannot leave a canonical recovery record hidden from the manifest. AW32 explicitly retires empty active-shard signals during bounded selection. At most four such crash signals are retired in one pass, so empty signals cannot permanently starve a later real ownership record.

When an existing sharded record is re-persisted idempotently, its shard is re-activated before returning. Flat and sharded copies for the same project must have identical source ownership and artifact paths or the index fails closed with `identityConflict`.

### Pre-AW32 flat migration

Legacy `.LibraryRecovery/DeleteOwnership/<UUID>.json` records remain readable throughout migration.

`pendingRecordSlice(limit:)` now:

1. enumerates only until `limit + 1` flat JSON candidates are found;
2. validates and relocates at most `limit` flat records into current shards;
3. removes each flat copy only after the sharded record is durable;
4. returns eligible migrated records immediately for the current recovery pass;
5. fills remaining capacity from at most four active shards.

With the default AW25 ownership-only budget this migrates at most 64 flat records per pass. Enumeration errors fail closed rather than treating a partial legacy directory view as complete.

### Removal and corruption behavior

`remove(projectUUID:)` removes both legacy and sharded copies and retires an active shard only after that shard directory is verified empty.

Record reads preserve prior validation:

- regular non-symlink file requirement;
- canonical UUID filename;
- payload project identity match;
- schema version 1;
- `Imports/**` / `Stems/**` ownership-path validation through `Lane2TombstonedMetadataCompactionPolicy`.

Shard reads additionally require the UUID to hash to the containing shard. Active-manifest schema/range/uniqueness violations fail closed. A missing active manifest while the shard root already contains entries also fails closed rather than silently hiding sharded recovery state.

The AW22 `.legacy-scan-v1-complete` marker and CrashSafe recovery call-site API are unchanged; no Shared/App/Core Data model contract change is required.

## Validation

Swift environment: Swift 6.2.1 Linux.

- exact final production source with minimal existing Library contract stubs: Swift 6 strict concurrency + warnings-as-errors => PASS;
- `DeletionOwnershipShardingTests.swift`: strict XCTest typecheck => PASS;
- exact committed self-check compiled with strict concurrency + warnings-as-errors and executed => PASS;
- static production audit => `L2_AW32_STATIC_AUDIT_PASS checks=24/24`.

Exact committed blobs:

- `DeletionOwnershipIndex.swift`: `235faf2b8ae9e04de1fc14facb556e6ee76a983d`
- `DeletionOwnershipShardingTests.swift`: `73bc2fba8bac7697917c1ddee6fad4b8ea05afb7`
- `L2AW32ShardedDeletionOwnershipSelfCheck.swift`: `7e01ee6d99992db5cb28ff72272a457372a86987`

Exact committed self-check result:

`L2_AW32_SELF_TEST_PASS scenarios=6 legacy_records=257 migration_passes=5 slice_limit=64 shard_count=256 shard_visit_limit=4 conflict_fail_closed=true manifest_fail_closed=true empty_signal_recovery=true`

The self-check covers:

1. current sharded persist + direct lookup;
2. 257 simulated pre-AW32 flat ownership records converging through 64-record bounded migration in five passes;
3. exclusion/direct availability for journal-backed ownership;
4. flat/sharded ownership identity conflict fail-closed behavior;
5. corrupt active-manifest fail-closed behavior;
6. four manifest-only crash signals being retired without permanent starvation of a later real shard.

The XCTest regression additionally covers deterministic shard location, flat backlog convergence, journal exclusion, conflicting duplicate ownership, corrupt manifest, sharded-record symlink rejection, and empty-signal recovery.

Static checks covered the 256-shard layout, four-shard visit budget, active-before-record durability order, atomic record/manifest writes, bounded `limit + 1` flat compatibility enumeration, enumeration-error fail-closed behavior, journal exclusion/direct lookup, duplicate identity validation, path policy revalidation, symlink/regular-file validation, UUID filename validation, hash-to-shard validation, missing-manifest fail-closed behavior, manifest schema/range validation, empty-signal retirement, dual-location removal, unchanged legacy tombstone marker, and unchanged CrashSafe public slice API.

## Scope audit

The branch already contained one AW31 status-only commit after AW31 Evidence head `8da84c0bfc891f519a12576b281a3f7ba1341677`. Before this Evidence, AW32 added five commits and changed only:

- `tech-assets/moises-audio/Library/Sources/DeletionOwnershipIndex.swift`
- `tech-assets/moises-audio/Library/Tests/DeletionOwnershipShardingTests.swift`
- `tech-assets/moises-audio/Library/benchmarks/L2AW32ShardedDeletionOwnershipSelfCheck.swift`

No Shared, App, PARITY, Queue, work-package, lane-plan, resource-lock or other-lane implementation file was modified by AW32.

Implementation/test commits before Evidence:

1. `8f4180e6072db3a7f80e2e384745db198de8a1e4` — initial sharded ownership index
2. `472c122f3687c1b3363ec48f3d095b0ea48bbc37` — empty active-shard crash-signal recovery and idempotent shard activation
3. `4d5c8e8ede7b0b4af71ab5aee203ff6cf8bd58d4` — sharding regression tests
4. `5be5ab5aacd5fbfbb1d73a7225f3429c8398c870` — portable self-check
5. `b97d45e32ad823ad63d2d684382c63606316ff53` — align exact committed self-check source

## Remaining gates / limitations

- A single ownership shard still uses `contentsOfDirectory` for that shard and is not hard-capped by record count. Sharding changes the expected selection cost from all pending ownership filenames to active-shard-local filenames, but pathological hash concentration and actual 1k/10k/100k distribution/RSS/wall time need device measurement and may justify second-level bucket splitting.
- The pre-AW32 flat compatibility migration stops after `limit + 1` candidates but relies on filesystem enumeration order while it removes each migrated flat record. It is bounded and convergent, not a globally sorted migration.
- Journal enumeration remains intentionally priority/unbounded for correctness; extreme journal backlog still needs device/policy evidence.
- Actual iPhone/APFS process-kill behavior around active-manifest write, sharded record write, flat retirement, record removal and manifest retirement is pending.
- APFS/ENOSPC failure behavior for ownership manifest/shard writes remains pending.
- Apple Core Data runtime/WAL visibility, AW21 compaction, setlist recovery, real import/export/File Provider/codec and integrated device gates remain pending.
- WMA remains in reference format scope; an audited production compatibility decoder/license is still required if native decoding is unavailable.

## PARITY

No PARITY row is promoted from AW32. MOI-P001/P002/P017/P018/P019/P020/P024 remain MISSING until HQ performs Apple runtime, integrated iPhone, real-audio/reference and differential gates.

## Next lane-local priority

Re-read current Lane-2 gaps. The strongest remaining scalable-index candidates are hard-capping oversized deletion-ownership/managed-artifact/publication-intent shards or bounding the intentionally priority deletion-journal namespace, while preserving crash ordering and direct journal recovery. Device-only gates remain HQ pending but are not a reason to stop lane-local hardening.
