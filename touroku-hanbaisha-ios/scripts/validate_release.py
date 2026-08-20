#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import plistlib
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
IOS = ROOT / "touroku-hanbaisha-ios"
NATIVE = IOS / "native-ios"
WEB = ROOT / "touroku-hanbaisha-sprint"
EXPECTED_BUNDLE = "com.allsunday1122.tourokuhanbaisha"
EXPECTED_APP_ID = "6802119268"
EXPECTED_TEAM = "MN3D2ZM44N"
EXPECTED_ICON_SHA = "c0cefbae22cdcd7b614d213ddca7942c7d693f02ead758b11b66d447a66bff03"
EXPECTED_WEB_URL = "https://allsunday1122.github.io/touroku-hanbaisha-sprint/"
EXPECTED_ORIENTATIONS = (
    "INFOPLIST_KEY_UISupportedInterfaceOrientations: \"UIInterfaceOrientationPortrait "
    "UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft "
    "UIInterfaceOrientationLandscapeRight\""
)
EXPECTED_EXPORT_COMPLIANCE = "INFOPLIST_KEY_ITSAppUsesNonExemptEncryption: NO"

app = json.loads((IOS / "app.json").read_text(encoding="utf-8"))['expo']
assert app['version'] == '1.0.0'
assert app['ios']['bundleIdentifier'] == EXPECTED_BUNDLE
assert app['extra']['webAppUrl'] == EXPECTED_WEB_URL
assert app['ios']['icon'].endswith('AppIcon-1024.png')

project = (NATIVE / "project.yml").read_text(encoding="utf-8")
for token in (
    EXPECTED_BUNDLE,
    EXPECTED_TEAM,
    'MARKETING_VERSION: 1.0.0',
    'ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon',
    EXPECTED_ORIENTATIONS,
    EXPECTED_EXPORT_COMPLIANCE,
):
    assert token in project, f'missing project setting: {token}'
assert '\n    resources:\n' not in project, 'XcodeGen target resources must be declared under sources'
for token in (
    '- path: Assets.xcassets\n        buildPhase: resources',
    '- path: PrivacyInfo.xcprivacy\n        buildPhase: resources',
):
    assert token in project, f'missing XcodeGen resource source: {token}'

icon = NATIVE / "Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
data = icon.read_bytes()
assert hashlib.sha256(data).hexdigest() == EXPECTED_ICON_SHA
assert data[:8] == b'\x89PNG\r\n\x1a\n'
w, h = struct.unpack('>II', data[16:24])
assert (w, h) == (1024, 1024)

with (NATIVE / "PrivacyInfo.xcprivacy").open('rb') as f:
    privacy = plistlib.load(f)
assert privacy.get('NSPrivacyTracking') is False
assert privacy.get('NSPrivacyCollectedDataTypes') == []

for name in ('index.html', 'history-calendar-v02.js', 'support.html', 'privacy.html'):
    assert (WEB / name).is_file(), f'missing web release input: {name}'
index = (WEB / 'index.html').read_text(encoding='utf-8')
history = (WEB / 'history-calendar-v02.js').read_text(encoding='utf-8')
assert 'history-calendar-v02.js' in index
for token in ('state?.inProgress', 'chapterAnswered', 'inProgress=true'):
    assert token in history, f'missing history-calendar behavior marker: {token}'

metadata = (IOS / 'APP_STORE_METADATA.md').read_text(encoding='utf-8')
assert f'Bundle ID: {EXPECTED_BUNDLE}' in metadata
assert f'- サポート: {EXPECTED_WEB_URL}support.html' in metadata
assert f'- プライバシーポリシー: {EXPECTED_WEB_URL}privacy.html' in metadata

print(f'PASS: Touhan release inputs; bundle={EXPECTED_BUNDLE}; app_id={EXPECTED_APP_ID}; icon_sha256={EXPECTED_ICON_SHA}; orientations=all-four; export_compliance=exempt')
