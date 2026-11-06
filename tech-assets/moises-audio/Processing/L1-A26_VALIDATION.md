# L1-A26｜Lane 1 Full Regression / Dependency Closure Audit

Status: `IN_PROGRESS_EXACT_CHECKOUT_AUDIT_PENDING`  
PARITY claim: `NONE`

## Dependency repair already closed

A26 previously found a real A24→A25 interface drift. `A24RetentionGateway` preserves final A24 delete/refund/runtime-erasure semantics while satisfying the A25 facade seam. The focused gateway regression is observed `12/12 PASS`.

Final A24 source readback also confirms physical generated-artifact reachability uses **both all manifests and all active pointers** and fails closed on corrupt/symlink references before GC/delete. This prevents an active shared content-addressed object from being removed merely because a historical manifest is damaged or absent.

## Why the full audit is still not marked PASS

The mandatory full runner is `Separation/Evaluation/lane1_dependency_audit.py`.

The current execution container still has no exact Worker-branch checkout and cannot clone the branch into an executable environment. No available CI run substitutes for that missing full execution. Therefore these remain `NOT_OBSERVED` on one exact Worker checkout:

- full Lane 1 unittest discovery;
- full Lane 1 Python py_compile;
- full owned JSON syntax audit;
- full Draft 2020-12 schema self-validation;
- dependency-surface inventory;
- one-command `overall_state=PASS` on the exact Worker branch.

A26 is intentionally not placed in `completed_waves` until that execution exists.

## A26 provenance hardening

### Exact git HEAD binding

The closure command requires:

`--expected-git-head <exact 40-hex final Worker branch tip>`

The runner executes `git rev-parse HEAD` from the repository root. `overall_state=PASS` is impossible when the expected head is absent/malformed, git HEAD is unavailable, or actual HEAD differs from the supplied Worker-branch tip.

### Deterministic owned-source snapshot

`Separation/Evaluation/lane1_source_snapshot.py` hashes every durable regular file beneath:

- `Separation/**`
- `Processing/**`

For every file the report records relative path, byte count and SHA-256, then derives one deterministic `source_snapshot_sha256` over the ordered manifest.

Base fail-closed rules remain:

- symlinks are rejected;
- missing owned scope is rejected;
- unreadable/stat-failing source is rejected;
- only runtime-generated cache/temp/lock artifacts are automatically excluded;
- an audit output file may be explicitly excluded only when inside the Lane root;
- files outside Separation/Processing do not influence the Lane-owned snapshot.

### HEAD-tree/worktree binding hardening

During this session a remaining provenance hole was identified before claiming A26 complete: `git rev-parse HEAD` proves the ref but, by itself, does **not** prove the current owned working-tree bytes equal that commit. A checkout with the correct HEAD plus modified/missing/untracked owned files could otherwise produce a fresh SHA-256 snapshot and appear bound to the correct commit.

Commit `32fb32ff6a70c74237360e361c000cb99cdc8358` closes that false-positive path. When `build_source_snapshot` is running inside a git checkout it now additionally requires:

1. git top-level resolution to match the expected repository root used by the Lane layout;
2. no tracked `Separation/**` or `Processing/**` working-tree changes (`git status --untracked-files=no`);
3. the complete durable on-disk Lane file set to equal `git ls-tree -r --name-only HEAD` for both owned scopes.

This catches:

- modified tracked owned files → `L1A26_OWNED_WORKTREE_DIRTY`;
- deleted tracked owned files → `L1A26_OWNED_WORKTREE_DIRTY`;
- untracked durable owned files → `L1A26_OWNED_TREE_MISMATCH`;
- gitignored durable owned files → `L1A26_OWNED_TREE_MISMATCH`;
- attempts to hide a tracked source/evidence file through the explicit output-exclusion mechanism → `L1A26_OWNED_TREE_MISMATCH`;
- unavailable/inconsistent git tree binding → `L1A26_GIT_TREE_BINDING_UNAVAILABLE`.

An explicitly excluded **untracked** audit output remains allowed so a report can be written inside the Lane root without hashing itself.

The SHA-256 manifest remains engineering evidence only and makes no PARITY claim.

## Focused provenance validation

Because the full Worker checkout remains unavailable, focused provenance logic was executed in isolated git fixtures. This is explicitly not a substitute for the full audit.

Observed results:

- deterministic source-snapshot behavior from the prior hardening: `7/7 PASS`;
- exact git-head/source-binding behavior from the prior hardening: `5/5 PASS`;
- new HEAD-tree/worktree binding regression: `7/7 PASS`;
- new source-snapshot implementation/test `py_compile`: `PASS`;
- v2 report JSON Schema self-check from the prior hardening: `PASS`.

The new 7-case regression covers clean HEAD, modified tracked file, deleted tracked file, untracked durable file, gitignored durable file, explicit untracked audit-output exclusion, and rejection of excluding a tracked file.

Remote readback at implementation commit `32fb32ff6a70c74237360e361c000cb99cdc8358` confirms the checked-in implementation blob and focused test blob are the versions exercised by the fixture validation.

## Report schema

`Separation/Evaluation/schemas/lane1-dependency-audit-report-v2.schema.json` requires `git_head_binding.state=PASS` and `owned_source_snapshot.state=PASS` whenever `overall_state=PASS`.

Because HEAD-tree/worktree mismatch now causes `owned_source_snapshot.state=FAIL`, a PASS report cannot be emitted merely from a correct HEAD ref paired with altered owned bytes.

## Full one-command audit contract

On an executable exact Worker checkout, run the final A26 runner with the **then-current final branch tip** supplied explicitly. The runner performs:

1. exact git HEAD verification;
2. complete owned `Separation/**` + `Processing/**` source snapshot plus HEAD-tree/worktree binding;
3. Python `py_compile` for Lane 1 Server/Evaluation/tests;
4. full `unittest discover` for `Separation/Tests/test_*.py`;
5. owned JSON syntax validation;
6. Draft 2020-12 schema self-validation;
7. A21-A26 critical dependency-surface checks;
8. stable error-code inventory.

Completion requires archived v2 evidence with `overall_state=PASS`, `git_head_binding.state=PASS`, and `owned_source_snapshot.state=PASS` at that exact Worker-branch tip.

## PARITY boundary

No PARITY row is promoted. P003/P004/P005/P020/P021/P024/P025 remain canonical `MISSING` pending real runtime/current-iPhone/real-audio/device/HQ gates.

A26 dependency repair, provenance hardening, focused regression, static audit and any eventual portable full regression are engineering evidence only. They cannot substitute for real separated/generated audio quality, current-iPhone differential evidence or HQ PARITY judgment.

## Current conclusion

A05-A25 remain a coherent engineering checkpoint. A26 is safer than the previous v2 state because a future PASS now binds not only to the expected git commit and a SHA-256 manifest, but also to the actual HEAD-tracked Separation/Processing tree and clean tracked content state. The remaining A26 closure condition is execution of the hardened one-command audit on an executable exact Worker-branch checkout/CI runner. Until then, full A26 PASS is not claimed.
