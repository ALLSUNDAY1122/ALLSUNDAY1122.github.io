# L1-E08｜Generic Runtime-Authority Live Gate Readiness

Status: `READY_PENDING_EXTERNAL_INPUT`  
Live runtime-authority gate: `PENDING_EXTERNAL_INPUT`  
PARITY claim: `NONE`

## Purpose

L1-E07 proved that a rejected hosted separation route can be replaced without weakening A06-A20 engineering invariants, but it also exposed a correctness gap: E05/E06 v1 names live provenance around a `provider_account`, which is truthful for hosted providers but false for a licensed local SDK or project-owned runtime.

L1-E08 closes that live-evidence vocabulary gap. It provides one authority-neutral recovery/capacity gate for:

- `HOSTED_PROVIDER_ACCOUNT`
- `LOCAL_RUNTIME`
- `PROJECT_OWNED_RUNTIME`

No local or project-owned runtime is relabeled as a hosted provider account.

## E07 binding

Every E08 run binds the exact sanitized E07 evidence by physical SHA plus:

- `e07_substitution_lock_sha256`
- exact fallback `route_id` / `route_kind`
- exact authority kind
- exact authority provenance SHA
- exact runtime/model artifact SHA
- E07 proof that Shared/App contract was not changed
- E07 proof that provider-neutral publication contract was preserved

Changing the runtime artifact, authority provenance, E07 evidence bytes, route kind, or E07 lock changes/fails the E08 evidence chain.

## Generic live scenario vocabulary

The hosted-only E05 terms are generalized without relaxing their safety meaning.

Mandatory scenarios:

1. `INPUT_INTERRUPTION`
2. `CANCEL_PRE_START`
3. `CANCEL_EXECUTING`
4. `CANCEL_FINALIZING`
5. `AMBIGUOUS_START_RETRY`
6. `RELAUNCH`
7. `OUTPUT_AVAILABILITY_LOSS`
8. `CAPACITY_LIMIT`
9. `LONG_TRACK`
10. `STORAGE_PRESSURE`

Key normalizations:

- provider task create -> `work_start_request_count`
- provider task identity -> `distinct_execution_count`
- provider cancel request -> `upstream_cancel_request_count`
- provider billable task -> `billable_execution_count`
- rate limit -> generic `CAPACITY_LIMIT`
- expiring provider URL -> generic `OUTPUT_AVAILABILITY_LOSS`

For hosted routes these values can still be derived from provider/account evidence. For local/project-owned routes they come from actual runtime/scheduler/process evidence instead of fabricated account records.

## Non-negotiable safety semantics

E08 fails closed when any scenario shows:

- project corruption or partial result publication
- more than one distinct execution for the same logical identity
- more than one billable execution
- automatic start repost after an ambiguous start
- ambiguous start without reconciliation
- logical/idempotency identity loss
- output publication after logical cancellation
- duplicate upstream cancel request
- upstream cancellation claimed without authoritative confirmation
- cancel-before-start that nevertheless starts runtime work
- runtime artifact or authority provenance mismatch
- missing relaunch observation
- unobserved capacity-limit behavior
- unbounded long-track transfer
- missing storage preflight
- unsafe output-availability recovery
- missing stable interruption code

`failed_closed` and `recoverable` remain degraded operational outcomes, not successful recovery. Their non-cancel fraction is compared against the explicit engineering policy.

## Runtime authority provenance

Each private scenario result references two physical evidence files outside the repository:

- fault-injection provenance
- runtime-authority provenance

The authority provenance SHA must equal the same authority provenance already bound by E07.

For `LOCAL_RUNTIME` and `PROJECT_OWNED_RUNTIME`, any `provider_account_*` field is explicitly rejected. This prevents an old hosted-only schema from being satisfied by invented identities.

## Generic capacity snapshot

E08 replaces hosted-only quota/credit/rate-limit naming with three normalized headroom states:

- `execution_capacity_status`
- `cost_headroom_status`
- `throughput_headroom_status`

Each value is one of `ADEQUATE`, `INSUFFICIENT`, or `UNKNOWN`.

The raw measurement file remains private and is physically SHA-bound. Public evidence contains only status values and hashes.

Gate result:

- all safety checks pass + all three capacity states `ADEQUATE` -> `READY_FOR_HQ_E08_LIVE_REVIEW`
- any capacity state `UNKNOWN` -> `PENDING_EXTERNAL_EVIDENCE`
- any capacity state `INSUFFICIENT` -> `LIVE_AUTHORITY_REJECTED`
- safety/degradation policy failure -> `LIVE_AUTHORITY_REJECTED`

This distinction is important: safe fail-closed behavior does not make a runtime operationally acceptable.

## Privacy

Public E08 output never emits:

- credential values
- authority/account IDs
- provider account IDs
- private filesystem paths
- raw capacity measurements
- raw billing records
- raw audio

Private scenario/result indexes, fault evidence, authority evidence and capacity measurements stay outside the public repository.

## Local control verification

Final local execution against the checked-in E08 semantics:

- `test_runtime_authority_live_gate.py`: **9/9 unittest methods PASS**
- targeted behavioral checks: **33/33 PASS**
- implementation `py_compile`: **PASS**
- test file `py_compile`: **PASS**

Coverage includes all three authority classes, UNKNOWN/INSUFFICIENT capacity outcomes, E07 binding, fake-provider-account rejection, runtime artifact mutation, duplicate execution/billing, ambiguous-start reconciliation, cancellation truthfulness, relaunch, capacity limit, output availability, long-track streaming, storage preflight, corruption/partial publication, identity continuity, capacity privacy, scenario completeness and degradation policy.

The tests use synthetic temporary files and do not prove actual runtime quality, licensing, capacity, cost, current-iPhone behavior, or PARITY.

## Required live inputs

E08 cannot become live-complete until an actual fallback candidate exists and the following are captured against that exact runtime:

- accepted E07 conformance evidence
- real runtime/model artifact and authority provenance
- real fault-injection evidence for all 10 scenarios
- actual execution/billing/cancel/relaunch/output-integrity observations
- actual capacity/cost/throughput headroom measurement
- real rights-cleared audio and real differential evidence from the surrounding E02/E03/E04 chain

For a hosted provider, legacy E05/E06 may continue to provide equivalent hosted-account evidence. For local/project-owned fallbacks, E08 is the truthful live-authority path.

## Next integration requirement

E06 provider-route selection still directly consumes hosted-style E05/E06 evidence. The next autonomous lane task should adapt route selection to consume either:

- legacy hosted E05/E06 evidence, or
- E07 + E08 generic authority evidence

without weakening quality, cost, latency, privacy, cancellation or reliability hard gates.

## PARITY

`parity_claim = NONE`.

E08 readiness does not change P003/P004/P005/P020/P021/P024. Real provider/runtime, real audio, current-iPhone blind comparison, physical-device evidence and HQ Late Integration remain mandatory before any PARITY promotion.
