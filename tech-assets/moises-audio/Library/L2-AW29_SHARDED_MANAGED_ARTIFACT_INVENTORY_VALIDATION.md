# L2-AW29 Sharded Managed Artifact Inventory Validation

Result: `COMPLETED_NON_PARITY`

## Scope

Lane 2 only. AW28 bounded orphan candidate retention, targeted Core Data lookup and destructive work, but each sweep still traversed all visible files below `Imports`, `Stems` and `Exports` to find that bounded candidate window. AW29 removes that O(N) managed-root walk from **fresh / verified-authoritative steady-state** by maintaining a durable deterministic artifact inventory. Upgrade/pre-AW29 installations remain on the AW28 compatibility scanner until an explicit complete census is implemented and verified.

## Fresh canonical state

At wave start:

- Notion canonical: `Moises技術同等化｜AI音源分離アプリ 正本`; v4 autonomous-lane contract unchanged.
- Worker contract SHA: `c9e8ec5d191108db6eb20fbd40db0dab3c46b725`.
- Work Package SHA: `aad7983bdaf315a996dce1496ed245008085c712`.
- Lane Plan SHA: `10b595b47e5a71278bde32e8656bd284e14e62eb`.
- Resource Lock SHA: `f727363edcf7cc209ca636db9b6d770f67d5402b`, integration epoch 20, assignment epoch 2.
- Worker-2 prior status blob: `5527461c8289005daf6e3ef378669fdba737ad91`.
- PARITY SHA: `db98892a379180c25ffeb3586a7c3353620a2d5d`.
- Worker branch matched AW28 final status commit `01ccf1f32c30c49f2ce22e4be5240f83c9225646` exactly.

## Production design

### Deterministic sharded inventory

`ManagedArtifactInventory.swift` stores ready managed artifacts in 256 deterministic FNV-1a path shards:

`.LibraryRecovery/ArtifactInventory/v1/Shards/00.json ... ff.json`

It does not enumerate the shard directory to select work. The traversal cursor directly names a shard and optional last path:

`.LibraryRecovery/ArtifactInventory/v1/cursor.json`

Default steady-state budgets are:

- 4 shards visited per pass;
- 128 orphan candidates per pass.

Shard and cursor writes are atomic JSON. Shard reads validate schema, shard identity, normalized managed path, path-to-shard hash, duplicate paths, and regular/non-symlink file type. Corrupt shards/cursors fail closed.

### Authority boundary

The inventory is not trusted merely because a marker path exists. `ManagedArtifactInventoryMarker.swift` requires the authority marker to be a regular non-symlink file whose exact payload is:

`lane2-managed-artifact-inventory-v1\n`

Malformed/missing authority therefore falls back to AW28 filesystem compatibility instead of hiding unmanaged artifacts.

The canonical first-artifact activation in `ManagedArtifactInventoryFreshActivation.swift` marks a fresh installation authoritative only when every visible regular managed artifact is exactly the current first ready artifact. Any second preexisting file, symlink or enumeration error leaves the install non-authoritative.

This is intentional upgrade safety: pre-AW29 installations are never assumed completely indexed from partial observations.

### Write-through readiness boundary

`LibraryArtifactLifecycle.requireReady(relativePath:)` retains its existing regular/non-empty validation and then:

1. attempts safe first-artifact activation;
2. registers the ready path if it belongs to `Imports/**`, `Stems/**` or `Exports/**`.

This reuses existing canonical readiness calls from import/project creation, stem recording, export recording and ready-artifact promotion without changing Shared/App contracts. Non-managed staging paths are ignored.

### Steady-state orphan sweep

`BoundedOrphanSweep.swift` now has two modes:

- valid authoritative inventory + standard managed roots: direct bounded shard reads; no managed-root filesystem enumeration for candidate selection;
- non-authoritative/upgrade installation: AW28 bounded candidate semantics with full filesystem compatibility scan.

The existing `CrashSafeProjectLibraryStore.sweepOrphanArtifacts()` order is unchanged:

1. mutation gate;
2. interrupted delete recovery;
3. bounded candidate preparation;
4. only selected `Imports/**` / `Stems/**` paths go to AW26 targeted Core Data live-reference lookup;
5. candidate application revalidates filesystem state;
6. cursor persists only after application succeeds.

### Destructive revalidation

Inventory records are never deletion authority by themselves. Immediately before removal AW29 rechecks:

- managed-root membership;
- current filesystem existence;
- regular non-symlink file type;
- current modification time / grace period;
- live-reference set for selected source/stem paths.

Missing files retire stale inventory entries. Files that became young are retained and their inventory mtime is refreshed. A removed file is deleted from inventory only after the filesystem deletion decision. If inventory persistence fails after a successful file deletion, the stale record is safe and converges as missing on a later pass.

## Validation

Swift environment: Swift 6.2.1 Linux.

- exact AW29 inventory + fresh-activation production sources with minimal Library contract stubs: Swift 6 strict concurrency + warnings-as-errors => PASS;
- AW29 `BoundedOrphanSweep.swift` exact source with compatible minimal stubs: Swift 6 strict concurrency + warnings-as-errors => PASS;
- `ManagedArtifactInventoryTests.swift`: strict XCTest typecheck => PASS;
- updated `ManagedArtifactInventoryWiringTests.swift`, including malformed authority fallback: strict XCTest typecheck => PASS;
- marker validation extension strict compile => PASS;
- production/static audit => `L2_AW29_STATIC_AUDIT_PASS checks=24/24`.

