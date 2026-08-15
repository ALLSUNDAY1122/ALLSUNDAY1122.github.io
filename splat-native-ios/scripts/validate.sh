#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

test -f project.yml
test -f SplatNative/ScanModel.swift
test -f SplatNative/CapturePolicy.swift
test -f SplatNative/ScanModel+SessionLifecycle.swift
test -f SplatNative/SplatViewer.swift
test -f SplatNative/RootScanView.swift
test -f SplatNative/SplatNativeApp.swift
test -f SplatNative/PrivacyInfo.xcprivacy
test -f SplatNativeTests/CapturePolicyTests.swift

test -f SplatNative/Resources/Licenses/msplat-APACHE-2.0.txt
test -f SplatNative/Resources/Licenses/MetalSplatter-MIT.txt
test -f SplatNative/Resources/Licenses/nanoflann-BSD.txt
test -f SplatNative/Resources/Licenses/nlohmann-json-MIT.txt
grep -q 'Apache License' SplatNative/Resources/Licenses/msplat-APACHE-2.0.txt
grep -q 'Copyright (c) 2026 Sean Cier' SplatNative/Resources/Licenses/MetalSplatter-MIT.txt
grep -q 'Jose L. Blanco' SplatNative/Resources/Licenses/nanoflann-BSD.txt
grep -q 'Copyright (c) 2013-2022 Niels Lohmann' SplatNative/Resources/Licenses/nlohmann-json-MIT.txt

grep -q 'jp.allsunday1122.splatlab' project.yml
grep -q 'MARKETING_VERSION: 1.0.0' project.yml
grep -q 'INFOPLIST_KEY_ITSAppUsesNonExemptEncryption: NO' project.yml
grep -q 'INFOPLIST_KEY_CFBundleDisplayName: Scan Lab' project.yml
grep -q 'ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon' project.yml
grep -q 'd620d9c58d270e7de9e34a9d8a85dcf938a5070d' project.yml
grep -q '2b965de1934de38dda1c71cf90bf798aa948a14c' project.yml

# Root/session gate: AR camera exists before the capture action, and ScanModel owns session start/restart.
grep -q 'RootScanView()' SplatNative/SplatNativeApp.swift
grep -q 'PersistentScanCameraView()' SplatNative/RootScanView.swift
grep -q 'model.attach(session: view.session)' SplatNative/RootScanView.swift
grep -q 'session.run(makeWorldTrackingConfiguration()' SplatNative/ScanModel.swift

# Permission/session failure and interruption recovery must surface to the user.
grep -q 'didFailWithError' SplatNative/ScanModel+SessionLifecycle.swift
grep -q 'sessionWasInterrupted' SplatNative/ScanModel+SessionLifecycle.swift
grep -q 'sessionInterruptionEnded' SplatNative/ScanModel+SessionLifecycle.swift
grep -q 'sessionShouldAttemptRelocalization' SplatNative/ScanModel+SessionLifecycle.swift

# S1 capture quality gate: coverage must support both object-orbit and room/outdoor movement,
# use adaptive translation, reject pose jumps, and prevent rotation-in-place completion.
grep -q 'minimumTranslation(subjectDistance:' SplatNative/CapturePolicy.swift
grep -q 'delta.translation <= 1.25' SplatNative/CapturePolicy.swift
grep -q 'objectCoverageSatisfied' SplatNative/CapturePolicy.swift
grep -q 'sceneCoverageSatisfied' SplatNative/CapturePolicy.swift
grep -q 'spatialCell' SplatNative/CapturePolicy.swift
grep -q 'viewDirectionSector' SplatNative/CapturePolicy.swift
grep -q 'pathLengthMeters' SplatNative/ScanModel.swift
grep -q 'trackingNeedsRecovery' SplatNative/ScanModel.swift
grep -q 'recoveryFramesRequired = 6' SplatNative/ScanModel.swift

# Long scans must warn even when coverage is still incomplete, and the frame cap must be a
# soft rescue limit rather than a dead-end that prevents missing coverage from being added.
grep -q 'longScanStage(seconds:' SplatNative/CapturePolicy.swift
grep -q 'softLimitAllowsFrame' SplatNative/CapturePolicy.swift
grep -q 'frameAddsMissingCoverage' SplatNative/ScanModel.swift
grep -q '撮影が90秒を超えています' SplatNative/ScanModel.swift
grep -q '撮影が3分を超えています' SplatNative/ScanModel.swift
grep -q '未撮影の方向・高さだけを追加してください' SplatNative/ScanModel.swift

