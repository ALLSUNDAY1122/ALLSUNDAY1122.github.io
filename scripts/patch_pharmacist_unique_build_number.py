#!/usr/bin/env python3
from pathlib import Path

p = Path('codemagic.yaml')
text = p.read_text(encoding='utf-8')
start = text.index('  pharmacist-ios:')
end = text.index('\n  shoshi-ios:', start)
block = text[start:end]
old = '''      - name: Set CI build number and generate native project
        script: |
          cd "$CM_BUILD_DIR/pharmacist-manabi-sprint/ios"
          python3 - <<'PY'
          from pathlib import Path
          import os
          p=Path('project.yml')
          text=p.read_text(encoding='utf-8')
          text=text.replace('CURRENT_PROJECT_VERSION: 1', 'CURRENT_PROJECT_VERSION: '+os.environ['CM_BUILD_NUMBER'], 1)
          p.write_text(text,encoding='utf-8')
          PY
          xcodegen generate
          python3 apply-xcode-capabilities.py PharmacistSprint.xcodeproj/project.pbxproj
'''
new = '''      - name: Set unique release build number and generate native project
        script: |
          set -euo pipefail
          cd "$CM_BUILD_DIR/pharmacist-manabi-sprint/ios"
          # Codemagic's per-workflow CM_BUILD_NUMBER can collide with a build
          # already present in App Store Connect after workflow history resets.
          # Use the current UTC minute as a monotonically advancing numeric build
          # identifier. App Store review submission remains disabled.
          RELEASE_BUILD_NUMBER="$(date -u +%Y%m%d%H%M)"
          export RELEASE_BUILD_NUMBER
          python3 - <<'PY'
          from pathlib import Path
          import os, re
          p=Path('project.yml')
          text=p.read_text(encoding='utf-8')
          updated,count=re.subn(r'(?m)^(\\s*CURRENT_PROJECT_VERSION:\\s*)\\d+\\s*$', r'\\g<1>'+os.environ['RELEASE_BUILD_NUMBER'], text, count=1)
          if count != 1:
              raise SystemExit('CURRENT_PROJECT_VERSION was not updated exactly once')
          p.write_text(updated,encoding='utf-8')
          print('PASS: Pharmacist release build number='+os.environ['RELEASE_BUILD_NUMBER'])
          PY
          xcodegen generate
          python3 apply-xcode-capabilities.py PharmacistSprint.xcodeproj/project.pbxproj
          /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' PharmacistSprint/Info.plist 2>/dev/null || true
'''
if old not in block:
    raise SystemExit('Expected pharmacist build-number block not found; fail closed')
updated_block = block.replace(old, new, 1)
if updated_block.count('RELEASE_BUILD_NUMBER') < 3:
    raise SystemExit('Patch verification failed')
p.write_text(text[:start] + updated_block + text[end:], encoding='utf-8')
print('PASS: pharmacist release build number now uses UTC-minute unique identifier')
