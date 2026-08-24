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
| MOI-P025 AI stem generation | generated-stem runtime, entitlement/credit, recovery, publication, mix compatibility and live quality gate | **A21** durable credit/lifecycle + **A22** provider-neutral runtime/live gate + **A23** exact source-format/timeline compatibility, normalization provenance and atomic active-variant transaction | generated-stem retention/delete/refund/orphan cleanup coupling | exact current-iPhone role/mode/credit/entitlement UX; commercial live runtime; real generated quality/latency; current-iPhone A/B; integrated iPhone mixer; HQ PARITY |

## Existing implementation groups

### Separation provider/runtime
- `Separation/Sources/ServerSeparationProvider.swift`
- `Separation/Server/audioshake_api.py`
- `Separation/Server/rights_gate.py`
- `Separation/Server/ai_stem_generation_models.py`
- `Separation/Server/ai_stem_generation_contract.py`
- `Separation/Server/ai_stem_generation_runtime.py`
- `Separation/Server/generated_stem_mix_compatibility.py`

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
- `Separation/Evaluation/ai_stem_generation_live_gate.py`
- A19/A20 Golden/differential reproducibility stack
- E01-E10 route/live-evidence readiness stack

## A21 generation boundary

P025 is not ordinary source separation. It creates new audio, so the processing contract must protect both execution and user credits.

A21 invariants include hash-bound capability/entitlement snapshots, concurrent credit reservation, ambiguous-start reconciliation, truthful cancel/refund semantics, project-controlled output publication, regeneration identity and privacy-safe evidence.

## A22 runtime / live gate boundary

A22 connects A21 to a future real generation engine without assuming a specific unapproved vendor. Runtime descriptors support hosted/local/project-owned authority kinds, private execution binding, fail-closed ambiguous start, rights-cleared real-source live campaigns, explicit current-iPhone role/mode pairs, differential evidence and mandatory recovery scenarios.

## A23 mix compatibility / variant boundary

A23 prevents a generated runtime artifact from being treated as mixer-ready merely because generation completed.

1. sample rate, channels, PCM/float format, bit depth, frame count and zero timeline origin must match the source project mix spec before activation;
2. resample/channel-remix/sample-format conversion/edge trim-pad are fail-closed unless explicitly permitted by a hash-bound policy;
3. when conversion is needed, the evidence chain binds raw artifact SHA -> normalization plan SHA -> normalizer artifact SHA -> execution evidence SHA -> normalized output SHA;
4. normalized output still must exactly match the source mix format/frame count;
5. generated variants use immutable content-addressed objects/manifests plus an atomic active pointer;
6. same variant identity is idempotent, conflicting same-index replacement and index regression are rejected;
7. crash after object or manifest persistence preserves the previously active variant;
8. active pointer corruption, artifact mutation and symlink audio fail closed;
9. public evidence exposes hashes/format metadata only, not paths or raw audio.

## Current non-negotiable gaps

No Lane 1 row can be promoted from synthetic/control/schema evidence. P003/P004/P005/P020/P021/P024 remain live/HQ-gated. P025 now has A21 processing/credit, A22 runtime/live-evaluation and A23 mix-compatible atomic variant infrastructure, but remains `MISSING` until a real commercially acceptable generation runtime, rights-cleared source audio, exact current-iPhone role/mode/credit/entitlement workflow, generated-audio quality/latency, differential listening, integrated iPhone mixer and deletion/retention behavior exist.

Synthetic, mock, compile-only or harness-only results remain `NON_PARITY_EVIDENCE_ONLY`.
