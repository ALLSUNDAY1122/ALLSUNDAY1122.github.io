# L1-A29 Validation | Provider Delete Interruption / Reconciliation

State: COMPLETE_NON_PARITY

## Goal

Close the remaining A28 recovery gap where a provider delete may have been durably reserved and then the process can terminate before the external side effect is conclusively recorded. The safe behavior is not to blindly replay the delete. A later authoritative observation must be bound to the registered provider object and durably reconciled.

## Implementation

- `Separation/Server/provider_delete_reconciliation.py`
  - `ProviderDeletionObservation` validates logical job ID, provider object hash, observation state, source class, private authority-reference SHA-256 and observation epoch.
  - `AtomicDeletionReconciliationLedger` persists only hashed observation identifiers and authority references under POSIX `flock`, fsync and atomic replace.
  - observation receipts are deterministic SHA-256 values, making repeated/concurrent identical observations idempotent.
  - ledger uses a two-stage `observed_not_applied -> applied` state so a crash or rejected registry mutation cannot be confused with successful reconciliation.
  - `ProviderDeletionReconciler` requires a prior durable provider-delete reservation and verifies the observed object hash against the privacy registry before changing provider deletion state.
  - confirmed terminal erasure state is monotonic; a later `present`/`unknown` observation cannot downgrade it.
  - the module never invokes `delete_asset` or `delete_task`; it is observation-only recovery and therefore cannot blindly replay an ambiguous external side effect.

- `Separation/Tests/test_provider_delete_reconciliation.py`
  - ambiguous in-flight delete -> authoritative `confirmed/not_found` reconciliation
  - no-reservation rejection
  - object-hash mismatch rejection
  - `present` remains privacy-incomplete
  - terminal-state downgrade rejection
  - deterministic/idempotent receipt behavior
  - failed registry application remains `observed_not_applied`
  - documented-expiry source restrictions
  - raw provider ID / URL exclusion from durable ledger
  - concurrent duplicate observation collapse
  - corrupt-ledger fail-closed behavior

## Focused observation

A portable interface-compatible harness exercising the A29 reconciliation logic produced `11/11 PASS`.

`provider_delete_reconciliation.py` and `test_provider_delete_reconciliation.py` both passed Python `py_compile` before commit.

This is focused engineering evidence only. The complete exact Worker-branch test suite has not been executed in the current environment because A26 still lacks an executable exact checkout/CI runner. A29 therefore does not claim that unavailable execution.

## Safety semantics

1. Delete intent/reservation remains durable before any provider side effect, as established by A28.
2. If the process dies after reservation, restart does **not** repeat provider deletion automatically.
3. Reconciliation requires a separately observed provider state tied to the registered provider object by SHA-256.
4. `confirmed` / `not_found` cannot be inferred from documented expiry alone.
5. Documented expiry may represent only the asset expiry state, never task deletion confirmation.
6. An observation is durably recorded before registry application. Until registry application succeeds, the ledger explicitly says `observed_not_applied`.
7. Durable public evidence contains hashes and controlled state only; no raw provider identifiers, user content paths, URLs, prompts or audio are stored.
8. A29 remains single-host file-backed. It does not weaken A27's prohibition on treating POSIX `flock` as distributed synchronization.

## PARITY boundary

A29 is `NON_PARITY_EVIDENCE_ONLY` and `parity_claim=NONE`.

It improves P024/P020/P025 safety and recovery readiness, but cannot promote those rows. Final PARITY still requires current-iPhone integrated deletion/recovery UX, real provider/runtime evidence, production privacy behavior and HQ judgment.

## Remaining gates

- A26 exact checkout command must be run against the then-current Worker branch tip after A29 and must produce full PASS evidence.
- Real provider/console/support observations are external/private inputs and are not fabricated here.
- Multi-host independent writers still require the A27 shared transactional backend and concrete adapters.
- P003/P004/P005/P020/P021/P024/P025 remain canonical `MISSING` until HQ obtains the required live/device/reference evidence.
