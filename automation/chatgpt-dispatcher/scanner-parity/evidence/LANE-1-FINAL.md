# LANE-1 Product Lane Final Evidence

## Identity
- worker: `worker1`
- lane: `LANE-1-PRODUCT`
- branch: `scanner-parity/worker1-product-lane`
- original lane baseline: `fd9cb2ec7745a927fae80a82f5cfc514ebc40020`
- original final PR: `#4523`, merged by HQ as `df0f56ad68e8db184538d9c968380eb47d20c61e`
- post-merge hardening PR: `#4531`
- policy: `AUTONOMOUS_LANES`

## Current disposition
`LANE_INTEGRATION_READY_POST_MERGE_HARDENING`

The original Product Lane was integrated by HQ. A subsequent large-loop audit found recovery/privacy defects that were not acceptable to leave behind. This branch now contains a focused post-merge hardening delta for HQ integration.

## Product capability
- SwiftUI reducer-backed app shell and navigation.
- Photos/video/Files import with camera-denial fallback.
- Canonical `frameExtraction -> imageCorrection -> pageAudit -> ocr -> packageWrite` orchestration boundary.
- incremental progress, cancellation and checkpoint resume.
- replaceable ReviewCore workflow boundary.
- BookPackage Share + Save to Files UX.
- bounded iOS background grace; no false claim of unlimited background processing.

## Hardening defects found after original integration
### H1 — relaunch Resume was not actually restorable
The original checkpoint stored input IDs but not durable input descriptors. After process relaunch, `ProductFlowState.inputAssets` was empty, so Resume could not actually start.

Fix:
- checkpoint schema defaults to v2 and stores optional `inputAssets` alongside IDs.
- optional field preserves decode compatibility with schema-v1 checkpoints.
- relaunch restores input descriptors only when every managed file still exists and IDs match.
- stale checkpoint is invalidated when the user selects different input.

### H2 — source media lived in OS temporary storage
Photo/video/Files imports were copied to `temporaryDirectory`, which cannot support reliable long-book relaunch recovery.

Fix:
- active-run media is copied into app-managed `Application Support/ScannerParity/Imports`.
- the recovery import directory is explicitly excluded from device backup.
- movie import still uses `Transferable.FileRepresentation`, avoiding whole-long-video `Data` loading.
- only app-managed import paths are eligible for automatic deletion; arbitrary external URLs are never deleted.

### H3 — durable recovery could conflict with Privacy retention
Worker2 Privacy/Security lane defines raw book source/page data as processing-only data that must be purged after use; only final BookPackage may persist normally.

Fix:
- managed raw imported media is retained only while needed for active-run/relaunch recovery.
- after pipeline completion, raw managed inputs are purged and removed from live UI state.
- the completed `packageWrite` checkpoint remains until export completion so relaunch can reopen final review/export without retaining raw source media.
- `markExportFinished` clears that completed checkpoint.

### H4 — resume trusted broken checkpoint artifacts
The original resume path skipped any stage named in checkpoint metadata even if the output had disappeared or stages were out of canonical order.

Fix:
- `ProductPipelineCheckpoint.hasCanonicalExistingArtifacts` centralizes artifact validation.
- completed artifacts must be exactly a canonical stage prefix.
- every checkpoint artifact output URL must exist.
- every newly returned stage artifact must match its expected stage and exist on disk.
- malformed/missing resume state fails closed as `invalidResumeCheckpoint`.

### H5 — completed-session restore could trust only packageWrite
A checkpoint containing a packageWrite artifact could previously reopen review/export even if the preceding chain was malformed.

Fix:
- completed-session restoration now requires `isCompletedPackageCheckpoint`: all five canonical stage artifacts, in order, with existing outputs.
- corrupt completed checkpoints are rejected before UI restore.

### H6 — checkpoint date decode mismatch
Earlier runtime verification found ISO-8601 encoding paired with default date decoding. `JSONDecoder.dateDecodingStrategy = .iso8601` was added and roundtrip verification passed.

## Cross-lane compatibility read-back
### Worker2 Privacy/Security
`BookDataLifecyclePolicy` requires raw/intermediate book data to remain local and be purged after processing; network/log paths are denied in the standard flow. LANE-1 now uses backup-excluded recoverable storage only while an active run may need resume, then purges managed raw input at completion.

### Worker3 Package Quality
Worker3 final evidence reports PackageValidation/PackageQuality non-Golden completion with 16/16 fixtures PASS. LANE-1 keeps `packageWrite` as the final composition boundary; PackageValidation/Quality can run there or immediately afterward without changing the shared scanner contract.

### Worker4 Review/Recovery
Worker4 provides `AppShellReviewAdapter`, stable ReviewQueue IDs and retry/reOCR/recapture/defer/exclude/accept decisions. LANE-1 keeps a type-erased `ProductReviewWorkflow` factory so HQ can bind the concrete Worker4 adapter without changing navigation or Shared Contract.

## Verification
Environment used for executable ProductFlow verification:
- Swift 6.2.1
- Linux x86_64
- strict concurrency enabled for reconstructed production-core checks.

Observed executable checks after recovery hardening:
- canonical five-stage run/checkpoints: PASS
- checkpoint contains durable input descriptor: PASS
- package completion: PASS
- schema-v2 encode/decode roundtrip: PASS
- durable input descriptor survives roundtrip and points to an existing file: PASS
- resume skips already-completed canonical prefix: PASS
- schema-v1 checkpoint remains decodable: PASS
- schema-v1 missing `inputAssets` resolves to nil: PASS
- completed-session `restoreCompleted` state restores package/review while dropping raw input: PASS

Repository fixtures additionally define fail-close cases for mismatched identity, missing resume artifacts, non-prefix stage order, missing bindings, 200-page incremental progress and stable review dedupe.

AppShell static contract now covers durable import storage, backup exclusion, managed cleanup, relaunch input restoration, completed-session canonical validation, corrupt-checkpoint rejection, raw input purge after completion, stale checkpoint invalidation, share/Files export and bounded background grace.

## Apple SDK boundary
`scanner-parity/Tests/AppShell/run-apple-product-compile.sh` remains the ProductShell iPhoneOS compile harness.

The existing `.github/workflows/scanner-parity-apple-validation.yml` runs the established Apple adapter harness only; it does not execute the AppShell-specific harness. Worker1 write scope does not permit editing `.github/workflows/**`, so no ProductShell Apple SDK PASS is claimed here. HQ/final integration must run the retained AppShell harness on an allowed macOS/Xcode runner before marking ProductShell Apple compile PASS.

## Scope audit
The hardening delta is limited to:
- `scanner-parity/AppShell/**`
- `scanner-parity/ProductFlow/**`
- `scanner-parity/Tests/AppShell/**`
- `scanner-parity/Tests/ProductFlow/**`
- `automation/chatgpt-dispatcher/scanner-parity/evidence/LANE-1-*.md`

No `scanner-parity/SHARED_CONTRACT.md` change. No Golden Dataset PASS/FAIL or canonical SHA decision.

## Remaining HQ final-integration gates
1. Merge post-merge hardening PR #4531.
2. Bind real integrated FrameExtraction/ImageCorrection/PageAudit/OCRExport/PipelineOCR implementations at `ScannerPipelineBindings`.
3. Bind Worker4 Review/Recovery adapter through `ProductReviewWorkflow`.
4. Run Worker3 package validation/quality in final `packageWrite` path.
5. Execute the AppShell-specific iPhoneOS compile harness on macOS/Xcode.
6. Run HQ Golden Gate with the user-provided Golden Dataset.

Worker1 does not merge its own integration PR and does not issue formal Golden or Release PASS.
