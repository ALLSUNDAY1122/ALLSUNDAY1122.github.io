# LANE-2 Post-Integration Privacy Regression Audit

- worker: `worker2`
- branch: `scanner-parity/worker2-privacy-postintegration`
- audit target: merged `scanner-parity/integration` after autonomous lanes and HQ final composition
- final Privacy PASS owner: HQ Release Gate

## Result

**NOT READY FOR FINAL PRIVACY PASS.** The original integration-level findings were re-evaluated after Worker1 PR #4531 and HQ PR #4532.

### P2-INT-001 — managed recovery input storage: partially resolved

Worker1 PR #4531 moves active-run imported source media under app-managed `Application Support/ScannerParity/Imports`, excludes that directory from device backup, persists descriptors required for relaunch resume, and purges managed raw inputs after successful processing. This is a reasonable privacy/reliability tradeoff and should not be blocked merely because Application Support is used.

The Worker2 gate was therefore corrected: Application Support usage alone is no longer a privacy failure. Managed persistence is judged by lifecycle invariants instead.

### P2-INT-002 — intermediate processing workspace: still release-blocking

`ProductFlowStore` still uses `Application Support/ScannerParity/<bookID>` as the processing workspace. HQ `ProductionScannerRuntime` writes:

- `01-frame-extraction`
- `02-image-correction` including reading/OCR page images
- `03-page-audit`
- `04-ocr`
- `05-book-package`

Worker1 added a lightweight terminal `ProductCompletionSnapshot`, explicitly intended for the state after raw/intermediate cleanup, but the current `ProductFlowStore` source still does not deterministically remove the per-book intermediate workspace on successful completion/export/session end. Managed source inputs are purged; intermediate stage artifacts are not yet shown as purged.

Required remediation: keep resumable artifacts only while resume is valid, purge intermediate frame/correction/audit/OCR stage material once terminal completion is safely represented, retain only the BookPackage/review metadata needed for review/export, and delete remaining app-managed staging when the export/session retention period ends unless the user explicitly chose persistent storage. Cover success, cancel/resume, failure, completed-review and export-finished paths.

### P2-INT-003 — Camera purpose string in shipping host target: still release-blocking

HQ PR #4532 correctly adds `AppShell/Sources/AppShell/Resources/PrivacyInfo.xcprivacy` and copies it as an AppShell SwiftPM target resource. This resolves the missing privacy-manifest resource finding.

However, AppShell still uses `AVCaptureDevice`. The represented AppShell is a SwiftPM library target and no shipping executable/native host target with `NSCameraUsageDescription` is present in the audited tree. A Privacy Manifest does not replace the host app purpose string required for camera authorization.

Required remediation: add `NSCameraUsageDescription` to the actual shipping app target, or remove camera access. The final release gate must inspect the real host target representation, not only the Swift package resource.

## Gate hardening in PR #4530

1. Network / analytics / external-AI egress remains non-bypassable and fail-closed.
2. Blanket `applicationSupportDirectory` blocking was removed to avoid rejecting legitimate crash-recovery storage.
3. `ProcessingStorageLifecycleAuditor` checks managed import backup exclusion, purgeability, intermediate workspace cleanup and camera purpose-string representation.
4. Fixture coverage includes accepted managed recovery storage and failure cases for missing purge / backup exclusion / camera purpose string.
5. `run-lane2-privacy-gate.sh` compiles the lifecycle fixtures and audits the final AppShell sources/resources.

## HQ CI read-back

HQ PR #4532 ran `Scanner Parity Apple Validation` run `32629630372` and concluded `success`. Its log shows `LANE2_PRIVACY_GATE=PASS`, but that run used the earlier LANE-2 gate: the executed fixture list had the original 12 static tests and did not include `ProcessingStorageLifecycleAuditor` or host-target camera-purpose verification. Therefore this successful run is valid for Apple SDK compile and the older egress checks, but **must not be treated as final Privacy PASS**.

## Final-gate rule

Do not mark final Privacy PASS until:

1. Product/HQ resolves intermediate workspace lifecycle cleanup.
2. The shipping native host target represents `NSCameraUsageDescription` while camera access is enabled.
3. PR #4530 (or equivalent strengthened gate) is integrated.
4. The strengthened `scanner-parity/Tests/SecurityHardening/run-lane2-privacy-gate.sh` passes on the final assembled shipping checkout.

Golden Dataset availability and SHA status are unrelated to these blockers.
