# L1-A21｜AI Stem Generation Parity Surface / Processing Contract

Status: `COMPLETE_NON_PARITY`  
Target: `MOI-P025｜AI stem generation`  
PARITY claim: `NONE`

## Why this wave exists

The canonical PARITY matrix marks AI Stem Generation as current-iPhone in-scope and `MISSING`. A05-A20 and E01-E10 hardened ordinary separation and its live-evidence route, but did not implement the generated-stem processing/credit surface.

A21 adds the Lane 1 processing contract needed before a concrete generation runtime can be integrated.

## Current official Reference boundary

Public Moises material confirms AI Stem Generation is available on mobile, web and desktop for Free, Premium and Pro users, with credit limits varying by subscription. Public feature material describes generated instruments that fit supplied audio and supports instrument/style/direction controls.

Current Moises Terms make subscription features/usage limits and monthly credit allocations dependent on the current Pricing Page. Therefore A21 does **not** freeze a monthly Free/Premium/Pro credit allowance into source code.

Exact current-iPhone role list, mode/preset list, credit consumption formula, monthly allowance, maximum generation duration, cancellation/refund behavior and entitlement UX remain external/current-iPhone evidence requirements. Cross-platform public documentation is not treated as exact iPhone UI evidence.

See `Separation/AI_STEM_GENERATION_REFERENCE_NOTES.md`.

## Implemented contract

### 1. Versioned capability snapshot

`CapabilityPolicy` binds tier/role/mode/credit semantics to a deterministic `snapshot_sha256` and source evidence hash. It carries an explicit reference confidence:

- `OFFICIAL_CROSS_PLATFORM_ONLY`
- `CURRENT_IPHONE_CAPTURED`

Changing a semantic field without changing the snapshot fails closed.

### 2. Entitlement snapshot

`EntitlementSnapshot` binds:

- plan tier;
- generation-enabled state;
- current included-credit balance or unlimited state;
- purchased-credit balance;
- exact capability snapshot;
- source evidence.

Raw account identity is not persisted; only a hash is carried.

### 3. Request identity

`GenerationIntent` binds project/source hashes, duration, target role, generation mode, preset/prompt/reference-audio semantics, variant number and capability snapshot into a deterministic request fingerprint.

Raw custom prompt text is never persisted. It is domain-hashed. Regeneration is represented as a new variant/new request identity, not as a free replay.

### 4. Credit reservation safety

The durable ledger reserves credit before generation start. Reservations sharing the same entitlement snapshot are aggregated under a file lock, preventing concurrent jobs from spending the same observed balance twice.

Included and purchased balances remain distinct. Unlimited entitlement is represented explicitly rather than by a fabricated large number.

### 5. Ambiguous start safety

After `authorize_start`, a timeout or unknown response may mean the generation actually started. `mark_start_ambiguous` therefore keeps the credit reservation and sets the execution state to ambiguous.

Credit cannot be released until reconciliation provides physical evidence that no execution existed. There is no blind retry/refund assumption.

### 6. Cancellation truthfulness

Logical cancel immediately wins product publication. Upstream cancellation is tracked separately:

- pre-start: `not_requested`;
- supported runtime after start: `requested` until confirmed;
- unsupported runtime: `unsupported`;
- `confirmed` only after authority evidence.

A cancelled generation can never publish its output.

### 7. Credit commitment / refund

Credit usage is committed only after an execution has been bound and authority evidence is supplied.

A post-execution cancellation does not automatically restore credit. A refund requires an explicit `refund_pending -> refunded` authority-evidence transition. This keeps the engine safe even when a runtime's commercial policy does not offer refunds.

### 8. Output publication

Generated output becomes `ready` only when all are true:

- generation is not logically cancelled;
- one execution identity is bound;
- credit use is committed;
- output role exactly matches the requested target;
- the artifact is copied under project control;
- integrity is verified;
- artifact SHA and byte count are recorded.

Replacing an already-published output with different bytes is rejected. Re-publishing the same exact artifact is idempotent.

### 9. Durability / privacy

The generation ledger uses POSIX file locking and atomic temp + fsync + replace semantics. Corrupt ledger content fails closed.

Public/durable evidence omits:

- raw prompt;
- raw account/project/execution IDs;
- signed output URLs;
- raw audio.

## Automated verification

Locally tested final bytes:

- `test_ai_stem_generation_contract.py`: **33/33 PASS**
- capability/entitlement/evidence JSON Schema validations: **3/3 PASS**
- `ai_stem_generation_models.py`: `py_compile PASS`
- `ai_stem_generation_contract.py`: `py_compile PASS`
- test module: `py_compile PASS`

After branch persistence, GitHub blob read-back for the two implementation files and regression test matched the Git blob SHA of the locally tested bytes.

Negative/edge coverage includes entitlement disabled/exhausted, concurrent reservation, snapshot mutation, invalid modes, unsupported roles, duplicate start, ambiguous start, duplicate execution, progress regression, output-before-credit, role mismatch, integrity failure, output replacement, cancel races, refund without cancellation, regeneration identity and corrupt ledger.

All automated inputs are synthetic/control values and are not PARITY evidence.

## Remaining P025 gates

A21 does not make P025 `PARTIAL`, `NEAR_PARITY` or `PARITY`. The canonical matrix remains unchanged.

Still required:

1. exact current-iPhone role/mode/preset and entitlement/credit workflow capture;
2. a commercially acceptable concrete generation runtime/provider or project-owned model;
3. live account/runtime credit consumption and cancellation behavior;
4. generated audio on rights-cleared real inputs;
5. latency, failure/recovery and capacity evidence;
6. exact-input current-iPhone Moises generated-stem differential and independent listening review;
7. integrated iPhone entitlement UX and product flow;
8. HQ Late Integration and final PARITY judgment.

## Next Lane 1 target

`L1-A22｜AI Stem Generation Runtime Adapter / Live Evaluation Gate`

A22 should connect the A21 processing contract to a provider-neutral concrete generation runtime seam and build the rights-aware generated-stem benchmark/differential evidence producer without weakening A07/A14/A16/A17/A18 safety invariants.
