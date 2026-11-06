# L2-AW26 Targeted Live Reference Authorization Validation

Result: `COMPLETED_NON_PARITY`

## Scope

Lane 2 only. AW25 bounded already-indexed deletion ownership recovery, but destructive authorization still called `listMaintenanceProjects()` and materialized every live project/source/stem before processing a bounded deletion candidate set. AW26 replaces that canonical recovery dependency with a targeted read-only Core Data resolver whose inputs are only the current journal/index project IDs and the candidate `Imports/**` / `Stems/**` paths being authorized.

Fresh canonical state at wave start:
- assignment epoch: `2`
- planning revision: `4`
- integration epoch: `19`
- Worker branch/status start: `460223510a3f890402ff4af82169ed59b35b78a4`
- prior status blob: `fb9ad4fb2a8e9124b2d6276b62ec95ba8d908824`
- resource-lock SHA: `886524e11843213a5abf444c33c97ffc037e63da`
- Worker contract SHA: `c9e8ec5d191108db6eb20fbd40db0dab3c46b725`
- Work Package SHA: `aad7983bdaf315a996dce1496ed245008085c712`
- Lane Plan SHA: `10b595b47e5a71278bde32e8656bd284e14e62eb`
- PARITY SHA: `db98892a379180c25ffeb3586a7c3353620a2d5d`
- MOI-P001/P002/P017/P018/P019/P020/P024 remain `MISSING`.

## Production implementation

`TargetedLiveReferenceResolver.swift` adds a lane-local resolver protocol and the file-backed `Lane2CoreDataLiveArtifactReferenceResolver`.

For each recovery pass it:
1. validates every candidate path and rejects anything outside `Imports/**` / `Stems/**`, traversal, absolute paths, backslash paths and empty path components;
2. constructs the exact frozen `L2-V1` model and verifies the SQLite model version hashes before reading;
3. opens a fresh read-only persistent-store coordinator, so each authorization pass observes a new committed-store snapshot rather than retaining a long-lived reader;
4. queries only the supplied target project UUIDs to determine which of those projects are currently live;
5. for candidate `Imports/**` paths, resolves matching AssetRecord identities and asks whether any live ProjectRecord references those assets;
6. for candidate `Stems/**` paths, resolves matching StemRecord project identities and asks whether those projects are live;
7. returns only the candidate paths that are currently referenced by a live project.

All Core Data fetches use dictionary projection and batching. The resolver does not call `listProjects()` or `listMaintenanceProjects()` and does not materialize processing/edit/mix payloads.

`CrashSafeProjectLibraryStore` now accepts an optional `Lane2LiveArtifactReferenceResolving`. Approved file-backed construction routes inject the Core Data resolver. Recovery gathers candidate paths from durable ownership records, resolves live status/reference only for those identities, and then reuses the existing AW21 authorization policy. If a defensive legacy candidate scan is required, only those newly discovered candidate paths are sent through a second targeted resolution and the diagnostics are merged.

The resolver is injected by:
- `openPreservingUserData(...)`;
- `openBulkPrepared(...)` for file-backed stores;
- legacy `CrashSafeProjectLibraryStore.open(...)` when it receives a file-backed metadata configuration.

In-memory/direct initializer test paths may omit the resolver and retain the old full-maintenance fallback. Raw Core Data / direct un-injected App integration remains unapproved.

## Correctness / safety invariants

- The existing mutation gate still serializes createProject, recordStems, delete and recovery operations, so approved CrashSafe mutations cannot change live artifact ownership between authorization and deletion.
- `recordProcessing`, user edits and setlist-only mutations do not change source/stem ownership and therefore do not invalidate the targeted artifact reference snapshot.
- A PREPARED journal whose target project remains live is still discarded without destructive work.
- COMMITTED/PREPARED destructive work still requires a durable ownership candidate and still passes `Lane2TombstonedMetadataCompactionPolicy.requireAuthorizedJournal(...)`.
- Shared source/stem paths returned as live references are retained.
- Tombstoned-only paths remain eligible for deletion.
- ARTIFACTS_DELETED journals still perform metadata compaction only.
- Unsafe ownership paths fail closed before querying/deletion.
- Physical AssetRecord retention remains controlled by AW21 compaction, which checks all remaining ProjectRecord source-asset references independently of this resolver.

