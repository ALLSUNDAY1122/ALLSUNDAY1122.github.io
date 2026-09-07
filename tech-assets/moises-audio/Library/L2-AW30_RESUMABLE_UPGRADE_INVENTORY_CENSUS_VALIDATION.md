# L2-AW30 Resumable Upgrade Inventory Census / Safe Authority Cutover Validation

Result: `COMPLETED_NON_PARITY`

## Scope

Lane 2 only. AW29 removed repeated O(N) managed-root traversal for fresh / verified-authoritative installs, but pre-AW29 upgrades and artifacts left before readiness registration remained outside the sharded inventory. AW30 adds a durable compatibility census that incrementally seeds the inventory and promotes authority only after two complete matching generations.

AW30 deliberately does **not** claim a strict bounded raw filesystem walk. Foundation exposes no portable durable cross-process directory-enumerator cookie for arbitrary pre-existing directories. Registration work and durable progress are bounded; raw compatibility enumeration may still be O(N) until authority cutover. After cutover, AW29 steady-state uses bounded direct shard reads.

## Fresh canonical state

At wave start:

- Notion canonical: `Moises技術同等化｜AI音源分離アプリ 正本`; v4 autonomous-lane contract unchanged.
- Worker contract SHA: `c9e8ec5d191108db6eb20fbd40db0dab3c46b725`.
- Work Package SHA: `aad7983bdaf315a996dce1496ed245008085c712`.
- Lane Plan SHA: `10b595b47e5a71278bde32e8656bd284e14e62eb`.
- Resource Lock SHA: `f727363edcf7cc209ca636db9b6d770f67d5402b`, integration epoch 20, assignment epoch 2.
- Worker-2 prior status blob: `3cfbfe064e6b4cc154d8c39f4108a02dc760e01d`.
- PARITY SHA: `db98892a379180c25ffeb3586a7c3353620a2d5d`.
- Worker branch matched AW29 final status commit `c1eef6a5a63dc591213aa75509698213de603cd7` exactly.

## Production behavior

### Durable compatibility census

`ManagedArtifactCompatibilityCensus.swift` stores migration state at:

`.LibraryRecovery/ArtifactInventory/v1/Census/state.json`

State contains schema version, generation, lexical checkpoint, rolling digest/count and the previous completed generation digest/count.

Default registration budget is 128 paths per invocation. Each invocation:

1. scans standard managed roots `Imports`, `Stems`, `Exports`;
2. selects at most `limit + 1` lexically ordered candidates after the durable checkpoint;
3. registers at most `limit` paths into the AW29 sharded inventory;
4. only after shard registration succeeds, atomically advances census state.

If a process terminates after shard writes but before state persistence, the same chunk is selected again and registration is idempotent.

### Two-generation authority cutover

A single complete census is insufficient for authority. The completed generation digest is based on:

- normalized relative path;
- modification time in microseconds;
- file size.

The next complete generation must produce the same digest **and** entry count. Only then does AW30 call the AW29 atomic authority-marker writer. Insert/remove/rename/mtime/size changes between generations therefore prevent promotion and cause another generation from the beginning.

If authority was written but process termination occurred before census-state cleanup, the next invocation sees the validated AW29 authority marker, removes stale census state, and returns without a managed-root scan.

### Safety / fail-closed authority

Census refuses authority when it encounters:

- a managed root that is not a real non-symlink directory;
- any symlink below a managed root;
- a directory-enumeration failure;
- a path escaping the managed-root namespace;
- corrupt/non-regular/symlinked census state.

The census does not delete user artifacts. It only populates inventory records and, after stable verification, writes the authority marker.

### Nonblocking user-data open

Census is a maintenance/cutover mechanism, not a prerequisite to accessing user projects. Both approved file-backed open routes advance exactly one census invocation per launch after legacy tombstone preparation:

- `CrashSafeProjectLibraryStore.openBulkPrepared(...)`
- `CrashSafeProjectLibraryStore.openPreservingUserData(...)`

They invoke census with `try?`. A census error therefore leaves authority absent and AW28 compatibility behavior active, while Library open/delete recovery continues. This is fail-closed for inventory authority but fail-open for user-data access.

Existing ordering remains:

legacy tombstone preparation -> census attempt -> targeted resolver/store construction -> interrupted delete recovery -> setlist recovery/integrity where applicable.

## Validation

Swift environment: Swift 6.2.1 Linux.

- AW30 census logic reconstructed source-equivalently against production-API-compatible AW29 inventory stubs: Swift 6 strict concurrency + warnings-as-errors => PASS.
- Exact remote production census blob was read back and statically audited after compile validation.
- `ManagedArtifactCompatibilityCensusTests.swift` covers two-generation cutover, process-value recreation/durable checkpoint, generation mutation, symlink rejection and corrupt-state rejection.
- production/static audit => `L2_AW30_STATIC_AUDIT_PASS checks=24/24`.

