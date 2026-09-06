# L1-A16 Validation — Reconnect / Relaunch Durable Job Registry

Captured: 2026-08-24 JST  
Worker: `Moises-Worker-1`  
Branch: `moises/wp1-separation-processing`  
Result: `COMPLETE_NON_PARITY`

## Goal

Reconstruct logical separation processing safely after app/server process termination without trusting stale non-terminal cache, issuing a blind second provider create, resurrecting deleted work, or exposing provider-ready artifacts before the project-controlled result is actually committed.

## Existing seams reused

A16 composes rather than replaces the earlier Lane 1 safety layers:

- A06 durable `AtomicJobRegistry` remains the backend record for provider asset/task state.
- A07 remains authoritative for ambiguous provider-create reconciliation and duplicate-billing protection.
- A08 remains authoritative for logical cancellation and ready-vs-cancel output discard.
- A14 remains authoritative for local multi-stem result commit.
- A15 remains the production streaming/storage-pressure route.

A16 adds the missing relaunch identity/snapshot layer above those seams.

## Implementation

### `Separation/Server/durable_reconnect_registry.py`

A second durable registry records the stable logical intent needed by the app/server relaunch path:

- logical job ID;
- project ID;
- asset ID;
- requested profile ID;
- canonical requested model set;
- SHA-256 of the idempotency key, never the raw key;
- backend request fingerprint and source SHA after A06 has bound the request;
- provider asset/task operational IDs after backend bind;
- recovery-attempt count;
- creation/update/delete timestamps;
- monotonic authoritative snapshot revision;
- terminal deleted tombstone.

The registry deliberately does not persist source file paths, user filenames, signed output URLs or raw audio.

Writes use a process advisory lock, temp file, `fsync` and atomic replace. A platform without the required lock must provide an equivalent transactional store rather than silently running without coordination.

### Intent-before-work durability

`begin_intent()` persists the logical request before backend `start()` is called. A process termination in that window therefore leaves a known logical identity rather than an invisible half-request.

If the process restarts before A06 ever created a backend record, recovery returns an explicit `unknown / SEP_RECOVERY_BACKEND_NOT_STARTED` snapshot. Re-running `start()` with the same logical identity is idempotent. A different project/asset/profile/model set with the same idempotency key fails closed.

Requested model identity is canonicalized as a sorted set. This matches A06/A07's order-insensitive request fingerprint: `vocals,drums` and `drums,vocals` cannot become a false A16 conflict.

## Recovery authority order

A16 uses the following precedence:

1. **deleted tombstone** — never query provider or resurrect the logical job;
2. **logical cancellation** — A08 cancellation wins even if provider later says ready;
3. **server/project committed outputs** — a locally committed result remains ready after vendor output/task retention expires;
4. **provider/server authoritative observe** — refresh separating/failed/cancelled/ready state;
5. **old non-terminal snapshot** — diagnostic `previous_phase` only, never current truth when authority is unavailable.

This means a network/TLS/provider-observe failure after a cached `separating` state becomes current `unknown`; the old phase is retained only as diagnostic history.

## Ready semantics

Provider `ready` is not exposed as product `ready` by itself.

On recovery A16 first calls the existing local output collection/commit path. Only when `outputs_committed` is true does the authoritative snapshot become `ready`.

If output download/storage/integrity/commit fails, the state is `recovering`, with provider phase `ready`. This preserves A13/A14/A15 guarantees and prevents a relaunch from pointing Library/App at incomplete stems.

## Ambiguous provider start

Recovery never calls backend `start()` or provider task creation.

If A06/A07 has a start-ambiguous record, A16 invokes the existing reconciliation seam:

- unique provider metadata match -> bind that task and continue observing;
- zero match -> unknown/non-retryable for create; no repost;
- multiple matches -> persist `unknown / SEP_PROVIDER_DUPLICATE_TASKS_DETECTED`; no automatic create/retry.

`retryable` on an `unknown` recovery snapshot means that the authoritative **recovery/observe operation** may be checked again later. It never authorizes a blind provider task create.

A process killed in an earlier provider-upload/create boundary can therefore remain explicitly unknown if the backend cannot prove a provider task. This is preferable to duplicate processing/billing; broader provider-phase fault classification continues in A17.

## Cancellation and deletion

A08 logical cancellation outranks provider-ready on relaunch. A cancelled job never enters output collection through A16.

A16 deletion is represented by a durable tombstone. Provider state arriving later cannot resurrect that logical identity, and the same idempotency identity cannot silently be reused after tombstoning.

Artifact deletion itself remains the A09/A14 responsibility; A16 does not invent deletion completion evidence.

## Machine verification

Executed against the final A16 module:

- `test_durable_reconnect_registry.py`: **25 / 25 PASS**.
- Python compile check for `durable_reconnect_registry.py`: **PASS**.

The suite includes:

- intent persisted before backend work;
- simulated process termination after intent but before backend start;
- service reconstruction from the same durable registry;
- provider progress overriding stale cached progress;
- provider ready -> local commit -> ready;
- provider ready + local storage/copy failure -> recovering, never ready;
- locally committed result surviving provider 404/retention disappearance;
- network loss producing current unknown rather than stale separating;
- provider task 404 producing non-retryable unknown without recreate;
- locally terminal upload failure without provider observe;
- ambiguous create unique-match recovery without second start;
- ambiguous create zero-match no repost;
- duplicate provider tasks persisted as non-retryable unknown;
- logical cancel winning provider-ready race;
- deleted tombstone preventing resurrection;
- unregistered legacy/backend job not silently adopted;
- backend identity mismatch fail closed;
- backend start exception after A06 persistence still bound for later relaunch;
- same key/different profile conflict;
- same model set/different order canonical identity;
- corrupt recovery registry fail closed;
- durable recovery-attempt count across service instances;
- mixed active/deleted `recover_all` behavior;
- raw idempotency key/path/filename/URL redaction;
- previous phase retained only as diagnostic after authority loss.

Machine-readable matrix:

`Processing/Tests/L1-A16_RECONNECT_MATRIX.json`

## What A16 does not prove

A16 is lane-local engineering evidence, not product PARITY. Still required:

- production provider credentials and actual provider restart/retention behavior;
- integrated iPhone background termination/relaunch tests;
- actual app UI state restoration through HQ-owned Shared/App/Library seams;
- multi-process/horizontally-scaled transactional recovery store if production runs more than one writer;
- actual provider disappearance/error timing and full fault matrix (A17);
- rights-cleared real-audio and current-iPhone Moises differential evidence.

The A16 registry is a server/lane recovery ledger, not proof that iOS background execution itself is reliable.

## PARITY

`parity_state = NON_PARITY_EVIDENCE_ONLY`.

`MOI-P020` remains `MISSING`. A16 materially closes the relaunch state-reconstruction engineering gap, but P020 requires integrated real-device interruption/retry/resume evidence and final HQ differential judgment.
