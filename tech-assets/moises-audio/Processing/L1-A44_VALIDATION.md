# L1-A44 Validation — AudioShake Task Target Contract Preflight

State: `COMPLETED_NON_PARITY`

## Why this wave

The advanced AudioShake path already discovered account model access before upload, but the selected canonical roles were not available to `upload_asset`. A request could therefore discover the account successfully, upload user media, and only then discover during Task creation that one requested role was disabled or that the Task request shape exceeded the provider contract.

Current AudioShake developer documentation observed 2026-08-27 states that `POST /tasks` accepts one source and **1–20 targets**. `GET /models` reports the models available to the account, including `enabled` versus `request_access`; its optional `limits` field is model-specific and may be absent. Task-wide target count is therefore treated as an explicit provider-boundary contract rather than inferred from optional model records.

## Implementation

### `Separation/Server/audioshake_task_contract.py`

- Adds `AUDIOSHAKE_TASK_MAX_TARGETS = 20`.
- `effective_audioshake_max_targets()` permits a deployment to narrow the provider cap but never widen it.
- `build_contract_bound_audioshake_capabilities()` wraps the provider-neutral capability builder so the canonical AudioShake production route always exposes a concrete target cap.
- Keeps vendor-specific truth outside the generic profile planner.

### `Separation/Server/canonical_advanced_provider.py`

- Adds `preflight_separation(models)`.
- Validates canonical role selection against the 20-target Task contract before media access.
- Performs account model discovery and rejects roles that are not enabled for the credentialed account.
- `create_separation_task()` reuses the same preflight as defense in depth before `POST /tasks`.
- Capability maps are now built through the contract-bound AudioShake builder.

### `Separation/Server/budgeted_production_orchestrator.py`

- Stores the original provider as the request-preflight authority.
- If the provider exposes `preflight_separation`, calls it after deletion/idempotency validation but before source containment/stat/hash, duration analysis, cost reservation, upload, or provider Task creation.
- Providers without that optional hook retain the prior behavior.
- Stable provider preflight error codes are surfaced as `OrchestratorError` without creating a local job, reserving cost, or uploading user content.

## Regression coverage

Formal repository test `Separation/Tests/test_a44_audioshake_task_target_contract.py` contains 10 scenarios covering:

1. provider Task cap = 20;
2. narrower deployment cap retained;
3. wider configured cap clamped to 20;
4. invalid cap fail-closed;
5. capability descriptor exposes 20;
6. exactly 20 roles accepted;
7. 21 roles rejected before discovery/upload/POST;
8. create Task rechecks the contract before POST;
9. account-disabled model fails media-free;
10. cost-guarded production preflight executes before even a deliberately missing source is touched.

`Separation/Tests/test_a44_dependency_binding.py` adds four full-discovery binding checks for runtime/evidence presence, the immutable provider cap, canonical preflight wiring, and preflight ordering before source IO/hash/cost reserve.

## Validation observed in this session

- Exact GitHub checkout: `NOT_OBSERVED`.
- Container `git ls-remote`: failed with `Could not resolve host: github.com`.
- Exact repository-native unittest discovery: `NOT_OBSERVED`.
- Focused interface-compatible harness: `PASS`, 9 assertions. It covered cap default/narrow/widen/invalid semantics, 21-target rejection, and proof that provider preflight precedes modeled source IO.
- Remote source was re-fetched after writes and the contract/preflight/order wiring was present.

The focused harness is not represented as a substitute for the A26 exact checkout audit.

## Product effect

A known-invalid advanced AudioShake request no longer needs to read/hash a potentially multi-gigabyte source, reserve quota, or transfer user media merely to discover a provider request-contract/account-access failure. This improves real P003/P004/P005 execution readiness and privacy/cost behavior at failure boundaries.

The checked-in current canonical role catalog contains fewer than 20 roles, so the immediate practical gain is especially the account-enabled-role media-free preflight. The 20-target contract also prevents future catalog/provider expansion from silently crossing the provider Task boundary.

## Non-claims / remaining gates

- No production AudioShake credentials were available/executed here.
- No rights-cleared real-audio separation was executed.
- No current-iPhone resource/latency or audible-quality evidence was produced.
- No current-Moises differential was executed.
- Moises-equivalent Hi-Fi provider mapping remains unverified/fail-closed.
- Complete current-iPhone Premium/Pro custom-role activation remains unverified.
- `MOI-P003`, `MOI-P004`, and `MOI-P005` remain `MISSING` until HQ live/runtime/current-iPhone/real-audio gates are satisfied.
- `L1-A26` remains open until an exact final-tip checkout reports all required PASS states.