Static checks covered default 128 registration budget, valid-authority zero-scan return, durable state location, register-before-checkpoint ordering, atomic state persistence, lexical checkpointing, hash+count generation match, path+mtime+size digest, authority only on matching completed generation, generation reset after mismatch, managed-root restriction, root symlink rejection, nested symlink rejection, enumeration failure handling, normalized path validation, regular/non-symlink state validation, no destructive census operation, nonblocking canonical open calls, legacy-preparation ordering, recovery-after-census ordering, in-memory bypass in bulk open, no Shared/App/PARITY/schema change, explicit raw-enumeration limitation and post-authority race disclosure.

Portable self-check:

`L2_AW30_SELF_TEST_PASS initial_files=257 mutation_files=1 passes=27 completed_generations=3 max_registered_per_pass=32 authority=true post_authority_scan=0 symlink_fail_closed=true raw_enumeration_portably_unbounded=true`

The self-check created 257 preexisting real temporary artifacts, recreated the census value every invocation to model relaunch, limited registration to 32, inserted a lexically earlier artifact after generation 1, observed generation-2 mismatch, reached authority only after the later stable generation, confirmed zero scan after authority, and separately confirmed symlink fail-closed behavior.

This is Linux filesystem evidence only. It is not iPhone/APFS performance or PARITY evidence.

## Exact remote blobs

- `ManagedArtifactCompatibilityCensus.swift`: `963f786ea449ab09f9c859ab416fcb7300c2fc02`
- `CrashSafeProjectLibraryStore+BulkOpen.swift`: `0ed6219e7e57c0ee7869fe6c06bb79547cbafd59`
- `CrashSafeProjectLibraryStore+Recovery.swift`: `f550f9e69917215e86edd2878f187977c8cf1a8d`
- `ManagedArtifactCompatibilityCensusTests.swift`: `f5b3bb520cd1fe663ff8c359d2995a7fe30353b2`
- `L2AW30ManagedArtifactCompatibilityCensusSelfCheck.swift`: `d5ab96c196c413be05b204b29e5abf4e98aedc1f`

## Scope audit

Before Evidence, AW29 status commit -> AW30 branch contained seven commits and changed only five `tech-assets/moises-audio/Library/**` files. No Shared, App, PARITY, queue, work-package, lane-plan, resource-lock or other-lane path changed.

Implementation/test commits before Evidence:

1. `67b79730d6cce8d592d89bc377d7894a73fe1ab1` — resumable compatibility census
2. `0cb4f3b206a9b1f06fa2cdcb08c3745b39ed35d4` — initial bulk-open census wiring
3. `1e81c64dce2925e3b5602263ff9e9d78cdc6f37b` — initial preserving-open census wiring
4. `5f377476ee6de201acf9dfa2ea02e3c40c02067f` — make bulk-open census nonblocking
5. `6f4202d60c2ad4f44d675093a670b1d73003c6f5` — make preserving-open census nonblocking
6. `e92559cee8035d7928e156cfe12e0baedca5a0a5` — census regression tests
7. `a6c5ca77038c9edf24bfd1663a3b4aeed0ecb76d` — census self-check

## Remaining gates / limitations

- Raw compatibility enumeration remains potentially O(N) on each census invocation. AW30 bounds registration and persists progress honestly; it does not claim a portable durable filesystem enumerator cursor that Foundation does not provide.
- There is no filesystem transaction spanning the final complete scan and authority-marker write. Canonical ready writers are AW29 write-through registered, but an out-of-band or pre-readiness managed-file publication in that final cutover interval can still escape inventory. Authority is therefore safe for canonical lifecycle use but a durable publication intent/dirty signal is the next lane-local hardening target.
- A managed artifact created after authority but before `requireReady` registration can still survive as unindexed storage after process termination. It is not accidentally deleted, but it may leak space indefinitely without an explicit dirty/publication recovery signal.
- Individual AW29 inventory shard JSON size remains hash-distributed rather than hard entry-count capped.
- AW25 ownership slice selection still walks all ownership filenames each pass.
- Apple/iPhone census cost, APFS atomic-write behavior, force termination, WAL visibility, Core Data runtime and real IO/codec/File Provider evidence remain pending.
- Existing AW21/AW20/AW18 Apple metadata/setlist recovery gates and AW19/AW14/AW16 device/import/export/storage gates remain pending.

## PARITY

No PARITY row is promoted from AW30. MOI-P001/P002/P017/P018/P019/P020/P024 remain MISSING until HQ performs Apple runtime, integrated iPhone, real-audio/reference and differential gates.

## Next lane-local priority

Introduce a durable managed-artifact publication intent / dirty signal before canonical `Imports/**`, `Stems/**`, and `Exports/**` publication so a crash before `requireReady` registration is discoverable without restoring periodic full filesystem scans. Recovery must reconcile intent -> actual file -> inventory before orphan deletion authority, and any cross-lane publication writer that cannot use the Lane-2 seam must be surfaced as a precise HQ integration request rather than editing frozen contracts.
