# L1-A17 Validation — Full Provider Fault Matrix

Captured: 2026-08-24 JST  
Worker: `Moises-Worker-1`  
Branch: `moises/wp1-separation-processing`  
Result: `COMPLETE_NON_PARITY`

## Goal

Normalize production provider/network/storage/process failures into stable Lane 1 semantics so retry, reconciliation and user recovery do not depend on raw vendor exception text. The critical invariant is:

> `operation_retryable = true` never means that a provider task create request may be blindly sent again.

Once a provider create request may have reached the provider, A07 reconciliation is mandatory before any new create can occur.

## Existing safety layers reused

A17 composes the earlier Lane 1 work rather than duplicating it:

- A07 owns ambiguous-create / duplicate-billing reconciliation.
- A08 owns truthful logical cancellation.
- A10 owns quota/credit/billing limit semantics.
- A13 owns corrupt/missing output rejection.
- A14 owns atomic multi-stem promotion and crash recovery.
- A15 owns bounded streaming and storage-pressure behavior.
- A16 owns durable logical-job relaunch recovery.

## Implementation

### `Separation/Server/provider_fault_matrix.py`

Adds:

- `FaultDisposition`
  - category
  - stable error code
  - operation retryability
  - automatic provider-create retry permission
  - safe recovery action
  - privacy-safe message key
  - existing-result preservation flag
- `CrashDisposition`
- `classify_fault(...)`
- `classify_process_crash(...)`
- `machine_fault_matrix()`
- `FaultNormalizedProviderAdapter`

The adapter is A06-compatible: it can wrap the concrete provider client before it is passed into A15/A10/A06 composition. It does **not** retry operations. It only converts raw provider/socket failures into stable policy so the existing orchestrators can persist and recover them deterministically.

The normalized exception intentionally exposes only stable fields. Raw exception messages are not copied into `ProviderFaultError`; this prevents signed URLs, provider diagnostics or credentials embedded in exception text from becoming normal telemetry by accident.

## Provider create ambiguity rule

The most important distinction in A17 is between:

1. `operation_retryable`
2. `automatic_provider_create_retry_allowed`

Examples:

- HTTP 429 during polling: operation retryable; poll again after backoff.
- HTTP 503 during polling: operation retryable; poll again later.
- HTTP 429/503/timeout/malformed response during provider create: the recovery operation may be retried, but automatic provider-create retry is **false**. Action is `reconcile_create_not_repost`.
- duplicate provider tasks: non-retryable billing incident; manual/reconciliation path only.

This preserves A07's no-blind-rePOST invariant.

## Fault classes covered

The machine matrix contains 21 fault rows, including every A17 roadmap minimum class:

- missing/invalid credentials;
- HTTP 401;
- HTTP 403;
- provider job 404;
- HTTP 409 conflict;
- HTTP 413 oversized source;
- HTTP 429 rate limit;
- HTTP 5xx;
- DNS failure;
- TLS failure;
- upload timeout;
- poll timeout;
- malformed JSON/provider shape;
- vendor task error;
- missing target;
- duplicate/invalid target set;
- expired output URL;
- corrupt WAV/container output;
- disk full / storage exhaustion;
- local deletion failure;
- duplicate provider-task billing incident / quota / credit / billing codes through the same classifier.

### Representative stable actions

