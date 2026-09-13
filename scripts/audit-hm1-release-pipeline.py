#!/usr/bin/env python3
from pathlib import Path

text = Path('codemagic.yaml').read_text(encoding='utf-8')
start = text.find('\n  health-manager-1-testflight:')
if start < 0:
    raise SystemExit('FAIL: health-manager-1-testflight workflow missing')
end = text.find('\n  ', start + 4)
section = text[start:end if end >= 0 else len(text)]
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
