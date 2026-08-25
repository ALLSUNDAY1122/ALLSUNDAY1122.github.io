# L4-W43 Validation

## Scope

W43 implements a durable local ledger above W42 external-anchor verification. It persists accepted W42 anchor receipts and destination certificates as immutable records, chains them by receipt root and W43 record root, updates one committed HEAD atomically, and recovers interrupted appends via a pending marker.

This file records engineering validation only. It is **NON_PARITY**.

## Canonical refresh before implementation

Observed before W43 work:

- Notion still defines v4 Four Autonomous Independent Lanes / Late Integration.
- Worker 4 remains owner of `Analysis/**`, `Package.swift`, `Tests/**`, `iOS/**` and worker-4 status only.
- PARITY rows P009/P011/P013/P016/P021 remain `MISSING`.
- HQ Integration PR #4431 is open/draft/mergeable.
- Epoch 28 is canonical with Run #209 SUCCESS 333/333; Lane 4 remains canonical through W40, W41+ post-Epoch28.
- Worker branch at W42 completion `d02ce5892b243f890b628d1218631e5ff015c79a` was identical to remote.
- Frozen base `be1c84314db182d6eee5097de34e017af1a4a7de` -> Worker branch was ahead 442 / behind 0.

No rebase or destructive synchronization was performed.

## Implementation checks

W43 production code enforces:

- valid W42 receipt and destination-certificate pair before mutation;
- recomputation of W42 receipt and certificate roots;
- exact publication/transfer/run/root binding from certificate to receipt;
- first local sequence exactly 1 with no predecessor receipt;
- every next sequence exactly latest + 1;
- exact previous W42 receipt root;
- exact previous W43 record root;
- immutable deterministic record paths;
- idempotent reacceptance only for an exact duplicate of the current latest verification;
- lower sequence rejection as rollback;
- same-current-sequence different-root rejection;
- sequence-gap rejection;
- forked predecessor rejection;
- pending marker written before record/HEAD mutation;
- recovery from pending-only, record-before-HEAD and HEAD-before-marker-removal states;
- corrupt/rebound pending state preserved and rejected;
- undeclared orphan record not auto-adopted;
- regular non-symlink files only;
- exact committed file inventory on each reopen/export;
- record-root and ledger-root recomputation;
- deterministic snapshot export for HQ.

## Durable XCTest source

Added:

`Tests/MoisesAudioCoreTests/AnalysisPhysicalEvidenceAnchorLedgerTests.swift`

Cases cover:

1. two-record append, relaunch and deterministic snapshot;
2. exact latest duplicate is idempotent;
3. older receipt rejected as rollback;
4. same latest sequence with changed root rejected;
5. forked predecessor receipt rejected;
6. stale/forged certificate rejected before journal mutation;
7. pending-marker-only crash recovery;
8. record-written-before-HEAD crash recovery;
9. corrupt pending marker preserved and rejected;
10. orphan record without pending marker rejected after relaunch;
11. unexpected ledger file rejected.

Fresh full Worker-branch SwiftPM/XCTest was attempted but is `NOT_OBSERVED` because:

```text
fatal: unable to access 'https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io.git/': Could not resolve host: github.com
```

No GitHub commit status checks were present on the W43 Package commit.

## Swift filesystem mirror

Environment:

```text
Swift version 6.2.1
Target: x86_64-unknown-linux-gnu
```

Compilation:

```text
swiftc -warnings-as-errors W43Mirror.swift
PASS
compile_elapsed = 1.01 s
compile_max_rss = 172636 kB
```

Runtime:

```text
PASS fs_checks=732
run_elapsed = 2.14 s
run_max_rss = 22272 kB
```

The mirror used real temporary directories/files and alternated interruption points between pending-marker-only and record-written-before-HEAD. It also exercised duplicate acceptance, rollback, same-sequence root reuse, predecessor fork and unexpected-file fail-close.

This is a source-shaped Linux engineering mirror, not canonical Worker XCTest or APFS evidence.

## SHA-256 ledger-chain mirror

Python `hashlib.sha256` independently mirrored W43 record/ledger binding.

```text
PASS packages=30000 mutations=180000
elapsed = 10.77 s
max_rss = 110744 kB
```

Verified mutation dimensions:

- W42 anchor receipt root;
- W42 destination certificate root;
- W43 record root;
- immutable record relative path;
- predecessor W43 record root;
- record-level predecessor binding.

Record-order canonicalization was stable.

## Remaining gaps

- No physical iPhone/APFS crash-durability evidence.
- No selected Xcode/Apple ARM compile for W41-W43.
- No genuine Lane-2 bounded decoder execution.
- No physical RSS/thermal/battery/cancellation or repeated W24 acceptance.
- No rights-cleared current-iPhone differential for P009/P011/P013/P016.
- A coordinated replacement of the entire local W43 ledger can still rollback to an internally valid old ledger unless HQ independently preserves/signs/timestamps the latest W43 ledger root.
- W43 hashes are not signatures, trusted timestamps, Secure Enclave proofs or Apple attestation.

Therefore no PARITY state is changed.
