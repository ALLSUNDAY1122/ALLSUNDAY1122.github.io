#!/usr/bin/env python3
from pathlib import Path
import re,sys
pbx=Path(sys.argv[1] if len(sys.argv)>1 else 'KangoshiSprint.xcodeproj/project.pbxproj')
text=pbx.read_text(encoding='utf-8')
proper=re.compile(r'com\.apple\.InAppPurchase\s*=\s*\{\s*enabled\s*=\s*1;\s*\};',re.S)
if proper.search(text):
    print('PASS: IAP capability present')
    raise SystemExit(0)
malformed=re.compile(r'(?m)^(?P<i>[ \t]*)SystemCapabilities\s*=\s*"[^"\n]*com\.apple\.InAppPurchase[^"\n]*";\s*$')
m=malformed.search(text)
if m:
    i=m.group('i')
    rep=f'{i}SystemCapabilities = {{\n{i}\tcom.apple.InAppPurchase = {{\n{i}\t\tenabled = 1;\n{i}\t}};\n{i}}};'
    text=text[:m.start()]+rep+text[m.end():]
else:
    m=re.search(r'(?m)^(?P<i>[ \t]*)ProvisioningStyle\s*=\s*Automatic;\s*$',text)
    if not m:
        raise SystemExit('ERROR: target ProvisioningStyle not found')
    i=m.group('i')
    ins=f'\n{i}SystemCapabilities = {{\n{i}\tcom.apple.InAppPurchase = {{\n{i}\t\tenabled = 1;\n{i}\t}};\n{i}}};'
    text=text[:m.end()]+ins+text[m.end():]
if not proper.search(text):
    raise SystemExit('ERROR: failed to add IAP capability')
pbx.write_text(text,encoding='utf-8')
print('PASS: normalized In-App Purchase capability')
