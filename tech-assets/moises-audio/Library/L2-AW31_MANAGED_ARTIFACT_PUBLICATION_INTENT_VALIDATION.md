# L2-AW31 Managed Artifact Publication Intent Validation

Result: `COMPLETED_NON_PARITY`

## Scope

Lane 2 only. AW29 introduced authoritative sharded steady-state artifact inventory and AW30 added bounded/resumable compatibility census. One correctness gap remained after authority: a process could publish a final `Imports/**`, `Stems/**`, or non-batch `Exports/**` file and terminate before `LibraryArtifactLifecycle.requireReady(...)` registered that path in the inventory. Because authoritative steady-state intentionally avoids full managed-root scans, that file could otherwise remain invisible to orphan maintenance.

AW31 closes the Lane-2-owned publication gap with a durable pre-publication intent and bounded previous-session recovery. It does not alter Shared/App/PARITY contracts.

## Fresh canonical state

At wave start:

- Notion canonical: `Moises技術同等化｜AI音源分離アプリ 正本`; v4 autonomous independent lanes unchanged.
- Worker contract SHA: `c9e8ec5d191108db6eb20fbd40db0dab3c46b725`.
- Work Package SHA: `aad7983bdaf315a996dce1496ed245008085c712`.
- Lane Plan SHA: `10b595b47e5a71278bde32e8656bd284e14e62eb`.
- Resource Lock SHA: `8e1a4774ca5824f711539eb990d04d0803bfa525`, integration epoch 21, assignment epoch 2; Lane-2 ownership unchanged.
- Worker-2 prior status blob: `a685aa3ae5516135bfb8bc1da026d45d62534074`.
- PARITY SHA: `db98892a379180c25ffeb3586a7c3353620a2d5d`.
- Worker branch start was AW30 status commit `e9223bc45a4f339649877a207b258d2c3b23f56a`.

## Durable publication ordering

`IO/Sources/ManagedArtifactPublicationJournal.swift` owns the pre-publication signal. It stores deterministic path-sharded records at:

`.LibraryRecovery/ArtifactInventory/v1/Publications/Shards/00.json ... ff.json`

and a recovery cursor at:

`.LibraryRecovery/ArtifactInventory/v1/Publications/cursor.json`

Default previous-session recovery budgets are:

- 64 publication candidates;
- 128 visited journal records;
- 4 visited shards.

The canonical single-file publication order is now:

1. calculate final managed relative path;
2. atomically persist the publication intent;
3. move/rename staging bytes to the final path;
4. `LibraryArtifactLifecycle.requireReady(...)` validates the final artifact;
5. register the final managed path in AW29 inventory;
6. only then retire the publication intent.

A process termination in the critical interval between steps 3 and 5 therefore leaves a bounded durable signal instead of an invisible managed file.

`IOFileStore.finalizeImport(...)` and `finalizeExport(...)` use this ordering. `IOSAudioIOService` routes app-owned import, external File Provider import, direct-download import, compatibility-decoded import, and its non-batch export finalization through these IOFileStore methods.

`LibraryArtifactLifecycle.promoteReadyArtifact(...)` applies the same pre-publication ordering only when the final path is under `Imports`, `Stems`, or `Exports`. Non-managed promotion preserves the pre-AW31 behavior and is not forced into the managed publication journal.

## Rollback behavior

If the final move fails, only the current-session intent is cancelled. `IOFileStore.removeIfExists(...)` also retires a current-session intent only after the target path is actually absent, covering non-batch multi-output rollback without discarding recovery evidence for a file that failed to delete.

A same-path intent from a prior process is never overwritten by a new process. `begin(...)` fails closed with `priorSessionIntentExists` until canonical open recovery resolves the old state.

## Previous-session recovery

`Library/Sources/ManagedArtifactPublicationRecovery.swift` consumes only previous-process publication intents; it never enumerates `Imports`, `Stems`, or `Exports`.

For each selected bounded record:

