# L1-E05 Readiness — Live Processing Recovery / Provider Semantics

Captured: 2026-08-24 JST  
Worker: `Moises-Worker-1`  
Branch: `moises/wp1-separation-processing`

Engineering readiness: `READY_PENDING_EXTERNAL_INPUT`  
Live gate: `PENDING_EXTERNAL_INPUT`  
PARITY claim: `NONE`

## Purpose

E05 is the live failure/recovery gate for Lane 1. It does not reimplement A07/A08/A09/A14/A15/A16/A17. It binds their invariants to actual production-provider fault evidence so HQ can determine whether the real route behaves safely.

Required live scenarios are:

1. network interruption;
2. cancel during upload;
3. cancel while separating;
4. cancel while finalizing;
5. retry after ambiguous provider-create outcome;
6. server/process relaunch;
7. provider output expiry;
8. provider rate limit;
9. representative long track;
10. storage pressure.

No production credential or live provider/account-side fault evidence was supplied during this Worker wave. Live E05 is therefore intentionally not marked complete.

## Source gates

`Separation/Evaluation/live_processing_recovery.py` refuses a campaign unless:

- E01 is `READY_FOR_LIVE_PROVIDER_GATE`;
- E01 remains `NON_PARITY_EVIDENCE_ONLY / parity_claim = NONE`;
- E01 credential preflight says the server-side secret was present and not persisted;
- E03 is `READY_FOR_HQ_E03_LIVE_REVIEW`;
- every E03 acceptance check is true;
- the E01 approval identity and E03 live benchmark lock are valid SHA-256 identities.

The final E05 lock also binds canonical hashes of the supplied plan, E01 evidence and E03 evidence.

## External provenance requirement

A result JSON saying “network was interrupted” or “429 happened” is not live proof by itself.

Every E05 scenario must bind two private external artifacts:

- fault-injection / fault-observation provenance;
- provider/account-side provenance showing the provider-side task/billing/result consequence.

The validator hashes the physical files and rejects SHA mismatch, missing files, path traversal, symlinks, or a private evidence root placed inside the repository.

Public E05 evidence contains only the provenance SHA-256 values. It does not emit the private path, provider task/asset ID, raw billing/account record, credential, or audio.

## Duplicate processing and billing safety

Each scenario records only hashed logical identities plus counts:

- `logical_job_identity_sha256`;
- `idempotency_key_sha256`;
- whether the logical identity survived recovery;
- provider create request count;
- distinct provider task count;
- billable provider task count;
- automatic create repost count.

E05 rejects:

- more than one distinct provider task for one tested logical job;
- more than one billable provider task;
- any automatic provider-create repost after an ambiguous outcome;
- changed logical identity across a recovery scenario.

For `AMBIGUOUS_CREATE_RETRY`, metadata/provider reconciliation must be observed and provider create request count must not exceed one. This preserves A07/A17's rule that generic retryability never authorizes a blind second create.

## Cancellation truthfulness

Cancel scenarios preserve A08 semantics.

### Cancel during upload

- logical cancellation must become authoritative;
- no provider task may have been created;
- no result may be published.

### Cancel during separating/finalizing

- logical cancellation remains authoritative even when upstream compute continues;
- provider cancel request count must be at most one;
- output publication after cancel is forbidden;
- upstream state may truthfully remain `requested`, `unsupported`, `unknown_after_error`, or `not_addressable`;
- the product may claim upstream cancellation only when provider evidence is `confirmed`.

A conservative UI that does not claim upstream termination even after confirmation is not treated as false evidence. An affirmative upstream-cancel claim without confirmation is rejected.

## Relaunch and logical identity

The relaunch scenario requires an actual relaunch observation plus preservation of the logical job and idempotency identities.

The live provider/account evidence must show that relaunch did not create a second provider task or a second billable task. This connects A16 durable recovery semantics to provider reality rather than only to a test double.

## Output expiry

Safe E05 output-expiry outcomes are explicitly limited to:

- `verified_local_copy`;
- `refreshed_provider_url`;
- `failed_closed`.

A blind new separation job is not an allowed expiry recovery.

