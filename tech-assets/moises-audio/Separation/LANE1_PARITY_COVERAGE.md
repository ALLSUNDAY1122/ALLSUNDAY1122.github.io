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
| MOI-P024 privacy | server upload/output/retention/deletion contribution | A09 ordinary separation privacy enforcement + A24 generated-stem deletion/erasure truthfulness + A25 delete-relaunch composition | written/live route terms still required | written provider/runtime terms + integrated deletion/account behavior |
| MOI-P025 AI stem generation | generated-stem runtime, entitlement/credit, recovery, publication, mix compatibility, retention and live quality gate | **A21** credit/lifecycle + **A22** provider-neutral runtime/live gate + **A23** mix compatibility/atomic variant + **A24** retention/delete/refund/orphan recovery + **A25** durable end-to-end composition | no material P025 layer-ordering gap known; full Lane regression/dependency closure remains | exact current-iPhone role/mode/credit/entitlement UX; commercial live runtime; real generated quality/latency; current-iPhone A/B; integrated iPhone mixer/delete; HQ PARITY |

## Existing implementation groups

### Separation provider/runtime
- `Separation/Sources/ServerSeparationProvider.swift`
- `Separation/Server/audioshake_api.py`
- `Separation/Server/rights_gate.py`
- `Separation/Server/ai_stem_generation_models.py`
- `Separation/Server/ai_stem_generation_contract.py`
- `Separation/Server/ai_stem_generation_runtime.py`
- `Separation/Server/generated_stem_mix_compatibility.py`
- `Separation/Server/generated_stem_retention.py`
- `Separation/Server/ai_stem_generation_processing_facade.py`
- `Separation/Server/ai_stem_generation_delete_resume.py`

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

A21 protects execution and user credits with hash-bound capability/entitlement snapshots, concurrent reservation, ambiguous-start reconciliation, truthful cancel/refund semantics, project-controlled publication, regeneration identity and privacy-safe evidence.

## A22 runtime / live gate boundary

A22 connects A21 to a future real generation engine without assuming an unapproved vendor. It provides hosted/local/project-owned runtime descriptors, private execution binding, fail-closed ambiguous start, explicit current-iPhone role/mode pairs, rights-cleared live campaigns, differential evidence and mandatory recovery scenarios.

## A23 mix compatibility / variant boundary

A23 keeps raw generation completion separate from mixer readiness. Sample rate, channels, audio/sample format, frame count and timeline origin must match the source mix contract. Any conversion is explicit/provenance-bound. New generated variants are content-addressed and the active role pointer changes atomically only after object+manifest durability.

## A24 retention / delete / refund / orphan boundary

A24 composes A09 privacy principles with A21/A22/A23 generated-state semantics.

1. retention grace values are hash-bound to the durable registry and cannot silently change on relaunch;
2. delete intent is fsynced before destructive local work;
3. project deletion fails closed if a project-generated manifest is unregistered;
4. physical content-addressed audio is deleted only after both manifest and active-pointer references reach zero;
5. inactive orphan objects require repeated observation, policy grace and durable delete intent;
6. inactive unregistered manifests are reported, not auto-destroyed; explicit abandonment evidence is required;
7. external runtime deletion uses a durable `requesting` state before the call, preventing concurrent or crash-recovery blind resend;
8. `accepted` is not erasure; authority evidence is required for `confirmed`, `not_found`, or a true no-remote-storage `not_applicable` conclusion;
9. local deletion never manufactures a credit release/refund; A21 credit authority remains independent;
10. `privacy_erasure_complete` requires association deletion + local physical erasure + authority-confirmed runtime erasure;
11. public evidence contains hashes/state only, never raw logical/runtime IDs, paths or audio.

## A25 end-to-end generation composition boundary

A25 prevents Late Integration or future callers from bypassing the independently hardened A21-A24 layers.

1. source identity/format and generation identity are durable before runtime work;
2. an ambiguous or possibly-issued runtime start is reconciled, never blindly repeated;
3. the only automatic start replay exception is an intact A21 ledger proving `GEN_RECORD_NOT_FOUND` before A22 could have issued an external start;
4. runtime `READY` is not final publication: A22 artifact SHA is rechecked and A23 is still mandatory;
5. A23 active variant is durable before A24 retention registration;
6. crash after active-variant creation resumes retention only, not generation;
7. logical cancel is durable before upstream cancel and an interrupted upstream cancel is not blindly resent;
8. cancelled output cannot become mixer-active;
9. destructive generated-variant deletion remains A24-owned and A25 adds a private same-reason delete-resume journal for relaunch;
10. A25 public evidence is hash/state/format metadata only and remains `NON_PARITY_EVIDENCE_ONLY`.

## Current non-negotiable gaps

No Lane 1 row can be promoted from synthetic/control/schema evidence. P003/P004/P005/P020/P021/P024 remain live/HQ-gated. P025 now has A21-A25 lifecycle/runtime/mix/retention/composition infrastructure but remains canonical `MISSING` until a real commercially acceptable generation runtime, rights-cleared source audio, exact current-iPhone workflow/credit behavior, generated-audio quality/latency, differential listening, integrated iPhone mixer/delete behavior and HQ PARITY evidence exist.

After A25, no material standalone P025 processing-layer gap is known. The next high-value Lane-local step is a full A05-A25 dependency/regression closure audit so accumulated modules, schemas, stable error codes, protocol assumptions and evidence formats are verified together before HQ Late Integration.

Synthetic, mock, compile-only or harness-only results remain `NON_PARITY_EVIDENCE_ONLY`.
