# L2-AW28 Bounded Targeted Orphan Sweep Validation

Result: `COMPLETED_NON_PARITY`

## Scope

Lane 2 only. AW27 removed full-live-library materialization from foreground project deletion, but `sweepOrphanArtifacts()` still loaded every live maintenance project/source/stem before deciding whether filesystem artifacts were orphaned. It also removed every eligible orphan in one invocation.

AW28 removes the full-live Core Data projection from the approved file-backed orphan-sweep route and bounds live-reference lookup/deletion work to a durable filesystem candidate window.

## Fresh canonical state

At wave start:

- Notion canonical: `Moises技術同等化｜AI音源分離アプリ 正本`, v4 autonomous lanes unchanged.
- Worker contract SHA: `c9e8ec5d191108db6eb20fbd40db0dab3c46b725`.
- Work Package SHA: `aad7983bdaf315a996dce1496ed245008085c712`.
- Lane Plan SHA: `10b595b47e5a71278bde32e8656bd284e14e62eb`.
- Resource Lock SHA: `f727363edcf7cc209ca636db9b6d770f67d5402b`, integration epoch 20, assignment epoch 2.
- Worker-2 prior status blob: `f8ccdd24ff23d9e4e256da455c58097cf59a84f1`.
- PARITY SHA: `db98892a379180c25ffeb3586a7c3353620a2d5d`.
- Worker branch matched AW27 status commit `0e895e3d404c0d6a4381786d2a4c846ba31a307a` exactly.

## Production behavior

### Bounded candidate window

`BoundedOrphanSweep.swift` adds a default maximum of 128 eligible old artifact candidates per pass.

The scanner still visits managed roots `Imports`, `Stems`, and `Exports`, but retains only bounded candidate buffers (`limit + 1`) rather than building an unbounded orphan list. Young files are counted and excluded before destructive consideration.

### Durable cursor and starvation avoidance

The cursor is stored atomically at:

`.LibraryRecovery/OrphanSweep/cursor-v1.json`

Candidate ordering is lexical by relative path. After a successful candidate application, the cursor advances to the last selected path. If live-referenced artifacts occupy an early lexical window, the next invocation proceeds beyond them instead of repeatedly selecting the same referenced files. At the end of the eligible namespace, the next pass wraps to the start.

Cursor persistence happens only after candidate application succeeds. A process death before cursor persistence repeats the prior window idempotently rather than skipping possibly unprocessed candidates.

### Targeted live-reference authorization

For approved file-backed `CrashSafeProjectLibraryStore` construction:

1. interrupted deletes are recovered first under the existing mutation gate;
2. one bounded old-file candidate slice is selected;
3. only selected `Imports/**` and `Stems/**` paths are sent to the AW26 live-reference resolver;
4. live referenced source/stem paths are retained;
5. selected unreferenced candidates that still exceed the grace period are deleted;
6. the cursor advances only after the pass finishes.

`Exports/**` preserve pre-AW28 semantics: the existing Library maintenance projection never treated exports as project references, so old export artifacts remain grace-based cleanup candidates and are not sent to Core Data live-reference lookup.

Direct/in-memory construction without an injected live-reference resolver retains the legacy full-maintenance fallback and remains outside the approved App production route.

### Destructive revalidation and filesystem safety

Immediately before removing a selected candidate AW28 rechecks:

- path remains inside the configured managed roots;
- file still exists;
- it is a regular non-symlink file;
- its modification date still exceeds the grace period;
- it is not in the live-reference set.

Symlinks are never selected as deletion candidates. Directory symlinks are not descended into. Missing candidates are idempotently already clean.

## Validation

Portable helper compiled with Swift 6.2.1 strict concurrency and warnings-as-errors: PASS.

`BoundedOrphanSweepTests.swift` strict XCTest typecheck: PASS.

Production `CrashSafeProjectLibraryStore.swift` AW28 route and Apple-gated `TargetedOrphanSweepCoreDataTests.swift` syntax parse: PASS. Actual Apple Core Data execution is pending and is not counted as PASS.

Exact committed source blobs:

