# L1-E09｜Generic Route Decision Integration Readiness

Status: `READY_PENDING_EXTERNAL_INPUT`  
Live unified route decision: `PENDING_EXTERNAL_INPUT`  
PARITY claim: `NONE`

## Purpose

L1-E09 removes the final route-selection asymmetry discovered in E07/E08. Lane 1 can now evaluate one declared candidate set containing either:

- `LEGACY_E06_HOSTED`: an integrity-checked hosted-provider E06 decision chain, or
- `GENERIC_E07_E08`: a fallback route using E07 substitution conformance plus E08 authority-neutral live recovery/capacity evidence.

The generic path does not receive weaker quality, latency, cost, privacy, cancellation or reliability gates.

## Legacy E06 integrity and re-ranking

E09 verifies the legacy E06 decision identity and decision lock before using any hosted row. The E06 engineering policy must also be semantically equal to the E09 policy. In particular, provider latency is mapped to generic execution latency and `require_delete_api` is mapped to generic deletion control; incompatible thresholds cannot be ranked together.

An important correction is applied when the candidate universe changes: an E06 row that previously said `ACCEPT_PRIMARY` is normalized back to `ACCEPT_WITH_LIMITS` before the E09 union is ranked. Its old primary status was only valid relative to the old E06 candidate set. E09 then performs one fresh ranking over the full hosted + generic set, preventing two simultaneous primaries.

## Generic E07 + E08 chain

For a generic fallback E09 verifies:

- physical E07 evidence SHA and `e07_substitution_lock_sha256`
- route kind and truthful authority kind
- exact runtime/model artifact SHA
- physical E08 evidence SHA and `e08_live_authority_lock_sha256`
- E08 binding back to the exact E07 bytes/lock
- E08 ten-scenario set and derived degraded fraction
- E08 capacity status and gate-state consistency
- Shared/App unchanged and provider-neutral publication contract preserved through E07

The supported authority classes remain:

- `HOSTED_PROVIDER_ACCOUNT`
- `LOCAL_RUNTIME`
- `PROJECT_OWNED_RUNTIME`

No local or project-owned runtime is relabeled as a provider account.

## No quality bypass through a handwritten summary

E07/E08 prove substitution and recovery/capacity semantics, but they do not by themselves prove current quality or operational suitability. E09 therefore requires a private `GENERIC_ROUTE_LIVE_EVALUATION` that is bound to the exact E07/E08 chain and runtime artifact.

That evaluation contains three normalized sections:

1. operational/commercial/privacy/region/retention/deletion controls
2. benchmark mode/G1 objective/failure/retry/latency/cost measurements
3. exact-input current-iPhone differential-listening measurements

E09 does **not** trust those summary values alone. Each section must have a separate private machine-readable measurement record. E09 physically SHA-verifies the record, parses it, verifies route/runtime identity, and requires its `measurement` object to exactly equal the normalized evaluation section. Editing the summary or the underlying record independently fails closed.

Private measurement records and their raw source material remain outside the public repository.

## Common hard gates

Generic candidates are rejected/pended with the same decision dimensions used for hosted routes:

- commercial/privacy/region/retention/deletion -> `REJECT_PRIVACY`
- missing mode or insufficient execution capacity -> `REJECT_CAPABILITY`
- G1 objective failure, non-exact differential input, current-iPhone inferiority -> `REJECT_QUALITY`
- cancellation truth failure -> `REJECT_CANCELLATION`
- excessive failure/retry/degraded recovery or insufficient throughput -> `REJECT_RELIABILITY`
- excessive mean execution latency -> `REJECT_LATENCY`
- excessive/incomparable cost or insufficient cost headroom -> `REJECT_COST`
- unknown required capacity, unfinished human review or missing score -> `PENDING_EXTERNAL_EVIDENCE`

`failed_closed` remains a safe integrity outcome but an operationally degraded outcome. It is not counted as successful recovery.

## Pending-candidate suppression

If any declared candidate remains `PENDING_EXTERNAL_EVIDENCE`, E09 does not automatically name another route primary. A currently eligible route is held at `ACCEPT_WITH_LIMITS` until the declared candidate set is complete or explicitly removed by a higher-level decision. This prevents a temporary evidence gap from silently becoming route lock-in.

## Ranking

Only routes that pass all hard gates are scored. Quality, latency, reliability and cost ranking weights remain explicit engineering policy and are **not Moises Reference facts**. If the top-two score margin is below policy, E09 returns multiple acceptable routes instead of manufacturing a winner.

## Privacy

Public E09 output does not emit credential values, authority/account IDs, private paths, contract text, raw capacity/billing records, raw reviewer IDs or raw audio. It contains stable route identities, sanitized metrics, physical source hashes and evidence locks only.

## Local verification

Final checked-in semantics were exercised by the E09 regression matrix:

- behavioral checks: **32/32 PASS**
- `generic_route_decision.py`: `py_compile PASS`
- `test_generic_route_decision.py`: `py_compile PASS`

Coverage includes local/project-owned generic happy paths, UNKNOWN/INSUFFICIENT capacity mapping, commercial/privacy/deletion/region failures, missing modes, G1/current-iPhone quality failures, latency/cost/reliability thresholds, E07/E08 mutation and state inconsistency, runtime mismatch, measurement semantic mismatch, legacy E06 policy/lock integrity, mixed hosted+generic ranking, pending-candidate primary suppression, decision-lock binding and public privacy.

These tests use synthetic control records only. They do not establish provider/runtime quality or PARITY.

## Required live inputs

E09 remains external-input pending because no actual candidate currently has the complete real evidence chain required for a production route decision:

- E01 written commercial/privacy/credential approval where applicable
- E02 rights-cleared real G1/G2 audio
- actual E03 live separation benchmark evidence
- actual current-iPhone exact-input Moises differential evidence and independent review
- actual E05 or E08 recovery/capacity campaign for the exact route/runtime
- actual operational, benchmark and differential measurement records bound to the selected runtime
- physical-device Late Integration evidence where relevant

No live hosted, local SDK or project-owned runtime is selected by this Wave.

## Next engineering target

The next useful lane-local gap is `L1-E10｜Generic Evaluation Provenance Producer`.

E09 deliberately refuses to trust hand-authored evaluation summaries, but the three private measurement records are still external inputs. E10 should provide an executable producer that derives those records from the actual benchmark/review/operational source artifacts with stable identity, redaction and replay semantics, reducing manual transcription risk without weakening the external/live evidence requirement.

## PARITY

`parity_claim = NONE`.

L1-E09 readiness does not change P003/P004/P005/P020/P021/P024. Real audio, current-iPhone comparison, real runtime/provider behavior, physical-device evidence and HQ Late Integration remain mandatory before any PARITY promotion.
