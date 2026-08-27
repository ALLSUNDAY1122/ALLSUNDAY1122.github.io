# L4-W50 validation

## Scope

W50 hardens the W49 W48-certificate consumption ledger at the filesystem and interrupted-write boundary without changing W49 record/head root formats.

## Implemented

- Added bounded regular-file reader with lexical + resolved root confinement.
- Rejects symlinked root descendants, control files and record files.
- Rejects non-regular files and unexpected ledger-directory topology.
- Head/pending/record byte bounds: 16 MiB / 4 MiB / 2 MiB.
- Secure append retains W49 certificate/package/report/predecessor hash-chain semantics.
- Secure recovery handles pending-only rollback, record-written roll-forward and head-written marker cleanup.
- Corrupt pending markers and record collisions fail closed.
- Injected post-commit read-back failure leaves a reopenable committed state instead of replaying the certificate.
- Secure checkpoint manager resolves pending state, then reopens through the secure filesystem path before producing or accepting a checkpoint.
- Secure consumed-root inventory is available directly for future W48 expectations.

## Durable XCTest source

`AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreTests.swift` covers:

1. secure append / legacy W49 format compatibility;
2. symlinked head rejection;
3. symlinked record rejection;
4. symlinked `records/` rejection;
5. unexpected ledger topology rejection;
6. non-regular head rejection;
7. oversized head rejection before JSON decode;
8. pending-marker-only rollback;
9. record-written-before-head roll-forward exactly once;
10. head-written-before-marker-removal cleanup;
11. corrupt pending marker fail-close;
12. record-collision fail-close;
13. injected read-back failure with durable committed reopen;
14. secure checkpoint rejection of symlink-substituted evidence.

## Independent executable evidence

A standalone Swift 6.2.1 filesystem mirror using the same regular-file/no-symlink/root-confinement/size-bound rules compiled with `-warnings-as-errors`. Compile: 4.46 s, 221372 kB RSS. Runtime: 0.07 s, 21084 kB RSS. Result: 5/5 for regular accept, symlink reject, non-regular reject, oversized reject and outside-root reject.

An independent canonical-JSON/SHA-256 protocol mirror exercised 120,000 mutations across 12 classes and detected 120,000/120,000 with zero undetected when anchored to the externally retained ledger checkpoint root.

The crash-state model produced the intended six outcomes: pending-only rollback; record-written roll-forward; head-written marker cleanup; corrupt marker fail-close; collision fail-close; read-back-failure state reopens as committed.

## Canonical test status

**NOT_OBSERVED.** `git ls-remote https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io.git HEAD` failed with `Could not resolve host: github.com` before SwiftPM could start. Therefore no Worker-branch canonical compile/XCTest PASS is claimed.

## Remaining external gates

- HQ canonical SwiftPM/XCTest on the exact W50 Worker files.
- Selected physical-iPhone filesystem/crash/power-interruption testing.
- Independent external retention of latest W49 checkpoint/handoff root.
- Real W47 rights-cleared physical-iPhone corpus execution with genuine Lane-2 decoder.
- Current-iPhone Moises Reference and W46 paired differential evidence.
- HQ final PARITY_MATRIX judgment.

W50 is **NON_PARITY** and does not promote MOI-P009/P011/P013/P016 or MOI-P021.