## Diagnostics

`LibraryRecoveryReport` now also exposes `Lane2TargetedLiveReferenceDiagnostics`:
- targeted resolver used or fallback used;
- requested project ID count;
- requested artifact/source/stem path counts;
- matched live project/path counts;
- Core Data `context.fetch` call count issued by the resolver.

`logicalFetchCalls` is an adapter-level measurement hook only. It is **not** claimed to equal SQLite internal query count.

## Portable validation

Swift 6.2.1 Linux:
- `TargetedLiveReferenceResolver.swift` portable portion strict-concurrency + warnings-as-errors module compile: PASS.
- `TargetedLiveReferenceQueryPolicyTests.swift` strict XCTest typecheck: PASS.
- `CrashSafeProjectLibraryStore.swift`, Core Data resolver branch and Apple-gated tests syntax parse: PASS on locally validated source.
- final static canonical wiring/recovery audit: `L2_AW26_STATIC_AUDIT_PASS checks=17/17`.

Remote-validated blobs:
- targeted resolver: `c68b9290ff728dddf623f1cd7c563363142fd953`
- CrashSafe facade: `d6933b021a3be1f64ea6704f3de02814bbfa85b0`
- preserving open: `259442965146907095968e1b98635f8499ef51ba`
- bulk open: `52ecd2176642bd01995e661cd4ce5cf4d2a534d1`
- portable policy tests: `c16b98936ad663a6a45a8fab9783f4aaec75e3b1`
- self-check: `76f5b00f535f1f2434c75153e30771c0b6a4b610`
- Apple-gated resolver/recovery tests: `bcf25fda04bddc8c2f162fbeee18682c3c11d1fa`

Exact committed resolver/self-check blobs were recompiled and rerun:

`L2_AW26_SELF_TEST_PASS scenarios=4 simulated_live_projects=100000 candidate_paths=192 source_paths=64 stem_paths=128 batch_size=128 elapsed_seconds=0.000780`

The `simulated_live_projects` value demonstrates that the portable query-plan input is independent of total Library size; it is not a database execution benchmark. The timing is a Linux in-memory policy microbenchmark only.

## Apple-gated tests prepared

`TargetedLiveReferenceResolverTests.swift` prepares actual Core Data coverage for:
1. a live and tombstoned project sharing one source and one stem path, plus an exclusive tombstone; the resolver must return only the shared paths and only the live target UUID;
2. CrashSafe recovery with 128 unrelated live projects, one shared source and one deleted-project-only stem; targeted recovery must retain the shared source, delete the exclusive stem, compact the tombstone and report only two requested candidate paths.

Actual Apple Core Data/SQLite execution is pending and is not counted as PASS.

## Remaining gates

- actual Apple compile/run of the AW26 resolver and prepared tests;
- observed SQLite query count/query plan, wall time and RSS with large live libraries and bounded deletion candidate sets;
- verify a second read-only coordinator sees the expected just-committed WAL state across real iOS termination/relaunch scenarios;
- force termination/APFS/ENOSPC around resolver authorization, journal execution and metadata compaction;
- foreground `deleteProject()` still uses full `listMaintenanceProjects()` to create initial ownership/journal evidence; targeting this path is a separate follow-up;
- orphan sweeping still materializes the full live maintenance projection by design and needs separate large-library work;
- AW25 ownership directory deterministic slice selection still walks all ownership filenames per pass;
- deletion-journal enumeration remains intentionally priority/unbounded for correctness;
- raw metadata mutations outside the CrashSafe mutation gate remain an unapproved integration route and can invalidate the transaction assumptions;
- actual picker/share/codec/File Provider/WMA compatibility and export/share device gates remain pending;
- Differential Moises and final PARITY remain HQ-owned.

No Shared/App/PARITY or Core Data model schema was changed.
