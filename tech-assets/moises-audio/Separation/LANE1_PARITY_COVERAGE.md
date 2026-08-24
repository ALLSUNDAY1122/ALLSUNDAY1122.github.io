# Lane 1｜PARITY Coverage / Completion Gap Inventory

Captured: 2026-08-24 JST
Planning mode: v4 autonomous worker
Scope: `Separation/**`, `Processing/**`

This inventory is a Worker planning/evidence map only. It does not modify or promote `PARITY_MATRIX.json`.

| PARITY row | Lane 1 responsibility | Current lane evidence | Lane-local remaining work | External/HQ remaining gate |
|---|---|---|---|---|
| MOI-P003 core separation | vocals/drums/bass real separation | production orchestration; idempotency/billing; output assurance; rights/evaluation/differential stack | no material non-external core gap known | commercial route, real G1/G2, current-iPhone A/B, HQ PARITY |
| MOI-P004 other/instrument | other + representative instrument modes | reference profile registry; canonical capability boundary; output assurance | exact live profile mapping remains evidence-driven | live runtime modes + current-iPhone comparison |
| MOI-P005 advanced separation | custom / Hi-Fi / professional modes | advanced capability registry; canonical provider boundary; fail-closed unsupported mapping | exact Hi-Fi/current-iPhone capability mapping | current-iPhone entitlement/mode observation, live quality A/B |
| MOI-P020 processing | progress/cancel/retry/resume | durable registry; truthful cancellation; provider fault matrix; reconnect/relaunch; atomic publication | no material non-external lifecycle gap known | integrated iPhone interruption/background/relaunch + real runtime semantics |
| MOI-P021 performance | Lane 1 upload/separation/download contribution | bounded streaming; storage preflight; long-track instrumentation | server/runtime evidence producer is ready | physical-iPhone memory/thermal/battery and integrated device gate |
| MOI-P024 privacy | server upload/output/retention/deletion contribution | retention/delete enforcement; redaction; privacy-safe telemetry/evidence | written/live route terms still required | written provider/runtime terms + integrated deletion/account behavior |
| MOI-P025 AI stem generation | generated-stem processing/runtime, entitlement/credit and publication safety | **A21** capability + entitlement snapshots; durable credit reservation; idempotent start; ambiguous-start reconciliation; truthful cancel/refund; project-controlled output publication; privacy-safe evidence | concrete generation runtime/provider adapter and generated-stem live evaluation/differential harness | exact current-iPhone role/mode/credit/entitlement UX; real generated quality/latency; current-iPhone A/B; HQ PARITY |

## Existing implementation groups

### Separation provider/runtime
- `Separation/Sources/ServerSeparationProvider.swift`
- `Separation/Server/audioshake_api.py`
- `Separation/Server/rights_gate.py`
- `Separation/Server/ai_stem_generation_models.py`
- `Separation/Server/ai_stem_generation_contract.py`

### Output assurance
- `Separation/Sources/AssuredSeparationProvider.swift`
- `Separation/Sources/SeparationOutputAssurance.swift`
- `Separation/Sources/SeparationOutputAssuranceHelpers.swift`
- `Separation/Sources/SeparationOutputIntegrity.swift`
- `Separation/Sources/SeparationOutputModels.swift`
- `Separation/Sources/SeparationRunManifestCodec.swift`

### Processing lifecycle
- `Processing/Sources/ProcessingLifecycleCoordinator.swift`
- `Processing/Sources/ProcessingLifecycleStateStore.swift`
- `Processing/Sources/ProcessingProviderCapabilities.swift`
- `Processing/Sources/ServerStableStartCapability.swift`

### Quality/evidence
- `Separation/Evaluation/evaluation_core.py`
- `Separation/Evaluation/differential_gate.py`
- `Separation/Evaluation/differential_execute.py`
- `Separation/Evaluation/differential_review.py`
- A19/A20 Golden/differential reproducibility stack
- E01-E10 route/live-evidence readiness stack

## A21 generation boundary

P025 is not ordinary source separation. It creates new audio, so the processing contract must protect both execution and user credits.

A21 adds these invariants:

1. exact generation tier/role/mode/credit behavior comes from a hash-bound capability snapshot, not hard-coded monthly plan assumptions;
2. account entitlement is a separate hash-bound snapshot and raw account IDs are not persisted;
3. concurrent reservations against the same entitlement snapshot cannot double-spend the same observed credits;
4. ambiguous start holds reserved credit until authoritative reconciliation proves whether execution existed;
5. logical cancellation wins publication, but upstream cancellation is claimed only when confirmed;
6. committed credit is never automatically refunded; any refund state requires explicit authority evidence;
7. generated output is publishable only after execution binding, credit commitment, project-controlled copy and integrity verification;
8. regeneration is a new variant/new request identity rather than a free replay of a previous execution;
9. raw prompts, account/project/execution IDs, signed URLs and raw audio are excluded from durable public evidence.

## Current non-negotiable gaps

No Lane 1 row can be promoted from synthetic/control/schema evidence. P003/P004/P005/P020/P021/P024 remain live/HQ-gated. P025 now has a Lane 1 processing/credit safety surface, but remains `MISSING` until a real generation runtime, rights/commercial basis, actual current-iPhone capability/credit/entitlement workflow, generated-audio quality/latency and differential evidence exist.

Synthetic, mock, compile-only or harness-only results remain `NON_PARITY_EVIDENCE_ONLY`.
