#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

test -f project.yml
test -f SplatNative/ScanModel.swift
test -f SplatNative/ScanModel+SessionLifecycle.swift
test -f SplatNative/CapturePolicy.swift
test -f SplatNative/SplatViewer.swift
test -f SplatNative/RootScanView.swift
test -f SplatNative/SplatNativeApp.swift
test -f SplatNative/SplatReconstructionPolicy.swift
test -f SplatNative/SplatSeedColorizer.swift
test -f SplatNative/SplatSkySeeder.swift
test -f SplatNative/SplatResourceGuard.swift
test -f SplatNativeTests/CapturePolicyTests.swift
test -f SplatNativeTests/SplatReconstructionPolicyTests.swift
test -f SplatNative/PrivacyInfo.xcprivacy

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
grep -q 'SplatNative/CapturePolicy.swift' project.yml

# Root camera/session gate.
grep -q 'RootScanView()' SplatNative/SplatNativeApp.swift
grep -q 'PersistentScanCameraView()' SplatNative/RootScanView.swift
grep -q 'model.attach(session: view.session)' SplatNative/RootScanView.swift
grep -q 'session.run(makeWorldTrackingConfiguration()' SplatNative/ScanModel.swift

# Permission and interruption failures must surface and relocalization must preserve one coordinate system.
grep -q 'didFailWithError' SplatNative/ScanModel+SessionLifecycle.swift
grep -q 'sessionWasInterrupted' SplatNative/ScanModel+SessionLifecycle.swift
grep -q 'sessionInterruptionEnded' SplatNative/ScanModel+SessionLifecycle.swift
grep -q 'sessionShouldAttemptRelocalization' SplatNative/ScanModel+SessionLifecycle.swift
grep -q 'handleSessionInterrupted' SplatNative/ScanModel.swift
grep -q 'handleSessionInterruptionEnded' SplatNative/ScanModel.swift
grep -q 'session.run(makeWorldTrackingConfiguration(), options: \[\])' SplatNative/ScanModel.swift

# S1 capture parity gate: count alone is not enough; object and scene coverage use different evidence,
# spinning in place cannot satisfy movement, long scans are bounded, and pause/resume + optional depth survive.
grep -q 'CapturePolicy.coverageSatisfied' SplatNative/ScanModel.swift
grep -q 'CapturePolicy.shouldAcceptFrame' SplatNative/ScanModel.swift
grep -q 'CapturePolicy.softLimitAllowsFrame' SplatNative/ScanModel.swift
grep -q 'acceptedFrames >= maxFrames' SplatNative/ScanModel.swift
grep -q 'elevationBands' SplatNative/ScanModel.swift
grep -q 'viewDirectionSectors' SplatNative/ScanModel.swift
grep -q 'spatialCells' SplatNative/ScanModel.swift
grep -q 'pathLengthMeters' SplatNative/ScanModel.swift
grep -q 'activeCaptureSeconds' SplatNative/ScanModel.swift
grep -q 'sceneDepth' SplatNative/ScanModel.swift
grep -q 'depthFilePath' SplatNative/ScanModel.swift
grep -q 'func pauseCapture' SplatNative/ScanModel.swift
grep -q 'func resumeCapture' SplatNative/ScanModel.swift
grep -q 'testRotationInPlaceNeverCountsAsUsefulCaptureMotion' SplatNativeTests/CapturePolicyTests.swift
grep -q 'testNearbyObjectCannotPassUsingSceneCoverageFromOneSide' SplatNativeTests/CapturePolicyTests.swift
grep -q 'testSceneModeDoesNotRequireObjectOrbit' SplatNativeTests/CapturePolicyTests.swift

# A storage failure is a hard stop, never a silently skipped frame.
grep -q '撮影データを保存できませんでした。iPhoneの空き容量を確認してください。' SplatNative/ScanModel.swift
python3 - <<'PY'
from pathlib import Path
s=Path('SplatNative/ScanModel.swift').read_text()
resume=s.index('func resumeCapture()')
finish=s.index('func finishCapture()')
block=s[resume:finish]
assert 'options: []' in block
assert '.resetTracking' not in block
print('PASS: resumed capture preserves AR world coordinates')
PY

