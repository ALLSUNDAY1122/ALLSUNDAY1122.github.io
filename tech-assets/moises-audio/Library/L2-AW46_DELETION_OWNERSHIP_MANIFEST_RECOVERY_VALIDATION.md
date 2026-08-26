# L2-AW46 | Deletion Ownership Manifest Recovery Validation

## Result

`COMPLETED_NON_PARITY`

AW46 makes deletion-ownership recovery resumable when the tiny `.active-shards-v2.json` control manifest is missing, malformed, or stale. It does not promote any PARITY row.

## Fresh gap analysis

AW45 already bounded record enumeration inside an active shard to 1,024 inspected entries and preserved the ordering `active-shard signal -> ownership record publication`. That ordering means an ordinary crash between those writes can leave an empty active shard but cannot publish a record that a successfully persisted manifest omits.

The remaining portable failure mode was damage/loss/staleness of the manifest itself. Before AW46, `loadActiveShards()` intentionally failed closed when shard directories existed without a manifest or when the manifest could not be decoded, which preserved safety but stopped launch delete recovery.

## Implementation

Added `Library/Sources/DeletionOwnershipManifestRecovery.swift`.

`Lane2DeletionOwnershipManifestRecovery` treats ownership record directories as recoverable evidence and the active-shard manifest as a reconstructible acceleration index. Reconciliation:

1. probes exactly the deterministic 256-shard namespace instead of enumerating an attacker/unbounded root inventory;
2. for each existing canonical shard, rejects non-directory and symlink paths;
3. inspects only the first visible entry needed to determine whether the shard is active;
4. requires canonical `.json` UUID filenames, regular non-symlink records, and deterministic UUID-to-shard ownership;
5. reconstructs missing/corrupt manifests from validated shard evidence;
6. repairs a syntactically valid but stale manifest when it omits a non-empty shard or retains only an empty shard;
7. rewrites the control manifest atomically with normalized unique sorted shard indices;
8. never edits ownership record bytes while repairing the control manifest.

Unsafe shard structure remains fail-closed. A shard directory symlink or malformed visible entry is not converted into authority by repair.

## Production wiring

The repair is invoked immediately before CrashSafe deletion recovery in both production helper opens:

- `CrashSafeProjectLibraryStore.openPreservingUserData(...)`
- `CrashSafeProjectLibraryStore.openBulkPrepared(...)`

This keeps the existing publication-recovery / compatibility-census sequencing intact and changes no Shared/App/PARITY/Core Data schema.

The older base `CrashSafeProjectLibraryStore.open(...)` entry point was not rewritten in AW46 because it lives in the larger core facade and was not needed to establish the new repair primitive or the two dedicated production helper paths. Unifying that entry point is retained as a follow-up correctness cleanup rather than risking a broad unrelated core-file rewrite in this Wave.

## Portable Swift 6.2.1 self-check

Focused AW46 source was compiled with:

`swiftc -swift-version 6 -warnings-as-errors -strict-concurrency=complete`

Observed:

`L2_AW46_SELF_TEST_PASS discovered=2 missing=true corrupt=true stale_missing=true stale_empty=true symlink=true malformed=true fixed_namespace=256`

Validated:

- missing manifest rebuild;
- malformed JSON manifest rebuild;
- valid stale manifest missing a real shard converges to directory evidence;
- stale empty shard is removed from reconstructed active set;
- canonical namespace is fixed at 256 candidates;
- shard-directory symlink fails closed;
- malformed visible shard entry fails closed.

## Durable regression coverage

Added `Library/Tests/DeletionOwnershipManifestRecoveryTests.swift` covering:

- manifest deletion after a persisted ownership record followed by successful recovery selection;
- malformed manifest recovery without dropping directly addressable ownership evidence;
- valid-but-stale manifest missing one of two real shards;
- stale empty shard retirement from manifest authority;
- symlink shard directory rejection;
- malformed visible shard entry rejection.

## Commits before evidence

- `35c7e2ce8bc9149b3c49a6d645e40f194ce209c4` — recovery primitive
- `b720239b5bcd03933bb938c720c3301be7b37f28` — regression coverage
- `aa8abfa10c9ce437d8c08eec888165f7377e9781` — preserving-open wiring
- `6619f52fd3f251f58b18ee0fb66e0d216ff5ef7b` — bulk-open wiring

## Remaining gates / non-claims

- The base `CrashSafeProjectLibraryStore.open(...)` path still needs the same pre-recovery reconciliation call or a future centralization inside `Lane2DeletionOwnershipIndex`.
- Physical iPhone/APFS force-termination around manifest replacement and record publication remains unmeasured.
- APFS latency/RSS of the 256 fixed-path probes remains an Apple-device benchmark item, although work is bounded independently of record count.
- AW45's administrative `pendingRecords()` whole-inventory API remains intentionally outside normal launch recovery.
- Apple Core Data/WAL, ENOSPC, production codecs, real import/export/share, AVFoundation validity/synchronization and Differential Moises remain external/HQ gates.
- `MOI-P001/P002/P017/P018/P019/P020/P024` remain `MISSING`.
