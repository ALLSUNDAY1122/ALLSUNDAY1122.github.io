#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

test -f project.yml
test -f SplatNative/ScanModel.swift
test -f SplatNative/ScanModel+SessionLifecycle.swift
test -f SplatNative/SplatViewer.swift
test -f SplatNative/RootScanView.swift
test -f SplatNative/SplatNativeApp.swift
test -f SplatNative/PrivacyInfo.xcprivacy
test -f SplatNative/ScanLabBackend.swift
test -f SplatNative/ScanLabShellView.swift
test -f SplatNative/PublishScanView.swift
test -f SplatNative/ScanLabAccountView.swift

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

# Harsh-review gate: a successful splat must open centered on its actual data,
# and the user must be able to restore that framing.
grep -q 'robustFraming(for: points)' SplatNative/SplatViewer.swift
grep -q 'sceneCenter = framing.center' SplatNative/SplatViewer.swift
grep -q 'center: sceneCenter' SplatNative/SplatViewer.swift
grep -q 'resetView' SplatNative/SplatViewer.swift

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

# S7 intentionally adds authenticated cloud sharing. Network access is therefore
# expected, but it must use the declared Supabase client and must not introduce
# advertising/analytics SDKs as a side effect of the parity work.
grep -q 'import Supabase' SplatNative/ScanLabBackend.swift
grep -q 'ScanLabVisibility' SplatNative/ScanLabBackend.swift
grep -q 'contentConfirmed' SplatNative/PublishScanView.swift
grep -q 'publicPlaceConfirmed' SplatNative/PublishScanView.swift
! grep -R -nE 'Firebase|Amplitude|Mixpanel' SplatNative --include='*.swift'

plutil -lint SplatNative/PrivacyInfo.xcprivacy >/dev/null
python3 - <<'PY'
import plistlib
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
assert expected.issubset(by_type), (expected - set(by_type))
for kind in expected:
    item = by_type[kind]
    assert item.get('NSPrivacyCollectedDataTypeLinked') is True
    assert item.get('NSPrivacyCollectedDataTypeTracking') is False
    assert 'NSPrivacyCollectedDataTypePurposeAppFunctionality' in item.get('NSPrivacyCollectedDataTypePurposes', [])
print('PASS: Privacy Manifest matches S7 authenticated sharing')
PY

echo 'PASS: static Splat Lab Native checks'
