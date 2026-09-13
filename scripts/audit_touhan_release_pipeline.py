#!/usr/bin/env python3
"""Fail closed if Touhan regresses to Internal-TestFlight-only packaging."""
from pathlib import Path
import re

text = Path('codemagic.yaml').read_text(encoding='utf-8')
start = text.find('\n  touhan-ios:\n')
if start < 0:
    raise SystemExit('FAIL: touhan-ios workflow missing')
start += 1
rest = text[start + len('  touhan-ios:\n'):]
match = re.search(r'(?m)^  [A-Za-z0-9_-]+:\s*$', rest)
end = start + len('  touhan-ios:\n') + (match.start() if match else len(rest))
block = text[start:end]

# Touhan provisions its App Store profile explicitly via Codemagic CLI instead of
# declaring ios_signing/distribution_type in the workflow. Validate the real path,
# not one particular Codemagic syntax.
required = (
    'name: 登録販売者 - iOS App Store Release Candidate',
    'BUNDLE_ID: com.allsunday1122.tourokuhanbaisha',
    'APP_STORE_CONNECT_APP_ID: "6802119268"',
    'CODEMAGIC_PROFILE_REF: tourokuhanbaisha_appstore',
    'python3 touroku-hanbaisha-ios/scripts/validate_release.py',
    '--type IOS_APP_STORE',
    'keychain add-certificates',
    'xcode-project use-profiles',
    'app-store-connect publish',
)
for token in required:
    if token not in block:
        raise SystemExit(f'FAIL: Touhan release pipeline missing {token}')

for forbidden in (
    'testFlightInternalTestingOnly',
    'submit_to_app_store: true',
    'submit_to_testflight: true',
):
    if forbidden in block:
        raise SystemExit(f'FAIL: Touhan release pipeline contains forbidden marker {forbidden}')

print('PASS: Touhan pipeline provisions IOS_APP_STORE signing and produces an App Store eligible candidate without auto submission/distribution')
