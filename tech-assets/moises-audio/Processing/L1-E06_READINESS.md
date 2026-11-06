# L1-E06｜Provider Route Decision Loop Readiness

Status: `READY_PENDING_EXTERNAL_INPUT`  
Live provider decision: `PENDING_EXTERNAL_INPUT`  
PARITY claim: `NONE`

## Purpose

L1-E06 prevents the project from becoming locked to the first hosted separation provider. It consumes the exact sanitized E01/E03/E04/E05 evidence chain plus a quota/credit/rate-limit capacity attestation and can reject a route when commercial/privacy, capability, practical quality, cancellation, reliability, latency, cost, quota, credit, or rate-limit evidence is materially inadequate.

This Wave is decision infrastructure only. The checked-in tests are synthetic controls and do **not** establish that AudioShake, another hosted provider, a local SDK, or a project-owned model is superior.

## Inputs and identity binding

Each candidate route binds:

- E01 commercial route evidence physical SHA and `approval_manifest_identity_sha256`
- E03 live benchmark physical SHA and `e03_live_benchmark_lock_sha256`
- E04 current-iPhone blind differential physical SHA and `e04_differential_lock_sha256`
- E05 live recovery physical SHA and `e05_live_recovery_lock_sha256`
- E06 capacity snapshot physical SHA
- capacity `provider_account_provenance_sha256`, which must equal the physically verified provider-account provenance SHA already bound by the E05 `RATE_LIMIT` scenario
- normalized E06 engineering policy

Replacing any bound evidence changes `decision_identity_sha256` and `decision_lock_sha256`. A stale E04/E05 chain or mismatched E01/E03 identity fails closed.

## Decision semantics

Possible route outcomes:

- `ACCEPT_PRIMARY`
- `ACCEPT_WITH_LIMITS`
- `REJECT_QUALITY`
- `REJECT_COST`
- `REJECT_PRIVACY`
- `REJECT_CANCELLATION`
- `REJECT_LATENCY`
- `REJECT_RELIABILITY`
- `REJECT_CAPABILITY`
- `PENDING_EXTERNAL_EVIDENCE`

A provider can be rejected even when project-side safety is intact. In particular, `recoverable` and `failed_closed` non-cancel scenarios are treated as degraded operation, not successful recovery.

A route is not automatically selected while another declared candidate still lacks required live evidence. The overall decision remains `PENDING_EXTERNAL_EVIDENCE` and otherwise-eligible routes stay `ACCEPT_WITH_LIMITS`.

## Hard-gate dimensions

### Commercial / privacy

- written E01 approval identity must be READY
- provider training on user content must remain prohibited
- commercial input/output/export flags must pass
- service region and data region must be explicitly allowed by E06 engineering policy
- uploaded-asset retention must remain within policy
- delete API is required when policy says so

### Capability / quality

- required live E03 mode classes must be present
- exact model/version/quality profile must be within the E01-approved capability snapshot
- E03 G1 objective floor must pass with actual objective runs
- E04 exact-input current-iPhone blind review must be complete
- material practical inferiority causes `REJECT_QUALITY`

### Recovery / cancellation / long-track

- E05 must bind all ten required live scenarios
- cancellation claims must be truthful
- no output may be published after logical cancellation
- duplicate provider cancel/create/billable behavior remains bounded by E05
- safe fail-closed is distinguished from successful recovery
- E05 rate-limit, bounded long-track streaming, and storage-preflight observations are surfaced into E06 metrics

### Cost / latency / quota / credit

- actual E03 live mean provider latency is compared with policy
- actual E03 live cost is compared only in the declared comparable currency
- quota, credit, and rate-limit capacity require a sanitized E06 capacity snapshot
- the capacity snapshot cannot invent a new provenance identity: it must bind the provider-account provenance physically verified by the E05 `RATE_LIMIT` scenario
- `UNKNOWN` capacity remains pending; insufficient quota/credit rejects capability and insufficient rate-limit capacity rejects reliability

## Ranking

Only routes that pass every hard gate are ranked. Ranking weights are engineering policy, **not Moises Reference facts**. Quality, latency, reliability, and cost are normalized only to break ties among already-acceptable routes.

If two acceptable routes do not exceed the configured minimum score margin, E06 does not mechanically declare a primary route; both remain `ACCEPT_WITH_LIMITS`.

## Fallback order

If the active hosted route is rejected:

1. licensed local inference SDK capable of equivalent practical quality
2. alternate provider with written commercial/privacy approval using the same Lane 1 contracts
3. project-owned model only when rights-cleared training data is available

Changing provider must not weaken A07-A20 project-side invariants: idempotency, duplicate-billing safety, cancellation truthfulness, atomic publication, artifact integrity, privacy, cost/quota guard, long-track streaming, durable recovery, fault taxonomy, observability, Golden lock, and differential reproducibility.

## Local control verification

- `test_provider_route_decision.py`: **21/21 PASS**
- `provider_route_decision.py`: `py_compile PASS`
- test file: `py_compile PASS`
- matrix: `Processing/Tests/L1-E06_PROVIDER_ROUTE_DECISION_MATRIX.json`

The local suite covers missing evidence, human-review pending, missing/insufficient quota and credit, provenance mismatch, objective/current-iPhone quality rejection, cost, latency, privacy/region, capability, fail-closed degradation, cancellation, E05 scenario completeness, source-lock mismatch, evidence replacement, multi-route ranking, pending-candidate suppression, and public privacy fields.

## Required live inputs before route selection is real

- E01 production/evaluation credential and written commercial/privacy/confidentiality/output-use/pricing approval
- authenticated provider capability snapshot with exact model/version/profile
- rights-cleared E02/G1/G2 corpus and approved locks
- actual E03 live provider runs with cost/latency/failure/artifact/objective evidence
- current-iPhone exact-G2 Moises captures and independent blind human review for E04
- actual E05 fault campaign with provider/account-side provenance
- capacity snapshot anchored to the physically verified E05 rate-limit provider-account provenance
- actual quota/credit/rate-limit headroom status without exposing account identifiers or raw account/billing records
- integrated physical-iPhone background/relaunch/RSS/thermal/battery/storage evidence at HQ Late Integration

Until those inputs exist, E06 must not claim a real provider winner.

## Privacy

Public E06 evidence does not emit credential values, provider task IDs, provider account IDs, private contract text, raw billing/quota/credit records, private paths, or raw audio. Private evidence indexes and raw provider/account records remain outside the public repository.

## Final gate

Engineering readiness is complete for L1-E06, but live selection remains external-input pending. `parity_claim = NONE` remains mandatory. HQ owns Late Integration and all final PARITY_MATRIX changes.
