# STEP09 HQ — Worker code/CI audit and W1 native test trigger
Date: 2026-10-20 JST. IN_PROGRESS.

## Live Queue and baseline
Queue automation/scanlab-hq-control-20261020 remains CLAIMED epoch1 W1/W2/HQ; all resource locks unchanged. Main integration baseline 2bcbbd6128863739ad168610cd2e3f8e3b01b458.

## W1
HEAD 31ba91fdd7f6a550952ab0a814692377033783cf, ahead4. Changed CapturePolicy.swift, MeshScanModel.swift, ScanModel.swift. Push-run native iOS workflow skipped due to branch guard.
HQ created DRAFT PR #5620 from attempt/scanlab-w1-20261020-a1 into feature/splat-native-ios-poc to invoke required pull_request-triggered native XCTest, without merging.
Native CI run 39354568521 observed QUEUED, not PASS. W1 requires actual successful test evidence and outstanding pose/stale generation gates.

## W2
HEAD e74430a6a5ff24f20d6f3f1d66bd5428c05eb7fa, ahead6. Changed SplatViewerState.swift and viewer tests; investigation/gates docs added. Draft PR #5619 exists.
Native iOS run 39352775495 FAILED after executing 245 tests, now only 1 failure (down from 2):
SplatExportAdmissionTests.testPreflightRecoversViewerEditsBeforeExportMaterialization.
Failure: decoding corrupt primary sidecar JSON still fails following preflight, because ordinary SplatViewerEditStore.load() is deliberately nonmutating.
SplatViewerSidecarWriteSafetyTests.testExportMaterializerRecoversSettingsFromBackup now passed or not reported among failures. Must reconcile the remaining export admission contract rather than simply delete assertion without implementing valid explicit repair.
Other W2 smoke/privacy/memory contracts passed, but native XCTest is red.

## Decision
W1 not yet PASS, W2 native red: NO integration. No Codemagic, IPA Upload, App Review submission.
Next: reread W1 PR #5620 native workflow after completion; W2 must satisfy explicit authenticated durable export repair/legacy test under nondestructive viewer reads, then rerun full native CI.

## Late read-back of W1 pull-request CI
Native iOS run 39354568521 completed FAILURE during Static checks, before Swift XCTest. Log: splat-native-ios/scripts/test_mesh_durability_contract.py line 54, reset_block.index("FileManager.default.removeItem") ValueError: substring not found. Worker1 modified MeshScanModel.swift reset path, and contract's fixed-source pattern does not match. Worker1 must prove behavior is safe and update invariant-based contract test or repair implementation without weakening durability. Never claim XCTest PASS. Worker1 PR #5620 remains draft, unmerged.
