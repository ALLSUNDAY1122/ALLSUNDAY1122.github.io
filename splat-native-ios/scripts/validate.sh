#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

test -f project.yml
test -f SplatNative/ScanModel.swift
test -f SplatNative/SplatViewer.swift
test -f SplatNative/RootScanView.swift
test -f SplatNative/SplatNativeApp.swift
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
