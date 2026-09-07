# L1-A27｜File-Backed Mutation Store Deployment Topology Safety

Status: `COMPLETE_NON_PARITY`

PARITY claim: `NONE`

## Why this Wave exists

A26 remains open only because the hardened full dependency audit still cannot be executed on an exact Worker-branch checkout in the available execution environment. The v4 operating model permits additional meaningful Lane-local hardening rather than falsely declaring A26 complete or waiting for an external execution capability.

The Worker status also carried a known deployment gap: file-backed mutation stores require equivalent shared transactional coordination when deployed with multiple independent hosts/writers.

Source readback confirmed this is not merely theoretical:

- A16 `AtomicDurableJobRegistry` uses POSIX `flock`, which serializes cooperating writers only where that lock is actually shared and cannot be treated as a distributed transaction primitive.
- A23 `GeneratedStemVariantStore` uses POSIX `flock` around content-addressed object / manifest / active-pointer mutation and therefore has the same cross-host boundary.
- A24 generated-stem retention state uses local file locking for destructive delete/refund/orphan-recovery state mutation and must not be treated as cross-host safe.
- A09 `AtomicPrivacyRegistry` performs file-backed load / read-modify-write / atomic replace without a transaction lock spanning the full mutation. It is therefore catalogued as insufficient even for concurrent same-host writers until the RMW path is serialized or moved behind a transactional authority.

## Implemented contract

`Separation/Server/mutation_topology.py` provides a strict deployment preflight contract rather than pretending to implement a distributed lock.

Built-in stores are classified by their actual current coordination boundary. The contract supports two declared topologies:

- `single_host`
- `multi_host`

For `multi_host`, a shared authority descriptor must provide all of:

- atomic compare-and-swap;
- durable commit;
- monotonic fencing tokens;
- read-after-write consistency.

Possessing those capability labels is still not enough. Each store must also have an actual `shared_authority_adapter`. Current A09/A16/A23/A24 file-backed implementations do not, so every built-in store fails closed for multi-host deployment even when a complete authority descriptor is supplied.

This prevents a configuration object from being mistaken for an implementation.

## Single-host boundary

A16/A23/A24 are classified as single-host-safe under their current POSIX-lock contract.

A09 is intentionally not. Its current privacy registry has no lock spanning the entire read-modify-write sequence, so the preflight returns:

`L1A27_SINGLE_HOST_SERIALIZATION_INSUFFICIENT`

This Wave does not conceal that defect by labelling atomic file replacement as transactional serialization.

## Focused validation

Observed in an isolated executable fixture using the authored implementation/test logic:

- focused topology regression: `8/8 PASS`;
- `mutation_topology.py` + `test_mutation_topology.py` py_compile: `PASS`.

Coverage includes:

1. single-host acceptance for A16/A23/A24;
2. single-host rejection for current A09 RMW;
3. multi-host rejection without shared authority;
4. rejection of incomplete authority capability sets;
5. rejection when authority capabilities exist but a store adapter does not;
6. positive future-adapter contract case;
7. truthful NON_PARITY topology snapshot;
8. unknown-store / invalid-topology rejection.

Matrix: `Processing/Tests/L1-A27_MULTI_HOST_COORDINATION_MATRIX.json`

## What this does not claim

This module is a Lane-local deployment safety preflight. It does not itself wire an App/HQ deployment entrypoint, does not provide distributed storage, and does not convert any existing file-backed store into a multi-host transactional store.

Therefore the actual production integration rule remains:

- do not deploy A09/A16/A23/A24 as independent multi-host writers until a real shared transactional backend plus store adapter exists;
- do not use POSIX `flock`, atomic rename, or a capability declaration as evidence of distributed correctness;
- A09 requires additional same-host RMW serialization hardening before its registry can be classified single-host concurrent-writer safe.

Those are engineering/deployment gates, not PARITY gates.

## A26 relationship

A26 is deliberately **not** completed by this Wave. Its exact-checkout full audit is still required. A27 adds new owned source and test bytes, so any eventual A26 closure audit must run against the then-current final Worker branch tip and include these files in the deterministic Separation/Processing snapshot and unittest discovery.

## PARITY boundary

P003/P004/P005/P020/P021/P024/P025 remain canonical `MISSING`. Synthetic topology tests and deployment preflight cannot substitute for real current-iPhone, real-audio, production-runtime, provider, or HQ parity evidence.
