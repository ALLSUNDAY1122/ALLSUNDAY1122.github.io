# L2-AW25 Bounded Indexed Recovery Scheduler Validation

Result: `COMPLETED_NON_PARITY`

## Scope

Lane 2 only. AW24 bounded newly discovered pre-AW22 journal-less tombstones before they were ownership-indexed, but a process upgrading from AW23 could already have a very large durable `.LibraryRecovery/DeleteOwnership/*.json` backlog. The pre-AW25 CrashSafe recovery loaded and processed every ownership record in one pass. AW25 bounds ownership-only recovery while preserving current deletion-journal priority, AW21 deletion authorization, AW22 ownership evidence and AW24 compatibility slicing.

Fresh canonical state at wave start:
- assignment epoch: `2`
- planning revision: `4`
- integration epoch: `18`
- Worker branch/status start: `814fb430a14d3c56f10f78b072259e100f1332c8`
- prior status blob: `19e58a26158904aecd731cc2dff3f10633d7f5c7`
- resource-lock SHA: `c7ce95cb0a0f1eb245010acbbff3cacdf3f4cbec`
- PARITY SHA: `db98892a379180c25ffeb3586a7c3353620a2d5d`
- MOI-P001/P002/P017/P018/P019/P020/P024 remain `MISSING`.

## Scheduler semantics

`IndexedRecoveryScheduler.swift` defines a lane-local ownership-only budget:
- default: 64 records/recovery pass;
- minimum: 8;
- maximum: 256.

Deletion journals are not charged against this ownership-only budget. CrashSafe recovery first loads the deletion journal list and reads ownership evidence directly for those exact project UUIDs. It then asks the index for one bounded ownership-only slice excluding every journal-backed project. All journal-backed projects are processed before the selected ownership-only slice. Therefore a large historical indexed backlog cannot starve a current PREPARED/COMMITTED/ARTIFACTS_DELETED journal.

`LibraryRecoveryReport` now carries `Lane2IndexedRecoveryDiagnostics`:
- prioritized deletion-journal count;
- ownership-only records selected;
- whether ownership-only records were deferred;
- effective ownership-only limit.

These values are integration/device measurement hooks, not performance claims.

## Bounded ownership index enumeration

`DeletionOwnershipIndex.swift` retains `pendingRecords()` only as a compatibility/admin API. Production CrashSafe recovery uses `pendingRecordSlice(limit:excludingProjectUUIDs:)`.

The bounded selector:
1. scans direct non-hidden entries under `.LibraryRecovery/DeleteOwnership`;
2. ignores non-JSON files;
3. rejects symlink/non-regular JSON records;
4. requires a canonical `<PROJECT-UUID>.json` filename;
5. excludes deletion-journal project IDs;
6. retains at most `limit + 1` candidate URLs while scanning;
7. decodes at most `limit` ownership JSON payloads;
8. validates payload `projectUUID` equals the filename UUID;
9. returns a deterministic UUID-ordered slice plus `hasMore`.

This bounds decoded ownership payload count and recovery compaction work. It does **not** make directory discovery O(1): the current implementation still walks all ownership filenames to choose the deterministic smallest slice. Very large directories therefore still require Apple filesystem/RSS/latency evidence and are a future sharding/cursor target.

A corrupt JSON payload outside the selected slice is not decoded early; when that file becomes selected it fails closed. Structural directory hazards such as symlink JSON entries and noncanonical/mismatched identity fail immediately rather than being silently skipped.

## CrashSafe recovery ordering

`CrashSafeProjectLibraryStore.recoverInterruptedOperations()` now:
1. reads deletion journals;
2. loads any ownership records for those exact journal project UUIDs directly;
3. selects at most 64 ownership-only records by default;
4. materializes current live references under the existing mutation gate;
5. processes every journal-backed delete first using the existing authorization/state machine;
6. processes only the selected ownership-only slice;
7. leaves deferred ownership records untouched and durable for the next invocation.

A live project with ownership-only evidence still means the delete never committed: that ownership record is removed and user content is retained. A tombstoned ownership-only project still reconstructs a conservative COMMITTED journal, deletes only authorized non-live Imports/Stems paths, compacts metadata, then retires journal and ownership evidence.

The old Core Data candidate scan remains only a defensive compatibility fallback for callers that bypass AW24 canonical preparation. Approved product construction routes remain `openPreservingUserData(...)` and `openBulkPrepared(...)`.

