# L1-A26｜Lane 1 Full Regression / Dependency Closure Audit

Status: `IN_PROGRESS_EXACT_CHECKOUT_AUDIT_PENDING`  
PARITY claim: `NONE`

## Dependency repair already closed

A26 previously found a real A24→A25 interface drift. `A24RetentionGateway` preserves final A24 delete/refund/runtime-erasure semantics while satisfying the A25 facade seam. The focused gateway regression is observed `12/12 PASS`.

Final A24 source readback also confirms physical generated-artifact reachability uses **both all manifests and all active pointers** and fails closed on corrupt/symlink references before GC/delete. This prevents an active shared content-addressed object from being removed merely because a historical manifest is damaged or absent.

## Why the full audit is still not marked PASS

The mandatory full runner is `Separation/Evaluation/lane1_dependency_audit.py`.

The current execution container still has no exact Worker-branch checkout and cannot resolve `github.com`, so a full checkout cannot be cloned into the executable environment. No CI run exists that can substitute for the missing full execution. Therefore the following remain `NOT_OBSERVED`:

- full Lane 1 unittest discovery;
- full Lane 1 Python py_compile;
- full owned JSON syntax audit;
- full Draft 2020-12 schema self-validation;
- one-command `overall_state=PASS` on the exact Worker branch.

A26 is intentionally not placed in `completed_waves` until that execution exists.

## A26 v2 provenance hardening

The previous runner could report test results without strongly proving which complete Lane 1 byte snapshot produced them. That is now hardened.

### Exact git HEAD binding

The closure command now requires:

`--expected-git-head <exact 40-hex final Worker branch tip>`

The runner executes `git rev-parse HEAD` from the repository root. `overall_state=PASS` is impossible when:

- the expected head is absent;
- the expected head is malformed;
- `.git` / git HEAD is unavailable;
- the actual checkout HEAD differs from the supplied Worker-branch tip.

This blocks reuse of a PASS report from an older checkout or another branch.

### Deterministic owned-source snapshot

`Separation/Evaluation/lane1_source_snapshot.py` hashes every durable regular file beneath:

- `Separation/**`
- `Processing/**`

For every file the report records relative repository path, byte count and SHA-256, then derives one deterministic `source_snapshot_sha256` over the ordered manifest.

Fail-closed rules:

- a symlink anywhere in the owned source snapshot is rejected;
- a missing owned scope is rejected;
- an unreadable/stat-failing source file is rejected;
- only runtime-generated cache/temp/lock artifacts are excluded automatically;
- an audit output file may be explicitly excluded only when it is inside the Lane root, preventing a report from hashing itself;
- files outside Separation/Processing do not influence the Lane-owned snapshot.

The snapshot is evidence of exact owned bytes. It does not make a PARITY claim.

### Report schema

`Separation/Evaluation/schemas/lane1-dependency-audit-report-v2.schema.json` requires both:

- `git_head_binding.state=PASS`; and
- `owned_source_snapshot.state=PASS`

whenever `overall_state=PASS`.

A PASS-shaped report that lacks either exact checkout binding or source-snapshot evidence is therefore schema-invalid or cannot be emitted by the v2 runner as PASS.

## Focused provenance validation

Because the full Worker checkout remains unavailable, only the new provenance logic was executed in an isolated local fixture. This is explicitly not a substitute for the full audit.

Observed focused results:

- deterministic source-snapshot behavior: `7/7 PASS`;
- git-head/source-binding behavior: `5/5 PASS`;
- v2 report JSON Schema self-check: `PASS`.

Cases cover deterministic repeatability, mutation sensitivity, non-owned/cache exclusion, explicit report exclusion, outside-root exclusion rejection, symlink rejection, missing-scope rejection, exact git HEAD success, mismatched/missing/malformed expected HEAD rejection, and source-snapshot emission.

## Full one-command audit contract

On an executable exact Worker checkout, run the final A26 runner with the final branch tip supplied explicitly. The runner then performs:

1. exact git HEAD verification;
2. complete owned `Separation/**` + `Processing/**` source snapshot;
3. Python `py_compile` for Lane 1 Server/Evaluation/tests;
4. full `unittest discover` for `Separation/Tests/test_*.py`;
5. owned JSON syntax validation;
6. Draft 2020-12 schema self-validation;
7. A21-A26 critical dependency-surface checks;
8. stable error-code inventory.

Completion requires archived v2 evidence with `overall_state=PASS`, `git_head_binding.state=PASS`, and `owned_source_snapshot.state=PASS` at the exact final Worker-branch tip.

## PARITY boundary

No PARITY row is promoted. P003/P004/P005/P020/P021/P024/P025 remain canonical `MISSING` pending real runtime/current-iPhone/real-audio/device/HQ gates.

A26 dependency repair, source provenance, focused regression, static audit and any eventual portable full regression are engineering evidence only. They cannot substitute for real separated/generated audio quality, current-iPhone differential evidence or HQ PARITY judgment.

## Current conclusion

A05-A25 remain a coherent engineering checkpoint. A26 is materially safer than before because a future full PASS can now be tied to both the exact git commit and exact Lane-owned file bytes. The only remaining A26 closure condition is execution of that hardened one-command audit on an executable exact Worker-branch checkout/CI runner.
