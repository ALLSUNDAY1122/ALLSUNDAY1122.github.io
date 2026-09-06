# L1-A07 Validation — Idempotency / duplicate-billing safety

Captured: 2026-08-23 JST
Worker: `Moises-Worker-1`
Branch: `moises/wp1-separation-processing`
Result: `COMPLETE_NON_PARITY`

## Goal

Complete provider-capability-aware recovery for ambiguous separation Task creation without allowing a blind retry to create duplicate provider work or duplicate billing.

## Implementation

### `Separation/Server/production_orchestrator.py`

- registry schema advanced to v2 while accepting v1 records for migration safety;
- request fingerprint now treats target ordering as semantically irrelevant;
- provider metadata binds logical job, project, asset, source SHA-256, requested models and request fingerprint;
- raw idempotency key remains absent from persisted/provider metadata;
- new `reconcile_ambiguous_start()` path never performs a second create;
- unique provider metadata match recovers the original logical job;
- zero matches remain `unknown_do_not_retry` rather than being treated as safe-to-repost;
- multiple matches become `billing_incident` and fail closed;
- missing provider reconciliation capability becomes `manual_review_required`;
- lookup/network failure remains non-retryable for provider create;
- reconciliation attempt count, match count, recovery state and billing-safety state are durable.

### `Separation/Server/audioshake_api.py`

- added documented `GET /tasks` pagination support using `skip` / `take`;
- maximum page size fixed to the documented 100 records;
- added exact canonical metadata lookup across paginated Task history;
- duplicate Task IDs from pagination are de-duplicated;
- malformed list responses fail closed;
- bounded scans that end on a full page raise `AUDIOSHAKE_TASK_SCAN_LIMIT_REACHED` rather than returning false absence;
- create/get response shape validation remains fail closed.

### Provider evidence

Current AudioShake developer documentation was re-read on 2026-08-23 and now explicitly documents `GET /tasks` plus pagination and returned client metadata:

- https://developer.audioshake.ai/api-reference/tasks/create
- https://developer.audioshake.ai/api-reference/tasks/get
- https://developer.audioshake.ai/api-reference/tasks/list

The project deliberately does **not** infer strong consistency from the list endpoint. A zero-result scan is not permission to repost.

## Machine verification

Local reconstruction against the exact implementation written to the branch:

- Python `py_compile` for `production_orchestrator.py`: PASS
- Python `py_compile` for `audioshake_api.py`: PASS
- Python `py_compile` for both updated test modules: PASS
- `test_production_orchestrator.py`: 23 tests, 0 failures
- `test_audioshake_api.py`: 18 tests, 0 failures

Key new negative/recovery cases:

1. same logical key/request returns existing job without second create;
2. same targets in different order remain the same request;
3. same key with different request fails `SEP_IDEMPOTENCY_CONFLICT`;
4. ambiguous start persists non-retryable billing uncertainty;
5. one exact metadata match recovers original provider Task;
6. reconciliation survives orchestrator restart;
7. zero matches never trigger repost;
8. multiple matches are a billing incident;
9. repeated identical Task IDs are de-duplicated;
10. reconciliation network error never triggers create retry;
11. provider without finder requires manual review;
12. recovery metadata contains no raw idempotency key;
13. AudioShake list pagination path/limits are validated;
14. exact metadata search spans multiple pages;
15. bounded full-page scan fails closed instead of reporting false absence.

## Remaining external evidence

This Wave does not prove:

- AudioShake production/commercial authorization;
- provider-side billing semantics for ambiguous requests;
- actual charged credits;
- live Task-list consistency behavior;
- real-audio separation quality;
- current-iPhone Moises differential quality;
- upstream compute cancellation.

Those remain live/external gates.

## PARITY

`parity_state = NON_PARITY_EVIDENCE_ONLY`.

No `PARITY_MATRIX.json` state change is proposed from machine-only evidence. A07 reduces a P020 production-safety gap and future live-cost risk but does not itself satisfy P020/P003/P004/P005.
