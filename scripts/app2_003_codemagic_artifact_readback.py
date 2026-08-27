#!/usr/bin/env python3
from __future__ import annotations

import io
import json
import os
import re
import urllib.request
import zipfile
from pathlib import Path

EXPECTED_BUILD_ID = "6a90341bd1e2d6f6c5af8a4d"


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
    if not artifacts:
        raise SystemExit('no build artifacts')
    url = artifacts[0].get('short_lived_download_url')
    if not url:
        raise SystemExit('artifact download URL unavailable')

    with urllib.request.urlopen(url, timeout=30) as response:
        blob = response.read()
    zf = zipfile.ZipFile(io.BytesIO(blob))
    chunks = []
    names = []
    for info in zf.infolist():
        if info.is_dir() or info.file_size > 5_000_000:
            continue
        names.append(info.filename)
        raw = zf.read(info)
        try:
            text = raw.decode('utf-8', errors='replace')
        except Exception:
            continue
        chunks.append(f'===== {info.filename} =====\n{text}')

    text = '\n'.join(chunks)
    text = re.sub(r'-----BEGIN [^-]+-----.*?-----END [^-]+-----', '[REDACTED PEM]', text, flags=re.S)
    text = re.sub(r'eyJ[A-Za-z0-9._-]{20,}', '[REDACTED JWT]', text)
    text = re.sub(r'(?i)(token|password|secret|private[_ -]?key)\s*[=:]\s*\S+', r'\1=[REDACTED]', text)
    result = {
        'ok': True,
        'request_id': command.get('request_id'),
        'action': 'inspect_artifact',
        'build_id': build_id,
        'status': build.get('status'),
        'artifact_files': names,
        'sanitized_text': text[-50000:],
        'secret_values_persisted': False,
    }
    Path('release-result.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
