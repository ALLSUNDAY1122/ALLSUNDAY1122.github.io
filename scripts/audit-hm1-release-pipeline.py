#!/usr/bin/env python3
from pathlib import Path
import re

text = Path('codemagic.yaml').read_text(encoding='utf-8')
match = re.search(r'(?ms)^  health-manager-1-testflight:\n(.*?)(?=^  [A-Za-z0-9_-]+:\n|\Z)', text)
if not match:
    raise SystemExit('FAIL: health-manager-1-testflight workflow missing')
section = match.group(0)
required = [
    'bundle_identifier: jp.allsunday1122.healthmanager1',
    'distribution_type: app_store',
    'xcode-project use-profiles',
    'submit_to_app_store: false',
]
for token in required:
    if token not in section:
        raise SystemExit(f'FAIL: HM1 release workflow missing {token!r}')
if 'testFlightInternalTestingOnly' in section:
    raise SystemExit('FAIL: HM1 release candidate export is INTERNAL_ONLY')
print('PASS: HM1 pipeline exports an App Store eligible candidate and does not auto-submit for review')
