#!/usr/bin/env python3
from pathlib import Path
import hashlib

root=Path(__file__).resolve().parents[1]
icon=root/'Assets.xcassets'/'AppIcon.appiconset'/'AppIcon-1024.png'
expected='6afe16483852c98e0e030874ce7829f0e1a42fe017bb2f854eee1d9410f8ee80'
if not icon.exists():
    raise SystemExit('canonical AppIcon binary missing')
if hashlib.sha256(icon.read_bytes()).hexdigest()!=expected:
    raise SystemExit('canonical AppIcon SHA-256 mismatch')
p=root/'project.yml'
s=p.read_text(encoding='utf-8')
source='      - path: Sources\n'
catalog='      - path: Assets.xcassets\n'
catalog_block='      - path: Assets.xcassets\n        buildPhase: resources\n'
if catalog not in s:
    if source not in s: raise SystemExit('Sources marker missing')
    s=s.replace(source,source+catalog_block,1)
elif catalog_block not in s:
    s=s.replace(catalog,catalog_block,1)
bundle='        PRODUCT_BUNDLE_IDENTIFIER: jp.allsunday1122.kangoshi\n'
appicon='        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon\n'
if 'ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon' not in s:
    if bundle not in s: raise SystemExit('Bundle ID marker missing')
    s=s.replace(bundle,bundle+appicon,1)
if 'CFBundleIconName: AppIcon' not in s:
    props='      properties:\n'
    if props not in s: raise SystemExit('info.properties marker missing')
    s=s.replace(props,props+'        CFBundleIconName: AppIcon\n',1)
p.write_text(s,encoding='utf-8')
print('PASS: exact canonical AppIcon verified and bound')
