#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

test -f project.yml
test -f SplatNative/ScanModel.swift
test -f SplatNative/ScanModel+SessionLifecycle.swift
test -f SplatNative/ScanProjectStore.swift
test -f SplatNative/SplatViewer.swift
test -f SplatNative/RootScanView.swift
test -f SplatNative/SplatNativeApp.swift
test -f SplatNative/PrivacyInfo.xcprivacy
test -f SplatNativeTests/ScanProjectStoreTests.swift
test -f scripts/scan-project-store-tests/main.swift

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

# Regression gate: the root view must mount the AR session before the first
# capture button can call ScanModel.startCapture(). ARSCNView itself does not
# auto-run world tracking; ScanModel explicitly starts it with session.run().
grep -q 'RootScanView()' SplatNative/SplatNativeApp.swift
grep -q 'PersistentScanCameraView()' SplatNative/RootScanView.swift
grep -q 'model.attach(session: view.session)' SplatNative/RootScanView.swift
grep -q 'session.run(config' SplatNative/ScanModel.swift

# Permission/session failure must surface instead of leaving the user on a dead camera screen.
grep -q 'didFailWithError' SplatNative/ScanModel+SessionLifecycle.swift
grep -q 'sessionWasInterrupted' SplatNative/ScanModel+SessionLifecycle.swift
grep -q 'sessionInterruptionEnded' SplatNative/ScanModel+SessionLifecycle.swift

# Harsh-review gate: photo count alone is not enough. The capture must require
# spatial coverage and real translation so spinning in place cannot complete a scan.
grep -q 'minimumCoverageSectors = 8' SplatNative/ScanModel.swift
grep -q 'coverageSectorCount >= minimumCoverageSectors' SplatNative/ScanModel.swift
grep -q 'translation >= 0.030 || (translation >= 0.012 && angle >= 0.080)' SplatNative/ScanModel.swift
grep -q 'acceptedFrames < maxFrames' SplatNative/ScanModel.swift
grep -q '同じ側の写真に偏っています' SplatNative/ScanModel.swift

# S8 #4149: a frame storage write failure is terminal for the active capture.
# It must never fall through to another write attempt while the UI remains `.capturing`.
grep -q 'private func failCaptureStorage()' SplatNative/ScanModel.swift
grep -q 'guard success else {' SplatNative/ScanModel.swift
grep -q 'self.failCaptureStorage()' SplatNative/ScanModel.swift
grep -q 'session?.pause()' SplatNative/ScanModel.swift
grep -q 'iPhoneの空き容量を確認して' SplatNative/ScanModel.swift
# A recoverable capture failure with a persisted checkpoint must be resumable after reopening
# and directly from the failure screen while the in-memory AR coordinate frame still exists.
grep -q 'stage == .capturing || stage == .captured || stage == .failed' SplatNative/ScanModel.swift
test "$(grep -c 'if model.activeProjectCanResume' SplatNative/RootScanView.swift)" -ge 2

# Harsh-review gate: a successful splat must open centered on its actual data,
# and the user must be able to restore that framing.
grep -q 'robustFraming(for: points)' SplatNative/SplatViewer.swift
grep -q 'sceneCenter = framing.center' SplatNative/SplatViewer.swift
grep -q 'center: sceneCenter' SplatNative/SplatViewer.swift
grep -q 'resetView' SplatNative/SplatViewer.swift

# S5 lifecycle gate: projects must be self-describing and reconstructible without an in-memory index.
grep -q 'manifest.json' SplatNative/ScanProjectStore.swift
grep -q 'capture-checkpoint.plist' SplatNative/ScanProjectStore.swift
grep -q 'worldmap.arexperience' SplatNative/ScanProjectStore.swift
grep -q 'loadOrMigrateManifest' SplatNative/ScanProjectStore.swift
grep -q 'recoveredAfterInterruption' SplatNative/ScanProjectStore.swift
grep -q 'moveToTrash' SplatNative/ScanProjectStore.swift
grep -q 'restoreFromTrash' SplatNative/ScanProjectStore.swift
grep -q 'clearRawData' SplatNative/ScanProjectStore.swift
grep -q 'reprocessRequest' SplatNative/ScanProjectStore.swift

# S8 #4151: active reconstruction must use a two-phase write plus durable completion evidence.
grep -q 'result.pending.splat' SplatNative/ScanProjectStore.swift
grep -q 'result.splat.complete.json' SplatNative/ScanProjectStore.swift
grep -q 'commitPendingSplat' SplatNative/ScanProjectStore.swift
grep -q 'committedSplatURL' SplatNative/ScanProjectStore.swift
grep -q 'ScanProjectStore.pendingSplatFileName' SplatNative/ScanModel.swift
grep -q 'detachedStore.commitPendingSplat' SplatNative/ScanModel.swift
! grep -q 'trainer.exportSplat(to: output.path)' SplatNative/ScanModel.swift

# S5 product wiring: raw data can be saved before processing, reopened, resumed when
# relocalization data exists, and a finished scan is not destroyed by leaving the viewer.
grep -q 'saveDraftAndReturnToLibrary' SplatNative/RootScanView.swift
grep -q 'model.openProject' SplatNative/RootScanView.swift
grep -q 'model.resumeActiveCapture' SplatNative/RootScanView.swift
grep -q 'model.reprocessCurrentSplat' SplatNative/RootScanView.swift
grep -q 'model.clearRawDataForActiveProject' SplatNative/RootScanView.swift
grep -q 'model.returnToLibrary' SplatNative/RootScanView.swift
grep -q 'persistCaptureCheckpoint' SplatNative/ScanModel.swift
grep -q 'persistWorldMapIfPossible' SplatNative/ScanModel.swift
grep -q 'ScanProjectStore' project.yml

# Harsh-review gate: consumer UI must not expose internal training/debug jargon,
# and destructive loss of a finished scan needs an explicit confirmation.
grep -q 'Text("Scan Lab")' SplatNative/RootScanView.swift
grep -q 'showingDiscardConfirmation' SplatNative/RootScanView.swift
grep -q '生成だけもう一度試す' SplatNative/RootScanView.swift
! grep -q '特徴点 ' SplatNative/RootScanView.swift
! grep -q 'iteration ' SplatNative/RootScanView.swift
! grep -q 'splats ' SplatNative/RootScanView.swift

# Parity work must remain product-neutral until Scaniverse functional parity is achieved.
! grep -R -n 'おもちゃばこ' SplatNative project.yml

# Current PoC is intentionally local-only.
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