- final path missing: publication never became visible at the contract path; retire the intent idempotently;
- final path is a regular non-symlink file: register it in the managed-artifact inventory first, then retire the intent;
- final path is symlink/non-regular: retain the intent and revoke inventory authority.

Zero-byte regular interrupted outputs may be indexed by recovery. They have no Library metadata/live reference and remain subject to the existing grace-based orphan policy; recovery does not fabricate project ownership or mark them ready user assets.

If publication-journal shard/cursor decoding itself fails, canonical open revokes inventory authority. Existing inventory shards remain preserved for AW30 reconciliation; only the authority claim is removed.

## Authority/census gate

During implementation review, an unsafe sequence was found and fixed: running AW30 census immediately after AW31 had invalidated authority could allow census to re-authorize an unresolved corrupt/unsafe publication journal in the same open.

Both approved file-backed opens now enforce:

`publication recovery safe -> AW30 census may advance`

and:

`publication recovery corrupt/unsafe -> authority remains absent; AW30 census does not run in that open`.

Affected canonical routes:

- `CrashSafeProjectLibraryStore.openPreservingUserData(...)`
- `CrashSafeProjectLibraryStore.openBulkPrepared(...)`

The legacy/raw/in-memory routes remain compatibility/test routes and are not the approved App integration path.

## Existing atomic batch export contract

`IOExportBatchTransaction` already writes and synchronizes `.lane2-registration-pending` inside the staging batch before the atomic directory rename into `Exports/Batches`. Older-process markers are owned by the existing Library export-registration/quarantine recovery. AW31 deliberately does not add a second generic publication-intent owner to this batch path.

This preserves one recovery authority per publication mechanism:

- single-file Imports/non-batch Exports and Library managed promotion: AW31 publication journal;
- atomic multi-stem export batches: existing `.lane2-registration-pending` contract.

## Validation

Portable environment: Swift 6.2.1 Linux.

- AW31 publication journal + publication recovery source-equivalent core: Swift 6 strict concurrency + warnings-as-errors typecheck => PASS.
- exact committed self-check source blob: `7834d6e1e9f91d09d5a2de0bf9f2e8e1569eebad`; local validated source had the same Git blob SHA.
- exact committed self-check rerun with the source-equivalent publication core =>

`L2_AW31_SELF_TEST_PASS prior_intents=256 published=128 missing=128 current_preserved=16 passes=64 max_candidates=7 max_records=7 max_shards=4 conflict_fail_closed=true symlink_fail_closed=true`

The self-check exercised 256 previous-session intents (128 published regular files, 128 missing), 16 current-session intents that must not be consumed, bounded traversal, prior-session same-path conflict, and unsafe symlink retention.

Portable regression sources additionally cover:

- published prior-session intent -> inventory registration -> intent retirement;
- missing prior-session publication -> idempotent intent retirement;
- current-session intent preservation;
- bounded candidate/record/shard selection;
- unsafe symlink -> intent retained + authority revoked;
- `IOFileStore.finalizeImport` leaves an intent before Library readiness;
- Library readiness registers inventory before retiring the intent;
- simulated next-process adoption after finalize-before-readiness interruption;
- successful `removeIfExists` rollback retires only the current-session intent;
- managed `promoteReadyArtifact` publication ordering;
- non-managed promotion compatibility.

Static production review: `L2_AW31_STATIC_AUDIT_PASS checks=28/28`.

The checks covered: Lane-2-only paths; journal location in IO rather than reverse IO->Library dependency; 256 deterministic publication shards; 64/128/4 recovery defaults; normalized managed-root-only paths; duplicate-path/prior-session conflict rejection; atomic shard/cursor writes; regular/non-symlink shard/cursor validation; intent before IO final move; intent retained after successful move; current-session cancel on failed move; rollback cancel only after file absence; Library inventory registration before intent retirement; managed-only Library promotion journaling; non-managed promotion compatibility; previous-session-only recovery; missing-final idempotence; regular-file inventory-first recovery; symlink/non-regular fail closed; authority invalidation on unsafe/corrupt state; no managed-root enumeration in publication recovery; recovery cursor after record processing; preserving-open recovery before census/delete recovery; bulk-open recovery before census/delete recovery; census allowed only after safe publication recovery; existing batch export marker left unchanged; no metadata fabrication; and no Shared/App/PARITY/schema edits.

