# L1-E07｜Provider Fallback Substitution Conformance Readiness

Status: `READY_PENDING_EXTERNAL_INPUT`  
Live substitution conformance: `PENDING_EXTERNAL_INPUT`  
PARITY claim: `NONE`

## Purpose

E06 can reject an initial separation route. E07 prevents the fallback path from weakening Lane 1 safety contracts merely to make another provider/runtime fit.

Fallback order remains:

1. `LICENSED_LOCAL_INFERENCE_SDK`
2. `ALTERNATE_WRITTEN_COMMERCIAL_PROVIDER`
3. `PROJECT_OWNED_MODEL_IF_RIGHTS_CLEARED_TRAINING_DATA_AVAILABLE`

Skipping an earlier fallback requires physical evidence that it is `UNAVAILABLE` or `REJECTED`.

## Critical E05/E06 vocabulary gap

E05/E06 v1 was built around hosted-provider evidence and names the rate-limit/capacity provenance field `provider_account_*`.

That vocabulary is valid for a hosted provider, but it is not truthful for a local SDK or project-owned model. E07 therefore introduces a generic authority boundary:

- hosted provider: `HOSTED_PROVIDER_ACCOUNT`
- licensed local SDK: `LOCAL_RUNTIME`
- project-owned model: `PROJECT_OWNED_RUNTIME`

A local/project-owned fallback containing `provider_account_*` identity fields is rejected. No fake provider account may be invented to satisfy an old schema.

For non-hosted fallback kinds E07 reports `CONFORMANT_REQUIRES_GENERIC_LIVE_AUTHORITY_GATE`. This is intentional: engineering substitution can be conformant while the old hosted-only E05/E06 live evidence vocabulary remains insufficient. A later generic live-authority gate must preserve the same actual recovery/capacity checks under truthful runtime provenance.

## Provider-neutral adapter surface

A candidate adapter source file is physically SHA-256 bound and AST-checked for the provider-neutral A06 surface:

- `upload_asset`
- `create_separation_task`
- `get_task_state`
- `find_tasks_by_metadata`

Optional cancel/delete methods are recorded but are not fabricated.

The fallback must preserve the existing project publication boundary; Shared/App changes are forbidden in this Worker wave.

## Non-waivable A06-A20 invariants

E07 requires exactly fifteen invariant records, each `PASS`, `waived=false`, and bound to a physical owned-scope evidence SHA:

- A06 provider-neutral orchestration
- A07 idempotency / duplicate billing
- A08 cancellation truth
- A09 retention / deletion / privacy
- A10 cost / quota / rate guard
- A11 reference profile registry
- A12 advanced capability mapping
- A13 artifact integrity
- A14 atomic multi-stem publication
- A15 long-track / storage pressure
- A16 durable relaunch recovery
- A17 fault normalization
- A18 privacy-safe observability
- A19 Golden input binding
- A20 differential reproducibility

Missing, duplicated, failed, waived, or mutated invariant evidence fails closed.

## Route-specific requirements

### Licensed local SDK

Requires commercial consumer-app use and output export rights, local runtime/model artifact physical SHA, `LOCAL_RUNTIME` capacity provenance, and no fake provider-account identity.

### Alternate written-commercial provider

Requires fresh commercial basis, runtime/model artifact/capability evidence, `HOSTED_PROVIDER_ACCOUNT` authority, and evidence showing the higher-priority local SDK fallback was unavailable or rejected. This route can remain compatible with legacy E05/E06 v1 hosted-account vocabulary.

### Project-owned model

Requires commercial/output-use basis, project-owned model artifact SHA, `PROJECT_OWNED_RUNTIME` capacity provenance, rights-cleared training-data evidence, and evidence that both earlier fallback classes were unavailable or rejected.

## Privacy

Public E07 evidence contains hashes and stable identities only. It emits no credential values, provider account IDs, private paths, private contract/license text, training data, or raw audio.

## Local verification

Final local execution against E07 semantics:

- `test_provider_fallback_conformance.py`: **30/30 PASS**
- implementation/test `py_compile`: **PASS**

Coverage includes all three fallback classes, authority-kind mismatch, fake provider-account rejection, adapter SHA/class/method faults, path/SHA safety, all A06-A20 invariant failure modes, fallback-order proof, commercial/training rights, deterministic identity, mutation-sensitive lock, and public privacy.

Tests use synthetic temporary files and adapters only. They do not prove any provider/model quality, licensing approval, or PARITY.

## Remaining external/live work

E07 live completion still requires an actual rejected E06 route plus a real fallback candidate, its commercial/license/runtime evidence, and fresh real provider/runtime + real audio + current-iPhone + recovery evidence.

For a non-hosted fallback, HQ must use a generic runtime-authority version of the live capacity/recovery gate rather than relabeling a local runtime as a provider account.

Missing external evidence does not change Worker 1 to `BLOCKED_HUMAN`.

## PARITY

`parity_claim = NONE`.

E07 readiness does not change P003/P004/P005/P020/P021/P024. Final product/device PARITY remains HQ-owned.