If a path fails closed and there was a previously committed result, the before/after committed-result SHA must remain identical. Therefore “safe failure” and “successful recovery” stay distinguishable without allowing project corruption.

## Rate limit

The RATE_LIMIT scenario must contain evidence that a real provider rate-limit event occurred. The campaign still forbids automatic ambiguous create repost and duplicate provider tasks/billing.

Retry-After details remain provider-specific evidence for HQ. E05 does not invent a header or provider policy that was not observed.

## Long track

The LONG_TRACK scenario requires observed bounded streaming. It is intended to connect A15's streaming/storage design to a real provider route.

This is server-side processing evidence only. Physical-iPhone RSS, thermal and battery evidence remains an HQ/device responsibility and P021 must not be promoted from E05 alone.

## Storage pressure

The STORAGE_PRESSURE scenario requires actual storage-preflight observation and forbids partial publication or project corruption.

If recovery fails closed, a previously committed result must remain immutable.

## Public evidence

Successful validation produces `LIVE_PROCESSING_RECOVERY` evidence containing:

- plan/E01/E03 hashes;
- E01 approval identity;
- E03 live benchmark lock;
- stable error codes;
- safe counts rather than provider IDs;
- hashed logical/idempotency identities;
- truthful cancellation state;
- recovery observations;
- external provenance hashes;
- deterministic `e05_live_recovery_lock_sha256`.

It never emits:

- credential values;
- provider task IDs;
- provider asset IDs;
- private evidence paths;
- raw provider/account evidence;
- raw audio.

## Machine verification

Local synthetic/control regression against the final E05 semantics:

- **26 / 26 test methods PASS**;
- Python `py_compile`: **PASS**.

Coverage includes E01/E03 gate binding, all ten required scenario kinds, duplicate billing/task rejection, create ambiguity, cancel truthfulness and idempotency, relaunch identity, output expiry, real-event flags, long-track streaming, storage preflight, evidence SHA validation, private-root isolation, previous-result immutability and public-evidence redaction.

These tests do not contain real provider failures, production billing records or real audio. They are engineering evidence only.

Machine-readable matrix:

- `Processing/Tests/L1-E05_LIVE_RECOVERY_MATRIX.json`

Implementation/test:

- `Separation/Evaluation/live_processing_recovery.py`
- `Separation/Tests/test_live_processing_recovery.py`

Schemas/templates:

- `Separation/Evaluation/schemas/live-processing-recovery-plan.schema.json`
- `Separation/Evaluation/schemas/live-processing-recovery-result.private.schema.json`
- `Separation/Evaluation/schemas/live-processing-recovery-evidence.schema.json`
- `Separation/Evaluation/examples/live-processing-recovery-plan.template.json`
- `Separation/Evaluation/examples/live-processing-recovery-result.private.template.json`
- `Separation/Evaluation/examples/live-processing-recovery-results-index.private.template.json`

## Remaining live inputs

Live E05 still requires:

1. E01 live-approved production route and credential;
2. E03 accepted live project benchmark evidence;
3. controlled real network interruption evidence;
4. actual provider cancellation observations at upload/separating/finalizing boundaries;
5. ambiguous-create reconciliation evidence from the real provider route;
6. process/server relaunch evidence;
7. actual expired-output behavior;
8. actual provider 429/rate-limit evidence;
9. real long-track processing evidence;
10. actual storage-pressure evidence;
11. provider/account-side task and billing provenance for each scenario.

Missing external evidence does not convert this Worker to `BLOCKED_HUMAN`. Lane Engineering remains checkpoint-ready.

## Next gate

The next autonomous preparation target is `L1-E06 | Provider Route Decision Loop`.

E06 must use E03/E04/E05 live evidence to reject a provider route when quality, cost, privacy, cancellation or latency remains materially inferior, rather than forcing the initially selected provider through to release.

## PARITY

`parity_claim = NONE`.

E05 readiness does not change `MOI-P003`, `MOI-P004`, `MOI-P005`, `MOI-P020`, `MOI-P021` or `MOI-P024`. Final PARITY remains HQ-owned and requires live provider, real audio, current-iPhone reference, human review, real-device and integrated evidence.
