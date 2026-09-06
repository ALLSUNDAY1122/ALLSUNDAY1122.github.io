# L1-A35｜Provider Delete Reconciliation Store Topology Coverage

State: `COMPLETE_NON_PARITY`

PARITY claim: `NONE`

## Why this wave exists

A27 introduced a fail-closed topology contract for Lane 1 file-backed mutation stores. At that checkpoint it covered A09 privacy, A16 reconnect, A23 variant and A24 retention stores. A29-A34 subsequently added a durable provider-delete reconciliation ledger plus same-host application locking, but that new mutation store was not added to the A27 built-in deployment inventory.

That omission matters operationally: a deployment preflight that does not know a store exists cannot truthfully reject a multi-host deployment for that store.

A35 closes that inventory gap. It does not add distributed synchronization.

## Implementation

`Separation/Server/mutation_topology.py` is now `L1-A35-v1` and includes:

- built-in store `a29_provider_delete_reconciliation_ledger`;
- `local_serialization=posix_flock`;
- `single_host_safe=true`;
- `shared_authority_adapter=false`;
- risk classification `reconciliation_watermark_race`;
- an explicit `EXPECTED_BUILTIN_STORE_IDS` inventory containing all five current Lane 1 file-backed mutation stores;
- fail-closed `L1A35_BUILTIN_STORE_INVENTORY_MISMATCH` if a required built-in store disappears from the preflight inventory;
- topology snapshots that publish the current store inventory alongside per-store decisions.

The reconciliation profile intentionally does not claim that A29-A34's POSIX flock, atomic replace, application lock, `applying` watermark or ordering rules are valid across hosts.

## Multi-host rule

For `a29_provider_delete_reconciliation_ledger`:

- `single_host` -> PASS under current same-host serialization;
- `multi_host` with no shared mutation authority -> `FAIL_CLOSED / L1A27_SHARED_AUTHORITY_REQUIRED`;
- `multi_host` with the capability labels but no concrete reconciliation-store adapter -> `FAIL_CLOSED / L1A27_SHARED_AUTHORITY_ADAPTER_NOT_IMPLEMENTED`.

A real multi-host implementation still requires a concrete shared transactional authority with all of:

1. atomic compare-and-swap;
2. durable commit;
3. monotonic fencing tokens;
4. read-after-write consistency;
5. a real store adapter using that authority.

Capability declarations alone are not accepted as implementation.

## Regression

`Separation/Tests/test_mutation_topology.py` now contains 12 focused tests covering:

- all file-backed stores passing the current single-host contract;
- A09 privacy serialization status;
- explicit presence and safety profile of the A29 reconciliation ledger;
- reconciliation ledger single-host PASS;
- reconciliation ledger multi-host fail-closed without authority;
- reconciliation ledger multi-host fail-closed when an authority is declared but no adapter exists;
- incomplete authority rejection;
- future adapter positive control only with a full authority contract;
- full topology snapshot inventory and multi-host rejection;
- required-store inventory omission fail-closed;
- unknown store and invalid topology rejection.

Observed focused result against the exact bytes later written to the Worker branch:

- `py_compile`: PASS
- `unittest`: 12/12 PASS
- failures: 0
- errors: 0

Remote blob binding after write:

- `mutation_topology.py`: `1b9d5bfce2d0d63448cbab164bd354184082ca18`
- `test_mutation_topology.py`: `10bf3aeb3607626533d5de0e6d3fb00643a5247f`

These match the git-blob hashes of the locally executed focused validation inputs.

## A26 remains open

At the start of this wave, exact checkout access was retried with `git ls-remote` against `moises/wp1-separation-processing` and again failed with:

`Could not resolve host: github.com`

Therefore A35 does not claim an exact current Worker-branch full-suite PASS, and `L1-A26` must remain current/incomplete until the hardened dependency audit is actually run on an executable exact checkout/CI runner.

When that becomes available, A26 must use the then-current final Worker tip, not an older A26-A34 commit.

## Deployment integration request

HQ/App owns the actual deployment entrypoint. At late integration it must invoke, or equivalently enforce, the Lane 1 topology preflight before enabling multiple writers. A35 means that enforcement must include the provider-delete reconciliation ledger, not only the four stores known at A27 time.

## PARITY boundary

A35 is topology/preflight safety evidence only. It does not change or support promotion of `P003`, `P004`, `P005`, `P020`, `P021`, `P024` or `P025` by itself. Real current-iPhone, real-audio, live provider, integrated device and HQ evidence remain required.
