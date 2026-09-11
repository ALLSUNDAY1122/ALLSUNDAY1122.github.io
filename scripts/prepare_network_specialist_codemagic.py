#!/usr/bin/env python3
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
path = ROOT / 'codemagic.yaml'
text = path.read_text(encoding='utf-8')
marker = '\n  network-specialist-native-ios:\n'
if marker not in text:
    raise SystemExit('network-specialist-native-ios workflow missing')

start = text.index(marker)
search_from = start + len(marker)
next_match = re.search(r'(?m)^  [A-Za-z0-9][A-Za-z0-9_.-]*:\s*$', text[search_from:])
end = search_from + next_match.start() if next_match else len(text)
block = text[start:end]
original = block

# Canonical integration and automatic signing must match the app-local source of truth.
block = block.replace('      app_store_connect: "Codemagic Shiwake Swipe"\n', '      app_store_connect: networkspecialist_appstore\n', 1)
if '      ios_signing:\n        distribution_type: app_store\n        bundle_identifier: jp.allsunday1122.networkspecialist\n' not in block:
    block = block.replace(
        '    environment:\n      vars:\n',
        '    environment:\n      ios_signing:\n        distribution_type: app_store\n        bundle_identifier: jp.allsunday1122.networkspecialist\n      vars:\n',
        1,
    )

# Remove brittle manual signing fetch. Codemagic ios_signing resolves the uploaded
# certificate/profile pair before scripts run.
manual = '''      - name: Initialize signing keychain\n        script: keychain initialize\n      - name: Fetch or create App Store signing files\n        script: app-store-connect fetch-signing-files "$BUNDLE_ID" --type IOS_APP_STORE --create\n      - name: Add signing certificate to keychain\n        script: keychain add-certificates\n'''
block = block.replace(manual, '', 1)

# AppIcon must come from the repository canonical binary, never public Drive curl.
old_start_line = "          DEST='network-specialist-sprint/ios/NetworkSpecialist/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png'\n"
src_line = "          SRC='network-specialist-sprint/07_ネットワークスペシャリスト試験.png'\n"
resume_line = '          python3 network-specialist-sprint/scripts/build_native_questions.py\n'
if src_line not in block:
    rel_start = block.find(old_start_line)
    rel_resume = block.find(resume_line, rel_start)
    if rel_start < 0 or rel_resume < 0:
        raise SystemExit('expected network-specialist AppIcon transport block not found')
    replacement = (
        src_line + old_start_line
        + '          test -f "$SRC"\n'
        + '          test "$(stat -f%z "$SRC")" = \'678310\'\n'
        + '          test "$(shasum -a 256 "$SRC" | awk \'{print $1}\')" = "$APPICON_SHA256"\n'
        + '          mkdir -p "$(dirname "$DEST")"\n'
        + '          cp "$SRC" "$DEST"\n'
    )
    block = block[:rel_start] + replacement + block[rel_resume:]

# TestFlight is a Human Gate, never a development-QA side effect.
block = block.replace('        submit_to_testflight: true\n', '        submit_to_testflight: false\n', 1)

if block == original:
    print('network-specialist-native-ios already canonical')
    raise SystemExit(0)

text = text[:start] + block + text[end:]
path.write_text(text, encoding='utf-8')
print('repaired network-specialist-native-ios integration/signing/AppIcon/TestFlight policy')
