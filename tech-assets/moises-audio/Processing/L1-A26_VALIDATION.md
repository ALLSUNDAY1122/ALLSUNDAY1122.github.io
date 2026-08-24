# L1-A26｜Lane 1 Full Regression / Dependency Closure Audit

Status: `IN_PROGRESS_RUNNER_PENDING`  
PARITY claim: `NONE`

## Why A26 did not immediately close

The current Worker branch is canonical for Worker 1 progress, and the latest status already placed A24-A25 in `completed_waves` with A26 current. During the A26 readback, a real cross-wave incompatibility was found before HQ Late Integration:

- A25 composes a retention seam with `register_variant`, `request_delete`, `snapshot` and `retention_policy_sha256`.
- The finalized A24 coordinator uses stricter lower-level primitives (`begin_delete`, `execute_local_delete`, tombstone/refund/runtime-erasure APIs) and no longer exposes the prototype service-shaped API.

Passing each wave independently was therefore not enough: an integration caller could not directly connect final A24 to A25.

## Repair

A26 adds `Separation/Server/ai_stem_generation_retention_gateway.py`.

`A24RetentionGateway` preserves the final A24 semantics while restoring the A25 seam:

- registration verifies an exact A23 manifest and exact active pointer;
- A24 tombstones block re-registration;
- delete reason is mapped deterministically and conflicting replay fails closed;
- all physical deletion/reference decisions remain delegated to A24;
- runtime delete `accepted` maps only to `PENDING`;
- missing binding / runtime exception maps to `UNKNOWN`;
- only authority-returned `confirmed` / `not_found` maps to authoritative erasure state;
- local association deletion never implies credit refund;
- the gateway policy hash describes the semantic bridge only and does not invent provider retention TTLs.

A focused 12-case regression was added at `Separation/Tests/test_ai_stem_generation_retention_gateway.py`. The checked-in cases cover registration, active-pointer requirement, delete mapping/replay, reason conflict, tombstone resurrection prevention, runtime confirmed/accepted/error/missing-binding semantics, binding identity mismatch and privacy-safe snapshot shape.

## A24 evidence reconciliation

A24 had an earlier prototype evidence/schema set on the branch. The A26 readback normalized it to the final A24 implementation:

- final object reachability uses both manifests and active pointers;
- deletion, refund and runtime erasure are separate state machines;
- stale prototype `generated-stem-retention-policy.schema.json` was removed;
- final A24 request/evidence schemas remain;
- A24 validation/matrix now describe the final coordinator rather than the superseded prototype.

This matters because A25's durable identity still needs a retention semantic hash, but that hash must not be mistaken for a vendor/current-iPhone TTL claim. The A26 gateway supplies a deterministic semantic hash for A25 without reintroducing the deleted TTL schema.

## One-command audit

`Separation/Evaluation/lane1_dependency_audit.py` was added for the final A26 closure run. On a real checkout it performs:

1. `py_compile` over Lane 1 Server/Evaluation/tests;
2. full `unittest discover` for `Separation/Tests/test_*.py`;
3. JSON syntax validation for Lane-owned evaluation/evidence JSON;
4. Draft 2020-12 schema self-validation;
5. critical A21-A26 dependency-surface checks, including final A24 coordinator and A26 gateway;
6. stable error-code inventory for review.

The runner exits non-zero unless all mandatory checks pass.

## Execution boundary in this session

The available execution container cannot resolve `github.com`, so the attempted Worker-branch checkout failed before any code was executed. GitHub combined status on the latest A26 branch commit also returned no CI status records.

Therefore this document does **not** claim:

- the 12 new gateway tests passed;
- full Lane 1 unittest discovery passed;
- full Lane 1 py_compile passed;
- full schema audit passed.

Those are deliberately recorded as `NOT_OBSERVED`, not inferred from file creation or earlier A21-A25 tests.

The missing runner is not a human/Golden blocker and does not justify `BLOCKED_HUMAN`. The coherent A24-A25 checkpoint remains ready for HQ semantic integration, while A26 itself stays current until its one-command audit is observed `PASS` on an executable checkout/CI environment.

## PARITY boundary

No PARITY row is promoted. P003/P004/P005/P020/P021/P024/P025 remain canonical `MISSING` pending their real runtime/current-iPhone/real-audio/device/HQ gates.

A26 dependency repair and any eventual full portable regression are engineering evidence only. They cannot substitute for real generated/separated audio quality, current-iPhone differential evidence or HQ PARITY judgment.
