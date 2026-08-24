# L2-AW27 Targeted Foreground Delete Preparation Validation

Result: `COMPLETED_NON_PARITY`

## Scope

Lane 2 only. AW26 removed full-live-library materialization from crash-safe recovery authorization, but foreground `deleteProject()` still called `listMaintenanceProjects()` to find one target project and determine whether its source/stem paths were shared by other live projects. On a large library, deleting one project therefore remained proportional to the entire live library before durable deletion intent could even be written.

Fresh canonical state at wave start:
- assignment epoch: `2`
- planning revision: `4`
- integration epoch: `20`
- Worker branch/status start: `1298c84faa382214d8dcbc948478adc182040abf`
- prior status blob: `129a9a8980e0f093cca6bc28442465f7042889f6`
- Worker contract: `c9e8ec5d191108db6eb20fbd40db0dab3c46b725`
- Work Package: `aad7983bdaf315a996dce1496ed245008085c712`
- Lane Plan: `10b595b47e5a71278bde32e8656bd284e14e62eb`
- Resource Lock: `f727363edcf7cc209ca636db9b6d770f67d5402b`
- PARITY: `db98892a379180c25ffeb3586a7c3353620a2d5d`
- MOI-P001/P002/P017/P018/P019/P020/P024 remain `MISSING`.

## Foreground deletion preparation

`ForegroundDeletePreparation.swift` adds a lane-local preparation policy that reuses the AW21 destructive path authorization contract. Given one project candidate and the candidate paths still referenced by other live projects, it computes:
- shared live paths that must be retained;
- project-owned `Imports/**` / `Stems/**` paths that may be placed in PREPARED deletion intent.

Unsafe roots, traversal, absolute/backslash/NUL forms continue to fail closed through the existing tombstoned-metadata deletion policy.

For approved file-backed construction routes, `CrashSafeProjectLibraryStore.deleteProject()` no longer enumerates the live library. It now:
1. resolves only the requested live project's deletion candidate;
2. resolves only that candidate's source/stem paths referenced by *other* live projects;
3. persists durable ownership evidence;
4. persists PREPARED only for paths not shared by another live project;
5. tombstones metadata;
6. marks COMMITTED;
7. re-enters the existing crash-safe recovery state machine for authorization, artifact deletion, metadata compaction and retirement.

The existing mutation gate continues to cover candidate/reference resolution through tombstone and recovery, so a concurrent project/stem mutation cannot create a new live reference between authorization and destructive execution through the approved facade.

## Dedicated candidate reader hardening

The first AW27 implementation used the existing single-project `loadProject()` to build the deletion candidate. Audit found that this still materialized processing/edit/mix payloads for the target. Corrupt non-artifact user metadata could therefore block a user's attempt to delete the project.

`ForegroundDeletionCandidateResolver.swift` closes that dependency for the production file-backed route. It opens a fresh read-only Core Data coordinator, verifies the exact L2-V1 model hash, and reads only:
- the requested live `ProjectRecord`;
- its exact source `AssetRecord`;
- its `StemRecord` paths.

It does not read ProcessingRecord, ProjectEditRecord or StemMixRecord before deletion intent is formed. Missing/duplicate identity, predicate escape, missing source asset, unsafe candidate path or incompatible model fails closed.

The in-memory/direct compatibility route retains the older fallback (`loadProject()` plus maintenance projection). It is not the approved App production route.

## Target-excluding shared-reference resolver

The file-backed foreground resolver deliberately excludes the deletion target while looking for shared references:
- source paths: candidate `AssetRecord` identities -> live `ProjectRecord.sourceAssetUUID`, with `projectUUID != target`;
- stem paths: candidate `StemRecord` rows with `projectUUID != target` -> live ProjectRecord identities.

Therefore the target's own source/stems do not falsely classify every candidate path as shared before tombstoning, while a second live project referencing the same source or stem path still forces retention.

## Crash-safe ordering

AW27 does not weaken the AW21 state machine. The destructive sequence remains:

`ownership evidence -> PREPARED -> Core Data tombstone -> COMMITTED -> reauthorization -> artifact deletion -> ARTIFACTS_DELETED -> physical metadata compaction -> journal/ownership retirement`

Shared paths are omitted from PREPARED, and recovery still independently reauthorizes any journal before deletion.