| Failure | Stable code | Retry operation? | Auto create retry? | Action |
|---|---|---:|---:|---|
| 401 | `SEP_PROVIDER_AUTH_INVALID` | no | no | fix credentials |
| 404 job | `SEP_PROVIDER_JOB_NOT_FOUND` | no | no | reconcile, never recreate blindly |
| 409 | `SEP_PROVIDER_CONFLICT` | no | no | reconcile conflict |
| 413 | `SEP_PROVIDER_SOURCE_TOO_LARGE` | no | no | reduce/transcode source |
| 429 during create | `SEP_PROVIDER_RATE_LIMITED` | yes | **no** | reconcile create |
| 5xx during create | `SEP_PROVIDER_5XX` | yes | **no** | reconcile create |
| DNS poll failure | `SEP_PROVIDER_DNS_FAILED` | yes | no | backoff/retry poll |
| TLS failure | `SEP_PROVIDER_TLS_FAILED` | no | no | endpoint/TLS intervention |
| upload timeout before task create | `SEP_PROVIDER_UPLOAD_TIMEOUT` | yes | yes, after upload recovery | retry upload path |
| poll timeout | `SEP_PROVIDER_POLL_TIMEOUT` | yes | no | retry poll |
| expired signed output | `SEP_PROVIDER_OUTPUT_URL_EXPIRED` | yes | no | refresh URL or use verified local copy |
| corrupt output | `SEP_PROVIDER_OUTPUT_CORRUPT` | yes | no | redownload output then fail closed |
| disk full | `SEP_LOCAL_STORAGE_EXHAUSTED` | yes | no | free space then resume |
| local deletion failure | `SEP_LOCAL_DELETE_FAILED` | yes | no | retry deletion |

## Process crash matrix

A17 fixes recovery action for ten durable boundaries:

1. intent persisted
2. upload in progress
3. provider create in flight
4. provider task bound
5. polling
6. output downloading
7. staging verified
8. atomic promotion in flight
9. committed-ledger write in flight
10. committed result

Only the pre-provider-create phases may resume through the same logical start without provider-task reconciliation. `provider_create_in_flight` and every later phase explicitly set automatic provider-create retry to false.

Recovery delegates to A16/A14 as appropriate:

- create in flight -> A07 reconciliation;
- task bound/polling -> A16 registry + authoritative poll;
- downloading -> recover then redownload only missing/unverified output;
- staging verified -> use verified local set;
- promotion/ledger commit -> A14 atomic recovery;
- committed -> verify committed result and resume.

## Machine verification

Lane-local execution against the final A17 semantics:

- classifier/recovery assertions: **44 / 44 PASS**
- generated fault rows: **21**
- generated process-crash rows: **10**
- Python compile of the final classifier semantics: **PASS**

The durable repository test suite is:

`Separation/Tests/test_provider_fault_matrix.py`

It covers status-code policy, socket/DNS/TLS/timeouts, quota/billing classifications, target/output faults, storage/delete faults, every crash phase, adapter success/failure paths and raw exception-message redaction.

Machine-readable evidence:

`Processing/Tests/L1-A17_PROVIDER_FAULT_MATRIX.json`

## Deployment composition

At Late Integration the expected server provider composition is conceptually:

`concrete provider -> FaultNormalizedProviderAdapter -> A15 long-track instrumentation -> A10 budget guard -> A06/A07 lifecycle -> A16 reconnect facade`

A08 cancellation and A14 committed-output publication remain authoritative at their existing boundaries.

This wrapper ordering is important: provider/network failures should be normalized before lifecycle registries persist them, but the normalizer must never perform retries itself.

## Remaining external gaps

A17 is an executable policy/fault harness, not live provider proof. Still missing:

- production provider credentials and commercial/privacy approval;
- live 401/403/404/409/413/429/5xx provider payload verification;
- authoritative `Retry-After`, quota and credit behavior from the production account;
- real DNS/TLS/provider outage timing;
- live expired-output re-sign/refresh behavior;
- physical-iPhone process termination/power-loss evidence;
- rights-cleared real-audio and current-iPhone Moises differential evidence.

Provider-specific payloads may require classifier aliases after live capture, but their recovery categories must preserve the A17 invariants.

## PARITY

`parity_state = NON_PARITY_EVIDENCE_ONLY`.

A17 materially hardens P020/P021/P024-related recovery behavior but does not change any PARITY row. `MOI-P020` remains `MISSING` until integrated real-device cancellation/retry/interruption evidence exists. P003/P004/P005/P021/P024 likewise remain governed by their real provider/audio/device gates.
