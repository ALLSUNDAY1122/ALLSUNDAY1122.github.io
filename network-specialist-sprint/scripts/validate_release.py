from pathlib import Path
import json, plistlib, re, struct, sys

root = Path(__file__).resolve().parents[1]
errors = []
required = [
    'index.html','style-v21.css','app-v21.js','questions-meta.js','questions-2025-a.js','questions-2025-b.js','questions-2024-a.js','questions-2024-b.js','questions-2023-a.js','questions-2023-b.js','questions-ui-fixes.js','manifest.json','sw.js','support.html','privacy.html',
    'ios/project.yml','ios/NetworkSpecialist/NetworkSpecialistApp.swift','ios/NetworkSpecialist/ContentView.swift',
    'ios/NetworkSpecialist/PrivacyInfo.xcprivacy',
    'ios/NetworkSpecialist/Assets.xcassets/AppIcon.appiconset/APPICON_SOURCE.md'
]
for rel in required:
    if not (root / rel).exists(): errors.append(f'missing: {rel}')

try:
    manifest = json.loads((root/'manifest.json').read_text(encoding='utf-8'))
    if manifest.get('orientation') != 'portrait': errors.append('manifest orientation must be portrait')
except Exception as e: errors.append(f'manifest invalid: {e}')

try:
    with (root/'ios/NetworkSpecialist/PrivacyInfo.xcprivacy').open('rb') as f: plistlib.load(f)
except Exception as e: errors.append(f'PrivacyInfo invalid: {e}')

try:
    with (root/'ios/NetworkSpecialist/Info.plist').open('rb') as f: info=plistlib.load(f)
    if info.get('ITSAppUsesNonExemptEncryption') is not False: errors.append('ITSAppUsesNonExemptEncryption must be false')
except Exception as e: errors.append(f'Info.plist invalid: {e}')

icon_path=root/'ios/NetworkSpecialist/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png'
if icon_path.exists():
    try:
        data=icon_path.read_bytes()[:33]
        if data[:8] != b'\x89PNG\r\n\x1a\n' or data[12:16] != b'IHDR':
            raise ValueError('not a PNG with IHDR')
        width,height=struct.unpack('>II',data[16:24])
        color_type=data[25]
        if (width,height) != (1024,1024): errors.append(f'AppIcon size is {(width,height)}')
        if color_type not in (2,6): errors.append(f'AppIcon PNG color type is {color_type}; RGB/RGBA required')
    except Exception as e: errors.append(f'AppIcon invalid: {e}')
else:
    source=(root/'ios/NetworkSpecialist/Assets.xcassets/AppIcon.appiconset/APPICON_SOURCE.md').read_text(encoding='utf-8')
    if '1V9gAXcE7jSuYn9Y8SFgYWHNfRGsE_Lb8' not in source: errors.append('AppIcon source reference missing')

js=(root/'app-v21.js').read_text(encoding='utf-8')
if "manabiSprint.networkSpecialist" not in js: errors.append('storage key mismatch')
if '2025' not in js or '2024' not in js or '2023' not in js: errors.append('3 exam years missing')
q=(root/'questions-meta.js').read_text(encoding='utf-8')
if 'NW_EXAM_OCCURRENCES' not in q or 'NW_UNIQUE_IDS' not in q: errors.append('question meta schema missing')
for y in ('2025','2024','2023'):
    for s in ('a','b'):
        if 'NW_EXAM_OCCURRENCES.push' not in (root/f'questions-{y}-{s}.js').read_text(encoding='utf-8'): errors.append(f'question year file invalid: {y}-{s}')
if 'NW_EXAM_OCCURRENCES' not in (root/'questions-ui-fixes.js').read_text(encoding='utf-8'): errors.append('UI classification fixes missing')
if 'questions-ui-fixes.js' not in (root/'index.html').read_text(encoding='utf-8'): errors.append('UI classification fixes not loaded')
if 'questions-ui-fixes.js' not in (root/'sw.js').read_text(encoding='utf-8'): errors.append('UI classification fixes not cached')
if re.search(r'http://', (root/'support.html').read_text(encoding='utf-8') + (root/'privacy.html').read_text(encoding='utf-8')): errors.append('insecure http link in public pages')

if errors:
    print('FAIL')
    for e in errors: print('-',e)
    sys.exit(1)
print('PASS: release static validation')
