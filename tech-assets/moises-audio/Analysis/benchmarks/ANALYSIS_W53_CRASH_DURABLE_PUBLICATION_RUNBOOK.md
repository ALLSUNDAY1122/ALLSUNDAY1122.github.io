# W53 Crash-Durable Bridge Consumption Runbook

## Scope

W53 hardens the W49-W52 bridge-consumption ledger publication order. It is custody/durability infrastructure only and remains NON_PARITY.

Canonical predecessor at implementation time is HQ Epoch 44 / Lane 4 W52. HQ Run `33030546532` passed SwiftPM `462/462` before W53.

## Publication contract

A normal append must execute in this order while the W51 per-ledger writer lease is held:

1. Encode the W49 pending marker.
2. Create a same-directory W53 temporary file with `O_EXCL | O_NOFOLLOW`.
3. Write every pending byte.
4. Sync pending file data. On Darwin, attempt `F_FULLFSYNC`; if unavailable, fall back to `fsync` and record the observed mode.
5. Atomically rename the temporary pending file to the canonical pending path.
6. `fsync` the ledger directory.
7. Encode the immutable W49 record.
8. Write/sync a same-directory temporary record, publish with collision-safe hard link, unlink the temporary name, then `fsync` the records directory.
9. Encode the new W49 head.
10. Write/sync same-directory temporary head, atomically rename to the canonical head path, then `fsync` the ledger directory.
11. Remove the pending marker and `fsync` the ledger directory again.
12. Securely reopen and verify the exact head/record chain.

W49/W50 record, ledger, checkpoint and handoff root payload formats are unchanged. W52 snapshot/receipt payload formats are unchanged.

## Interrupted temporary files

A process can terminate before a temporary name is removed. Reopen may tolerate only filenames matching `.w53-pub-*.tmp` when all of the following are true:

- regular file;
- not a symbolic link;
- still confined below the selected ledger root;
- within the appropriate record/head size bound;
- no more than 32 interrupted temporary files in a single controlled directory.

Interrupted temporary files never count as committed records. Unexpected names, symlink temps, non-regular temps or excess temp count fail closed.

## Selected physical iPhone probe

Use a semantic-integrated W53 build on the selected physical iPhone only. Simulator, Mac Catalyst and non-arm64 execution are invalid.

For each of the 12 cells (`pending`, `record`, `head`) × (`before data sync`, `after data sync before publish`, `after publish before directory sync`, `after directory sync`):

1. Use a unique ledger/probe/session identifier. Do not reuse a previous failed probe namespace.
2. Seed the ledger using a normal W53 durable append and securely reopen it.
3. Obtain/authorize the exact W52 quiescent pre-snapshot.
4. Call `AnalysisIOSBridgeDurabilityProbeCoordinator.makeTicket` with the exact candidate W48 certificate and current source/build/device identity.
5. Persist the complete ticket plus its root outside the mutable ledger directory before interruption testing.
6. Call `prepareInterruptedState` and record `observedSyncMode` exactly. Do not relabel `DARWIN_FSYNC_FALLBACK` as `DARWIN_F_FULLFSYNC`.
7. Continue only if status is `W53_INTERRUPTED_STATE_PREPARED_TERMINATE_OR_SUSPEND_NOW`.
8. Do not call ledger recovery in the same process after the prepared status. Isolate the app from other cooperating ledger writers.
9. Apply the intended external interruption mode: process termination first; separately exercise app background/suspension/relaunch. Controlled reboot/power-loss testing is a separate physical durability campaign and must only be used when operationally safe.
10. Relaunch the exact build on the same device/OS and call `reopenAfterRelaunch` with the retained ticket.
11. Preserve the reopen result, recovered snapshot, ticket root and current W52 checkpoint/handoff/receipt root outside the mutable ledger root.

## Expected reopen contract

- Pending-marker boundary: exact pre-append state.
- Immutable record before data sync: exact pre-append state.
- Immutable record after data sync but before publish: exact pre-append state.
- Immutable record after publish but before records-directory sync: exact pre **or** exact post state is acceptable after real power loss; mixed state is not.
- Immutable record after records-directory sync: exact post state.
- Head boundary: exact post state after W50 recovery, because pending and immutable record publication precede head publication.

Any mixed chain, unexpected sequence advance, wrong candidate certificate, changed prefix root, malformed temp topology, or corrupt head/record is a hard failure.

## Authorization rules

- A stale W52 pre-snapshot is not automatically retried. Re-observe and obtain a new authorization.
- A W53 probe ticket is bound to source revision, build identity, physical session, device model, OS version, pre-snapshot root and candidate W48 certificate root.
- Do not use a portable Linux result as proof of iPhone/APFS durability.
- Do not use successful fsync/F_FULLFSYNC execution as proof of Moises feature PARITY.
- Keep `MOI-P009/P011/P013/P016/P021` MISSING until their independent real-audio/current-reference/physical-performance gates pass.

## Evidence to retain

For every physical run retain:

- exact Worker/HQ integration SHA;
- Xcode/Swift version and build identity;
- physical iPhone model and iOS version;
- probe ticket JSON and ticket root;
- fault target and fault boundary;
- observed sync mode;
- interruption method;
- pre-snapshot root;
- recovered snapshot root;
- exact pre/post classification;
- W52 checkpoint/handoff/receipt roots;
- console/device logs sufficient to establish that no recovery was called between prepared state and external interruption.

Only HQ Late Integration may decide whether this physical evidence changes a PARITY row.