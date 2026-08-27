# L2-AW49｜Library Lifecycle Path Authority Validation

Date: 2026-08-27 JST
Lane: LANE-2-IO-LIBRARY / Moises-Worker-2
Result: COMPLETED_NON_PARITY

## Canonical starting point

A fresh Notion read still reported HQ Canonical Epoch 41 with Lane 2 AW47 integrated at `121c3f8b...`, zero PARITY promotions, and the v4 autonomous independent-lane rule active. The Worker branch itself started this Wave exactly at AW48 status commit `3ed056ad320efd6d1960253a40e1ebdc2860eba6`; it was not rebased onto moving integration state.

`PARITY_MATRIX.json` remains unchanged and all Lane-2 product rows remain MISSING pending HQ/device/reference gates.

## Why AW49

AW47/AW48 hardened the primary and auxiliary IO filesystem authorities, but AW48 explicitly did not claim every Library-owned recovery/index/quarantine directory.

A fresh source audit found a direct portable data-safety gap in `.LibraryLifecycle`:

- `Lane2LifecycleMetadataStore` created/removes v2 staging directories directly with `FileManager`;
- project/export/failure sidecars were read and overwritten without a shared non-following path boundary;
- corrupt metadata was moved into `Quarantine` without validating the quarantine directory authority;
- an unmarked v2 tree could be deleted/reinitialized based on lexical paths alone;
- `Lane2LifecycleQuarantineRecovery` read/wrote/cleared its durable export-recovery barrier directly;
- recovered export readiness and corrupt-export scans did not share the same fail-closed directory/leaf authority.

These metadata files control export cleanup, project ownership, migration, quarantine, recovery blocking and relaunch behavior. A symlink substitution can therefore affect destructive/recovery decisions and is higher priority than optional performance work.

## Implementation

### 1. Shared Library filesystem boundary

Added `LibraryManagedPathBoundary.swift`.

It:

- treats dangling symlinks as existing unsafe nodes rather than missing paths;
- validates the configured Library root and every existing descendant directory component;
- creates directories one component at a time after validating the parent;
- distinguishes genuine absence from regular-file authority;
- validates regular files before read/overwrite/remove/move;
- validates destinations before publication/quarantine moves;
- trusts only ancestors above the configured app-owned root, matching AW48's documented sandbox/container trust boundary.

The implementation intentionally mirrors the already-proven Lane-2 IO boundary semantics without introducing a Shared/App contract dependency.

### 2. `Lane2LifecycleMetadataStore` hardened

The lifecycle metadata store now applies the boundary to:

- `.LibraryLifecycle` and `v2/projects` / `v2/exports` creation;
- v2 `schema.json` marker authority;
- legacy `lane2-lifecycle-v1.json` reads/quarantine;
- project ownership shards;
- export shards and cleanup removal;
- bounded failure history;
- generic JSON enumeration;
- atomic sidecar writes and post-write revalidation;
- corrupt-shard quarantine source and destination;
- unmarked-v2 discard/reinitialization.

The existing crash-safety contract is preserved: an unmarked real v2 directory is staging metadata and may be discarded, but a symlink/non-directory occupying the v2 path is not treated as disposable staging authority and fails closed.

### 3. Export-metadata quarantine barrier hardened

`Lane2LifecycleQuarantineRecovery` now:

- validates `.LibraryLifecycle/Recovery` before barrier reads/writes/removal;
- treats a dangling/symlink barrier as corrupt authority rather than no barrier;
- validates barrier leaf before atomic overwrite and after persistence;
- validates the v2 export directory and each JSON shard before decoding;
- classifies unsafe shard leaves as corruption without reading through them;
- validates recovered export artifacts as real regular managed files before readiness;
- validates the barrier again before destructive clear.

This preserves the fail-closed invariant that corrupt or redirected recovery metadata cannot silently unblock export cleanup.

## Negative and recovery regression source

Added `LifecycleManagedPathBoundaryTests.swift` with 8 focused cases:

1. `.LibraryLifecycle` symlink cannot redirect initialization;
2. unmarked `v2` symlink is not recursively discarded;
3. dangling `schema.json` is not treated as absent;
4. project shard symlink cannot become metadata authority;
5. `Quarantine` symlink cannot redirect corrupt bytes;
6. `Recovery` symlink cannot redirect barrier persistence;
7. dangling barrier is corrupt authority, not missing state;
8. recovered export symlink cannot satisfy readiness.

These XCTest cases are committed for the integrated package/Apple-capable test gate. The Worker branch has no automatic CI run for this Wave, so they are not claimed as executed here.

## Portable strict-concurrency self-check

A focused copy of the committed `LibraryManagedPathBoundary` logic plus the committed AW49 benchmark logic was compiled with Swift 6.2.1 using:

- `-strict-concurrency=complete`
- `-warnings-as-errors`
- `-parse-as-library`

The first compile correctly exposed a defect in the benchmark itself: throwing calls were placed directly inside `precondition` autoclosures. The benchmark was fixed in the same Wave and the check was rerun.

Final output:

`L2_AW49_BOUNDARY_SELF_TEST_PASS checks=6 dangling=true directory_symlink=true missing=true regular=true node_probe_10000_ms=178.888`

The six checks cover genuine absence, dangling leaf rejection, regular-file acceptance, directory-symlink rejection, v2-symlink rejection and safe future destination handling.

The 10,000-node probe timing is Linux portable evidence only. It is not an iPhone/APFS performance threshold and is not PARITY evidence.

## Scope / limitations

AW49 does **not** claim elimination of all filesystem races.

Remaining limitations include:

- validation and subsequent Foundation read/write/move/remove remain separate syscalls; descriptor-relative/no-follow primitives would be required to fully close path-replacement TOCTOU;
- recursive removal of a validated real unmarked-v2 staging directory still relies on Foundation's recursive removal semantics for descendants;
- other Library-owned durable stores such as export-registration, prejournal quarantine, segmented inventory/migration and deletion-ownership paths retain their own prior guards and should be re-audited independently rather than inheriting this claim automatically;
- Apple Core Data/WAL/APFS/Files/File Provider/protection-class and force-termination behavior remain physical-runtime gates;
- production codecs, real import/export/share, real audio validity/sync/naming and Differential Moises remain outstanding.

No Shared/App/PARITY/Core Data schema contract was changed.

## PARITY

No PARITY promotion is requested from AW49. `MOI-P001`, `P002`, `P017`, `P018`, `P019`, `P020` and `P024` remain MISSING until HQ's current-iPhone, real-runtime and differential gates are satisfied.