## AW24 interaction

AW24's bounded migrator still contains a `pendingRecords()` compatibility read while bounded migration is active. It was re-audited during AW25 rather than rewritten:
- a pre-existing AW23 all-indexed state has the AW22 legacy-complete marker and no AW24 active marker, so the migrator returns before that read;
- during normal AW24 active migration, only the immediately prepared bounded slice remains indexed if recovery has not yet converged.

Therefore the large pre-existing all-indexed backlog addressed by AW25 reaches the new CrashSafe bounded selector, not the AW24 full-record read. The compatibility read remains a future cleanup candidate but is not the unbounded canonical path closed by this wave.

## Validation

Swift 6.2.1 Linux:
- `IndexedRecoveryScheduler.swift` + hardened `DeletionOwnershipIndex.swift` strict-concurrency/warnings-as-errors module compile: PASS.
- `IndexedRecoverySchedulerTests.swift` strict XCTest typecheck: PASS.
- `CrashSafeProjectLibraryStore.swift` syntax parse: PASS.
- Apple-gated `IndexedRecoveryCrashSafeTests.swift` syntax parse: PASS; actual Core Data execution is not counted as PASS.
- production/static audit: `L2_AW25_STATIC_AUDIT_PASS checks=20/20`.

Remote-validated implementation blobs:
- indexed scheduler: `c1c8bef7625a923053ab7cb38042a76a9c16ba6c`
- deletion ownership index: `7d435ae209a4a6cf891e3a7e1e6a7f0ec2c14e49`
- portable scheduler tests: `e4473b617726789a6eb05c3ff1b3ae6697d1048d`
- filesystem self-check: `b6013b460e682deb0c014abe1588e6bce4a77092`
- CrashSafe production facade: `064310eb7832a37d5b2fcea59e1752dbcc9c4641`
- Apple-gated CrashSafe tests: `049bf4bd522cb34f58926efe85e4562cc8acf78e`

Exact committed portable scheduler/index/self-check sources were recompiled and rerun:

`L2_AW25_SELF_TEST_PASS scenarios=6 records=2048 budget=64 passes=32 prioritized_journal_ids=16 write_seconds=3.737340 drain_seconds=4.910212`

The self-check writes 2,048 real temporary ownership JSON files, excludes 16 simulated journal-backed IDs, drains the remaining 2,032 records in 32 bounded passes, and verifies identity mismatch rejection. The timings are Linux temporary-filesystem microbenchmarks only. They are not APFS, iPhone launch, RSS, thermal, battery or Core Data performance evidence.

## Apple-gated tests prepared

`IndexedRecoveryCrashSafeTests.swift` prepares actual Core Data coverage for:
1. 20 already-indexed tombstoned projects with recovery limit 8; expected 8 + 8 + 4 convergence over three recovery passes with deferred diagnostics and zero remaining tombstones;
2. one journal-backed current delete plus nine ownership-only historical tombstones with limit 8; expected current journal priority plus only eight historical records in the pass, leaving one deferred.

Actual Apple Core Data/SQLite execution remains pending and is not represented as PASS.

## Remaining gates

- actual Apple compile/run of AW25 CrashSafe recovery and the prepared tests;
- observed per-pass Core Data/SQLite query count, wall time and RSS with 1k/10k/large already-indexed backlogs;
- ownership directory filename enumeration is still O(number of files) per pass even though JSON decode/compaction is bounded; sharding or durable cursoring may be required after device measurement;
- deletion journal enumeration itself remains intentionally priority/unbounded for correctness; an extreme journal backlog requires separate policy/device evidence rather than silently deferring destructive intent;
- live-reference computation still materializes the full live maintenance projection before destructive authorization and is a remaining large-library recovery cost;
- direct user `deleteProject` currently converges its journal first and may also drain one historical ownership slice before returning; foreground latency needs Apple measurement;
- force termination, APFS durability and ENOSPC around ownership selection/journal creation/artifact deletion/metadata compaction remain device gates;
- legacy raw `CrashSafeProjectLibraryStore.open(...)` / raw Core Data lifecycle integration remains unapproved; App must use the AW24 canonical construction paths;
- actual picker/share/codec/File Provider/WMA compatibility and export/share gates remain pending;
- Differential Moises and final PARITY remain HQ-owned.

No Shared/App/PARITY or Core Data model schema was changed.
