#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

require_file() { test -f "$1" || { echo "missing: $1"; exit 1; }; }
require_text() { grep -q "$2" "$1" || { echo "missing contract '$2' in $1"; exit 1; }; }

# Project / legal / privacy
require_file project.yml
require_file SplatNative/PrivacyInfo.xcprivacy
require_file APP_REVIEW_NOTES_JA.md
require_file SplatNative/Resources/Licenses/msplat-APACHE-2.0.txt
require_file SplatNative/Resources/Licenses/MetalSplatter-MIT.txt
require_text project.yml 'jp.allsunday1122.splatlab'
require_text project.yml 'MARKETING_VERSION: 1.0.0'
require_text project.yml 'SplatNative/CapturePolicy.swift'
require_text project.yml 'SplatNative/SplatViewerState.swift'
require_text project.yml 'SplatNative/ScanProjectStore.swift'

# S1 capture / recovery
for f in ScanModel.swift ScanModel+SessionLifecycle.swift CapturePolicy.swift RootScanView.swift CapturePolicyTests.swift; do
  if [[ "$f" == *Tests.swift ]]; then require_file "SplatNativeTests/$f"; else require_file "SplatNative/$f"; fi
done
require_text SplatNative/ScanModel.swift 'CapturePolicy.shouldAcceptFrame'
require_text SplatNative/ScanModel.swift 'CapturePolicy.coverageSatisfied'
require_text SplatNative/ScanModel.swift 'sceneDepth'
require_text SplatNative/ScanModel.swift 'func pauseCapture'
require_text SplatNative/ScanModel.swift 'func resumeCapture'
require_text SplatNative/ScanModel.swift 'persistWorldMapIfPossible'
require_text SplatNative/ScanModel.swift 'restoreSavedProject'
require_text SplatNative/ScanModel+SessionLifecycle.swift 'sessionShouldAttemptRelocalization'
python3 - <<'PY'
from pathlib import Path
s=Path('SplatNative/ScanModel.swift').read_text()
resume=s.index('func resumeCapture()')
finish=s.index('func finishCapture()')
block=s[resume:finish]
assert 'var options: ARSession.RunOptions = []' in block
assert 'if let worldMap = pendingResumeWorldMap' in block
assert 'config.initialWorldMap = worldMap' in block
assert 'options = [.resetTracking, .removeExistingAnchors]' in block
assert 'session.run(config, options: options)' in block
print('PASS: in-memory resume preserves coordinates; cold resume restores ARWorldMap')
PY

# S2 reconstruction / resource safety
for f in SplatReconstructionPolicy.swift SplatSeedColorizer.swift SplatSkySeeder.swift SplatResourceGuard.swift; do require_file "SplatNative/$f"; done
require_text SplatNative/ScanModel.swift 'trainer.saveCheckpoint'
require_text SplatNative/ScanModel.swift 'trainer.loadCheckpoint'
require_text SplatNative/ScanModel.swift 'SplatSkySeeder.makeSeeds'
require_text SplatNative/ScanModel.swift 'passResourceGuard.evaluate'
require_text SplatNative/SplatReconstructionPolicy.swift 'trainingHorizon = 30_000'
require_text SplatNative/SplatReconstructionPolicy.swift 'standardIterations = 7_000'
require_text SplatNative/SplatReconstructionPolicy.swift 'enhancementIncrement = 5_000'

# S3 viewer / edit / measure
for f in SplatViewer.swift SplatViewerState.swift SplatResultView.swift; do require_file "SplatNative/$f"; done
require_file SplatNativeTests/SplatViewerStateTests.swift
require_text SplatNative/SplatViewer.swift 'robustFraming(for: points)'
require_text SplatNative/SplatViewer.swift 'scenePan'
require_text SplatNative/SplatViewer.swift 'measureTap'
require_text SplatNative/SplatViewer.swift 'editedPoints'
require_text SplatNative/SplatResultView.swift '切り抜き'
require_text SplatNative/SplatResultView.swift '調整'
require_text SplatNative/SplatResultView.swift '計測'
require_text SplatNative/SplatResultView.swift '品質向上'

