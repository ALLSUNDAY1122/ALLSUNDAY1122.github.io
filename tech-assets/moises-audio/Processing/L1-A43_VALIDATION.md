# L1-A43｜Bounded Resumable Cache Retention and Delete Tombstones

Evidence state: `NON_PARITY_EVIDENCE_ONLY`  
PARITY claim: `NONE`  
Primary rows: `MOI-P021`, `MOI-P024`

## Why this wave

L1-A41 made long provider-output downloads crash-resumable by retaining only strong-validator-bound partial bytes in:

`artifact_root/<logical_job_id>.download-cache`

That fixed repeated full re-download cost, but the retained retry cache had no lifecycle bound. A separate inspection of the existing privacy path found a more serious correctness mismatch: `PrivacyRetentionService._delete_local_artifacts` deleted only:

`artifact_root/<logical_job_id>`

while output collection can also own:

- `artifact_root/<logical_job_id>.staging`
- `artifact_root/<logical_job_id>.download-cache`

Therefore a user/account/retention delete could previously set `local_delete_confirmed=true` while staging or resumable stem bytes remained locally.

## A43 implementation

### 1. Bounded retry-cache lifecycle

`Separation/Server/resumable_transfer_cache.py` adds `ResumableTransferCacheManager` and `ResumeCachePolicy`.

The default policy is configurable and bounds inactive retry caches by:

- 24 hour TTL,
- 32 entries,
- 4 GiB at the standalone manager level.

The production A43 wrapper derives its default total-byte cap as twice the configured A15 maximum accepted source size. Eviction is oldest-first. Resume progress is only an optimization, so quota/TTL eviction is allowed to force a clean byte-zero retry; it never changes committed output correctness.

Reclamation rejects unsafe lock roots, refuses cross-process reclamation when the POSIX locking backend is unavailable, ignores unrelated artifact directories, removes suspicious future-timestamp caches, and never follows a cache-root symlink to its target.

### 2. External per-job lease

The per-job lease is stored under:

`artifact_root/.resume-cache-locks/<logical_job_id>.lock`

not inside the deletable cache directory.

This matters because deleting a directory that contains its own lock inode can let a waiter later acquire an unlinked old inode while another process has created a new cache directory. Keeping the lease outside the cache gives cache deletion and output collection one stable authority on a shared single-host filesystem.

A43 reclamation uses nonblocking leases and skips active jobs. A43 output collection holds the blocking job lease across the A41 parent collection path, including final A41 cache cleanup.

### 3. Durable delete tombstone

Privacy deletion writes and fsyncs:

`artifact_root/.resume-cache-locks/<logical_job_id>.deleted`

under the same job lease before deleting retry-only cache bytes.

The tombstone contains no raw URL, provider identifier, filename, or audio content. It prevents a late retry using the same logical job/idempotency identity from recreating local stem data after deletion has been confirmed.

`BoundedCrashResumableLongTrackProductionSeparationOrchestrator` checks the tombstone:

- before `start`,
- before output collection,
- again after acquiring the output-collection lease.

The second collection check closes the race where deletion wins between the early preview and lease acquisition.

### 4. Delete-first production ordering

`BudgetedProductionSeparationOrchestrator.start` now validates the idempotency key, derives the logical job ID, and checks the A43 tombstone before:

- source containment/read,
- source SHA-256 hashing,
- duration analysis,
- cost reservation,
- upload,
- provider create.

Thus a deleted multi-gigabyte job does not trigger unnecessary source IO or cost-state mutation before the inner A43 runtime rejects it.

### 5. Privacy deletion covers every Lane-1 local job surface

`PrivacyRetentionService` now owns a `ResumableTransferCacheManager` on the same artifact root. Its local deletion sequence is:

1. deletion intent is already durably persisted in the privacy registry;
2. `tombstone_and_purge(logical_job_id)` waits for any active A43 output lease, durably writes the delete tombstone, and removes `.download-cache` bytes;
3. remove the committed `<jobID>` directory;
4. remove `<jobID>.staging`;
5. verify committed, staging, and cache paths are absent;
6. verify the delete tombstone exists;
7. only then allow `local_delete_confirmed=true` to be persisted.

The explicit-expiry sweep uses the same path. Sibling job directories/caches are not selected.

## Regression surfaces added

- `Separation/Tests/test_resumable_transfer_cache.py` — 11 tests
- `Separation/Tests/test_a43_privacy_cache_deletion.py` — 5 tests
- `Separation/Tests/test_a43_deleted_job_runtime.py` — 3 tests
- `Separation/Tests/test_a43_budgeted_deleted_job.py` — 1 test
- `Separation/Tests/test_a43_dependency_binding.py` — 4 tests

Total formal A43 tests added: **24**.

These repository tests are committed and will participate in the normal Lane-1 full `unittest discover` gate. Their exact final-tip repository execution is not observed in this Worker environment.

## Focused interface-compatible validation

A separate local model harness exercised the same new lifecycle contracts and passed **9/9 assertions**:

- inactive quota eviction,
- active lease exclusion,
- TTL reclamation after lease release,
- durable tombstone + cache purge,
- deleted-job cache recreation rejection,
- privacy ordering with committed/staging/cache absence before modeled confirmation.

This is intentionally reported only as interface-compatible focused evidence. It is not a substitute for exact repository-native discovery.

## A26 state

HQ's current exact-audit workflow was re-read during this wave:

`.github/workflows/moises-hq-lane1-exact-audit.yml`

Its observed `LANE1_EXPECTED_HEAD` is still:

`bde14cc9dd63c5c250e4c9580aa79042b4dc5a95`

which is an A41-era Worker tip, not the final A43 tip. No workflow run is associated with the prior A42 metadata tip either. Therefore L1-A26 remains open and must not be marked PASS from A43 focused evidence.

HQ must retarget the exact audit to the final A43 Worker tip and require:

- exact git-head binding PASS,
- owned source snapshot PASS,
- Python compile PASS,
- JSON/schema gates PASS,
- dependency contracts PASS,
- full unittest discovery PASS with zero failures/errors,
- overall state PASS.

## Remaining non-claims / gates

A43 materially closes a concrete local-content deletion defect and bounds retry-only storage, but it does **not** establish P021 or P024 PARITY.

Still required:

- exact final-A43 full repository audit,
- live production-provider output-validator/Range qualification for A41,
- physical-current-iPhone long-track memory/thermal/battery/storage-pressure/relaunch evidence,
- integrated HQ/App deletion flow proving the real user/account delete action reaches the Lane-1 privacy service,
- multi-host shared transactional authority if deployment uses independent hosts,
- rights-cleared real-audio and current-Moises differential evidence where applicable.

P021 and P024 therefore remain `MISSING` in the HQ-owned PARITY matrix.