# Resume gate: manual pause, post-stop resume and app interruption must preserve the existing
# world coordinate system. A reset is allowed only when creating a brand-new scan.
grep -q 'func pauseCapture()' SplatNative/ScanModel.swift
grep -q 'func resumeCapture()' SplatNative/ScanModel.swift
grep -q 'Button("撮影を再開して追加")' SplatNative/RootScanView.swift
grep -q 'session.run(makeWorldTrackingConfiguration(), options: \[\])' SplatNative/ScanModel.swift
RESET_COUNT=$(grep -c 'resetTracking' SplatNative/ScanModel.swift || true)
test "$RESET_COUNT" -eq 1
! grep -q 'resetTracking' SplatNative/ScanModel+SessionLifecycle.swift

# Depth gate: LiDAR-capable devices may retain scene depth, while Ignore LiDAR keeps the RGB+pose path valid.
grep -q 'supportsFrameSemantics(.sceneDepth)' SplatNative/ScanModel.swift
grep -q 'frame.sceneDepth?.depthMap' SplatNative/ScanModel.swift
grep -q 'ignoreLiDAR' SplatNative/ScanModel.swift
grep -q 'capture_manifest.json' SplatNative/ScanModel.swift
grep -q 'LiDAR深度を撮影に使う' SplatNative/RootScanView.swift

# Regression tests must explicitly lock the S1 capture policy.
grep -q 'testRotationInPlaceNeverCountsAsUsefulCaptureMotion' SplatNativeTests/CapturePolicyTests.swift
grep -q 'testRelocalizationSizedPoseJumpIsRejected' SplatNativeTests/CapturePolicyTests.swift
grep -q 'testSceneCoverageCanPassWithoutObjectCenteredOrbit' SplatNativeTests/CapturePolicyTests.swift
grep -q 'testLongScanStagesAreIndependentOfCoverage' SplatNativeTests/CapturePolicyTests.swift
grep -q 'testSoftFrameLimitAllowsOnlyMissingObjectCoverage' SplatNativeTests/CapturePolicyTests.swift
grep -q 'testSoftFrameLimitLetsSceneRecoverButRejectsRedundantFrames' SplatNativeTests/CapturePolicyTests.swift

# Viewer framing and reset remain protected from the S0 baseline.
grep -q 'robustFraming(for: points)' SplatNative/SplatViewer.swift
grep -q 'sceneCenter = framing.center' SplatNative/SplatViewer.swift
grep -q 'center: sceneCenter' SplatNative/SplatViewer.swift
grep -q 'resetView' SplatNative/SplatViewer.swift

# Consumer UI must not expose internal training/debug jargon, and destructive loss needs confirmation.
grep -q 'Text("Scan Lab")' SplatNative/RootScanView.swift
grep -q 'showingDiscardConfirmation' SplatNative/RootScanView.swift
grep -q '生成だけもう一度試す' SplatNative/RootScanView.swift
! grep -q '特徴点 ' SplatNative/RootScanView.swift
! grep -q 'iteration ' SplatNative/RootScanView.swift
! grep -q 'splats ' SplatNative/RootScanView.swift

# Parity work must remain product-neutral until Scaniverse functional parity is achieved.
! grep -R -n 'おもちゃばこ' SplatNative project.yml

# S1 remains local-only; raw RGB/depth data must not be silently transmitted.
! grep -R -nE 'https?://.*(api|upload|analytics)|URLSession|Firebase|Amplitude|Mixpanel' SplatNative --include='*.swift'

plutil -lint SplatNative/PrivacyInfo.xcprivacy >/dev/null
python3 - <<'PY'
import plistlib
with open('SplatNative/PrivacyInfo.xcprivacy','rb') as f:
    data=plistlib.load(f)
assert data.get('NSPrivacyTracking') is False
assert data.get('NSPrivacyCollectedDataTypes') == []
assert data.get('NSPrivacyTrackingDomains') == []
print('PASS: Privacy Manifest matches local-only S1 capture')
PY

echo 'PASS: static Splat Lab Native S1 checks'
