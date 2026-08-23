# LANE-2 Post-Integration Privacy Regression Audit

- worker: `worker2`
- branch: `scanner-parity/worker2-privacy-postintegration`
- audit target: merged `scanner-parity/integration` after LANE-1/2/3/4 final PR integration
- final Privacy PASS owner: HQ Release Gate

## Result

**NOT READY FOR FINAL PRIVACY PASS.** Two integration-level blockers were identified after all autonomous lanes merged.

### Blocker P2-INT-001 — persistent processing workspace

`scanner-parity/AppShell/Sources/AppShell/ProductFlowStore.swift` chooses `FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)` as the default workspace root, then creates a per-book processing workspace beneath it. The merged input coordinator separately copies imported source images/videos into `temporaryDirectory`.

LANE-2's lifecycle contract allows temporary processing only with deterministic cleanup and does not allow raw/intermediate book content to silently persist in an app-managed persistent location. The merged AppShell does not show deterministic cleanup of imported temporary source files or the per-book processing workspace after successful export/cancel/failure.

Remediation owner at final integration: AppShell/ProductFlow. Preferred design is temporary processing workspace + explicit checkpoint metadata stored separately, with deterministic cleanup after success and privacy-safe cleanup policy on cancel/failure. If recovery requires persistence, persist only the minimum recovery metadata and explicitly bounded artifacts required for resume, not unrestricted raw/intermediate copies.

### Blocker P2-INT-002 — host AppShell privacy resources not integrated

The merged AppShell uses `AVCaptureDevice` camera authorization APIs. `scanner-parity/AppShell/Package.swift` currently defines a SwiftPM library target with no resources. No `PrivacyInfo.xcprivacy` is present under AppShell and no host-app Info.plist containing `NSCameraUsageDescription` is represented in the merged AppShell tree.

LANE-2's final PR explicitly required integration to bundle/adapt the privacy manifest into the final app target and provide purpose strings when camera/photo APIs are used. That integration requirement is not yet satisfied by the merged source tree.

Remediation owner at final integration: native Product/App target. Add the privacy manifest to the shipping app bundle (or correctly bundled target resource), add camera purpose text when camera access remains enabled, and rerun the privacy gate on the final app checkout.

## Gate hardening added by this follow-up

1. `PrivacyStaticAuditor` now distinguishes local sensitive-persistence risk from network egress risk.
2. `applicationSupportDirectory` processing persistence is non-bypassable by allowlist and is included in `releaseBlockingFindings`.
3. Lane fixture coverage verifies persistent-storage detection and prevents allowlist suppression.
4. `run-lane2-privacy-gate.sh` now fails on all release-blocking privacy findings, not only network egress.
5. The integrated AppShell gate requires a bundled `PrivacyInfo.xcprivacy` and camera usage description when camera APIs are present.

## Evidence from merged source

- `MediaImportCoordinator.swift`: imported images/videos are copied to `FileManager.default.temporaryDirectory`; camera authorization uses `AVCaptureDevice`.
- `ProductFlowStore.swift`: default workspace root is Application Support and per-book processing workspace is created below it.
- `AppShell/Package.swift`: library target only; no target resources are declared.
- All lane PRs #4514, #4515, #4522 and #4523 were merged before this audit.

## Final-gate rule

Do not mark final Privacy PASS until both blockers are resolved in the final shipping target and `scanner-parity/Tests/SecurityHardening/run-lane2-privacy-gate.sh` passes against that integrated checkout. Golden Dataset availability or SHA status is unrelated to these blockers.
