#!/usr/bin/env python3
from pathlib import Path
import re
import sys

pbx = Path(sys.argv[1] if len(sys.argv) > 1 else 'TsukanshiSprint.xcodeproj/project.pbxproj')
text = pbx.read_text(encoding='utf-8')

proper_re = re.compile(
    r'com\.apple\.InAppPurchase\s*=\s*\{\s*enabled\s*=\s*1;\s*\};',
    re.S,
)

if proper_re.search(text):
    print('PASS: In-App Purchase capability already normalized.')
    raise SystemExit(0)

# XcodeGen 2.46 serializes a nested TargetAttributes dictionary supplied via
# target.attributes as a quoted Swift dictionary description. Normalize that
# representation into the OpenStep dictionary syntax expected by .pbxproj.
malformed = re.compile(
    r'(?m)^(?P<indent>[ \t]*)SystemCapabilities\s*=\s*"[^"\n]*com\.apple\.InAppPurchase[^"\n]*";\s*$'
)
match = malformed.search(text)
if match:
    indent = match.group('indent')
    replacement = (
        f'{indent}SystemCapabilities = {{\n'
        f'{indent}\tcom.apple.InAppPurchase = {{\n'
        f'{indent}\t\tenabled = 1;\n'
        f'{indent}\t}};\n'
        f'{indent}}};'
    )
    text = text[:match.start()] + replacement + text[match.end():]
else:
    # Fallback for specs without SystemCapabilities: insert into the first
    # TargetAttributes target dictionary, immediately after ProvisioningStyle.
    marker = re.search(r'(?m)^(?P<indent>[ \t]*)ProvisioningStyle\s*=\s*Automatic;\s*$', text)
    if not marker:
        raise SystemExit('ERROR: could not locate target ProvisioningStyle in generated project')
    indent = marker.group('indent')
    insertion = (
        '\n'
        f'{indent}SystemCapabilities = {{\n'
        f'{indent}\tcom.apple.InAppPurchase = {{\n'
        f'{indent}\t\tenabled = 1;\n'
        f'{indent}\t}};\n'
        f'{indent}}};'
    )
    text = text[:marker.end()] + insertion + text[marker.end():]

if not proper_re.search(text):
    raise SystemExit('ERROR: failed to normalize In-App Purchase capability')

pbx.write_text(text, encoding='utf-8')
print('PASS: normalized generated Xcode project with In-App Purchase capability.')
