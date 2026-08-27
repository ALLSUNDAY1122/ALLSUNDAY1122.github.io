#!/usr/bin/env python3
from __future__ import annotations

import io
import json
import os
import plistlib
import urllib.request
import zipfile
from pathlib import Path

EXPECTED_BUILD_ID = "6a903f4e0b744f0115921f39"
TARGET_SUFFIXES = (
    "/Info.plist",
    "/PrivacyInfo.xcprivacy",
)


def safe_plist(raw: bytes):
    try:
        value = plistlib.loads(raw)
    except Exception:
        return None
    if isinstance(value, dict):
        allowed = {
            "CFBundleIdentifier",
            "CFBundleShortVersionString",
            "CFBundleVersion",
            "MinimumOSVersion",
            "ITSAppUsesNonExemptEncryption",
            "NSUserTrackingUsageDescription",
            "NSAppTransportSecurity",
            "NSPrivacyTracking",
            "NSPrivacyTrackingDomains",
            "NSPrivacyCollectedDataTypes",
            "NSPrivacyAccessedAPITypes",
        }
        return {k: value[k] for k in allowed if k in value}
    return value


def main() -> int:
    command = json.loads(Path('/tmp/release-command.json').read_text(encoding='utf-8'))
    if command.get('action') != 'inspect_artifact':
        raise SystemExit('action must be inspect_artifact')
    build_id = str(command.get('build_id') or '')
    if build_id != EXPECTED_BUILD_ID:
        raise SystemExit('unexpected build id')
    token = os.environ.get('CM_API_TOKEN','').strip()
    if not token:
        raise SystemExit('CM_API_TOKEN unavailable')

    req = urllib.request.Request(
        f'https://codemagic.io/api/v3/builds/{build_id}',
        headers={'x-auth-token': token, 'Accept': 'application/json'},
    )
    with urllib.request.urlopen(req, timeout=30) as response:
        payload = json.load(response)
    build = payload.get('data') or payload
    artifacts = build.get('artifacts') or []
    ipa = next((a for a in artifacts if a.get('type') == 'ipa'), None)
    if not ipa or not ipa.get('short_lived_download_url'):
        raise SystemExit('ipa artifact unavailable')

    with urllib.request.urlopen(ipa['short_lived_download_url'], timeout=60) as response:
        blob = response.read()
    zf = zipfile.ZipFile(io.BytesIO(blob))

    files = [i.filename for i in zf.infolist() if not i.is_dir()]
    audit = {}
    for name in files:
        if not name.endswith(TARGET_SUFFIXES):
            continue
        parsed = safe_plist(zf.read(name))
        if parsed is not None:
            audit[name] = parsed

    app_info = next((v for k, v in audit.items() if k == 'Payload/App.app/Info.plist'), {})
    privacy_files = {k: v for k, v in audit.items() if k.endswith('/PrivacyInfo.xcprivacy')}
    result = {
        'ok': True,
        'request_id': command.get('request_id'),
        'action': 'inspect_artifact',
        'build_id': build_id,
        'status': build.get('status'),
        'ipa': {
            'size_in_bytes': ipa.get('size_in_bytes'),
            'version_name': ipa.get('version_name'),
            'version_code': ipa.get('version_code'),
        },
        'app_info': app_info,
        'privacy_manifests': privacy_files,
        'privacy_manifest_count': len(privacy_files),
        'framework_names': sorted({n.split('/Frameworks/',1)[1].split('/',1)[0] for n in files if '/Frameworks/' in n}),
        'secret_values_persisted': False,
    }
    Path('release-result.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
