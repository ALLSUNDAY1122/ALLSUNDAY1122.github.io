# L2-AW36｜Export Registration Integrity Revalidation / Post-Intent TOCTOU Closure

## Result

`COMPLETED_NON_PARITY`

This Wave closes the Lane-2 portable integrity gap left by AW35 between durable export-registration intent creation, lifecycle metadata registration, intent retirement, and relaunch recovery.

It does **not** claim MOI-P019 PARITY. Apple runtime / real AVFoundation export / force-termination / real shareability and Differential Moises evidence remain HQ gates.

## Fresh-read canonical state

- Notion canonical: `Moises技術同等化｜AI音源分離アプリ 正本`, v4 autonomous lane contract still active.
- Worker contract: `c9e8ec5d191108db6eb20fbd40db0dab3c46b725`.
- Work Packages: `aad7983bdaf315a996dce1496ed245008085c712`.
- Lane Plan: `10b595b47e5a71278bde32e8656bd284e14e62eb`.
- Resource Locks: `17f38848ddcceb59ad44022a1cc4c058763fe663`.
- Resource Locks state: integration epoch `24`, assignment epoch `2`, planning revision `4`, Lane-2 ownership unchanged.
- PARITY Matrix: `db98892a379180c25ffeb3586a7c3353620a2d5d`; Lane-2 related PARITY rows remain `MISSING`.
- Prior Worker status blob: `84c130a8ce5bc85cebdbc040cf175ceef4f10ef4`.
- Wave start Worker branch HEAD: `e1f165abf589146ba0e09dfebec291a99eaf6fa6`.

## Problem

AW35 verifies `.lane2-batch-integrity-v1.json` before `Lane2ExportRegistrationJournal.prepare` persists the registration intent. A narrow mutable window remained afterward:

1. published bytes could drift after `prepare` returned but before `metadata.recordExports` committed;
2. bytes could drift after metadata commit but before registration-intent retirement;
3. after relaunch, `.alreadyRegistered` recovery checked regular/non-empty readiness but did not necessarily replay the AW35 manifest verification before deleting the durable intent.

This meant a previously verified batch could become lifecycle-registered even though the actual published bytes no longer matched the AW35 content fingerprint.

## Implementation

### Revalidation seam

Added `Lane2ExportRegistrationIntegrityRevalidation.swift`.

For AW35+ canonical `Exports/Batches/<batch>/<file>` artifacts, it re-runs `IOExportBatchTransaction.verifyPublishedBatch` and requires the exact verified path set to equal the intent path set.

The existing AW35 verifier continues to reject:

- byte-count drift;
- same-size content mutation via streamed digest mismatch;
- symlink replacement;
- unexpected files in the published batch;
- invalid/corrupt integrity manifest;
- filename/path-set mismatch.

Batches without the AW35 manifest retain the pre-AW35 compatibility route.

### Canonical registration ordering

`Lane2DurableLifecycleCoordinator.exportAndRecord` now performs integrity revalidation at both sides of lifecycle metadata registration:

1. `Lane2ExportRegistrationJournal.prepare`
2. **AW36 revalidate**
3. `metadata.recordExports`
4. **AW36 revalidate**
5. registration-intent retirement

The second revalidation happens after `metadata.recordExports` has committed but before intent removal. If it fails, `metadataCommitted == true`, so the error path does not delete published bytes and the durable registration intent remains for diagnosis/recovery instead of silently retiring evidence.

Intent completion is no longer best-effort (`try?`) on the successful canonical path. A retirement failure is surfaced and remains recoverable.

### Relaunch alreadyRegistered recovery

For `.alreadyRegistered`, recovery now revalidates the AW35+ manifest before regular/non-empty readiness and before intent retirement.

If drift is detected, recovery throws `publicationIntegrityFailed` and leaves the intent present. It does not convert changed bytes into a clean recovered registration.

### Compatibility

Pre-AW35 batches lacking `.lane2-batch-integrity-v1.json` continue through the legacy compatibility path. No Core Data schema, Shared/App contract, PARITY ledger, resource lock, work package, or lane plan change was required.

## Negative / edge coverage

`ExportRegistrationIntegrityRevalidationTests.swift` adds regression scenarios for:

- valid AW35 revalidation;
- byte growth after `prepare`;
- same-size byte mutation after `prepare`;
- symlink replacement after `prepare`;
- unexpected file insertion after `prepare`;
- integrity-manifest corruption after `prepare`;
- pre-AW35 no-manifest compatibility.

All drift cases assert that the durable registration intent is still present after rejection.

## Portable validation

Swift runtime used: `Swift 6.2.1` on Linux.

The AW36 helper shape was type-checked with:

`swiftc -typecheck -warnings-as-errors -strict-concurrency=complete`

Result:

`L2_AW36_HELPER_TYPECHECK_PASS`

Portable fingerprint self-check was compiled with warnings-as-errors / strict concurrency and executed.

Result:

`L2_AW36_SELF_TEST_PASS size_change=true same_size=true unexpected=true symlink=true`

The self-check is durable at:

`Library/benchmarks/L2AW36ExportRegistrationIntegritySelfCheck.swift`

This is portable algorithm evidence only; it is not a substitute for the repository's Apple/Xcode test target or physical-device force-termination evidence.

## Commits / exact durable artifacts

- `14e90fae46da34fba32b46e383f68d4c66cf2381` — integrity revalidation seam.
- `e032441bdec83b77ed40ad8b0becba4cc946bd44` — coordinator revalidation around metadata registration and relaunch recovery.
- `19e2829a1f3111d223b7632c0b72b5b8a89a5813` — AW36 regression tests.
- `51ae79dc62e79aa5fad1da69e1d486d279248b61` / `b1076fca770a81b72bc6cc0dc40d4c320a0a605b` — portable self-check plus compile fix.
- Revalidation source blob after remote read-back: `f6804e43592bef226f2e65b21ecb6b170e382b3e`.

## Remaining limits / non-claims

AW36 closes the known portable post-intent TOCTOU at the explicit coordinator boundaries, but does not make the manifest cryptographically authentic against an actor capable of rewriting both audio and manifest.

The following still require HQ / Apple / real-device evidence or later Lane-2 work:

- physical force termination exactly around revalidation / metadata-WAL visibility / intent retirement;
- APFS and ENOSPC behavior;
- real AVFoundation export validity, synchronization, naming and shareability;
- real picker/share/File Provider behavior;
- Apple Core Data runtime and WAL persistence visibility;
- DNS rebinding endpoint verification;
- real codec fixtures and WMA production decoder/licensing;
- pathological sharding/backlog performance on iPhone;
- Differential Moises comparison.

No PARITY row is promoted by this Wave.
