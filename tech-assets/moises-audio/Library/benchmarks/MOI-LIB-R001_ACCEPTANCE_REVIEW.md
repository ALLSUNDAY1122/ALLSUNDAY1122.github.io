# MOI-LIB-R001 — Acceptance / self-review

Captured: 2026-08-22 JST
Worker: Moises-Worker-1
Attempt: `task/MOI-LIB-R001/attempt-1`

## Acceptance review

### 1. SwiftData / Core Data / SQLite / file-backed comparison
PASS for research scope.

`MOI-LIB-R001_PERSISTENCE_DECISION.md` compares all four approaches against reliability, migration control, iOS fit, domain isolation, ordering/query and operational testability.

### 2. Commercial/native persistence path + schema/version/atomic strategy
PASS for research scope.

Selected baseline:
- Core Data + SQLite persistent store for canonical structured metadata;
- app-owned filesystem for source/stem/export artifacts;
- persistence adapter maps private records to HQ-owned value contracts;
- serialized writes through a dedicated service/actor and queue-confined Core Data contexts;
- explicit model versions, lightweight migration when inferable, staged/manual migration otherwise;
- no silent destructive reset;
- file finalization before metadata exposure, with orphan/tombstone reconciliation.

No third-party persistence dependency or distribution licence is required for this baseline.

### 3. Processing / stem references / user edits survive relaunch without opaque engine persistence
PASS for architecture definition; runtime parity remains unclaimed.

The machine-readable recovery record requires persistence of stable IDs, paths and primitive/versioned values only. Live AVFoundation objects, ML runtimes, Task handles, transient provider URLs and opaque engine archives are forbidden.

Recovery explicitly covers:
- nonterminal processing jobs;
- source/stem path verification;
- backend resume-or-retry fallback;
- missing-file states;
- staging/orphan cleanup;
- transactional setlist reorder;
- interrupted deletion.

### 4. Corruption / migration / deletion / interrupted-write gates
PASS for gate definition; implementation/device execution remains future work.

Eleven mandatory validation gates are recorded in `MOI-LIB-R001_SCHEMA_AND_RECOVERY.json`, including forced termination at critical commit boundaries, every released-schema migration fixture, non-destructive migration failure, corrupt-store handling and tombstone recovery.

## Self-review findings

1. **Core Data does not create an ACID transaction with arbitrary audio files.** The design therefore avoids pretending otherwise and explicitly uses staging/finalization + metadata exposure + startup reconciliation.
2. **SwiftData was not rejected as unsuitable.** It remains an alternative; Core Data is selected because migration/recovery control is more mature for the first parity implementation.
3. **Direct SQLite was not rejected on performance grounds.** It is deferred because the project does not need to own low-level WAL/concurrency policy unless Core Data proves insufficient.
4. **The Shared contract is currently write-heavy.** Full P017/P018/P020 implementation requires HQ decisions for project read/list, versioned edits, setlists, deletion and processing recovery. This attempt records those requirements but does not edit Shared/App.
5. **No real-device claim is made.** Storage pressure, corrupt-store behavior and kill/relaunch tests must be executed in a later implementation task.
6. **No PARITY change is warranted.** P017/P018/P020 remain MISSING until actual persistence implementation and recovery evidence exist.

## Evidence files

- `tech-assets/moises-audio/Library/benchmarks/MOI-LIB-R001_PERSISTENCE_DECISION.md`
- `tech-assets/moises-audio/Library/benchmarks/MOI-LIB-R001_SCHEMA_AND_RECOVERY.json`
- `tech-assets/moises-audio/Library/benchmarks/MOI-LIB-R001_ACCEPTANCE_REVIEW.md`

## HQ requests

Without independently changing HQ-owned contracts, the following semantics should be considered before a Library implementation task is released:
- project list/load;
- versioned user-edit save/load;
- setlist CRUD and atomic reorder;
- tombstone/delete + artifact cleanup;
- durable processing resume vs retry;
- optionally analysis snapshot restoration if Reference parity requires it.

## PARITY impact

Evidence informs MOI-P017, MOI-P018 and MOI-P020 only. `parity_state_changes = []`.