# B Mesh
for f in MeshScanModel.swift MeshScanView.swift MeshAdvancedSupervisor.swift MeshDepthRecorder.swift MeshLiDARDenseFusion.swift MeshDenseMVS.swift MeshDenseTextureBaker.swift MeshGeometryRefiner.swift MeshAppearanceEditor.swift MeshTrimEditor.swift MeshDetailSimplifier.swift MeshRawReprocess.swift MeshARViewer.swift MeshParityAuditor.swift MeshAssetContract.swift; do require_file "SplatNative/$f"; done
require_text SplatNative/MeshScanModel.swift 'sceneReconstruction'
require_text SplatNative/MeshScanModel.swift 'PhotogrammetrySession'
require_text SplatNative/MeshScanView.swift '2点タップで計測'
require_text SplatNative/MeshAdvancedSupervisor.swift 'MeshDepthRecorder'
require_text SplatNative/MeshAdvancedSupervisor.swift 'fuseLiDARDenseDepth'
require_text SplatNative/MeshAdvancedSupervisor.swift 'refineMetricGeometry'
require_text SplatNative/MeshAdvancedSupervisor.swift 'bakeDenseRGBTextureAtlas'
require_text SplatNative/MeshAdvancedSupervisor.swift 'runMeshParityAudit'
require_text SplatNative/RootScanView.swift 'Meshをスキャン'

# C local library / durable resume foundation.
require_file SplatNative/ScanProjectStore.swift
require_file SplatNative/ScanLibraryView.swift
require_file SplatNativeTests/ScanProjectStoreTests.swift
require_file SplatNativeTests/ScanColdResumePersistenceTests.swift
require_text SplatNative/ScanProjectStore.swift 'commitPendingSplat'
require_text SplatNative/ScanProjectStore.swift 'reprocessRequest'
require_text SplatNative/ScanProjectStore.swift 'moveToTrash'
require_text SplatNative/ScanProjectStore.swift 'recoverInterruptedProcessing'
require_text SplatNative/ScanProjectStore.swift 'worldMapURL'
require_text SplatNative/ScanLibraryView.swift 'restoreSavedProject'

! grep -R -n 'おもちゃばこ' SplatNative project.yml