## Scope audit

Immediately before Evidence, AW30 status commit `e9223bc45a4f339649877a207b258d2c3b23f56a` -> AW31 branch was 15 commits ahead and modified only nine Lane-2 files under `tech-assets/moises-audio/IO/**` and `tech-assets/moises-audio/Library/**`. No Shared, App, PARITY, queue, work-package, lane-plan, resource-lock, package, or other-lane file changed.

Implementation/test commits before Evidence:

1. `4ee9068499c9695cf64f8c839e6d8bb2a5668c06` — publication journal initial placement
2. `78fda92c280a730471ad5379afbffeaf2177570f` — move publication journal to IO boundary
3. `0a0903ce64f9ecbfc83547b23cad0e713c370a74` — bounded publication recovery
4. `dc3610d9af939677760e60a34e44d5bfd96e022c` — initial IOFileStore publication wiring
5. `8fc191b82098fcd6de2b6f99ee8f7c002e65fb21` — initial readiness/promotion retirement wiring
6. `d8d930bbe6b966e924b82c06e3f85eff0ea46ecd` — preserving-open recovery wiring
7. `bbe3d5cf724244a0dce9a5c5811799f56bdbc7df` — bulk-open recovery wiring
8. `374c595c18406e8ff6f86904449eb02a621b4f48` — publication recovery regressions
9. `45baf461c0fe72b160a95f3fe2ee2b18e8a8352e` — initial self-check
10. `bf758d26b8be5c4d1128d53377d3ae3a485786ad` — preserve authority absence on unsafe preserving open
11. `df73d04a7ee622a5251792534f23a99d46c82a26` — preserve authority absence on unsafe bulk open
12. `3dd3527e40df1c650722c66d762440b25b65af05` — rollback intent retirement
13. `e520dc134ebc9aafa6bc1d5a2d04c73d0e495c48` — non-managed promotion compatibility
14. `1827c6962bc1c208780f65cb501e94cef61d5886` — align committed self-check with validated source
15. `69a1c6b8c9d9b27aa7c59535231c2828f0c8639c` — publication lifecycle regressions

## Remaining gates / limitations

- `.atomic` publication-journal writes are process-interruption durable by the same Foundation file contract used elsewhere in Lane 2, but sudden-power-loss/fsync behavior still requires APFS/device evidence.
- Publication journal shards are deterministic but not hard entry-count capped. Extreme same-shard distribution, decode RSS, and latency require iPhone measurement.
- AW31 recovery is bounded by candidate/record/shard budgets, but enough passes are required to rotate through all 256 shards.
- Current-process intents are intentionally ignored by recovery to avoid treating an in-flight writer as abandoned. They become eligible after a process boundary.
- A writer that bypasses Lane-2 publication seams can still create an unindexed managed file. Canonical IOFileStore and Library promotion are covered; direct/out-of-band writers remain unapproved.
- Cross-lane stem publication cannot be modified by Worker 2. HQ must ensure the integrated Lane-1 -> `Stems/**` publication adapter uses `LibraryArtifactLifecycle.promoteReadyArtifact(...)` or an equivalent Lane-2-owned pre-publication intent seam before exposing final stem paths.
- Existing Apple Core Data/WAL, real File Provider/import/export/codec, APFS/ENOSPC, force-termination, iPhone performance, and Differential Moises gates remain pending.

## PARITY

No PARITY row is promoted from AW31. MOI-P001/P002/P017/P018/P019/P020/P024 remain MISSING until HQ completes Apple runtime, integrated iPhone, real-audio/reference, deletion/privacy and differential gates.

## Next lane-local priority

Bound the remaining AW25 deletion-ownership filename-directory walk or hard-cap/shard oversized AW29/AW31 recovery records based on the highest-value fresh gap at the next `次`. Device-only gates remain HQ-owned.
