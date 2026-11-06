# L1-M02 — Processing lifecycle ambiguity / cancellation / reconnect hardening

Bundle: `L1-M02`  
Lane: `LANE-1-SEPARATION-PROCESSING`  
Assignment epoch: `2`  
Frozen Shared/App contract: `17d129c9f0faaf7f24a96439cf3aa3cd0e7c02e8`  
PARITY impact: **NONE. MOI-P020 remains MISSING until real production-backend and current-iPhone evidence exists.**

## Implemented

### Stable provider idempotency without Shared changes

`ProcessingProviderCapabilities.swift` adds a lane-local optional `StableIdempotentSeparationStarting` capability. The durable `generationID` already persisted by the lifecycle is converted to a stable key (`proc-<uuid>`), so response-loss retry and relaunch can reuse the same provider start identity.

The frozen HQ `SourceSeparationProviding.start(_:)` signature is unchanged. Providers without the capability retain the existing fail-closed ambiguous-start behavior and cannot silently auto-retry.

`ServerStableStartCapability.swift` implements this capability for the project-controlled server endpoint by sending the supplied stable key as `Idempotency-Key`, while existing `ServerSeparationProvider` remains the authoritative snapshot/result/cancel implementation.

### Ambiguous start resolver

`ProcessingAmbiguousStartResolver` handles only records whose provider job binding is unknown:

- `.starting` after relaunch;
- `.startAmbiguous` after response loss;
- `.cancellationRequested` with no known job ID.

A retryable network/provider error keeps the same durable generation and therefore the same idempotency key. A later successful retry binds the returned provider job and records a queued snapshot. Definitive authorization/media failures become durable failure and rollback local transaction state.

### Cancellation ordering hardening

For cancellation during ambiguous start, recovery now orders the operations as:

1. reissue start with the stable generation key;
2. durably bind the recovered `jobID` while state remains `cancellationRequested`;
3. send idempotent provider cancel;
4. rollback partial output;
5. only after cleanup succeeds, write terminal `cancelled` and project snapshot.

Therefore a cleanup/storage failure does not erase the recovered job identity. Relaunch still has enough information to repeat cancellation/cleanup.

### Failure matrix

`Tests/L1-M02_FAILURE_MATRIX.json` records 14 lifecycle scenarios across start ambiguity, reconnect, progress regression, cancellation, storage/state persistence failure, result persistence and crash-safe output rollback. It combines the already-canonical 7 `MOI_PROC_001_SelfTest` paths with the new stable-idempotency scenarios.

## New executable tests

`Tests/L1_M02_SelfTest.swift` covers seven new scenarios:

1. deterministic key stability and generation rotation;
2. network-timeout ambiguity followed by same-key successful rebind;
3. cancellation intent surviving ambiguous start;
4. definitive access denial fail-closed behavior;
5. project-persistence failure after durable provider binding;
6. state-store write failure after provider success while preserving same-generation retry safety;
7. cleanup/storage failure leaving recoverable cancellation intent + job binding.

Failure injection is performed through lane-owned seams: scripted provider/stable starter, state store, project persistence and output transaction. No production fake separator is introduced.

## Machine verification

Executed with Swift 6.2.1 on Linux:

- production additions compiled with `-parse-as-library -strict-concurrency=complete -warnings-as-errors` — **PASS**;
- new failure self-test compiled with `-strict-concurrency=complete -warnings-as-errors` — **PASS**;
- `L1_M02_SELF_TEST_PASS scenarios=7` — **PASS**;
- failure-matrix JSON parsed and coverage IDs validated — **PASS**.

The compile harness uses minimal frozen-contract-compatible stubs only because v3 defers cross-lane/package compilation to HQ Late Integration. This is not iOS runtime evidence.

## Remaining Shared-contract request

No Shared change is required to execute L1-M02. The capability is deliberately lane-local.

At a later HQ checkpoint, one architectural choice should be made:

- keep provider-specific stable-start capability injection as implemented; or
- extend the Shared start contract with a caller-provided idempotency token and migrate providers centrally.

The latter could simplify composition but is not required for this lane checkpoint and was not performed by Worker 1.

## PARITY restraint

These are deterministic lifecycle and fault-injection tests. They do not prove real vendor cancellation behavior, real billing deduplication, actual network recovery, long-track survival, iPhone background behavior or Moises-equivalent UX. `MOI-P020` remains MISSING until those external/device gates are run by HQ with the real separator route.
