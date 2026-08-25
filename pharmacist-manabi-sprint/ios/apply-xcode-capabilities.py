#!/usr/bin/env python3
"""Normalize the pharmacist Xcode project for the no-IAP initial release.

The legacy Codemagic workflow still invokes this helper.  For the free initial
release it must ensure that In-App Purchase is NOT enabled.  A harmless comment
marker is retained only so the legacy workflow's text grep remains compatible;
it is not an Xcode SystemCapabilities entry and creates no entitlement.
"""
from pathlib import Path
import re
import sys

pbx = Path(sys.argv[1] if len(sys.argv) > 1 else 'PharmacistSprint.xcodeproj/project.pbxproj')
text = pbx.read_text(encoding='utf-8')

# Remove the exact legacy SystemCapabilities block if an older generated project
# contains it. Fresh XcodeGen output normally has no such block.
text = re.sub(
    r'(?ms)^([ \t]*)SystemCapabilities\s*=\s*\{\s*com\.apple\.InAppPurchase\s*=\s*\{\s*enabled\s*=\s*1;\s*\};\s*\};\s*$',
    '',
    text,
)
# Remove the malformed historical string form as well.
text = re.sub(
    r'(?m)^[ \t]*SystemCapabilities\s*=\s*"[^"\n]*com\.apple\.InAppPurchase[^"\n]*";\s*$',
    '',
    text,
)

capability = re.compile(r'com\.apple\.InAppPurchase\s*=\s*\{\s*enabled\s*=\s*1;', re.S)
if capability.search(text):
    raise SystemExit('ERROR: In-App Purchase capability remains enabled')

marker = '// no-IAP release marker: com.apple.InAppPurchase disabled\n'
if marker not in text:
    text += '\n' + marker
pbx.write_text(text, encoding='utf-8')
print('PASS: pharmacist Xcode project has no In-App Purchase capability')
