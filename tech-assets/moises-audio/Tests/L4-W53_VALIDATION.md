# L4-W53 Validation｜Crash-Durable W50-W52 Ledger Publication

## Result

W53 changes the production W50 secure-store publication path itself rather than adding an optional wrapper. Pending marker, immutable record, mutable head and pending deletion now have explicit data/directory durability ordering before an append is treated as durable.

W53 remains NON_PARITY. It does not supply physical-iPhone/APFS power-loss evidence, rights-cleared real-audio evidence, current-iPhone Moises reference/differential evidence or final HQ judgment.

## Canonical context refreshed before work

The latest Notion/PR state is HQ Canonical Epoch 44:

- `L1 A23 / L2 AW49 / L3 AW49 / L4 W52`;
- Lane4 W52 source integration `a93ef6b058db89fa57d8ee0a8064e5df019af331`;
- canonical ledger commit `701698290b6e2076ce71a9208d2626af85f918b5`;
- HQ Run `33030546532` SUCCESS;
- SwiftPM `462/462 PASS`;
- PARITY advancement remains zero.

Therefore W53 has a canonically tested W52 predecessor. W53 itself was not yet HQ integrated when this validation was written.

## Production implementation

### `AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.swift`

Adds the low-level durable publication primitive:

- same-directory temp opened `O_EXCL | O_NOFOLLOW | O_CLOEXEC`;
- complete byte write with EINTR handling;
- Darwin `F_FULLFSYNC` attempt with explicit `fsync` fallback, or POSIX `fsync`;
- pending/head atomic `rename` publication;
- immutable-record collision-safe hard-link publication without overwriting an existing record;
- parent-directory `fsync` after publication;
- pending unlink followed by parent-directory `fsync`;
- exact secure readback before a successful durability receipt is returned.

### W50 filesystem/store integration

`AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.swift` and `AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.swift` now route the actual append/recovery path through W53.

Normal append order:

1. pending marker durable;
2. immutable record durable;
3. head durable;
4. pending deletion durable;
5. secure full reopen.

A durable head is therefore never intentionally published before its candidate record publication step.

Directory creation inside the selected custody root now also syncs the containing directory metadata. W53 intentionally does not claim to make filesystem ancestors outside the caller-selected root durable.

### Interrupted temporary topology

A terminated writer may leave `.w53-pub-*.tmp`. These names are tolerated only as bounded, regular, no-symlink, confined temporary metadata. At most 32 are allowed per controlled directory. They are not counted as W49 ledger records. Invalid temporary topology fails closed.

## Fault matrix

Durability fault injection covers three publication targets and four boundaries:

- pending marker;
- immutable record;
- ledger head;

at:

- before data sync;
- after data sync / before publish;
- after publish / before parent-directory sync;
- after parent-directory sync.

Current-process semantic recovery expects:

- pending faults -> exact pre state;
- record faults before publish -> exact pre;
- record faults after publish -> exact post;
- head faults -> exact post through W50 recovery.

For **true physical power loss**, record publish after link/rename visibility but before directory sync is explicitly classified `EXACT_PRE_OR_POST`. W53 does not falsely require one outcome where filesystem persistence is not yet proven. Mixed/corrupt state is always rejected.

## Durable XCTest source

`AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationTests.swift` covers:

- durable atomic control replacement;
- exclusive immutable record publication and collision rejection;
- durable deletion;
- all 12 publication fault cells with W50 recovery;
- bounded interrupted temp handling;
- excess-temp rejection;
- symlink temp rejection;
- W49 legacy head/root compatibility after normal W53 append;
- pending marker absent after successful append;
- complete physical recovered-state contract mapping.

The selected-iPhone probe is restricted to `os(iOS) && arch(arm64) && !simulator && !macCatalyst`, matching the existing W47 physical-runtime boundary.

## Executed validation

### Canonical predecessor

HQ Epoch44 Run `33030546532`: SwiftPM `462/462 PASS` for canonical W52 predecessor.

### Exact Worker W53 SwiftPM/XCTest

`NOT_OBSERVED` in this Worker runtime. Fresh `git ls-remote` failed before SwiftPM with `Could not resolve host: github.com`.

No W53 full-repository compile/XCTest PASS is claimed. HQ must rerun the exact W53 files after semantic integration.

### Portable Swift low-level protocol

Swift 6.2.1 with `-warnings-as-errors` executed:

- 1,000 same-directory temp → `fsync` → rename → parent-directory `fsync` cycles with exact reopen;
- immutable record exclusive hard-link publication;
- record collision rejection;
- directory `fsync`.

Result: PASS for the portable low-level protocol. This is not iPhone/APFS evidence.

### Independent process-crash protocol stress

A forked child stopped via `_exit` at every publication boundary and the parent reopened a W50-shaped state machine.

- 3 publication targets;
- 4 fault boundaries per target;
- 100 executions per cell;
- 1,200 total executions;
- exact pre: 600;
- exact post: 600;
- mixed: 0.

This demonstrates the intended protocol/recovery shape under the exercised Linux filesystem/runtime. It does not prove sudden power-loss persistence on APFS.

### Probe-ticket adversarial mirror

240,000/240,000 mutations detected, 0 undetected across 16 ticket/runtime/state classes, including a self-consistent but incorrect recovered-state mapping.

## Selected physical iPhone probe

`AnalysisIOSBridgeDurabilityProbeCoordinator` was added but was **not physically executed** in this Worker runtime.

It:

- creates a ticket bound to the W52 pre-snapshot, candidate W48 certificate, source/build/session/device/OS;
- records whether the selected device actually used `DARWIN_F_FULLFSYNC` or `DARWIN_FSYNC_FALLBACK`;
- prepares one selected interruption-state boundary without silently recovering it;
- requires external terminate/suspend action before reopen testing;
- after relaunch, accepts only exact pre or exact post according to the ticket contract;
- rejects mixed state, multi-advance, wrong candidate certificate or changed prefix.

The prepared-state API does not itself prove a process was killed during a kernel sync/rename syscall. Physical termination, app suspension, reboot/power-loss and APFS behavior remain an external campaign.

## Remaining limitations / next hardening

- selected physical-iPhone/APFS execution remains unobserved;
- `F_FULLFSYNC` success vs fallback must be captured on the actual selected device;
- dangling-symlink deletion and namespace substitution should be hardened with `lstat`/no-follow semantics;
- valid interrupted W53 temp files are bounded/tolerated but not yet garbage-collected under the writer lease;
- a malicious process that ignores W51 locking remains outside the cooperating-writer contract;
- external W52 checkpoint/handoff/receipt custody remains necessary against whole-directory rollback;
- P009/P011/P013/P016/P021 remain MISSING.

## Conclusion

W53 closes the previous absence of an explicit file-sync / atomic-publication / directory-sync order in the production bridge-consumption store while preserving existing evidence roots. It establishes a portable crash-durability protocol and a physical-iPhone measurement path, not physical APFS proof and not product PARITY.