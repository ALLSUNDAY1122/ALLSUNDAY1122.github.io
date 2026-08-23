# Lane 1｜PARITY Coverage / Completion Gap Inventory

Captured: 2026-08-23 JST
Planning mode: v4 autonomous worker
Scope: `Separation/**`, `Processing/**`

This inventory is a Worker planning/evidence map only. It does not modify or promote `PARITY_MATRIX.json`.

| PARITY row | Lane 1 responsibility | Current lane evidence | Lane-local remaining work | External/HQ remaining gate |
|---|---|---|---|---|
| MOI-P003 core separation | vocals/drums/bass real separation | ServerSeparationProvider; AudioShake adapter; rights gate; G1/G2 evaluator; output assurance; differential executor | production orchestration, idempotency/billing safety, artifact transaction hardening, live-profile mapping | commercial credential/terms, rights-cleared G1/G2, current-iPhone A/B, HQ PARITY |
| MOI-P004 other/instrument | other + additional instrument modes | core target adapter; provider-neutral evaluation/output manifest | reference profile registry, additional-instrument capability mapping, profile completeness validation | live provider modes + current-iPhone comparison |
| MOI-P005 advanced separation | custom / Hi-Fi / professional modes | Reference confirms in-scope; AudioShake SDK/API candidate documentation | explicit advanced capability registry, incompatible target validation, Hi-Fi/provider quality mapping | exact current-iPhone entitlement/mode observation, commercial provider capability, live A/B |
| MOI-P020 processing | progress/cancel/retry/resume | ProcessingLifecycleCoordinator/StateStore; stable-start capability; L1-M02 failure matrix | durable backend registry, truthful cancellation semantics, provider fault matrix, reconnect/relaunch production hardening | integrated iPhone interruption/background/relaunch and real provider semantics |
| MOI-P021 performance | Lane 1 upload/separation/download contribution | streaming client/provider paths; wall-time evidence hooks | long-track server streaming/storage pressure/backpressure/resource instrumentation | physical-iPhone memory/thermal/battery is HQ/device gate |
| MOI-P024 privacy | server upload/output/retention/deletion contribution | rights gate; project-controlled copy; retention/cost manifest structures | retention/delete enforcement, secret/content redaction, privacy-safe observability | written provider privacy/retention/deletion terms; integrated deletion/account behavior |

## Existing implementation groups

### Separation provider/runtime
- `Separation/Sources/ServerSeparationProvider.swift`
- `Separation/Server/audioshake_api.py`
- `Separation/Server/rights_gate.py`

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

## v4 autonomous execution order

The detailed source of execution truth is `Separation/LANE1_COMPLETION_ROADMAP.md`. Current intended critical path:

`A06 production orchestration -> A07 idempotency/billing -> A08 cancellation truthfulness -> A09 privacy/retention -> A10 cost/quota -> A11/A12 separation profiles -> A13/A14 artifact integrity/atomicity -> A15/A16 long-track/relaunch -> A17/A18 fault/observability -> A19/A20 real-corpus/differential readiness -> external live gates`.

Order may be re-optimized on every `次` when a higher-severity defect or newly available external input changes the critical path.

## Current non-negotiable gaps

The lane still has no truthful basis to promote P003/P004/P005/P020 because production credential/contract, rights-cleared real-audio corpus, live vendor evidence, current-iPhone differential assets, human listening evidence and integrated device evidence are absent.

Synthetic, mock, compile-only or harness-only results remain `NON_PARITY_EVIDENCE_ONLY`.