# D authenticated cloud sharing is explicit and isolated from capture/reconstruction core.
for f in ScanLabBackend.swift ScanLabShellView.swift ScanLabDiscoverFeedStore.swift PublishScanView.swift ScanLabAccountView.swift; do require_file "SplatNative/$f"; done
require_text SplatNative/SplatNativeApp.swift 'ScanLabShellView()'
require_text SplatNative/ScanLabShellView.swift 'RootScanView()'
require_text SplatNative/ScanLabBackend.swift 'import Supabase'
require_text SplatNative/ScanLabBackend.swift 'ScanLabVisibility'
require_text SplatNative/ScanLabDiscoverFeedStore.swift 'URLQueryItem(name: "offset"'
require_text SplatNative/ScanLabDiscoverFeedStore.swift 'URLQueryItem(name: "q"'
require_text SplatNative/ScanLabDiscoverFeedStore.swift 'guard hasMore, errorMessage == nil'
require_text SplatNative/ScanLabShellView.swift '.searchable(text: $feed.query'
require_text SplatNative/ScanLabShellView.swift '続きを再試行'
require_text SplatNative/PublishScanView.swift 'contentConfirmed'
require_text SplatNative/PublishScanView.swift 'publicPlaceConfirmed'
require_text project.yml 'package: Supabase'
require_text project.yml 'INFOPLIST_KEY_NSCameraUsageDescription'
require_text project.yml 'INFOPLIST_KEY_NSLocationWhenInUseUsageDescription'
! grep -qE 'INFOPLIST_KEY_NSLocationAlways|INFOPLIST_KEY_NSLocationAlwaysAndWhenInUse' project.yml
! grep -qE 'INFOPLIST_KEY_NSPhotoLibrary|INFOPLIST_KEY_NSMicrophoneUsageDescription|INFOPLIST_KEY_NSUserTrackingUsageDescription' project.yml
# D2-012: prefetch pagination must not skip rows that were fetched but not yet emitted,
# must terminate before replaying a capped page, and failed next-page loads require explicit retry.
python3 - <<'PY'
from pathlib import Path
edge=Path('supabase/functions/scanlab-public/index.ts').read_text()
store=Path('SplatNative/ScanLabDiscoverFeedStore.swift').read_text()
assert 'let consumedRows = 0' in edge
assert 'consumedRows += 1' in edge
assert 'if (visible.length === limit) break' in edge
assert 'const nextOffset = offset + consumedRows' in edge
assert 'const maxOffset = 10000' in edge
assert 'nextOffset <= maxOffset && (consumedRows < rows.length || rows.length === fetchCount)' in edge
assert 'nextOffset: hasMore ? nextOffset : null' in edge
assert 'offset + rows.length' not in edge
assert 'guard hasMore, errorMessage == nil, !isLoadingInitial, !isLoadingMore else { return }' in store
assert 'func clearError()' in store
print('PASS: Discover pagination preserves rows, terminates at cap, and requires explicit retry after errors')
PY
! grep -nE 'URLSession|Supabase' SplatNative/ScanModel.swift SplatNative/ScanModel+SessionLifecycle.swift SplatNative/SplatReconstructionPolicy.swift SplatNative/ScanProjectStore.swift
! grep -R -nE 'Firebase|Amplitude|Mixpanel|AppsFlyer|Adjust' SplatNative --include='*.swift'

# D2-020: privacy manifest, permission strings and review explanation must move together.
plutil -lint SplatNative/PrivacyInfo.xcprivacy >/dev/null
python3 - <<'PY'
import plistlib
from pathlib import Path
with open('SplatNative/PrivacyInfo.xcprivacy','rb') as f:
    data=plistlib.load(f)
assert data.get('NSPrivacyTracking') is False
assert data.get('NSPrivacyTrackingDomains') == []
collected = data.get('NSPrivacyCollectedDataTypes', [])
by_type = {item.get('NSPrivacyCollectedDataType'): item for item in collected}
expected = {
    'NSPrivacyCollectedDataTypeName',
    'NSPrivacyCollectedDataTypeEmailAddress',
    'NSPrivacyCollectedDataTypeUserID',
    'NSPrivacyCollectedDataTypePreciseLocation',
    'NSPrivacyCollectedDataTypeOtherUserContent',
}
assert set(by_type) == expected, (set(by_type), expected)
for kind in expected:
    item = by_type[kind]
    assert item.get('NSPrivacyCollectedDataTypeLinked') is True
    assert item.get('NSPrivacyCollectedDataTypeTracking') is False
    assert item.get('NSPrivacyCollectedDataTypePurposes') == ['NSPrivacyCollectedDataTypePurposeAppFunctionality']
assert data.get('NSPrivacyAccessedAPITypes') == []

project=Path('project.yml').read_text()
review=Path('APP_REVIEW_NOTES_JA.md').read_text()
assert '周囲を撮影して端末内で3Dスキャンを生成するため、カメラを使用します。' in project
assert 'Mapへ公開する地点をユーザーが明示的に設定した場合だけ、現在地を取得します。位置情報は自動送信しません。' in project
for phrase in ['Camera:', 'Location When In Use:', 'Tracking:', 'Name:', 'Email Address:', 'User ID:', 'Precise Location:', 'Other User Content:', 'NSPrivacyTracking = false']:
    assert phrase in review, phrase
assert '現段階ではログインはありません' not in review
assert 'Location: 現段階では要求しません' not in review
print('PASS: D2 privacy manifest / permissions / App Review explanation are aligned')
PY

echo 'PASS: integrated Scan Lab static contracts'
