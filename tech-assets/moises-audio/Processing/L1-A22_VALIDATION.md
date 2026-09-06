# L1-A22｜AI Stem Generation Runtime Adapter / Live Evaluation Gate

Status: `COMPLETE_NON_PARITY`  
Target: `MOI-P025｜AI stem generation`  
PARITY claim: `NONE`

## Purpose

A21 established the durable credit/lifecycle contract for generated stems, but no concrete runtime boundary or live generated-audio evaluation gate existed. A22 supplies that missing Lane 1 infrastructure without choosing an unverified vendor or weakening A21 safety semantics.

## Provider-neutral runtime adapter

`Separation/Server/ai_stem_generation_runtime.py` defines protocol `L1-A22-GENERATION-RUNTIME-v1` and a hash-bound runtime descriptor. A runtime may be:

- `HOSTED_PROVIDER_ACCOUNT`
- `LOCAL_RUNTIME`
- `PROJECT_OWNED_RUNTIME`

The descriptor binds the exact runtime identity, executable/driver artifact SHA-256, A21 capability snapshot, cancel/reconciliation support and credential **environment-variable names only**. Credential values are never serialized into the descriptor or public evidence.

### A21 composition

The adapter preserves A21 ordering:

1. verify source/prompt/reference-audio identity;
2. reserve credit;
3. durably authorize start;
4. call the runtime;
5. bind or reconcile execution identity;
6. commit usage only from authority evidence;
7. observe progress/cancel truthfully;
8. copy and verify the generated artifact under project control;
9. publish only after the A21 publication conditions remain satisfied.

A transport timeout or ambiguous response moves A21 to `ambiguous`; it never triggers a blind second generation request or releases reserved credit. Zero-match reconciliation may release credit only with physical authority evidence that execution did not exist. More than one match fails closed as duplicate execution.

Raw execution IDs are required for later observe/cancel/relaunch but are kept in a private durable binding store. Public A21/A22 evidence carries only domain-separated hashes.

## Generated output publication

A runtime READY response is not product READY by itself. A22 requires:

- credit usage reported as committed;
- exact requested output role;
- output inside the controlled runtime-output root;
- exact advertised byte count and SHA-256;
- structurally valid WAV;
- bounded streaming copy;
- fsync + atomic promotion into project-controlled storage;
- no replacement of an already-published artifact with different bytes.

Logical cancellation remains authoritative. A late runtime READY after logical cancel is discarded and cannot publish.

## Current-iPhone surface contract

The live gate does not assume every advertised role supports every generation mode. The private `AI_STEM_GENERATION_CURRENT_IPHONE_SURFACE` evidence records the **explicit role/mode pairs actually observed on the current iPhone app**, observed tiers, source-evidence SHA and deterministic `surface_sha256`.

This avoids creating fictional parity requirements from a Cartesian product of cross-platform documentation.

A capability snapshot with only `OFFICIAL_CROSS_PLATFORM_ONLY` confidence cannot reach the ready state. `CURRENT_IPHONE_CAPTURED` evidence is required.

## Live generated-audio campaign

Every required observed role/mode pair must have repeated successful real rights-cleared generation runs according to the experiment policy. Each run binds:

- exact A21 capability snapshot;
- exact A22 runtime descriptor;
- source SHA;
- generation settings SHA;
- runtime receipt SHA;
- execution provenance SHA;
- latency and retry count;
- credit/cancel/duplicate-execution safety;
- project-controlled verified output SHA.

Synthetic audio cannot satisfy this gate.

## Current-iPhone differential

Every successful project run requires an exact-input/settings blind comparison against a current-iPhone Moises capture for the same role and mode. The gate records project-minus-reference usability delta, material-inferiority vote, reference-capture SHA and review-evidence SHA without copying Moises audio into the repository.

A missing blind comparison cannot be treated as quality PASS. Material inferiority or a usability/latency/reliability threshold failure yields `LIVE_EVALUATION_REJECTED`.

## Recovery campaign

All four scenarios are mandatory:

1. `AMBIGUOUS_START_RECONCILIATION`
2. `RELAUNCH_BOUND_EXECUTION`
3. `CANCEL_DURING_GENERATION`
4. `CREDIT_EXHAUSTION`

Each scenario requires physical fault provenance and authority evidence and must show no duplicate execution, no project corruption, consistent credit accounting and truthful cancellation.

## Physical evidence binding

`evaluate_private_campaign()` accepts only a private root outside the repository. Plan, capability, current-iPhone surface, runtime descriptor, entitlement observations, live runs, differentials and recovery evidence are individual files whose SHA-256 values must match the private campaign index. Traversal and symlink paths fail closed.

The sanitized public report contains hashes/metrics/checks, not private paths or raw evidence material.

## Engineering policy vs Reference fact

The numeric acceptance thresholds in `ai-stem-generation-live-plan.template.json` are engineering policy for an experiment. They are **not claims about Moises performance**. Changing those thresholds creates a different decision input and changes the evidence lock.

Exact current-iPhone roles, modes, presets, tier entitlement, credit consumption and UX remain capture-driven; A22 does not hard-code uncertain cross-platform values.

## Privacy

A22 public evidence does not emit:

- raw prompts;
- raw account/project/execution IDs;
- credential values;
- source/runtime/private filesystem paths;
- raw generated/source audio;
- copied Moises reference audio;
- raw reviewer IDs.

## Verification

Final local validation before persistence:

- broad runtime/live fault suite: **59/59 PASS**;
- checked-in focused regression: **23/23 PASS**;
- 9 JSON Schema representative-document validations: **9/9 PASS**;
- Python implementation/test syntax compile: **PASS**.

Coverage includes descriptor mutation, driver identity, credential handling, ambiguous start, zero/one/multiple reconciliation, output integrity, cancellation race, source mutation, current-iPhone confidence, tier coverage, synthetic-run rejection, duplicate execution, blind-review enforcement, role/mode coverage, latency/quality/material-inferiority thresholds, recovery completeness, private SHA/path enforcement, deterministic locks and evidence privacy.

All automated runs are synthetic/control. No production generation runtime, real generated-audio quality result, current-iPhone Moises capture or human blind review was produced in this wave.

## Result / remaining gate

A22 is `COMPLETE_NON_PARITY`. It makes P025 technically executable against a real runtime later, but does not satisfy the canonical P025 gate.

`MOI-P025` must remain `MISSING` until at least:

- exact current-iPhone generation surface and entitlement/credit UX are captured;
- a commercially/legally acceptable generation runtime is supplied;
- real rights-cleared audio is generated repeatedly;
- output quality and latency are compared to current-iPhone Moises;
- cancellation/recovery/credit behavior is observed live;
- HQ integrates the workflow into the real iPhone app and performs final PARITY judgment.

The next high-value Lane 1 engineering gap is generated-stem timing/mix compatibility: sample format, duration/timeline alignment, source-relative fit and safe variant replacement/transaction semantics.
