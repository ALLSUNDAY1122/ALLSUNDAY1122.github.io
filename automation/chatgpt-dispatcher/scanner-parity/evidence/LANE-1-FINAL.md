# LANE-1 Product Lane Final Evidence

## Identity
- worker: `worker1`
- lane: `LANE-1-PRODUCT`
- branch: `scanner-parity/worker1-product-lane`
- original Product Lane PR: `#4523` -> HQ merge `df0f56ad68e8db184538d9c968380eb47d20c61e`
- HQ cross-lane composition PR: `#4532` -> merge `846bef866502bbb4065381c6845d2aacf28590d6`
- post-integration hardening PR: `#4531`
- Shared Contract: unchanged
- Golden decision: not made by Worker1

## Disposition
`LANE_INTEGRATION_READY_POST_MERGE_HARDENING`

HQ final composition connected the real five-stage runtime, Worker4 Review/Recovery and Worker3 package integrity, but the integrated Product Shell still retained several recovery/privacy defects. This hardening delta corrects them without editing HQ-owned Shared Contract or other lane-owned source.

## Defects found and fixed
### H1 — relaunch Resume could not reconstruct input
Old checkpoints retained input IDs but process relaunch lost the actual imported media descriptors.

Fix:
- active checkpoint retains `inputAssets` descriptors while the run is resumable.
- schema-v1/v2 decode compatibility remains.
- every referenced input must still exist before relaunch resume is enabled.
- input replacement invalidates stale checkpoint state.

### H2 — imported source media used OS temporary storage
`MediaImportCoordinator` originally copied Photos/Files inputs to `temporaryDirectory`.

Fix:
- active imports use `Application Support/ScannerParity/Imports`.
- directory is marked `isExcludedFromBackup=true`.
- only app-managed import paths may be automatically deleted.
- long movies still use `Transferable.FileRepresentation`; they are not loaded as one large Data blob.

### H3 — processing intermediates had no deterministic terminal purge
HQ `ProductionScannerRuntime` writes frame extraction, corrected images, audit snapshots, OCR snapshots and BookPackage under the per-book workspace. A successful run previously left those intermediates under Application Support.

Fix:
- per-book processing workspace is backup-excluded while active.
- on successful package completion the final BookPackage is first moved to backup-excluded `Application Support/ScannerParity/Completed/<bookID>`.
- then raw imported media and the full processing workspace are removed through explicit `purgeProcessingWorkspace(bookID:)`.
- this removes `01-frame-extraction` through `04-ocr` and the old package workspace after final package promotion.

### H4 — terminal state still depended on intermediate artifact paths
Retaining a full five-stage checkpoint after deleting intermediates would make review/export relaunch depend on deleted files.

Fix:
- checkpoint schema v3 adds `ProductCompletionSnapshot`.
- terminal state stores only staged BookPackage URL, review metadata, page count and completion time.
- terminal checkpoint has `inputAssets=nil` and `completedArtifacts=[]`.
- legacy completed v2 five-stage checkpoint is validated, promoted to Completed staging and migrated to v3 before workspace cleanup.
- review decisions update only terminal review metadata.

### H5 — broken checkpoints could be trusted
Fix:
- active resume artifacts must be exactly a canonical stage prefix.
- every active artifact output must exist.
- returned stage output must match expected stage and exist.
- terminal snapshot requires an existing staged BookPackage.
- malformed state fails closed.

### H6 — checkpoint date encode/decode mismatch
ISO-8601 encoding had been paired with default JSON date decoding.

Fix:
- `JSONDecoder.dateDecodingStrategy = .iso8601`.

### H7 — local Completed staging could remain after user finished
Fix:
- successful Files export or explicit `Finish and remove local staging` removes managed Completed package and clears terminal checkpoint.
- completed UI no longer offers a stale local `Share again` reference after cleanup.

### H8 — unused camera authorization path created an unnecessary permission requirement
AppShell had `AVCaptureDevice` permission checks but no camera-capture UI; actual supported Product inputs are Photos and Files.

Fix:
- removed AVFoundation from `MediaImportCoordinator`.
- removed `AVCaptureDevice` authorization calls and camera-permission UI.
- therefore Product Shell does not require a host-app `NSCameraUsageDescription` until an actual camera capture feature is implemented.

## Worker2 post-integration privacy alignment
Worker2 PR `#4530` adds `ProcessingStorageLifecycleAuditor`. Its relevant contract requires:
- Application Support processing storage to be managed and backup-excluded,
- deterministic imported-media purge,
- deterministic processing-workspace purge,
- no camera usage description when no camera API is used.

The current LANE-1 hardening deliberately exposes those invariants through:
- `isExcludedFromBackup = true`
- `discardImportedAssets`
- `purgeManagedInputs`
- `purgeProcessingWorkspace`
- no `AVCaptureDevice` token in AppShell input code.

Worker2's strengthened gate itself remains a separate HQ integration PR and is not merged by Worker1.

## Verification
### Swift production-core execution
Environment: Swift 6.2.1 / Linux x86_64 / strict concurrency.

Reconstructed production-core execution passed for:
- canonical five-stage orchestration
- canonical-prefix resume
- missing resume artifact fail-close
- schema-v3 terminal checkpoint encode/decode
- legacy full completion derivation
- missing terminal package fail-close
- schema-v1 decode compatibility

Repository fixture additionally covers mismatched identity, non-prefix order, review-ID dedupe and 200-page incremental progress.

### Apple / final assembled-tree validation
GitHub Actions workflow: `Scanner Parity Apple Validation`
- successful run: `32630191967`
- runner: macOS 26 arm64
- Xcode: 26.6
- Apple Swift: 6.3.3
- iPhoneOS SDK: 26.5
- target: `arm64-apple-ios17.0`

Observed in the PR merge tree:
- AppleValidation contract: PASS
- FrameExtraction Apple module: PASS
- ImageCorrection Apple module: PASS
- PageAudit Apple module: PASS
- final AppShell source contract: `34/34 PASS`
- existing Lane2 privacy/security gate: PASS
- SwiftPM dump-package for root / ReviewCore / Recovery / ProductFlow / AppShell: PASS
- ScannerRuntime iPhoneOS module: PASS
- ReviewCore iPhoneOS module: PASS
- Recovery iPhoneOS module: PASS
- ProductFlow iPhoneOS module: PASS
- AppShell iPhoneOS module: PASS
- terminal marker: `PRODUCT_APPLE_SDK_COMPILE_PASS`

Earlier failed runs were used as defect discovery evidence:
- `32630033711`: stale source-contract function-name expectation
- `32630094554`: legacy `ProductCompletionSnapshot` -> `ProductPipelineCompletion` bridge type mismatch
Both were corrected before successful run `32630191967`.

## Scope audit
Hardening changes remain limited to:
- `scanner-parity/AppShell/**`
- `scanner-parity/ProductFlow/**`
- `scanner-parity/Tests/AppShell/**`
- `scanner-parity/Tests/ProductFlow/**`
- `automation/chatgpt-dispatcher/scanner-parity/evidence/LANE-1-*.md`

No Shared Contract modification. No Golden original committed. No Golden SHA/PASS/FAIL decision.

## Remaining HQ gates
1. Merge hardening PR `#4531`.
2. Merge/refresh Worker2 post-integration privacy regression PR `#4530` so the strengthened lifecycle auditor becomes canonical.
3. Re-run the combined final Release/Privacy gate after both are canonical.
4. Execute `HQ_GOLDEN_GATE` with the user-provided real-book Golden Dataset.

Worker1 must not merge its own PR and does not claim formal Golden or Release PASS.