## Validation

Swift 6.2.1 portable validation:
- foreground preparation helper + AW21 authorization policy strict concurrency/warnings-as-errors compile: PASS;
- `ForegroundDeletePreparationTests.swift` strict XCTest typecheck: PASS;
- CrashSafe facade, target candidate resolver and Apple-gated targeted delete tests syntax parse: PASS;
- production/static audit: `L2_AW27_STATIC_AUDIT_PASS checks=22/22`.

Remote-validated blobs:
- foreground preparation/helper: `64f439d0b6f15a3fd2f0bbbda1e189ac475f5d9b`
- dedicated production candidate resolver: `f8c16755876c21992527b6cd9e926d09ad663534`
- CrashSafe facade: `66b733cef2cca216fa2b758565bb3f9999dd65e7`
- portable tests: `2573b353ea265f4af33d6ff480be4214b1e20b9d`
- Apple-gated Core Data tests: `7ed165442014154d9db44ab53bf35430de055d27`
- self-check: `c5673de1e0786d53057714a99adddbb13223fe19`

Exact committed portable policy/self-check sources were rerun:

`L2_AW27_SELF_TEST_PASS scenarios=4 simulated_unrelated_live_projects=100000 candidate_paths=3 shared_paths=2 delete_paths=1 elapsed_seconds=0.003735`

This is an in-memory policy microbenchmark. `simulated_unrelated_live_projects=100000` demonstrates that the preparation plan is a function of the one candidate path set, not a scan of 100k project payloads. It is not SQLite, APFS, iPhone latency, RSS, thermal or battery evidence.

## Apple-gated tests prepared

`ForegroundDeleteTargetedCoreDataTests.swift` prepares actual Core Data coverage for:
1. two live projects sharing one source AssetID/path, sharing one stem path, while the deletion target owns an additional exclusive stem; the shared source/stem must survive, the exclusive stem and target metadata must disappear, and journal/ownership evidence must retire;
2. deletion of an already-missing project remaining idempotent through the targeted file-backed route.

Actual Apple execution is pending and is not represented as PASS.

## Scope audit

AW26 status `1298c84faa382214d8dcbc948478adc182040abf` -> pre-Evidence AW27 branch:
- 7 commits;
- 6 changed files;
- all changed implementation/test/benchmark files are under `tech-assets/moises-audio/Library/**`;
- no Shared/App/PARITY/resource-lock/work-package/lane-plan or other-lane file changed.

No Core Data model/schema migration was introduced.

## Remaining gates

- actual Apple compile/run of AW27 candidate/reference/delete tests;
- WAL visibility on iOS for the two fresh read-only coordinators used during foreground delete preparation;
- real foreground-delete wall time, Core Data/SQLite query plan/count and RSS with 1k/10k/large live libraries;
- the file-backed foreground route currently opens one fresh read-only coordinator for target candidate resolution and another for target-excluding shared-reference resolution; device evidence may justify combining them into one snapshot later;
- L2-V1 programmatic model definitions are duplicated across AW24/AW26/AW27 helpers; future consolidation is desirable to reduce model-drift risk, but changing schema/Shared contracts was not required here;
- direct/in-memory compatibility deletion may still use `loadProject()` and full maintenance projection; App must use the approved file-backed canonical routes;
- orphan sweeping still materializes the full live maintenance projection and is the next lane-local scalability target;
- AW25 deterministic ownership slice selection still walks all ownership filenames per pass;
- deletion-journal enumeration remains intentionally priority/unbounded for correctness;
- force termination, APFS durability and ENOSPC around candidate read, ownership/PREPARED persistence, tombstone, artifact deletion and compaction remain device gates;
- AW21 physical compaction/shared Asset retention and AW20/AW18 setlist recovery still need Apple reopen/termination evidence;
- AW19 prejournal recovery UX plus AW14/AW16 real import/File Provider/codec/storage-pressure gates remain pending;
- WMA remains in the reference codec policy; real Apple fixtures and an audited production compatibility decoder/license remain required if native decoding is unavailable;
- Differential Moises and final PARITY remain HQ-owned.

No Shared/App/PARITY contract or Core Data model schema was changed. Portable/static evidence does not promote MOI-P017, MOI-P024, or any other PARITY row.
