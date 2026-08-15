#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Core project files.
test -f project.yml
test -f SplatNative/ScanModel.swift
test -f SplatNative/ScanModel+SessionLifecycle.swift
test -f SplatNative/CapturePolicy.swift
test -f SplatNative/SplatViewer.swift
test -f SplatNative/SplatViewerState.swift
test -f SplatNative/SplatResultView.swift
test -f SplatNative/RootScanView.swift
test -f SplatNative/SplatNativeApp.swift
test -f SplatNative/SplatReconstructionPolicy.swift
test -f SplatNative/SplatSeedColorizer.swift
test -f SplatNative/SplatSkySeeder.swift
test -f SplatNative/SplatResourceGuard.swift
test -f SplatNativeTests/CapturePolicyTests.swift
test -f SplatNativeTests/SplatReconstructionPolicyTests.swift
test -f SplatNativeTests/SplatViewerStateTests.swift
test -f SplatNative/PrivacyInfo.xcprivacy

# Mesh parity assets recovered from lane B.
for f in \
  MeshARViewer.swift MeshAdvancedSupervisor.swift MeshAppearanceEditor.swift MeshAssetContract.swift \
  MeshCaptureQualityAdvisor.swift MeshDenseMVS.swift MeshDenseTextureBaker.swift MeshDepthRecorder.swift \
  MeshDetailSimplifier.swift MeshGeometryRefiner.swift MeshLiDARDenseFusion.swift MeshParityAuditor.swift \
  MeshRGBTextureBaker.swift MeshRawReprocess.swift MeshScanModel.swift MeshScanView.swift \
  MeshSimplifier.swift MeshTrimEditor.swift MeshVisualFallback.swift; do
  test -f "SplatNative/$f"
done

# OSS/license and app metadata gates.
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
grep -q 'SplatNative/SplatViewerState.swift' project.yml

# Root app shell exposes both Splat and Mesh without replacing the Splat session.
grep -q 'RootScanView()' SplatNative/SplatNativeApp.swift
grep -q 'MeshScanModel()' SplatNative/SplatNativeApp.swift
grep -q 'environmentObject(meshModel)' SplatNative/SplatNativeApp.swift
grep -q 'PersistentScanCameraView()' SplatNative/RootScanView.swift
grep -q 'model.attach(session: view.session)' SplatNative/RootScanView.swift
grep -q 'Splatをスキャン' SplatNative/RootScanView.swift
grep -q 'Meshをスキャン' SplatNative/RootScanView.swift
grep -q 'MeshScanView()' SplatNative/RootScanView.swift
grep -q 'SplatResultView' SplatNative/RootScanView.swift
grep -q 'SplatでLiDAR深度を使う' SplatNative/RootScanView.swift

# Permission and interruption recovery must preserve one AR coordinate system.
grep -q 'didFailWithError' SplatNative/ScanModel+SessionLifecycle.swift
grep -q 'sessionWasInterrupted' SplatNative/ScanModel+SessionLifecycle.swift
grep -q 'sessionInterruptionEnded' SplatNative/ScanModel+SessionLifecycle.swift
grep -q 'sessionShouldAttemptRelocalization' SplatNative/ScanModel+SessionLifecycle.swift
grep -q 'handleSessionInterrupted' SplatNative/ScanModel.swift
grep -q 'handleSessionInterruptionEnded' SplatNative/ScanModel.swift
grep -q 'session.run(makeWorldTrackingConfiguration(), options: \[\])' SplatNative/ScanModel.swift

# S1 capture parity: coverage quality, pause/resume, long scans and optional LiDAR depth.
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

