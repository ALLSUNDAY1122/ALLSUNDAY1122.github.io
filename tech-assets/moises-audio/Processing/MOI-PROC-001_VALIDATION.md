# MOI-PROC-001｜Processing lifecycle validation

Captured: 2026-08-22 JST
Worker: `Moises-Worker-1`
Work branch: `moises/wp1-separation-processing`
Scope: `tech-assets/moises-audio/Processing/**`
PARITY impact: evidence only; Worker does not edit PARITY.

## Acceptance implemented

### Durable server/client job lifecycle

`ProcessingLifecycleCoordinator` persists a generation before provider start and binds the returned `ProcessingJobID` durably before exposing normal operation.

- same project + same active request reconnects to the existing job rather than creating another start;
- active / cancellation-requested / ready jobs can be recovered after relaunch;
- ready jobs are finalized immediately during relaunch so expiring provider result URLs are not left waiting;
- `ProcessingSnapshot` is mirrored into `ProjectPersisting` after the durable lifecycle journal is updated;
- phase or fraction regressions from the provider are rejected instead of silently corrupting visible progress.

### Cancel / retry / reconnect

Cancellation intent is persisted before the provider cancellation call. A race in which the server reaches `ready` after local cancellation intent is treated as cancelled locally and result download is suppressed.

Retry is allowed only from terminal/retryable state. A provider `start()` whose response may have been lost is recorded as `startAmbiguous` and is **not automatically retried**. The current HQ-owned `SourceSeparationProviding.start(_:)` contract has no caller-supplied stable idempotency key, so an explicit `allowPotentialDuplicateStart` decision is required before a potentially duplicate start.

This is deliberately fail-closed. It prevents the client from claiming exactly-once semantics that the canonical contract cannot presently guarantee.

### Partial-output cleanup and relaunch recovery

`FileProcessingOutputTransaction` protects a pre-existing stem directory while replacement processing is in flight.

- prior outputs are copied before the transaction marker is committed;
- an interrupted backup preparation with no marker never deletes live outputs;
- rollback is a no-op when no transaction exists;
- a marker claiming prior outputs existed requires the backup to be present before live outputs are touched;
- staged artifacts must exist, be non-empty and resolve under `separation-stems/<projectID>/`;
- finalization is journaled as `resultStaged -> resultPersisted -> completed`;
- if `recordStems` fails after result download, relaunch retries persistence without calling `provider.result` again;
- cancellation/failure restores the previous output set and removes partial replacement outputs.

## Machine verification

Environment: Swift 6.2.1, Linux x86_64 local verification harness using canonical-shape Shared domain stubs and the exact Worker-1 Processing sources.

Compile gate:

```text
swiftc -parse-as-library -strict-concurrency=complete -warnings-as-errors \
  DomainStubs.swift ProcessingLifecycleStateStore.swift \
  ProcessingLifecycleCoordinator.swift MOI_PROC_001_SelfTest.swift
=> PASS
```

State-machine / recovery executable:

```text
MOI_PROC_001_SELF_TEST_PASS
```

Covered cases:

1. identical active request calls provider `start` exactly once;
2. progress regression 0.6 -> 0.5 is rejected;
3. provider-confirmed cancellation rolls back output transaction;
4. network timeout during `start` becomes ambiguous and cannot auto-retry;
5. explicit ambiguous-start retry creates one new start attempt;
6. failed stem DB write leaves `resultStaged`; relaunch completes without re-fetching provider result;
7. file transaction rollback restores previous stem bytes and removes partial new stems;
8. markerless interrupted backup preparation leaves live stems untouched.

Actual file-backed lifecycle store supplementary check:

```text
MOI_PROC_001_FILE_STORE_PASS
```

Verified: semantic JSON round-trip of project/request/generation/job/state/snapshot/retry fields, removal, and corrupt JSON classification as non-retryable `PROC_STATE_CORRUPT`. `updatedAt` is observational metadata and ISO8601 encoding may normalize sub-second precision; no lifecycle decision depends on exact timestamp equality.

## Self-review corrections made during this wave

- Rejected a rollback implementation that could delete an existing stem set when no transaction journal existed.
- Hardened interrupted backup preparation so a partial backup without a committed marker cannot replace/delete live output.
- Added `resultStaged` / `resultPersisted` two-phase finalization to close crash windows around provider output and project DB writes.
- Persisted `retryable` independently of provider snapshots so pre-job start failures survive relaunch correctly.
- Separated provider-start uncertainty from failures occurring after a job ID was bound.
- Preserved `resultStaged` on DB persistence failure so recovery can resume without a second AI/result fetch.
- Treated cancellation after `resultPersisted` as completion of the already-persisted transaction, avoiding restoration of old bytes beneath new DB references.
- Fixed strict-concurrency violations in the self-test itself; final compile uses `-warnings-as-errors`.

## Known remaining gates

This Task provides the lifecycle implementation and deterministic local recovery behavior, but it does **not** justify `MOI-P020` PARITY yet.

Still required before PARITY:

- live production separator execution once `MOI-SEP-002` Human Gate is cleared;
- real interruption / relaunch / cancellation / retry evidence against that production backend;
- long-track/network/storage-pressure/device evidence;
- confirmation of upstream cancellation semantics for the selected production separator;
- differential UX/recovery evidence against the current iPhone Reference.

## HQ contract request

For strong server-side exactly-once semantics after a lost `start()` response, HQ should consider a future Shared contract extension that allows a caller-generated durable idempotency token to cross `SourceSeparationProviding.start`. Until then, this implementation intentionally exposes ambiguous start and requires explicit retry rather than silently creating duplicate jobs/cost.

`MOI-P020` remains `MISSING`; no PARITY state change is requested by this Worker.
