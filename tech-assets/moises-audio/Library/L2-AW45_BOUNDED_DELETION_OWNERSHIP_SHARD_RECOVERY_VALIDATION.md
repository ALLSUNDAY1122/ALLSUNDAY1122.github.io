# L2-AW45 | Bounded Deletion Ownership Shard Recovery Validation

## Result

`COMPLETED_NON_PARITY`

This Wave hardens the AW32 deletion-ownership recovery hot path against pathological concentration in one shard directory. It does not claim product PARITY.

## Fresh canonical state

- Operating model: `FOUR_AUTONOMOUS_INDEPENDENT_LANES_LATE_INTEGRATION`
- assignment epoch: 2
- planning revision: 4
- integration epoch at Wave start: 30
- HQ canonical Lane 2 checkpoint: AW42
- Worker branch Wave-start HEAD: `64217d66baceab58347cb85c00830f125565619c`
- Lane 2 ownership remains `IO/**` + `Library/**`
- Lane 2 PARITY rows remain MISSING; final judgment remains HQ-only.

## Gap correction

The pre-Wave shorthand "AW32 shard concentration" could be misread as one giant JSON shard. Fresh source inspection showed the actual AW32 format is UUID-per-file inside deterministic shard directories plus `.active-shards-v2.json`.

The real launch/recovery amplification was therefore directory enumeration: `shardedRecordSlice` called a whole-directory `contentsOfDirectory` helper, validating/materializing every filename in a visited shard before taking a bounded recovery slice. `retireShardIfEmpty` likewise materialized a directory merely to decide emptiness.

## Implementation

`Lane2DeletionOwnershipIndex` now adds `defaultShardDirectoryScanBudget = 1024` and keeps the existing on-disk schema.

Hot ownership-only recovery now:

1. visits at most the existing four active shards per pass;
2. enumerates a visited shard incrementally with `FileManager.DirectoryEnumerator`;
3. inspects at most 1,024 visible entries for that shard plus one sentinel used only to report deferred work;
4. validates regular-file / non-symlink / canonical UUID filename / deterministic shard ownership before a record may enter the recovery slice;
5. retains only a bounded candidate set and then loads record bytes only for selected candidates;
6. preserves journal-backed UUID exclusion;
7. reports `hasMore` rather than materializing the tail;
8. tests shard retirement with a first-entry streaming probe rather than `contentsOfDirectory(...).isEmpty`.

The compatibility/admin `pendingRecords()` API intentionally retains a full inventory scan. CrashSafe launch recovery continues to use `pendingRecordSlice`, so this full-scan API is not in the normal recovery hot path.

No Shared/App/PARITY/Core Data schema change was required.

## Portable stress self-check

Swift 6.2.1, warnings-as-errors and strict concurrency were used for the focused AW45 scanner self-check.

A temporary shard directory with 10,000 canonical UUID JSON filenames was scanned with recovery limit 64 and scan budget 1,024.

Observed:

`L2_AW45_SELF_TEST_PASS concentrated=10000 returned=64 scan_budget=1024 has_more=true malformed=true symlink=true empty=true`

Validated properties:

- 10,000 concentrated entries do not become a 10,000-element recovery filename array in the focused scanner;
- only 64 candidates are returned;
- scan work is capped at 1,024 entries before deferred-work signalling;
- malformed record filename fails closed;
- symlink record fails closed;
- empty-directory detection returns empty without a shard-wide list.

## Durable regression coverage

`Library/Tests/DeletionOwnershipBoundedShardRecoveryTests.swift` covers:

- 1,300 project ownership records deliberately concentrated into one deterministic shard;
- recovery `limit=64` remains bounded and reports `hasMore`;
- the production scan budget constant is 1,024;
- final-record removal leaves no pending ownership-only work;
- a symlink replacing a persisted ownership record fails closed when recovery visits it.

## Crash / recovery semantics preserved

- Record persistence ordering remains active-shard signal before ownership record publication.
- Existing per-record atomic writes remain unchanged.
- Journal-backed ownership records remain directly addressable and excluded from ownership-only recovery.
- Legacy flat-record migration remains bounded and resumable.
- Empty stale active shards can still self-retire.
- Administrative full inventory inspection remains available for explicit tooling/tests.

## Remaining gates / non-claims

- This is portable filesystem hardening, not physical-iPhone evidence.
- APFS directory enumeration latency/RSS under pathological concentration remains to be measured on Apple hardware.
- Force termination during active-shard manifest update / ownership record publication still requires Apple-runtime validation.
- Apple Core Data/WAL, ENOSPC, real import/export/share, real codecs, AVFoundation export validity and Differential Moises remain external/HQ gates.
- `MOI-P001/P002/P017/P018/P019/P020/P024` remain MISSING.
