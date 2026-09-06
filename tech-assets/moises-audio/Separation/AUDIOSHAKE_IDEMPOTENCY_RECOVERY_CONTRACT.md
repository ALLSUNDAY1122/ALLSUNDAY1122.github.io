# AudioShake ambiguous-start / idempotency recovery contract

Captured: 2026-08-23 JST
Owner: Moises-Worker-1
Scope: Lane 1 `Separation/**` only
Evidence state: `NON_PARITY_EVIDENCE_ONLY`

## Purpose

Prevent an ambiguous provider `POST /tasks` response from becoming a second provider Task or a second charge.

A network timeout after the request body leaves the server is not proof that AudioShake rejected the Task. The project therefore persists the logical job as `start_ambiguous` before any retry decision and never automatically repeats Task creation.

## Current official API surface used

AudioShake's current developer API documents:

- `POST /tasks` creates a Task and returns Task metadata including `id`, `cost`, `assetId`, `metadata`, and targets.
- client-provided `metadata` is stored on the Task.
- `GET /tasks/{id}` retrieves a specific Task.
- `GET /tasks` retrieves the account's paginated Task list.
- list pagination uses `skip` and `take`; current documented `take` range is 1...100.
- Task-list responses include the stored `metadata` field.

Official references:

- https://developer.audioshake.ai/api-reference/tasks/create
- https://developer.audioshake.ai/api-reference/tasks/get
- https://developer.audioshake.ai/api-reference/tasks/list

## Project recovery metadata

Every new provider Task is tagged with canonical JSON metadata containing only non-secret reconciliation identifiers:

- `logical_job_id`
- `project_id`
- `asset_id`
- `source_sha256`
- sorted `requested_models`
- `request_fingerprint`

The raw idempotency key is never sent to AudioShake metadata and is never persisted in the project registry. Only a SHA-256 key hash is persisted locally.

## Recovery algorithm

When Task creation throws after the request may have been accepted:

1. Persist `state=start_ambiguous` and `billing_safety_state=unknown_do_not_retry`.
2. Do not issue another provider Task create.
3. Use provider capability `find_tasks_by_metadata`.
4. For AudioShake, scan `GET /tasks` pages at `take=100` and require exact canonical metadata equality.
5. If exactly one Task ID matches, attach that ID to the existing logical job and continue observation.
6. If zero Tasks match, remain `start_reconciliation_unresolved`; do not infer that the original Task was rejected and do not repost.
7. If more than one distinct Task matches, record `duplicate_provider_tasks_detected` and `billing_safety_state=billing_incident`; fail closed.
8. If the provider cannot reconcile, require manual/HQ review rather than blind retry.
9. If the configured bounded scan ends on a full page, fail closed with `AUDIOSHAKE_TASK_SCAN_LIMIT_REACHED`; a partial scan must never be treated as authoritative absence.

## Why zero matches are still non-retryable

The current public list API proves that Task enumeration and metadata read-back are available, but it does not establish a consistency SLA strong enough for this project to treat an immediate zero-result scan as proof that a timed-out create was never accepted. The safe default is therefore to re-check later or use a stronger provider-specific contractual/idempotency guarantee, not to create a second Task.

## Billing-safety states

- `pre_provider_create`
- `provider_create_in_flight`
- `single_provider_task_confirmed`
- `unknown_do_not_retry`
- `manual_review_required`
- `billing_incident`

These are project safety semantics only. Actual provider billing behavior still requires live production evidence.

## PARITY impact

None. This contract closes a lane-local duplicate-job/billing risk but does not prove real separation quality, actual provider charges, live retry behavior, or current-iPhone Moises parity. `MOI-P003`, `MOI-P004`, `MOI-P005`, and `MOI-P020` remain unpromoted until required live evidence exists.
