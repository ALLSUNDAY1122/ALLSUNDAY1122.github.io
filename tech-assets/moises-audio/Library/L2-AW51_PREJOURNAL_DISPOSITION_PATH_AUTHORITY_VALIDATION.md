# L2-AW51｜Prejournal Disposition Path Authority Validation

Date: 2026-08-27 JST
Lane: LANE-2-IO-LIBRARY / Moises-Worker-2
Result: COMPLETED_NON_PARITY

## Canonical starting point

Fresh Notion read reported HQ Canonical Epoch 44 with Lane2 AW49 integrated, Run #316 SUCCESS, SwiftPM 462/462 PASS and Lane2 IO+Library full portable source typecheck PASS. Product PARITY remained zero. The Worker branch started this Wave at AW50 status commit `f8b7f4e28118c55c457964b592934b8b2ebe3b58` and was not rebased onto the moving integration branch.

## Why AW51

AW50 hardened export-registration intent/marker/prejournal quarantine transfer authority, but its own status left `Lane2PrejournalExportQuarantineManager` as the next direct data-safety gap. That manager owns explicit preserve/purge decisions and crash-recoverable disposition intents under:

- `.LibraryRecovery/PrejournalExport`
- `.LibraryRecovery/RecoveredPrejournalExport`
- `.LibraryRecovery/PrejournalExportDisposition`

Before AW51 it still used direct `fileExists`, `createDirectory`, `Data(contentsOf:)`, `moveItem` and `removeItem` authority in relaunch recovery and destructive purge paths. A dangling/symlink topology could therefore alter whether a path was interpreted as missing, present, recoverable or purgeable.

## Implementation

### 1. Disposition root and leaves

`recoverPendingDispositions()` now uses the AW50 ancestor-aware `LibraryManagedPathBoundary` before enumerating the disposition root. Each JSON disposition must be a real regular file before decoding. A symlink/dangling disposition root fails closed; a symlink disposition leaf is corrupt authority and is never decoded or removed.

Disposition persistence now:

1. creates the directory component-by-component through the boundary;
2. requires a completely absent destination rather than allowing an existing regular file to be atomically overwritten;
3. writes atomically;
4. revalidates the resulting leaf as a real regular file.

The final absent-only rule was added during same-Wave re-audit. Commit `8e50d815b79e4025910e958a5c60232df65e2ead` changed exactly the intended one line from `requireRegularFileOrMissing` to `requireSafeDestination`.

### 2. Preserve authority

`preserveForUser` and relaunch `apply(.preserveForUser)` now distinguish genuine absence from dangling/symlink authority for source and destination. The recovered root is created only through the boundary; destination must be absent; source must be a real directory; and the moved destination is revalidated before the durable disposition intent is retired.

If a dangling destination occupies the recovered batch path, preserve fails and the original pending batch remains intact.

### 3. Destructive purge authority

`applyPurge` now uses non-following existence semantics, re-inspects the batch and snapshot, requires a real directory immediately before removal, and verifies absence after removal. A symlink batch cannot become destructive purge authority. If relaunch recovery encounters such a destructive intent, the external target is untouched and the disposition intent remains durable for explicit resolution.

### 4. Inventory and recovered artifact URLs

Pending/recovered roots must themselves be real directories. Unsafe roots are surfaced non-destructively as the stable inventory issue `UNSAFE_ROOT` rather than being enumerated through a symlink. Batch artifact topology keeps the historical distinctions between nested directory, symlink and invalid file cases while adding the common boundary revalidation.

`recoveredArtifactURLs` revalidates each returned artifact as a real regular managed file immediately before exposing the URL.

## Portable validation

Exact AW51 manager source plus the exact AW50 `LibraryManagedPathBoundary` compiled with Swift 6.2.1 using:

`-swift-version 6 -warnings-as-errors -strict-concurrency=complete`

The focused real-filesystem harness passed after the final absent-only disposition update:

`L2_AW51_SELF_TEST_PASS checks=7 disposition_root=true dangling_destination=true disposition_leaf=true pending_root=true relaunch_preserve=true symlink_purge=true normal_preserve_purge=true preserve_purge_200_ms=2972.175 per_cycle_us=14860.873`

Validated scenarios:

1. disposition-root symlink fails closed without touching external contents;
2. dangling recovered destination blocks preserve and keeps the pending batch;
3. disposition-leaf symlink is rejected without changing its external target;
4. pending-root symlink is reported as `UNSAFE_ROOT` and external entries are not inventoried;
5. a manually persisted preserve intent converges correctly after relaunch;
6. a persisted purge intent pointing at a symlink batch cannot delete through the link and is not retired;
7. normal preserve -> recovered artifact URL -> purge continues to work.

The 200-cycle timing is Linux portable reference only. It is not physical-iPhone/APFS performance evidence and is not a PARITY gate.

## Regression source

`PrejournalDispositionPathAuthorityTests.swift` adds six async XCTest regressions for the same destructive/recovery authority cases. The test source itself passed Swift 6.2.1 strict-concurrency typecheck with the exact AW51 manager and boundary. The first draft placed `await` inside `XCTUnwrap`'s non-concurrent autoclosure; that test-harness compile defect was corrected and typecheck rerun successfully.

This Worker branch does not have automatic XCTest execution for this checkpoint, so committed XCTest execution PASS is not claimed here. HQ/integrated CI must run the full package and existing `PrejournalExportQuarantineTests.swift` together with the new regressions.

## Scope audit

AW50 status -> AW51 pre-Evidence implementation compare was `ahead 4 / behind 0` and limited to three Library-owned files: the manager, one regression test file and one benchmark/self-check file. No Shared, App, PARITY, queue, resource-lock or other-Lane file was changed.

## Residual limits

- Boundary validation and subsequent Foundation move/remove/read/write remain separate syscalls. Same-path replacement TOCTOU is not eliminated.
- Whole-batch purge still uses Foundation recursive directory removal after snapshot and boundary revalidation. AW51 prevents a symlink batch root from authorizing that purge but does not provide descriptor-relative recursive deletion.
- Physical iPhone/APFS/File Provider/protection-class/force-termination behavior remains unmeasured.
- Real export/share/AVFoundation validity and current-iPhone Moises differential evidence remain external gates.
- MOI-P001/P002/P017/P018/P019/P020/P024 remain MISSING under HQ PARITY authority.

## Result

`COMPLETED_NON_PARITY`

AW51 closes the portable preserve/purge disposition path-authority gap without changing Shared/App/PARITY contracts. The next Lane-2 portable audit should move to segmented managed-artifact inventory/migration and deletion/recovery metadata, prioritizing stores whose metadata can authorize destructive cleanup or canonical lifecycle transitions.