# S2 reconstruction: colored seeds, sky/background, checkpoints, resource guard and Enhance.
grep -q 'property uchar red' SplatNative/ScanModel.swift
grep -q 'property uchar green' SplatNative/ScanModel.swift
grep -q 'property uchar blue' SplatNative/ScanModel.swift
grep -q 'trainingHorizon = 30_000' SplatNative/SplatReconstructionPolicy.swift
grep -q 'standardIterations = 7_000' SplatNative/SplatReconstructionPolicy.swift
grep -q 'enhancementIncrement = 5_000' SplatNative/SplatReconstructionPolicy.swift
grep -q 'config.shDegree = 3' SplatNative/SplatReconstructionPolicy.swift
grep -q 'trainer.saveCheckpoint' SplatNative/ScanModel.swift
grep -q 'trainer.loadCheckpoint' SplatNative/ScanModel.swift
grep -q 'requiresThermalPause' SplatNative/ScanModel.swift
grep -q 'enhancementTarget(from: trainingIteration)' SplatNative/ScanModel.swift
grep -q 'SplatSkySeeder.makeSeeds' SplatNative/ScanModel.swift
grep -q 'residentMemoryBudgetBytes' SplatNative/SplatResourceGuard.swift
grep -q 'maxSplatCount' SplatNative/SplatResourceGuard.swift
grep -q 'passResourceGuard.evaluate' SplatNative/ScanModel.swift
grep -q 'SplatReconstructionRunReport.write' SplatNative/ScanModel.swift
python3 - <<'PY'
from pathlib import Path
s=Path('SplatNative/ScanModel.swift').read_text()
pause=s.index('if let reason = resourcePauseReason')
checkpoint=s.rfind('trainer.saveCheckpoint', 0, pause)
assert checkpoint >= 0
finish=s.index('func finishCapture()')
train=s.index('private func startTraining(')
detached=s.index('Task.detached', train)
prepare=s.index('Self.preparePointCloudPLY', detached)
assert finish < train < detached < prepare
assert 'preparePointCloudPLY' not in s[finish:train]
print('PASS: S2 reconstruction remains checkpoint-safe and off capture MainActor')
PY

# S3 viewer/edit parity: robust framing, true pan, crop/appearance editing and metric measurement.
grep -q 'robustFraming(for: points)' SplatNative/SplatViewer.swift
grep -q 'sceneCenter = framing.center' SplatNative/SplatViewer.swift
grep -q 'scenePan' SplatNative/SplatViewer.swift
grep -q 'measureTap' SplatNative/SplatViewer.swift
grep -q 'targetOffset' SplatNative/SplatViewer.swift
grep -q 'editedPoints' SplatNative/SplatViewer.swift
grep -q 'SplatViewerState' SplatNative/SplatViewer.swift
grep -q 'case crop = "切り抜き"' SplatNative/SplatResultView.swift
grep -q 'case adjust = "調整"' SplatNative/SplatResultView.swift
grep -q 'case measure = "計測"' SplatNative/SplatResultView.swift
grep -q '2本指で移動' SplatNative/SplatResultView.swift
grep -q 'ARKit実スケール' SplatNative/SplatResultView.swift
grep -q 'testDefaultEditSettingsAreNonDestructive' SplatNativeTests/SplatViewerStateTests.swift

# B Mesh parity: real capture/reconstruction paths, texture, editing, measurement and export contracts.
grep -q 'final class MeshScanModel' SplatNative/MeshScanModel.swift
grep -q 'sceneDepth' SplatNative/MeshScanModel.swift
grep -q 'MeshLiDARDenseFusion' SplatNative/MeshScanModel.swift
grep -q 'MeshDenseMVS' SplatNative/MeshScanModel.swift
grep -q 'MeshDenseTextureBaker' SplatNative/MeshScanModel.swift
grep -q 'MeshGeometryRefiner' SplatNative/MeshScanModel.swift
grep -q 'MeshScanCameraView' SplatNative/MeshScanView.swift
grep -q '2点タップで計測' SplatNative/MeshScanView.swift
grep -q 'Meshを書き出す' SplatNative/MeshScanView.swift

# Product-neutral until functional parity is achieved and local-only by default.
! grep -R -n 'おもちゃばこ' SplatNative project.yml
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

echo 'PASS: integrated Splat + Mesh static checks'