# S2 reconstruction gate: seed points carry observed RGB, preserve sky/background, use full SH/densification,
# checkpoint safely, and support repeatable Enhance passes.
grep -q 'property uchar red' SplatNative/ScanModel.swift
grep -q 'property uchar green' SplatNative/ScanModel.swift
grep -q 'property uchar blue' SplatNative/ScanModel.swift
grep -q 'trainingHorizon = 30_000' SplatNative/SplatReconstructionPolicy.swift
grep -q 'standardIterations = 7_000' SplatNative/SplatReconstructionPolicy.swift
grep -q 'enhancementIncrement = 5_000' SplatNative/SplatReconstructionPolicy.swift
grep -q 'config.shDegree = 3' SplatNative/SplatReconstructionPolicy.swift
grep -q 'config.numDownscales = 1' SplatNative/SplatReconstructionPolicy.swift
grep -q 'config.warmupLength = 500' SplatNative/SplatReconstructionPolicy.swift
grep -q 'trainer.saveCheckpoint' SplatNative/ScanModel.swift
grep -q 'trainer.loadCheckpoint' SplatNative/ScanModel.swift
grep -q 'requiresThermalPause' SplatNative/ScanModel.swift
grep -q 'enhancementTarget(from: trainingIteration)' SplatNative/ScanModel.swift
grep -q 'SplatSkySeeder.makeSeeds' SplatNative/ScanModel.swift
grep -q 'farDistance: Float = 20' SplatNative/SplatSkySeeder.swift
! grep -q 'SplatForegroundIsolator' SplatNative/ScanModel.swift

# S8 resource guard regression gate.
grep -q 'residentMemoryBudgetBytes' SplatNative/SplatResourceGuard.swift
grep -q 'maxSplatCount' SplatNative/SplatResourceGuard.swift
grep -q 'TASK_VM_INFO' SplatNative/SplatResourceGuard.swift
grep -q 'phys_footprint' SplatNative/SplatResourceGuard.swift
grep -q 'UIApplication.didReceiveMemoryWarningNotification' SplatNative/ScanModel.swift
grep -q 'passResourceGuard.evaluate' SplatNative/ScanModel.swift
grep -q 'resourcePauseReason' SplatNative/ScanModel.swift
grep -q 'SplatReconstructionRunReport.write' SplatNative/ScanModel.swift
grep -q 'reconstruction-run-%05d.json' SplatNative/SplatResourceGuard.swift
grep -q 'testSyntheticHighDensityTriggersCheckpointPauseBeforeUnboundedGrowth' SplatNativeTests/SplatReconstructionPolicyTests.swift
grep -q 'testSyntheticMemoryPressureRecordsPeakAndPauses' SplatNativeTests/SplatReconstructionPolicyTests.swift
python3 - <<'PY'
from pathlib import Path
s=Path('SplatNative/ScanModel.swift').read_text()
pause=s.index('if let reason = resourcePauseReason')
checkpoint=s.rfind('trainer.saveCheckpoint', 0, pause)
assert checkpoint >= 0
print('PASS: S2 resource pause is checkpoint-recoverable')
PY

# CPU-heavy RGB projection/sky seeding belongs to the detached generation path, not finishCapture.
python3 - <<'PY'
from pathlib import Path
s=Path('SplatNative/ScanModel.swift').read_text()
finish=s.index('func finishCapture()')
train=s.index('private func startTraining(')
detached=s.index('Task.detached', train)
prepare=s.index('Self.preparePointCloudPLY', detached)
assert finish < train < detached < prepare
assert 'preparePointCloudPLY' not in s[finish:train]
print('PASS: S2 preprocessing runs off capture MainActor path')
PY

# A successful splat must open centered and support reset framing.
grep -q 'robustFraming(for: points)' SplatNative/SplatViewer.swift
grep -q 'sceneCenter = framing.center' SplatNative/SplatViewer.swift
grep -q 'center: sceneCenter' SplatNative/SplatViewer.swift
grep -q 'resetView' SplatNative/SplatViewer.swift

# Consumer UI gate: no training/debug jargon; destructive loss is confirmed; capture recovery and Enhance are visible.
grep -q 'Text("Scan Lab")' SplatNative/RootScanView.swift
grep -q 'showingDiscardConfirmation' SplatNative/RootScanView.swift
grep -q '生成だけもう一度試す' SplatNative/RootScanView.swift
grep -q '撮影を再開' SplatNative/RootScanView.swift
grep -q 'LiDAR深度を撮影に使う' SplatNative/RootScanView.swift
grep -q '品質をさらに上げる' SplatNative/RootScanView.swift
! grep -q '特徴点 ' SplatNative/RootScanView.swift
! grep -q 'iteration ' SplatNative/RootScanView.swift
! grep -q 'splats ' SplatNative/RootScanView.swift

# Product-neutral until Scaniverse functional parity is achieved.
! grep -R -n 'おもちゃばこ' SplatNative project.yml

# Current PoC remains local-only.
! grep -R -nE 'https?://.*(api|upload|analytics)|URLSession|Firebase|Amplitude|Mixpanel' SplatNative --include='*.swift'

plutil -lint SplatNative/PrivacyInfo.xcprivacy >/dev/null
python3 - <<'PY'
import plistlib
with open('SplatNative/PrivacyInfo.xcprivacy','rb') as f:
    data=plistlib.load(f)
assert data.get('NSPrivacyTracking') is False
assert data.get('NSPrivacyCollectedDataTypes') == []
assert data.get('NSPrivacyTrackingDomains') == []
print('PASS: Privacy Manifest matches local-only PoC')
PY

echo 'PASS: static Splat Lab Native checks'
