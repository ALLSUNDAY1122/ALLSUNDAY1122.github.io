# L1-A06｜Production Separation Backend Orchestrator Validation

Captured: 2026-08-23 JST
State: `NON_PARITY_EVIDENCE_ONLY`

## Goal

Close the server-side orchestration gap between the app-facing separation provider contract and an injected live vendor client without requiring production credentials for implementation verification.

## Implemented

`Separation/Server/production_orchestrator.py` adds:

- provider-neutral orchestration compatible with the existing `AudioShakeClient` method surface;
- app-owned source-root containment;
- streaming SHA-256 source identity and deterministic request fingerprint;
- persisted logical job registry with atomic/fsync-backed replacement;
- raw idempotency keys replaced by SHA-256 before persistence;
- repeated identical logical start returns the persisted job instead of creating another vendor task;
- same idempotency key + different request fails closed;
- upload failure persistence with stable provider error code;
- `starting` persisted before remote task creation;
- ambiguous remote task-create failure becomes non-auto-retryable `start_ambiguous`, preventing blind duplicate POST/billing risk;
- authoritative provider observation with bounded progress validation;
- ready-output target-set completeness validation;
- HTTPS-only output acquisition;
- per-target staging, SHA-256/size binding and full-set atomic promotion;
- staging cleanup after partial copy failure;
- output manifest explicitly marked `NON_PARITY_EVIDENCE_ONLY`;
- restart-safe registry reload.

## Edge / negative / recovery tests

`Separation/Tests/test_production_orchestrator.py` covers 12 scenarios:

1. persisted start + repeated identical start is idempotent;
2. same key / different request fails closed;
3. registry survives orchestrator restart;
4. ambiguous task-create failure is persisted and not blindly retried;
5. upload failure preserves stable retry information;
6. observe updates authoritative provider state;
7. ready outputs are copied atomically and manifested;
8. missing target fails before result commit;
9. mid-copy failure removes staging and leaves result uncommitted;
10. source outside owned root is rejected;
11. corrupt registry fails closed;
12. raw idempotency key is not persisted.

## Machine verification

Local Python 3 verification performed before GitHub persistence:

- `python3 -m py_compile production_orchestrator.py test_production_orchestrator.py` => PASS
- `python3 -m unittest -v test_production_orchestrator.py` => **12/12 PASS**

## What this does not prove

- no production credential was used;
- no user or rights-cleared real audio was sent to a vendor;
- no live latency/cost/retention/deletion/cancellation behavior was measured;
- no current-iPhone Moises A/B was performed;
- no P003/P004/P005/P020 promotion is justified.

## Remaining A06/A07 boundary

This Wave intentionally refuses automatic retry after an ambiguous remote create. A later idempotency/billing Wave must add authoritative recovery for providers that expose a stable lookup/idempotency mechanism, rather than weakening this fail-closed behavior.

## Result

A06 lane-local implementation is complete enough to accept the existing AudioShake client surface and persist/recover project orchestration without redesign. Live credential/terms/real-audio gates remain external. PARITY claim: `NONE`.
