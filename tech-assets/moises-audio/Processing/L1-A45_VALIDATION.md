# L1-A45 Validation — Provider Task Identity / Restart-Safe Advanced Observation

State: **COMPLETED_NON_PARITY**

## Why this Wave existed

A44 moved AudioShake advanced request validation ahead of source IO, cost reservation and media upload. A45 audited the other side of the production boundary: whether an observed provider result is provably the same Task that Lane 1 created and whether a process restart can continue observing an already-created advanced Task without unrelated model-discovery availability.

The current AudioShake Get Task API documents `GET /tasks/{id}` and a 200 response containing its own `id`; both identify the unique Task. The response also carries that Task's targets and output links. Before A45, `AudioShakeClient.get_task_state(task_id)` parsed the response but did not compare response `id` with the requested path id.

## Concrete pre-fix gaps

1. **Task identity was not bound at the low-level read boundary.** A syntactically valid payload for another Task could be accepted after requesting `/tasks/<expected>`.
2. **Duplicate provider model target rows were accepted by `parse_task_state`.** They could distort target cardinality/progress and make output identity ambiguous.
3. **Multiple WAV outputs for one completed target were reduced to the first link.** Lane 1 requests one WAV per separation target, so silently choosing one is weaker than fail-closed behavior.
4. **Fresh advanced adapters coupled existing-Task observation to `GET /models`.** After relaunch, an existing Task could become unobservable if model discovery was temporarily unavailable or if account access changed after Task creation.

## Production changes

### `Separation/Server/audioshake_api.py`

- `get_task_state()` now requires parsed response `task_id == requested task_id`; mismatch raises `AUDIOSHAKE_TASK_ID_MISMATCH`.
- task-state parsing rejects duplicate target models with `AUDIOSHAKE_TARGET_MODEL_DUPLICATE`.
- a completed target requires exactly one WAV output; multiple WAV outputs raise `AUDIOSHAKE_WAV_OUTPUT_AMBIGUOUS`.
- WAV output URLs must be HTTPS and have a hostname.

### `Separation/Server/canonical_advanced_provider.py`

- canonical observation independently requires raw provider `task_id == requested task_id`; mismatch raises `SEP_ADV_TASK_ID_MISMATCH`.
- duplicate provider target models are rejected before canonical role mapping.
- provider-model -> canonical-role identity for **existing Task observation** is built from the checked-in role catalog, not from the subset currently enabled by live account discovery.
- `get_task_state()` no longer calls `_refresh_maps()` / `GET /models` before polling an already-created Task.
- **New Task** preflight/create still uses live `GET /models` and refuses account-disabled models. This intentionally separates creation authorization from durable interpretation of an already-authorized Task.

This means a restart can still map an existing `keys` output to canonical `piano_keys` even if current account access later reports `request_access` or model discovery is temporarily unavailable. Unknown provider output models continue to fail closed.

## Regression coverage

Committed formal repository tests:

- `Separation/Tests/test_a45_provider_task_identity.py`: **13 cases**
- `Separation/Tests/test_a45_dependency_binding.py`: **6 cases**
- total new/updated A45 formal checks: **19**

Coverage includes exact/mismatched Task identity, duplicate targets, ambiguous WAV outputs, malformed HTTPS output, canonical mismatch/missing identity, duplicate provider target mapping, restart observation with model-discovery failure, account-access change after Task creation, live-discovery requirement for new Task preflight, unknown future model fail-closed and dependency/AST binding.

An interface-compatible focused boundary harness executed **12/12 PASS**. It is not an exact repository-native checkout and is recorded only as focused evidence.

## Exact audit state

During the prior A44 Wave, HQ Epoch45 integrated Lane 1 through A42 and ran the A26 exact checkout audit for Worker A42 tip `6acb782a35187ad8765060f89ceb791ef0304e1f`:

- Run `33036684021`
- Job `98400764989`
- conclusion: SUCCESS

That proves the historical A42 checkpoint only. A43, A44 and A45 were added afterward. The HQ workflow is still pinned to A42 at the time of this Wave. Therefore the exact final-A45 full discovery/dependency audit is **NOT_OBSERVED**, A26 remains open for the current tip, and no current-tip exact PASS is claimed.

The local execution environment still cannot resolve `github.com` for exact checkout (`Could not resolve host: github.com`). This is not reclassified as a test PASS.

## PARITY boundary

A45 is direct correctness/recovery work for P003/P004/P005/P020, but it does **not** promote any PARITY row. Missing evidence still includes:

- approved production credentials/commercial gate,
- rights-cleared real-audio live separation,
- actual advanced account model availability,
- separation quality/artifact/latency A/B,
- current-iPhone runtime/resource behavior,
- current-Moises differential evidence.

`P003/P004/P005/P020` therefore remain **MISSING**.

## HQ integration requirements

1. Preserve low-level response Task identity binding and canonical identity recheck.
2. Preserve restart-safe separation of concerns: live discovery authorizes **new Task creation**; static catalog identity interprets **existing Task output**.
3. Production output collection must continue comparing returned canonical target set with the persisted requested role set before commit.
4. Retarget the exact A26 workflow to the final Worker branch HEAD after this A45 status checkpoint and require all A26 gates PASS with zero unittest failures/errors before current-tip closure.
5. Do not promote P003/P004/P005/P020 from A45 lane-local correctness evidence alone.