Static checks covered shard/candidate budgets, deterministic direct shard addressing, atomic shard/cursor/authority persistence, corrupt shard/cursor fail-closed behavior, non-symlink checks, deletion-time mtime/live-reference revalidation, missing-record convergence, readiness write-through registration, staging exclusion, safe first-artifact activation, second-preexisting-file/enumeration-error rejection, exact authority marker validation, authoritative-only inventory routing, explicit AW28 fallback, mutation/recovery/live-reference/apply/cursor order, standard-root restriction, and no Shared/App/PARITY/schema changes.

Exact committed portable self-check rerun:

`L2_AW29_SELF_TEST_PASS files=512 referenced=32 removed=480 passes=64 shard_count=256 max_shards_per_pass=4 max_candidates_per_pass=13 upgrade_fail_closed=true`

The self-check created 512 real temporary managed files, registered them through the readiness boundary, retained 32 simulated live references, removed 480 old unreferenced files, and converged in 64 bounded passes. Every pass visited at most four inventory shards; the observed maximum candidate count was 13 under a configured limit of 16. A simulated upgrade with two preexisting managed files refused authoritative activation.

These are Linux filesystem/inventory results. They are not iPhone/APFS/SQLite performance or PARITY evidence.

## Exact remote blobs

- `ManagedArtifactInventory.swift`: `3a8bfce5b9c9410fd0084c397ecea9c2e59fadb8`
- `ManagedArtifactInventoryFreshActivation.swift`: `9e320807c67e2b1eeae1b37116e183301e48f2a4`
- `ManagedArtifactInventoryMarker.swift`: `5d5780a583d79a49f013eab4dad56051081bf21f`
- `BoundedOrphanSweep.swift`: `99c793cb4b4ca8acfe8d22a66219413eae70fded`
- `LibraryArtifactLifecycle.swift`: `eb6c211140e8d5f95ff06cf4994df861c514b355`
- `ManagedArtifactInventoryTests.swift`: `bae30da3f54ae87055697b8a306a11527edc9e84`
- `ManagedArtifactInventoryWiringTests.swift`: `b4a6891cc29998c9015edc3e49253ea8f4c5cbe7`
- `L2AW29ManagedArtifactInventorySelfCheck.swift`: `64ef8f3b92d181e04c7a84cfc3b9aba9b25b08ca`

## Scope audit

Before Evidence, AW28 status commit -> AW29 branch contained 12 commits and changed only eight `tech-assets/moises-audio/Library/**` files. No Shared, App, PARITY, queue, work-package, lane-plan, resource-lock or other-lane file changed.

Implementation/test commits before Evidence:

1. `6463d003ff74e090a32d24cddf3ece4829065f3b` — sharded managed artifact inventory
2. `c5f612aa8e58c9d65c2a4a83399f6222b03d35ba` — inventory-backed bounded orphan route
3. `10d8aebb39a782cec686c946ac590639b009e405` — safe first-artifact activation
4. `9d7b94170e306aaec672a14d22e037ace636ed2a` — readiness write-through wiring
5. `b40664e5da754c2c2f2ae570329a2ed2ac012ee0` — inventory regression tests
6. `794cf7e8a3e91b03872b942294f1cced0436c5f2` — inventory self-check
7. `783ff638def5c0f3b01d25474e1242a10f99b0a6` — self-check throwing-assertion correction
8. `eb30009560a102810ba095279f9b911ff38530c5` — readiness/fallback wiring tests
9. `4eeca7d8f8745373fc2ddf960e06f3e8027b8f29` — exact authority marker validator
10. `119f781a132f40bc2059e649e3204b24c3374e26` — require validated authority in sweep route
11. `6c51194f6e2262aff10474adb0950ad4fbbbc94f` — require validated authority in fresh activation
12. `62e48e407e22a1e188dd51d47443aa9c17de8c3d` — malformed marker regression

## Remaining gates / limitations

- Pre-AW29/upgrade installations remain on the AW28 O(N) filesystem compatibility scan until a complete bounded/resumable compatibility census populates every existing managed artifact and only then writes the authority marker.
- A crash can create an app-owned managed artifact before the canonical `requireReady` boundary. Such a pre-readiness artifact is safe from accidental deletion because it is absent from the authoritative inventory, but it may leak storage until a compatibility/reconciliation census discovers it. This is the next correctness/scalability target.
- One shard JSON is hash-distributed but not hard-capped by entry count; actual 1k/10k/100k artifact distribution, shard decode size, RSS and wall time need iPhone measurement.
- `initializeFreshAuthoritativeIfNoManagedArtifacts()` remains a noncanonical convenience helper; production readiness activation is `activateForFirstManagedArtifactIfSafe(...)`.
- AW25 ownership-slice selection still walks all ownership filenames.
- Fresh read-only Core Data WAL visibility, Apple runtime execution, force termination, APFS/ENOSPC behavior, real import/export/File Provider/codec evidence and integrated PARITY gates remain pending.

## PARITY

No PARITY row is promoted from AW29. MOI-P001/P002/P017/P018/P019/P020/P024 remain MISSING until HQ runs the required Apple runtime, iPhone, real-audio/reference and differential gates.

## Next lane-local priority

Implement a bounded/resumable compatibility census for pre-AW29 and pre-readiness managed artifacts. It must incrementally populate the 256 inventory shards, survive process termination and directory mutation, retain AW28 live-reference/grace/symlink safety, and write the authority marker only after a complete verified census cycle.
