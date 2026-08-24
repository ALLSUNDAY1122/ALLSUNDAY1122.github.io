# L1-A26｜Lane 1 Full Regression / Dependency Closure Audit

Status: `IN_PROGRESS_RUNNER_PENDING`  
PARITY claim: `NONE`

## Why A26 did not immediately close

The Worker branch is canonical for Worker 1 progress. A24-A25 are already in `completed_waves`; A26 remains current. During A26 source readback, a real cross-wave incompatibility was found before HQ Late Integration:

- A25 composes a retention seam with `register_variant`, `request_delete`, `snapshot` and `retention_policy_sha256`.
- The finalized A24 coordinator uses stricter lower-level primitives (`begin_delete`, `execute_local_delete`, tombstone/refund/runtime-erasure APIs) and no longer exposes the earlier prototype service-shaped API.

Passing each wave independently was therefore insufficient: final A24 could not be wired directly to A25 without a compatibility layer.

## Repair

A26 adds `Separation/Server/ai_stem_generation_retention_gateway.py`.

`A24RetentionGateway` preserves final A24 semantics while restoring the A25 seam:

- registration verifies an exact A23 manifest and exact active pointer;
- A24 tombstones block re-registration;
- delete reason is mapped deterministically and conflicting replay fails closed;
- all physical deletion/reference decisions remain delegated to A24;
- runtime delete `accepted` maps only to `PENDING`;
- missing binding / runtime exception maps to `UNKNOWN`;
- only authority-returned `confirmed` / `not_found` can become authoritative runtime-erasure state;
- local association deletion never implies credit refund;
- the gateway policy hash describes the semantic bridge only and does not invent provider/current-iPhone retention TTLs.

A focused 12-case regression is checked in at `Separation/Tests/test_ai_stem_generation_retention_gateway.py`.

## A24 evidence reconciliation / reference safety

Latest Worker-branch source readback confirms that final A24 object reachability is computed from **both**:

- every immutable generated-stem manifest; and
- every active generated-stem pointer.

`_collect_referenced_artifacts()` fails closed if either reference set contains a corrupt or symlinked record before physical-object GC/delete proceeds. This specifically prevents the unsafe case where a damaged/missing historical manifest could otherwise allow an object that is still active in another project/role to be deleted.

Final A24 also keeps deletion, refund and runtime erasure as separate state machines; tombstones prevent silent generation resurrection. The stale prototype retention-policy schema was removed and A24 evidence was normalized to the final coordinator semantics.

## Focused gateway execution now observed

The exact checked-in A26 gateway source and exact checked-in 12-case gateway test source were reconstructed through GitHub connector readback and executed against a locally available A24 coordinator whose gateway-invoked behavior was separately matched to the latest final A24 source readback.

Observed result:

- A24↔A25 gateway focused regression: `12/12 PASS`;
- failures: `0`;
- errors: `0`.

Observed cases include:

1. registration exposes the A25 retention surface;
2. exact active pointer is required;
3. delete maps to A24 and confirms only local association deletion;
4. same-reason delete replay is idempotent;
5. conflicting delete reason fails closed;
6. tombstone blocks re-registration/resurrection;
7. runtime `confirmed` is authoritative erasure but not refund;
8. runtime `accepted` remains pending;
9. runtime exception remains unknown;
10. missing runtime binding cannot claim erasure;
11. binding identity mismatch fails closed;
12. public snapshot is privacy safe.

This focused execution is valid dependency-repair evidence, but it is **not** represented as the full exact Worker-branch regression run.

## One-command audit

`Separation/Evaluation/lane1_dependency_audit.py` remains the mandatory final A26 closure runner. On a full Worker-branch checkout it performs:

1. `py_compile` over Lane 1 Server/Evaluation/tests;
2. full `unittest discover` for `Separation/Tests/test_*.py`;
3. JSON syntax validation for Lane-owned evaluation/evidence JSON;
4. Draft 2020-12 schema self-validation;
5. critical A21-A26 dependency-surface checks, including final A24 coordinator and A26 gateway;
6. stable error-code inventory for review.

It exits non-zero unless every mandatory check passes.

## Remaining execution boundary

A full Worker-branch checkout is still unavailable in the current execution container because `github.com` DNS resolution fails. GitHub reports no workflow runs for the inspected latest A26 commit, so there is also no CI result that can substitute for the missing checkout run.

Therefore A26 still does **not** claim:

- full Lane 1 unittest discovery PASS;
- full Lane 1 py_compile PASS;
- full owned JSON syntax audit PASS;
- full schema self-validation PASS;
- `lane1_dependency_audit.py overall_state=PASS`.

Those remain `NOT_OBSERVED`. Only the focused A24↔A25 gateway regression is now observed PASS.

The missing full runner is not a human/Golden blocker and does not justify `BLOCKED_HUMAN`. A24-A25 remain a coherent checkpoint candidate; A26 stays current until the full one-command audit is observed `PASS` on an executable exact Worker-branch checkout/CI runner.

## PARITY boundary

No PARITY row is promoted. P003/P004/P005/P020/P021/P024/P025 remain canonical `MISSING` pending real runtime/current-iPhone/real-audio/device/HQ gates.

A26 dependency repair, focused regression and any eventual portable full regression are engineering evidence only. They cannot substitute for real generated/separated audio quality, current-iPhone differential evidence or HQ PARITY judgment.
