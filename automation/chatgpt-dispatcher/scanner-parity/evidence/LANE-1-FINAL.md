# LANE-1 Product Lane Final Evidence

## Identity
- worker: `worker1`
- lane: `LANE-1-PRODUCT`
- branch: `scanner-parity/worker1-product-lane`
- baseline integration: `fd9cb2ec7745a927fae80a82f5cfc514ebc40020`
- policy: `AUTONOMOUS_LANES`

## Mission result
The product lane now provides an iOS-oriented application shell and a stable orchestration boundary from media input through processing, review entry and BookPackage export. Shared scanner-domain types were not redefined.

## Milestones
### 1. SwiftUI shell / navigation / state machine
- `ProductFlowState` reducer owns selecting/ready/processing/review/export/completed/failed transitions.
- SwiftUI `NavigationStack` renders each state explicitly.
- stage failure routes to recoverable UI rather than an app crash.

### 2. Video/photo input and permission recovery
- PhotosPicker supports images and videos.
- Files importer supports image/movie selection.
- camera permission is isolated from Photos/Files import; camera denial does not block imported input.
- movie import uses `Transferable.FileRepresentation`, avoiding whole-long-video `Data` loading.

### 3. Integrated pipeline orchestration adapter
- canonical stage order: `frameExtraction -> imageCorrection -> pageAudit -> ocr -> packageWrite`.
- `BoundProductPipelineDriver` sequences five injected real-engine bindings.
- `ScannerPipelineBindings` is the concrete app composition point; closures may retain native integrated stage types internally.
- output artifacts cross into AppShell only as stage/output/page-count/review metadata, avoiding a shadow shared contract.
- missing bindings and wrong-stage results fail closed.

### 4. Progress / cancel / resume
- per-stage and per-unit progress is propagated into UI.
- checkpoint is written atomically after each completed stage.
- checkpoint records run/book/input IDs and completed stage artifacts.
- resume validates the same book/input identity and skips completed stages.
- cancellation preserves imported input and completed checkpoint.
- app relaunch loads saved checkpoint and exposes Resume.

### 5. Review entry / replaceable ReviewCore adapter
- `ProductReviewWorkflow` is a replaceable boundary for worker4 ReviewCore.
- stable review IDs are deduplicated across stages.
- shell presents page/reason/detail rather than silently exporting unresolved issues.
- recovery-specific decisions remain unresolved in the reference adapter until a real ReviewCore adapter performs them.

### 6. BookPackage Files/share UX
- `ShareLink` exposes final package to the system share sheet.
- `UIDocumentPickerViewController(forExporting:asCopy:)` provides explicit Save to Files UX.
- export UI receives the actual package URL produced by the pipeline driver.

### 7. 200-page / background design
- progress API is incremental and does not require page objects to be retained by UI state.
- 200-page fixture emits incremental unit progress.
- iOS background execution uses bounded `beginBackgroundTask`; expiry cancels processing so completed-stage checkpoint can be resumed.
- this lane intentionally does not claim unlimited iOS background execution.

### 8. Apple SDK compile fixture
- `scanner-parity/Tests/AppShell/run-apple-product-compile.sh`
- compiles `ProductFlow` then `AppShell` against iPhoneOS target `arm64-apple-ios17.0` and records Xcode/Swift/SDK/report JSON.
- the lane write scope does not permit adding/modifying `.github/workflows/**`, so the product-specific harness cannot attach itself to a new GitHub macOS workflow from Worker 1.
- final integration must execute this retained harness on an allowed macOS/Xcode runner before claiming Apple Product Shell compile PASS.
- this is a technical final-integration assumption, not a Golden or human decision block.

## Verification
### ProductFlow core runtime
- toolchain: Swift 6.2.x / Linux x86_64.
- production `ProductPipelineContracts`, `BoundProductPipelineDriver`, `FileProductCheckpointStore`, review boundary were compiled with Swift and executed in an isolated harness.
- result after fix: `PASS`.
- verified five-stage run, package completion and checkpoint save/load/clear.

### Defect discovered and fixed during Macro Loop
Initial runtime verification found that checkpoint save used `JSONEncoder.dateEncodingStrategy = .iso8601` while load used default `JSONDecoder`, causing resume decode failure after persistence. Fixed by setting `decoder.dateDecodingStrategy = .iso8601`; rerun passed.

### Repository fixtures
- reducer fixture: `scanner-parity/Tests/ProductFlow/ProductFlowStateTests.swift`
- orchestration/resume/200-page fixture: `scanner-parity/Tests/ProductFlow/ProductPipelineDriverTests.swift`
- AppShell static contract: `scanner-parity/Tests/AppShell/source_contract_test.py`
- iPhoneOS compile harness: `scanner-parity/Tests/AppShell/run-apple-product-compile.sh`

Orchestration fixture covers:
1. canonical five-stage order
2. five stage checkpoints
3. resume skips already completed stages
4. mismatched checkpoint fails closed
5. review stable-ID dedupe
6. 200-page incremental progress
7. checkpoint persistence roundtrip
8. missing binding explicit failure

AppShell contract covers navigation, video/photo/Files input, permission fallback, start/cancel/resume, progress, review adapter, canonical five-stage bindings, share, Files export and bounded background grace.

## Final-integration assumptions
These are intentionally recorded rather than blocking the lane, per `AUTONOMOUS_LANES.json`:
1. The final native iOS target must inject the already-integrated FrameExtraction/ImageCorrection/PageAudit/OCRExport/PipelineOCR implementations into `ScannerPipelineBindings`.
2. Worker4's final ReviewCore should replace the reference `InMemoryProductReviewWorkflow` through the existing adapter boundary.
3. HQ/final integration must execute `run-apple-product-compile.sh` on macOS/Xcode and retain its report before Apple compile is marked PASS.

## Scope audit
All lane changes are confined to:
- `scanner-parity/AppShell/**`
- `scanner-parity/ProductFlow/**`
- `scanner-parity/Tests/AppShell/**`
- `scanner-parity/Tests/ProductFlow/**`
- `automation/chatgpt-dispatcher/scanner-parity/evidence/LANE-1-*.md`

No `scanner-parity/SHARED_CONTRACT.md` change. No Golden Dataset PASS/FAIL or SHA decision.

## Lane disposition
`LANE_INTEGRATION_READY`

Worker 1 must not merge its own final PR. HQ owns final integration and Golden Gate.
