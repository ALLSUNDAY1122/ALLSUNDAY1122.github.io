# L1-A10 Validation — Cost / Credit / Quota / Rate-Limit Guard

Captured: 2026-08-23 JST  
Worker: `Moises-Worker-1`  
Branch: `moises/wp1-separation-processing`  
Result: `COMPLETE_NON_PARITY`

## Goal

Prevent unpredictable separation spend, quota/credit exhaustion retry loops, and duplicate provider-create billing while preserving A07's fail-closed idempotency semantics.

## Implementation

### `Separation/Server/cost_quota_guard.py`

- `PricingPolicy` injects currency, per-target-minute price, billing increment/minimum, per-job ceiling, daily budget, monthly budget and budget timezone.
- Estimates use server-verified duration × target count and Decimal-backed persisted monetary values.
- `AtomicLedger` persists reservations and actual reconciliation across process restart.
- Ledger mutation is file-locked and atomically replaced; corrupt/schema-invalid ledgers fail closed.
- Per-job / daily / monthly ceilings are checked before a provider task create can be authorized.
- A repeated logical job with the same request fingerprint reuses its reservation; a changed fingerprint fails with `SEP_COST_IDEMPOTENCY_CONFLICT`.
- `authorize_provider_create()` is one-shot. Once a provider POST is in-flight/ambiguous/confirmed, a second create authorization is denied.
- An ambiguous provider-create response keeps the estimated spend reserved. It cannot be released merely because the client did not receive a task ID.
- A provably pre-create failure may release the reservation, and the same logical job may later reactivate that reservation safely.
- Provider task IDs are persisted only as SHA-256 hashes.
- Actual provider cost can replace the estimate without losing the original estimate; an actual per-job ceiling overrun is retained as an incident.
- 429, quota exhausted, credit exhausted and 402/billing rejected are normalized into stable semantics. None authorizes an automatic provider-create retry.
- Cost evidence excludes raw logical job ID, provider task ID, media filename/path, signed URL, API key and user content.

### `Separation/Server/budgeted_production_orchestrator.py`

- Composes the existing A06/A07 `ProductionSeparationOrchestrator` rather than changing Shared/App contracts.
- A provider proxy interposes the durable budget authorization immediately before `create_separation_task()`.
- Provider-create timeout/429/other ambiguous failure is persisted as `ambiguous` before A07 reconciliation.
- Unique A07 recovery can confirm the already-existing provider task without issuing a second POST.
- Multiple recovered provider tasks are promoted to a billing incident.
- Duration is not accepted as a caller-supplied request field; a required server-side `duration_resolver` derives it from the contained source artifact. Resolver failure occurs before upload/provider-create.
- Upload/local failures that are still provably `not_attempted` at provider-create release their reservation; later-stage failures never do.

## Machine verification

Exact A10 guard code was reconstructed locally and executed:

- `python -m unittest -v test_cost_quota_guard.py`: **28/28 PASS**
- `python -m py_compile cost_quota_guard.py budgeted_production_orchestrator.py`: **PASS**

The provider interposition adapter was additionally exercised with an A06/A07-compatible local contract stub mirroring the current orchestrator start metadata/create seam:

- `test_budgeted_production_orchestrator.py`: **5/5 PASS**

Key negative/recovery cases:

1. per-job ceiling rejects before ledger/provider write;
2. daily and monthly budgets reject projected overspend;
3. same logical job does not double-reserve;
4. same job with changed fingerprint fails closed;
5. provider-create authorization is exactly-once;
6. 429 during create becomes ambiguous and retains budget;
7. ambiguous create cannot be released or blindly reauthorized;
8. recovered provider task confirms by hashed ID;
9. conflicting provider task IDs become a billing incident;
10. safe pre-create failure releases and can later reactivate;
11. actual cost survives relaunch and replaces reservation accounting;
12. actual daily/monthly budget overruns are retained as incidents;
13. corrupt ledger fails closed;
14. server-side duration resolver failure occurs before provider calls;
15. outward evidence contains no raw logical/provider ID.

Scenario ledger: `Processing/Tests/L1-A10_COST_MATRIX.json`.

## Live configuration contract

No live AudioShake price is hard-coded. Shipping configuration must provide approved current pricing/budget values through `PricingPolicy`, plus a trusted server-side duration resolver. The included file ledger is appropriate only where that path is genuinely durable and single-writer/coherently locked; horizontally scaled deployment must inject or replace it with an equivalently transactional shared ledger before relying on global daily/monthly limits. Provider-specific quota/credit payloads should be normalized to the stable codes already supported by this module once production credentials/terms are approved.

This is deliberate: inventing or freezing an unverified vendor price would make the budget gate less safe, not more complete.

## Remaining external/live evidence

A10 does not prove:

- current production-provider pricing or billing units;
- actual account quota/credit error payloads;
- provider invoice/usage API reconciliation;
- commercial budget approval;
- live duplicate-billing behavior under real network ambiguity;
- any P003/P004/P005/P020/P021/P024 PARITY claim.

When production pricing/credential access is available, HQ/Worker can inject the approved policy and run the same gate without changing the accounting/idempotency design.

## PARITY

`parity_state = NON_PARITY_EVIDENCE_ONLY`.

L1-A10 is Lane Engineering Complete for the cost/quota guard itself, but live provider billing evidence remains mandatory before any PARITY promotion.
