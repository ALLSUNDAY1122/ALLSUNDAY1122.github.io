# L1-A32｜Provider Delete Reconciliation Crash-Atomic Watermark

State: `COMPLETE_NON_PARITY`

Parity claim: `NONE`

## Why this Wave existed

A29 added hash-bound provider-delete observation reconciliation, A30 made persisted observations resumable after process restart, and A31 added monotonic timestamp ordering. One crash window remained: registry mutation could complete and the process could terminate before the ledger event was changed from `observed_not_applied` to `applied`.

For a non-terminal observation this meant the registry could already contain a newer provider observation while the ordering ledger did not yet recognize that observation as a watermark. An older observation arriving before resume could therefore transiently roll registry state backward.

## Implementation

`Separation/Server/provider_delete_reconciliation.py` is now `L1-A32-v1`.

The reconciliation ledger adds a durable `applying` state. The sequence for a valid observation is now:

1. append immutable hash-bound observation as `observed_not_applied`;
2. evaluate stale/equal-epoch ordering under the one-host application lock;
3. validate the observation against the current privacy registry object hash, delete reservation and terminal-state rules;
4. durably transition the receipt to `applying`;
5. mutate the privacy registry;
6. durably transition the receipt to `applied`.

Both `applying` and `applied` receipts are ordering watermarks. Therefore a process failure after step 4 or step 5 cannot permit an older observation to cross the newer timestamp. `resume_pending` treats both `observed_not_applied` and `applying` as resumable.

Malformed observations do not receive an `applying` watermark. In particular, a wrong provider-object hash with an arbitrarily high timestamp fails registry binding validation first and remains non-authoritative pending evidence.

The ledger also enforces monotonic application-state transitions. A finalized `applied` or `superseded_stale` receipt cannot be moved back into an in-flight state.

`snapshot()` now exposes `inflight_observation_count`; any `applying` receipt keeps `reconciliation_required=true`.

## Focused verification

The exact remote implementation blob is `bc6a3c202ff20caf527d9a22f68f00214c6fe68d`. A local reconstruction with that exact git blob SHA was syntax-compiled and executed through the A32 focused interface-compatible harness.

Observed result:

- A32 crash-consistency focused harness: **8/8 PASS**
- failures: **0**
- errors: **0**
- exact remote implementation `py_compile`: **PASS**

Covered cases:

- crash after registry mutation but before final ledger commit;
- crash after `applying` durability but before registry mutation;
- stale rollback prevention while a newer receipt is only `applying`;
- wrong-hash high-epoch evidence cannot become a watermark;
- forbidden finalized-state rollback;
- equal-epoch equivalent in-flight convergence;
- equal-epoch conflict fail-closed behavior;
- concurrent reverse/out-of-order delivery.

Repository regression added:

`Separation/Tests/test_provider_delete_reconciliation_crash_atomicity.py`

Machine-readable evidence:

`Processing/Tests/L1-A32_RECONCILIATION_CRASH_ATOMICITY_MATRIX.json`

## Limits

This remains a **single-host** safety mechanism. POSIX `flock`, durable JSON replacement and an application watermark do not provide multi-host distributed consensus, CAS, fencing or shared transactional authority.

A32 does not contact a provider status endpoint and does not invent provider deletion semantics. Authoritative provider/API/console/support observations remain external/private inputs.

A32 does not prove actual current-iPhone deletion UX, integrated project/account deletion, real provider retention behavior, P024 PARITY, or any other PARITY row.

## A26 remains open

The current Wave remains `L1-A26｜Lane 1 Full Regression / Dependency Closure Audit` because an executable exact full Worker checkout is still unavailable from this session. At the beginning of A32, `git ls-remote` again failed with:

`Could not resolve host: github.com`

Therefore no exact-current-branch unittest discovery or full dependency-audit PASS is claimed. A26 must still be executed on the then-current final Worker tip using:

`Separation/Evaluation/lane1_dependency_audit.py --expected-git-head <exact final Worker branch tip>`

and archived only when `overall_state=PASS`, `git_head_binding.state=PASS`, and `owned_source_snapshot.state=PASS` are genuinely observed.
