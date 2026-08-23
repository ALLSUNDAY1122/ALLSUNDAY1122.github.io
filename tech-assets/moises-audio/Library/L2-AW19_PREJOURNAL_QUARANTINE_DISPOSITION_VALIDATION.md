# L2-AW19 Prejournal Quarantine Inventory / Explicit Disposition Validation

Result: `COMPLETED_NON_PARITY`

## Scope

Lane 2 only. This wave hardens the AW17 `.LibraryRecovery/PrejournalExport/**` preservation quarantine without changing `Shared/**`, `App/**`, `PARITY_MATRIX.json`, Queue, work packages, lane plan, or resource locks.

## Problem confirmed

AW17 correctly removes previous-process pre-registration batches from published `Exports/**` and preserves the bytes under `.LibraryRecovery/PrejournalExport/**` when a crash occurs before Library project ownership is durable. That deliberately avoids guessing ownership, but before AW19 the preserved bytes had no lane-local inventory or explicit disposition contract. App/HQ therefore lacked a safe way to distinguish valid recovery candidates, retain them for user retrieval, or explicitly discard them.

## Production change

### `Lane2PrejournalExportQuarantineManager`

A Foundation-only actor now manages the AW17 quarantine with three locations:

- unresolved: `.LibraryRecovery/PrejournalExport/<batch-id>/`
- explicitly preserved for user retrieval: `.LibraryRecovery/RecoveredPrejournalExport/<batch-id>/`
- durable disposition intents: `.LibraryRecovery/PrejournalExportDisposition/<intent-id>.json`

The recovered-for-user root intentionally stays outside `Exports/**`, so existing orphan sweep logic cannot mistake these ownership-unknown bytes for an unreferenced canonical export.

### Non-destructive inventory

`inventory()` returns valid unresolved/recovered batches plus per-batch issues. One malformed batch does not hide unrelated valid batches.

A valid batch requires:

- UUID batch directory directly under the expected recovery root;
- no batch-directory symlink;
- the AW17 `.lane2-registration-pending` marker as a small non-empty regular file;
- at least one non-empty regular artifact;
- no artifact symlink or nested directory;
- no case/canonical-equivalent ambiguous artifact filenames.

The hidden AW17 marker is never returned as a media artifact. Inventory includes filename, byte count, modification-time milliseconds, total bytes and a deterministic `v1-...` snapshot token.

The snapshot token is a non-cryptographic stale-confirmation revision token over batch ID, marker session and artifact filename/size/mtime metadata. It is not a content-authenticity hash and is not presented as one.

### Explicit keep / preserve

`preserveForUser(batchID:snapshotToken:)` requires an exact current snapshot token, atomically persists a disposition intent, then moves the entire batch from unresolved quarantine to `.LibraryRecovery/RecoveredPrejournalExport/**`.

It does **not** infer ProjectID, media type, lifecycle metadata ownership or recreate a canonical project export. `recoveredArtifactURLs(...)` revalidates the recovered batch and returns only media artifact URLs for HQ/App share/save UX.

### Explicit purge

`purgePending(...)` and `purgeRecovered(...)` are destructive only after exact snapshot-token validation and durable purge-intent persistence. They operate only on a validated UUID batch below the corresponding recovery root. There is no age-based or automatic purge in AW19.

### Crash recovery

`recoverPendingDispositions()` replays durable explicit decisions:

- preserve intent + source still present => validate exact snapshot, move to recovered root, retire intent;
- preserve intent + destination already moved => validate exact destination snapshot, retire intent;
- source and destination both present => fail closed as conflict;
- purge intent + batch present => revalidate exact snapshot then delete;
- purge intent + batch already absent => retire the already-completed decision.

Malformed disposition documents fail closed and are not ignored.

### `Lane2PrejournalExportRecoveryService`

The production-facing composition seam performs:

1. AW17 `Lane2ExportRegistrationJournal.recoverPrejournalPublishedBatches()`;
2. AW19 `recoverPendingDispositions()`;
3. non-destructive quarantine inventory.

This makes the expected App/HQ recovery order explicit while retaining AW17 as the publication-crash authority.

## Negative / recovery cases validated

- valid batch inventory returns deterministic artifact ordering and byte totals;
- malformed batch without AW17 marker becomes an issue without hiding valid siblings;
- preserve moves the whole batch and never exposes the hidden marker as media;
- stale snapshot rejects destructive purge and leaves bytes intact;
- durable preserve intent resumes when the move has not started;
- durable preserve intent converges when the move completed before intent cleanup;
- unresolved purge and recovered purge require explicit calls and converge;
- nested directories and symlink artifacts are fail-closed inventory issues;
- scale inventory covers 1,000 batches / 2,000 artifacts.

## Portable execution

Environment: Swift 6.2.1 Linux.

PASS:

- `Lane2PrejournalExportQuarantine.swift` strict-concurrency + warnings-as-errors typecheck;
- `PrejournalExportQuarantineTests.swift` strict XCTest typecheck;
- `Lane2PrejournalExportRecoveryService.swift` strict typecheck against the exact AW17 journal method shape via a contract-equivalent stub;
- static production audit: `L2_AW19_STATIC_AUDIT_PASS checks=15/15`;
- self-check: `L2_AW19_SELF_TEST_PASS scenarios=9 batches=1000 artifacts=2000 elapsed_seconds=0.343279`.

The 0.343279 s value is a Linux filesystem inventory microbenchmark for 1,000 recovery directories with two 1 KiB fixture artifacts each. It is not an iPhone/APFS performance result.

## Important boundaries

- AW19 does not automatically restore an ownership-unknown quarantine batch into a Project or canonical `Exports/**`; that would fabricate ownership after the exact crash state AW17 was designed to preserve.
- HQ/App can expose recovered artifact URLs through the share/save UX, or later add an explicitly user-selected project-adoption flow with a separate durable ownership contract. Such adoption is not inferred in Lane 2.
- The snapshot token is stale-state protection, not cryptographic content authentication.
- Real APFS atomicity/force termination, iPhone share sheet, Files destination behavior and user-facing recovery UX remain HQ/device gates.
- Existing AW13 metadata-quarantine and AW17 export-registration recovery semantics remain unchanged.
- MOI-P019 remains `MISSING`; portable quarantine management is not export PARITY.

## HQ integration requirements

1. Compose `Lane2PrejournalExportRecoveryService` during recovery UX setup and call `inventoryAfterRelaunch()` before displaying unresolved prejournal items.
2. Present explicit user choices for unresolved valid batches: retain/recover for user retrieval or discard. Do not infer a project from filename, time, ordering or adjacent metadata.
3. For retained batches, use only `recoveredArtifactURLs(...)` after snapshot revalidation when feeding share/save UI.
4. Do not age-purge `.LibraryRecovery/PrejournalExport/**` or `.LibraryRecovery/RecoveredPrejournalExport/**` without a separate explicit policy/decision.
5. Force terminate on iPhone after disposition intent write, during preserve move, after move/before intent removal, during purge and after purge/before intent removal; verify replay convergence.
6. Keep AW17 canonical exporter/pre-registration marker behavior unchanged.
7. Do not promote MOI-P019 from AW19 portable evidence alone; final PARITY remains HQ-owned.
