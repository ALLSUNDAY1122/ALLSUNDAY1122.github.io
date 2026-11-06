# L2-AW37｜Bounded Deletion Journal Recovery Validation

## Result

`COMPLETED_NON_PARITY`

AW37 bounds the previously unbounded deletion-journal recovery window used by `CrashSafeProjectLibraryStore.recoverInterruptedOperations()` through the existing `LibraryArtifactLifecycle.pendingDeletionJournals()` call.

## Fresh canonical read

- Notion canonical: `Moises技術同等化｜AI音源分離アプリ 正本`
- Worker contract: `c9e8ec5d191108db6eb20fbd40db0dab3c46b725`
- Work package: `aad7983bdaf315a996dce1496ed245008085c712`
- Lane plan: `10b595b47e5a71278bde32e8656bd284e14e62eb`
- Resource lock: `17f38848ddcceb59ad44022a1cc4c058763fe663`
- integration epoch: `24`
- assignment epoch: `2`
- planning revision: `4`
- PARITY matrix: `db98892a379180c25ffeb3586a7c3353620a2d5d`
- Wave start Worker branch HEAD: `185e9bd5b39e7c1500e3789d1f570cbe6a64b8c8`

## Gap

Before AW37, `pendingDeletionJournals()` used `FileManager.contentsOfDirectory`, materialized every journal URL, decoded every JSON payload and sorted the full backlog before recovery. Ownership-only recovery had a bounded budget, but journal-backed recovery did not. A pathological crash/retry backlog could therefore scale launch-time memory and decoding work with total backlog size.

## Implementation

`LibraryArtifactLifecycle` now defines:

- `defaultDeletionJournalRecoveryLimit = 64`
- `maximumDeletionJournalRecoveryLimit = 256`

`pendingDeletionJournals(limit:)` now:

1. clamps the requested window to `1...256`;
2. uses a non-recursive `FileManager` directory enumerator;
3. validates selected journal entries as regular, non-symlink canonical UUID JSON files;
4. stops after the bounded window instead of materializing the entire directory;
5. decodes only selected journal bytes;
6. preserves the existing in-window `createdAt/projectUUID` processing order;
7. retains crash correctness because every successful selected journal is still retired only after the pre-existing metadata/file-compaction sequence succeeds.

No Shared/App/PARITY/Core Data schema contract was changed.

## Recovery / negative cases

Durable tests cover:

- 300-journal backlog returns only the default 64-journal window;
- successful first/second recovery windows are disjoint and advance through remaining work;
- after two 64-item windows, a 140-item backlog leaves 12;
- requested `10,000` limit clamps to 256;
- filename/payload project UUID mismatch fails closed;
- symlink journal entry fails closed.

## Portable self-check

Swift 6.2.1, `-warnings-as-errors -strict-concurrency=complete`:

`L2_AW37_SELF_TEST_PASS backlog=10000 first=64 second=64 max_clamp=true progress=true`

The self-check creates 10,000 journal files, verifies the 64-item first window, removes that window, verifies a disjoint 64-item second window, and confirms the 256 hard maximum.

## Scope audit

Start HEAD `185e9bd5...` through pre-Evidence implementation head `5bb796c607c4cca6716c2f0d6598f8112dba188a` changed only:

- `tech-assets/moises-audio/Library/Sources/LibraryArtifactLifecycle.swift`
- `tech-assets/moises-audio/Library/Tests/DeletionJournalBacklogBoundedTests.swift`
- `tech-assets/moises-audio/Library/benchmarks/L2AW37DeletionJournalBacklogSelfCheck.swift`

No Shared/App/PARITY/other-Lane source was changed.

## Remaining limits

AW37 bounds the journal recovery window but does not prove physical-iPhone RSS/latency, APFS behavior, force termination or Core Data/WAL visibility. The AW29/AW32 shard-concentration gap also remains separately open. Final MOI-P017/P024/P019 judgments remain HQ-owned and require integrated real-device evidence.