- `BoundedOrphanSweep.swift`: `a429e3fdd9e04656a3e04e6370d96288feda7239`
- `CrashSafeProjectLibraryStore.swift`: `9ce2e9522ae89b64d57d6d0f7aa22624fe44998b`
- `BoundedOrphanSweepTests.swift`: `297119424e7ce8fdd736d4603603ab6320a68654`
- `L2AW28BoundedOrphanSweepSelfCheck.swift`: `bb171c23a4a6a8f416ce7ac6163f2576b1dcfb64`
- `TargetedOrphanSweepCoreDataTests.swift`: `01ef4c37a3731894f3b4a8520fc5168dc4c52008`

Exact committed self-check rerun:

`L2_AW28_SELF_TEST_PASS scenarios=4 limit=2 scanned=6 first_referenced=2 second_removed=2 wrapped=true`

The self-check covers:

1. bounded two-candidate selection;
2. referenced first window retained;
3. cursor advances to later orphan candidates instead of starving them;
4. later orphan files are removed;
5. deletion-time mtime revalidation retains a rejuvenated file;
6. cursor wrap after the end of the namespace;
7. symlink target remains untouched.

Production/static audit:

`L2_AW28_STATIC_AUDIT_PASS checks=18/18`

Checks included:

- recovery precedes orphan sweep;
- mutation gate remains around recovery + sweep;
- approved route does not call full maintenance projection before candidate selection;
- default candidate budget is 128;
- candidate buffers are bounded to `limit + 1`;
- lexical deterministic ordering;
- durable cursor file is under `.LibraryRecovery`;
- cursor written atomically;
- cursor advances only after candidate application;
- wrap prevents referenced-prefix starvation;
- young files are excluded;
- modification date is revalidated before deletion;
- symlinks are excluded and directory symlinks are not descended;
- only selected Imports/Stems paths reach Core Data live-reference lookup;
- referenced candidate paths are retained;
- Exports retain pre-AW28 grace semantics;
- direct/in-memory compatibility fallback remains explicit;
- no Shared/App/PARITY/schema change.

## Scope audit

Before Evidence, AW27 status commit -> AW28 branch contained five commits and modified only five `tech-assets/moises-audio/Library/**` files. No Shared, App, PARITY, queue, work-package, lane-plan or other-lane path was modified.

Implementation commits before Evidence:

1. `035461bc5965909fd7f853c9b20b4dc628085785` — bounded orphan cursor/window
2. `ff15398d786975c8c27c51e33ab36b8aab4ee3f5` — CrashSafe targeted orphan sweep route
3. `8f2ba1876b8db1d009339d68a531c984bdc0a8cd` — portable regression tests
4. `af84697ac69e3cd22aa842d585b8aea83ed91106` — exact filesystem self-check
5. `8216c4cc277ea8736ec720282082c7a1fb70f700` — Apple-gated Core Data integration test

## Remaining gates / limitations

- The filesystem scanner still traverses all visible regular files under managed roots to choose the bounded lexical window. Candidate retention, Core Data query scope and destructive work are bounded, but directory traversal remains O(N).
- Actual iPhone/APFS wall time, RSS and large-directory traversal cost are unmeasured.
- AW26/AW27/AW28 fresh read-only Core Data resolver behavior still requires real iOS WAL visibility testing.
- Force termination around candidate selection, candidate application and cursor persistence remains unverified on device.
- APFS/ENOSPC failures during orphan removal/cursor persistence remain unverified.
- Direct/in-memory compatibility routes retain the old full maintenance projection.
- AW25 ownership-directory selection still walks all ownership filenames.
- Existing Apple/runtime/import/export/codec/File Provider/PARITY gates remain pending.

## PARITY

No PARITY row is promoted from AW28. MOI-P017/MOI-P024 and other Lane-2 rows remain MISSING until HQ performs Apple runtime, integrated iPhone, real-audio/reference and differential gates.

## Next lane-local priority

Bound the remaining O(N) managed-root filesystem traversal itself with a crash-safe durable traversal frontier/sharded inventory so large artifact directories do not require a complete metadata walk on every orphan-sweep pass, while preserving cursor fairness, grace-period semantics and symlink/root safety.
