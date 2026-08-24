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
| MOI-P024 privacy | server upload/output/retention/deletion contribution | A09 ordinary separation privacy enforcement + A24 generated-stem local delete/runtime-erasure truth separation + A26 A24/A25 gateway | full A26 regression execution still needs an executable checkout/CI runner | written provider/runtime terms + integrated deletion/account behavior |
| MOI-P025 AI stem generation | generated-stem runtime, entitlement/credit, recovery, publication, mix compatibility, retention and live quality gate | **A21** credit/lifecycle + **A22** provider-neutral runtime/live gate + **A23** mix compatibility/atomic variant + **A24** retention/delete/refund/orphan coordinator + **A25** durable end-to-end facade + **A26** compatibility gateway/audit runner | execute A26 full Lane regression when a checkout/CI runner is available; no further standalone P025 feature layer currently known | exact current-iPhone role/mode/credit/entitlement/delete UX; commercial live runtime; real generated quality/latency; current-iPhone A/B; integrated iPhone mixer/delete; HQ PARITY |

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
- `Separation/Server/ai_stem_generation_retention_gateway.py`

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
- `Separation/Evaluation/lane1_dependency_audit.py`
- A19/A20 Golden/differential reproducibility stack
- E01-E10 route/live-evidence readiness stack

## A21 generation boundary

A21 protects execution and user credits with hash-bound capability/entitlement snapshots, concurrent reservation, ambiguous-start reconciliation, truthful cancel/refund semantics, project-controlled publication, regeneration identity and privacy-safe evidence.

## A22 runtime / live gate boundary

A22 connects A21 to a future real generation engine without assuming an unapproved vendor. It provides hosted/local/project-owned runtime descriptors, private execution binding, fail-closed ambiguous start, explicit current-iPhone role/mode pairs, rights-cleared live campaigns, differential evidence and mandatory recovery scenarios.

## A23 mix compatibility / variant boundary

A23 keeps raw generation completion separate from mixer readiness. Sample rate, channels, audio/sample format, frame count and timeline origin must match the source mix contract. Any conversion is explicit/provenance-bound. New generated variants are content-addressed and the active role pointer changes atomically only after object+manifest durability.

## A24 final retention / delete / refund / orphan boundary

A24 keeps four different facts separate: local association deletion, physical content deletion, runtime erasure and credit refund.

1. an exact A23 manifest/artifact identity is SHA-bound into a durable delete intent before destructive work;
2. the exact active pointer is detached only when it names the target; another active variant is preserved;
3. the target manifest must still match the captured SHA before it can be removed;
4. content-addressed object reachability is recomputed from **both all manifests and all active pointers**;
5. any corrupt/symlink reference fails delete/GC closed rather than guessing reachability;
6. unreferenced objects and stale temporary files require explicit age grace before cleanup;
7. inactive cancelled/failed variants require physical A21 abandonment evidence; an active variant cannot be classified as abandoned;
8. durable delete records are tombstones against silent generation resurrection;
9. local deletion does not imply credit refund: A21 `refund_pending/refunded` plus authority evidence remains mandatory;
10. local deletion does not imply runtime erasure: only authority-backed `CONFIRMED`, `NOT_FOUND`, or true `NOT_APPLICABLE` can complete remote-erasure evidence;
11. public evidence contains hashes/state only and never raw audio, paths, runtime IDs or billing records.

The earlier prototype retention-policy schema was removed because the final A24 coordinator does not invent provider/current-iPhone retention durations.

## A25 end-to-end generation composition boundary

A25 prevents callers from bypassing the A21-A24 order: intent/credit -> runtime binding/recovery -> verified A22 output -> A23 mix-ready activation -> A24 retention/delete. It also persists cancellation and delete-reason recovery boundaries.

A25's retention seam was written against the earlier A24 service-shaped surface (`register_variant`, `request_delete`, `snapshot`, `retention_policy_sha256`). A24's final coordinator deliberately exposes lower-level, stricter primitives. A26 detected this source-level drift before HQ integration.

## A26 dependency closure status

A26 adds `A24RetentionGateway` rather than weakening A24 or reverting A25. The gateway:

1. verifies the final A23 manifest and exact active pointer before A25 can call a variant retention-registered;
2. checks A24 tombstones before re-registration;
3. translates A25 delete reasons to final A24 reasons and preserves same-reason idempotency;
4. delegates physical deletion/reference safety to the final A24 coordinator;
5. maps runtime delete receipts conservatively: `accepted -> PENDING`, errors/missing binding -> `UNKNOWN`, and only confirmed/not-found can become authoritative erasure;
6. never turns association deletion into credit refund;
7. supplies a deterministic semantic retention-policy hash for A25 journal identity without inventing provider TTL values.

`lane1_dependency_audit.py` is now the one-command checkout audit for Python compilation, unittest discovery, JSON syntax, JSON-Schema self-validation and critical A21-A26 dependency surfaces.

The available connector runtime cannot execute a repository checkout and the Worker-branch commits currently expose no CI status. Therefore the A26 full-run result is **not yet claimed PASS**. This is a runner availability condition, not a PARITY or human-decision gate.

## Current non-negotiable gaps

No Lane 1 row can be promoted from synthetic/control/schema evidence. P003/P004/P005/P020/P021/P024 remain live/HQ-gated. P025 has A21-A26 lifecycle/runtime/mix/retention/composition/dependency infrastructure but remains canonical `MISSING` until a real commercially acceptable generation runtime, rights-cleared source audio, exact current-iPhone workflow/credit behavior, generated-audio quality/latency, differential listening, integrated iPhone mixer/delete behavior and HQ PARITY evidence exist.

The immediate Lane-local checkpoint condition is to execute the A26 one-command audit on an executable checkout/CI environment before declaring dependency closure complete.

Synthetic, mock, compile-only or harness-only results remain `NON_PARITY_EVIDENCE_ONLY`.
