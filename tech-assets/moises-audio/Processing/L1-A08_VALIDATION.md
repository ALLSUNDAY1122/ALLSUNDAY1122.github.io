# L1-A08 Validation — Cancellation Truthfulness / Race Semantics

Captured: 2026-08-23 JST
Worker: `Moises-Worker-1`
Branch: `moises/wp1-separation-processing`
Result: `COMPLETE_NON_PARITY`

## Goal

Make cancellation truthful across the full Lane 1 server lifecycle. A user-visible logical cancel must remain authoritative for output delivery, while the system separately records whether upstream provider compute cancellation is unsupported, merely requested, authoritatively confirmed, failed, or contradicted by later provider state.

This Wave directly reduces the `MOI-P020` cancel/retry/resume gap. It does not claim PARITY.

## Existing client behavior retained

`ProcessingLifecycleCoordinator` already persists `.cancellationRequested`, rolls back partial output, and gives user cancellation precedence when a provider reaches `ready` during the cancel race. `ServerSeparationProvider.cancel()` sends an idempotent backend `DELETE`, then relies on later snapshot polling for authoritative state.

The remaining gap was server/provider truth: a logical DELETE could be treated as if vendor compute had stopped even when the selected provider exposes no authoritative cancellation API.

## Implementation

### `Separation/Server/truthful_cancellation.py`

Added a provider-neutral `TruthfulCancellationService` facade around the production separation backend.

Durable cancellation facts:
- logical cancel intent;
- cancel request count;
- output disposition (`keep` / `discard`);
- provider task binding if known;
- upstream cancel state;
- provider phase observed after cancel;
- stable evidence/error code.

Safety semantics:
1. cancel intent is persisted before any provider cancellation call;
2. repeated cancel is locally idempotent and does not repeat an upstream cancel request unless future provider-specific evidence justifies that behavior;
3. provider absence of `cancel_task` becomes `upstream=unsupported`, not a fake success;
4. provider receipt `accepted` means only `requested`, never `confirmed`;
5. provider receipt `confirmed` is recorded as authoritative but is rechecked against later observed provider state;
6. provider cancel errors preserve logical cancellation and record `unknown_after_error`;
7. unbound/start-ambiguous jobs can be logically cancelled without inventing an upstream cancellation event;
8. after logical cancel, `collect_ready_outputs()` is blocked before the wrapped backend can download/promote outputs;
9. if provider reaches `ready` after cancel, public phase remains `cancelled` and the race is recorded as `SEP_CANCEL_RACE_PROVIDER_COMPLETED_OUTPUT_DISCARDED`;
10. if a supposedly confirmed cancellation is contradicted by later `separating`, evidence becomes `SEP_CANCEL_CONFIRMATION_CONTRADICTED`.

### Backward-compatible snapshot

The facade returns the existing canonical fields expected by the Swift client:
- `phase`
- `fractionComplete`
- `retryable`
- `stableErrorCode`

For a logical cancellation, `phase` remains `cancelled`. An additional `cancellationTruth` object carries server evidence:
- `logicalCancelled`
- `logicalState`
- `upstreamCancelState`
- `providerPhaseAfterCancel`
- `outputDisposition`

Swift `Decodable` ignores unknown response keys by default, so this evidence can be added by the backend without changing frozen Shared/App contracts. HQ may choose a later explicit contract if product UX needs to display upstream-compute semantics.

## Current AudioShake boundary

The current Lane 1 AudioShake adapter intentionally does not implement `cancel_task`. Existing captured developer evidence did not establish an authoritative task-cancellation endpoint. Therefore the current fast-track candidate is truthfully represented as:

- user logical cancellation: supported;
- further polling/output delivery: can be stopped/discarded by project logic;
- upstream vendor compute cancellation: **unsupported/unproven until superseding API or contract evidence exists**.

No claim is made that an AudioShake task or charge is stopped by logical cancellation.

## Machine verification

A local reconstruction using the exact module/test contents written to this branch was executed with Python 3.

- `py_compile truthful_cancellation.py`: PASS
- `py_compile test_truthful_cancellation.py`: PASS
- `test_truthful_cancellation.py`: **18/18 PASS**

Covered cases include:
- accepted vs confirmed upstream receipts;
- provider with no cancellation capability;
- provider cancellation error;
- invalid provider receipt;
- repeated cancellation idempotency;
- unbound provider job;
- ready-vs-cancel race;
- provider failure after logical cancel;
- later provider cancelled confirmation;
- contradicted confirmation;
- cancelled output collection block;
- service restart/relaunch durability;
- uncancelled delegation regression;
- corrupt registry fail-closed;
- invalid logical job identifier.

Durable scenario ledger:
`Processing/Tests/L1-A08_CANCELLATION_MATRIX.json`.

## Integration requirement

The production backend `DELETE /v1/separations/{jobID}` and subsequent snapshot/result handlers should be wired through `TruthfulCancellationService` (or semantically equivalent logic) at HQ/backend integration. Direct result collection after logical cancellation must not bypass the facade.

This is a composition requirement, not a Shared/App contract change.

## Remaining live evidence

Still unproven:
- actual vendor cancellation behavior under production credentials;
- whether a future provider cancel endpoint is idempotent;
- whether cancellation changes actual billed credits/cost;
- provider task-list/cancel consistency under network races;
- real long-running user-audio cancellation on target infrastructure;
- current-iPhone Moises differential cancel/retry UX.

## PARITY impact

`parity_state = NON_PARITY_EVIDENCE_ONLY`.

`MOI-P020` remains `MISSING` until integrated real processing survives cancellation/retry/interruption without project corruption and real-device/reference evidence is complete. Worker 1 does not edit `PARITY_MATRIX.json`.
