# L1-A38 Validation｜Reconciliation Composite Topology Preflight

State: `COMPLETED_NON_PARITY`

## Goal

A37 introduced a second durable file-backed reconciliation authority surface: the equal-epoch conflict-decision sidecar. A35 topology evidence only named the privacy registry and provider-delete reconciliation ledger. That left a deployment-safety gap: an operator could correctly preflight the ledger while silently omitting the A37 decision store, even though the decision store also uses host-local POSIX flock/atomic-replace semantics and is not safe for independent multi-host writers.

L1-A38 closes that lane-local gap without claiming distributed synchronization.

## Implementation

`Separation/Server/mutation_topology.py` is upgraded to `L1-A38-v1`.

Changes:

- Adds builtin store `a37_conflict_decision_store`.
- Classifies its risk as `adjudication_decision_race`.
- Keeps `shared_authority_adapter=false`; capability declarations alone therefore cannot make it multi-host safe.
- Defines a fixed reconciliation composite containing:
  - `a09_privacy_registry`
  - `a29_provider_delete_reconciliation_ledger`
  - `a37_conflict_decision_store`
- Adds `reconciliation_topology_snapshot(...)` so all three authorities can be assessed together.
- Adds `assert_reconciliation_topology_safe(...)` for HQ/App deployment preflight integration.
- Rejects unknown authority-map stores and reconciliation inventory shrinkage.

## Fail-closed properties

1. Single-host POSIX-flock-backed stores remain accepted only as single-host engineering safety.
2. Multi-host use without shared authority fails with `L1A27_SHARED_AUTHORITY_REQUIRED`.
3. Merely declaring atomic CAS / durable commit / fencing / read-after-write capabilities still fails because concrete adapters are not implemented.
4. Removing the A37 decision store from builtin inventory fails closed.
5. Shrinking the reconciliation composite fails closed.
6. `lane1_dependency_audit.py` is upgraded to `L1-A26-v4` and now semantically requires the A38 composite contract and its regression tokens.
7. Removing A38 contract semantics, regression semantics, or both together cannot false-green the dependency audit.

## Validation

Isolated interface-compatible execution:

- `test_mutation_topology.py`: 20/20 PASS.
- `test_lane1_dependency_audit_safety_surfaces.py`: 14/14 PASS.
- Combined focused run: 34/34 PASS, 0 failures, 0 errors.
- Candidate Python sources passed `py_compile` before remote write.

Durable matrix:

- `Processing/Tests/L1-A38_RECONCILIATION_COMPOSITE_TOPOLOGY_MATRIX.json`

## Important non-claims

This does **not** establish product PARITY, provider truth, current-iPhone behavior, or distributed safety. No concrete shared transactional authority adapter exists yet. POSIX flock, atomic rename, capability labels, decision sidecars, watermarks and preflight inventory are insufficient for independent multi-host writers.

HQ/App must still invoke `assert_reconciliation_topology_safe(...)` or an equivalent integrated contract at the deployment/composition boundary. Worker 1 does not edit `Shared/**` or `App/**`.

The exact final-tip `L1-A26` one-command full-checkout audit remains pending on an executable Worker checkout/CI runner and must not be marked complete from this focused evidence.
