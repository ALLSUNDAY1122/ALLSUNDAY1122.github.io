# STEP07 — HQ independent integration gate
Date: 2026-10-20. State: IN_PROGRESS; integration HOLD.

## Live refs and ownership
- Control Queue commit 7196cc2776f38fe9260c6cf5fa244fba4c5563c0, HQ/W1/W2 CLAIMED epoch1, locks distinct.
- Integration source feature/splat-native-ios-poc HEAD 2bcbbd6128863739ad168610cd2e3f8e3b01b458; PR #4145 draft.
- W1 HEAD ab9b476c9fea09b8cbdfd4a54d571047cae809c8, ahead 2. Source modified CapturePolicy.swift and MeshScanModel.swift.
- W2 HEAD c1b836d69cd84fa8fb91c66e87cfae3e4cd36aa3, ahead 3. Source modified SplatViewerState.swift, added W2_STEP04_FINDINGS.md.

## W1 review
Current pose and timestamp malformed inputs rejected in CapturePolicy. Still need previous pose validation, rigid-transform checks and actual capture-admission-before-side-effects verification. MeshScanModel changed; end-to-end proof missing. W1 Native iOS Build run 39348602451 SKIPPED, not PASS. HOLD.

## W2 review
Viewer measurement now displays シーン単位（実寸未校正） rather than uncalibrated physical meters, positive.
Conversion state still remains in code; ensure other render paths cannot label a non-calibrated value as meters.
Read-only sidecar recovery and T37/T38 publish/revoke still not proven. HOLD.

## Verified regression failure
W2 commit c1b836d6 GitHub Actions run 39348580713:
https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/39348580713
Native iOS Build FAILED with XCTest 245 tests and 2 failures, xcodebuild exit 65:
1. SplatExportAdmissionTests.testPreflightRecoversViewerEditsBeforeExportMaterialization — dataCorrupted, invalid JSON during recovery.
2. SplatViewerSidecarWriteSafetyTests.testExportMaterializerRecoversSettingsFromBackup — dataCorrupted, invalid JSON during recovery.
Privacy preflight, smoke diagnostic, S10 memory, S12 densification passed separately; these do not override the failed XCTest suite.
GitHub combined commit statuses were empty for both worker HEADs.

## Integration decision
Neither worker merges yet. No new Codemagic build, Apple upload, TestFlight build assignment, or App Store submission.
Next: W2 backup recovery and non-destructive read-path tests; W1 pose/lease before-disk-write tests; both full native CI PASS and current claim/epoch readback before serial integration.