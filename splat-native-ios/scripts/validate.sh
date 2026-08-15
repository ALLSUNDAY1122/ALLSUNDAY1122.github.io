#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

require_file() { test -f "$1" || { echo "missing: $1"; exit 1; }; }
require_text() { grep -q "$2" "$1" || { echo "missing contract '$2' in $1"; exit 1; }; }

# Project / legal / privacy
require_file project.yml
require_file SplatNative/PrivacyInfo.xcprivacy
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
require_text SplatNative/ScanModel+SessionLifecycle.swift 'sessionShouldAttemptRelocalization'
python3 - <<'PY'
from pathlib import Path
s=Path('SplatNative/ScanModel.swift').read_text()
resume=s.index('func resumeCapture()')
finish=s.index('func finishCapture()')
block=s[resume:finish]
assert 'options: []' in block
assert '.resetTracking' not in block
print('PASS: capture resume preserves AR world coordinates')
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

# B Mesh: base ARKit/Photogrammetry path plus advanced supervisor pipeline.
for f in \
  MeshScanModel.swift MeshScanView.swift MeshAdvancedSupervisor.swift MeshDepthRecorder.swift \
  MeshLiDARDenseFusion.swift MeshDenseMVS.swift MeshDenseTextureBaker.swift MeshGeometryRefiner.swift \
  MeshAppearanceEditor.swift MeshTrimEditor.swift MeshDetailSimplifier.swift MeshRawReprocess.swift \
  MeshARViewer.swift MeshParityAuditor.swift MeshAssetContract.swift; do
  require_file "SplatNative/$f"
done
require_text SplatNative/MeshScanModel.swift 'sceneReconstruction'
require_text SplatNative/MeshScanModel.swift 'PhotogrammetrySession'
require_text SplatNative/MeshScanView.swift '2点タップで計測'
require_text SplatNative/MeshAdvancedSupervisor.swift 'MeshDepthRecorder'
require_text SplatNative/MeshAdvancedSupervisor.swift 'fuseLiDARDenseDepth'
require_text SplatNative/MeshAdvancedSupervisor.swift 'refineMetricGeometry'
require_text SplatNative/MeshAdvancedSupervisor.swift 'bakeDenseRGBTextureAtlas'
require_text SplatNative/MeshAdvancedSupervisor.swift 'runMeshParityAudit'
require_text SplatNative/RootScanView.swift 'Meshをスキャン'

# C local library foundation is present before lifecycle hooks are wired.
require_file SplatNative/ScanProjectStore.swift
require_file SplatNativeTests/ScanProjectStoreTests.swift
require_text SplatNative/ScanProjectStore.swift 'commitPendingSplat'
require_text SplatNative/ScanProjectStore.swift 'reprocessRequest'
require_text SplatNative/ScanProjectStore.swift 'moveToTrash'
require_text SplatNative/ScanProjectStore.swift 'recoverInterruptedProcessing'

# Product-neutral and local-only by default.
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
print('PASS: Privacy Manifest matches local-only app')
PY

echo 'PASS: integrated Scan Lab static contracts'
