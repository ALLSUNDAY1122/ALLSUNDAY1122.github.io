# L4-W43｜Physical Evidence Anchor Ledger Runbook

## Purpose

W43 adds a durable local journal above W42 external-anchor verification. It preserves accepted W42 anchor receipts and destination certificates across relaunches, detects local sequence rollback/forks/corruption, and exports a deterministic ledger snapshot for HQ.

This is **NON_PARITY** integrity infrastructure. It does not prove physical-iPhone origin, product quality, trusted time, signature authority, or any PARITY row.

## Storage layout

For `ledgerID`:

```text
anchor-ledgers/<ledgerID>/
  W43_LEDGER_HEAD.json
  .W43_PENDING.json                 # exists only during an interrupted append
  records/
    00000000000000000001-<root16>.json
    00000000000000000002-<root16>.json
    ...
```

Records are immutable. `W43_LEDGER_HEAD.json` is the only moving committed pointer and is written with Foundation atomic replacement. Before any record/HEAD change W43 writes `.W43_PENDING.json`.

## Accepted input

Each append requires both:

1. a valid W42 `AnalysisPhysicalEvidenceAnchorReceipt`, and
2. the matching W42 `AnalysisPhysicalEvidenceDestinationVerificationCertificate`.

W43 independently recomputes both W42 roots and requires exact equality across:

- anchor ID and sequence,
- anchor receipt root,
- publication ID,
- transfer ID,
- W27/W38/W40/W41 expected roots,
- destination recomputed W27/W38/W40/W41 roots,
- exact W39 run / workload-execution / W39-root inventory,
- W42 limitation set,
- destination certificate root.

A stale or structurally forged certificate is rejected before journal mutation.

## Monotonic rules

The local ledger is genesis-based:

- first accepted sequence must be `1` and have no predecessor anchor-receipt root;
- each next sequence must be exactly `latest + 1`;
- its W42 predecessor anchor-receipt root must equal the latest accepted receipt root;
- its W43 record predecessor root must equal the latest W43 record root;
- the same latest sequence with byte-equivalent receipt/certificate is idempotently accepted;
- any lower sequence is rejected as rollback;
- same latest sequence with different roots is rejected as sequence reuse;
- sequence gaps and predecessor forks fail closed.

## Root chain

Each record root binds:

- ledger ID,
- anchor ID,
- sequence,
- W42 anchor-receipt root,
- W42 destination-certificate root,
- predecessor W43 record root.

The ledger root binds the ordered record summaries, including each immutable relative path and predecessor root. Any receipt, certificate, path, record root, or predecessor mutation changes the ledger root.

## Crash / relaunch recovery

### Pending marker only

If a crash occurs after `.W43_PENDING.json` but before the record exists, relaunch validates the marker against the committed HEAD, materializes the exact declared record, rebuilds HEAD, reads it back, then removes the marker.

### Record written, HEAD not advanced

If the declared record exists and exactly matches the pending marker, relaunch advances HEAD and removes the marker.

### HEAD advanced, marker not removed

If HEAD already declares the exact pending candidate and the immutable record matches, relaunch removes only the stale marker.

### Ambiguous state

W43 preserves state and fails closed when the pending marker is corrupt/rebound, the candidate record differs, predecessor roots do not match, or the committed ledger inventory is inconsistent.

A record that exists without a pending marker and is not declared by HEAD is an orphan and is **not** auto-adopted.

## Relaunch integrity checks

Every open/export validates:

- regular non-symlink files only;
- exact HEAD-declared record inventory;
- no undeclared regular files;
- contiguous sequence from genesis;
- W42 receipt chain;
- W43 record-root chain;
- full receipt/certificate semantic binding;
- recomputed record roots;
- recomputed ledger root;
- HEAD latest fields matching the last record.

## HQ export

`AnalysisPhysicalEvidenceAnchorLedgerStore.exportSnapshot(...)` returns a deterministic snapshot containing ledger ID, anchor ID, ordered record summaries, current ledger root, and explicit NON_PARITY limitations.

HQ should independently preserve the latest ledger root outside this local directory. Without an independent external copy/signature/timestamp, a coordinated rollback of the entire local ledger can still appear internally valid.

## Limitations

- Local SHA-256 chaining is not a signature or trusted timestamp.
- Foundation `.atomic` write behavior is not physical-device/APFS crash-durability evidence.
- W43 does not prove that W42 evidence originated on a selected physical iPhone.
- P009/P011/P013/P016/P021 remain subject to their real-audio/current-iPhone/physical-device gates.
- The authoritative rollback boundary remains an HQ-held external root or external signature/timestamp authority.
