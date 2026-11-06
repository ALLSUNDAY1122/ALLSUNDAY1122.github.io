# L1-A28 Validation — Privacy Registry Transactional Serialization Hardening

State: **COMPLETE_NON_PARITY**  
Owner: `LANE-1-SEPARATION-PROCESSING / Moises-Worker-1`  
Scope: `Separation/**`, `Processing/**` only  
PARITY claim: **NONE**

## Why this Wave existed

L1-A27 identified a concrete correctness gap in the A09 privacy registry: the old file-backed implementation performed `load -> modify -> save` as separate operations without one lock spanning the complete read-modify-write transaction. Atomic rename protected individual file replacement, but it did not prevent two same-host writers from loading the same prior state and overwriting each other's changes.

A26 remains independently open on its exact-checkout full-audit execution gate. Under the v4 autonomous-lane contract, that unavailable execution environment is not a reason to leave an actionable Lane 1 correctness defect unfixed.

## Implementation

`Separation/Server/privacy_retention.py` now provides a single-host transactional file store:

- `AtomicPrivacyRegistry._locked()` uses POSIX `flock(LOCK_EX)` and fails closed with `SEP_PRIVACY_LOCK_UNAVAILABLE` if that guarantee cannot be obtained.
- `mutate()` holds one lock across load, mutation validation and durable save.
- commit uses file `fsync`, atomic `os.replace`, then parent-directory `fsync`.
- registration and diagnostic updates are performed through `mutate()` rather than independent load/save calls.
- retention sweep reserves and confirms state with per-record atomic mutations.
- local artifact deletion remains outside the registry lock and is idempotent; a concurrent `ENOENT` race is treated as already-deleted success while other filesystem errors remain retryable failures.

Delete handling was also hardened around external side effects:

1. persist delete intent;
2. remove/confirm local artifact state;
3. atomically reserve the provider-delete operation once;
4. persist a non-confirmed `unknown_after_inflight` state before provider contact;
5. perform provider calls outside the local registry lock;
6. atomically persist final provider outcomes.

This prevents concurrent callers from duplicating provider delete calls and prevents a crash window from being misreported as confirmed erasure. Because there is no authoritative provider-delete reconciliation contract here, an ambiguous in-flight state is intentionally not blindly replayed.

## A27 topology contract update

`Separation/Server/mutation_topology.py` now records A09 as:

- `local_serialization = posix_flock`
- `single_host_safe = true`
- `shared_authority_adapter = false`

Therefore all current built-in Lane 1 file-backed stores can pass the **single-host** preflight, while **multi-host independent writers still fail closed** until a real shared transactional backend and concrete store adapters exist. POSIX flock is not presented as a distributed lock.

## Regression / edge evidence

Observed focused execution during this Wave:

- existing A09 privacy-retention regression: **25/25 PASS** on the A28 implementation before the final ENOENT micro-hardening;
- new concurrency regression: **5/5 PASS** before the final ENOENT micro-hardening, covering distinct registration, same-record diagnostic RMW, concurrent delete side-effect reservation, mixed registration/diagnostic mutation and topology behavior;
- A27 mutation-topology regression after the A09 profile update: **8/8 PASS**;
- A28 implementation/test set `py_compile`: **PASS** before the final ENOENT micro-hardening;
- final exact local-delete branch check after ENOENT hardening: **2/2 PASS** for an already-absent target and a normal existing target;
- a dedicated `test_local_delete_enoent_race_is_idempotent` regression was added to the repository after that edge was found.

The durable machine-readable case matrix is:

`Processing/Tests/L1-A28_PRIVACY_REGISTRY_SERIALIZATION_MATRIX.json`

## Commits in this Wave

- `d988607d273927f2aa6ef156c18812bebf806ed1` — serialize privacy registry mutations
- `faf855903743f719a1499648079892ed50c1115b` — mark privacy registry single-host serialized in topology contract
- `4ff5d4adbd2aa2cc4504904c7a5995a070942056` — update topology regression
- `322a618f2791961e741290dd1ceb23a5f685897c` — add privacy concurrency regression
- `39f398f36accf1ed8dd72be4f2c1443fbc3daa0b` — make concurrent local deletion idempotent
- `ee601f38dc04a5e97fa4056e36d55fb90830f3d6` — cover ENOENT delete race
- `a7b256caf315e9e5fd3be64fc2c80c3522606c39` — add A28 evidence matrix

## Limits / no false closure

A28 does **not** establish:

- distributed or multi-host transactional safety;
- a shared CAS/fencing backend for A09/A16/A23/A24;
- real current-iPhone deletion UX;
- real production provider deletion semantics;
- MOI-P024 PARITY;
- any other canonical PARITY row.

`L1-A26` also remains open. Because A28 changes owned bytes, its eventual full audit must execute against the **then-current exact Worker branch tip**, not an earlier A26/A27 SHA:

`Separation/Evaluation/lane1_dependency_audit.py --expected-git-head <exact final Worker branch tip>`

A26 may only close after an executable full checkout produces the required v2 audit report with `overall_state=PASS`, `git_head_binding.state=PASS`, `owned_source_snapshot.state=PASS`, and the HEAD-tree/worktree binding intact.
