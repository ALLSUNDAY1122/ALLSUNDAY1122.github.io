from pathlib import Path

p = Path('codemagic.yaml')
text = p.read_text(encoding='utf-8')
start = text.index('  health-manager-1-testflight:')
end = text.index('\n  health-manager-2-ios:', start)
block = text[start:end]

install_anchor = '''      - name: Install XcodeGen
        script: HOMEBREW_NO_AUTO_UPDATE=1 brew install xcodegen
'''
prepare_step = '''      - name: Prepare audited 264-question bundle and icon
        script: |
          bash "$CM_BUILD_DIR/ios/health-manager-1/prepare-ios.sh"
'''
if '      - name: Prepare audited 264-question bundle and icon\n' not in block:
    if install_anchor not in block:
        raise SystemExit('HM1 Install XcodeGen anchor not found')
    block = block.replace(install_anchor, install_anchor + prepare_step, 1)

old_generate = '''      - name: Generate Xcode project
        script: |
          cd "$CM_BUILD_DIR/ios/health-manager-1"
          xcodegen generate
'''
new_generate = '''      - name: Set CI build number and generate Xcode project
        script: |
          cd "$CM_BUILD_DIR/ios/health-manager-1"
          BUILD_NUM="${CM_BUILD_NUMBER:?CM_BUILD_NUMBER is required}"
          python3 - "$BUILD_NUM" <<'PY2'
          from pathlib import Path
          import re,sys
          q=Path('project.yml')
          s=q.read_text(encoding='utf-8')
          s,n=re.subn(r'CURRENT_PROJECT_VERSION:\\s*\\d+',f'CURRENT_PROJECT_VERSION: {sys.argv[1]}',s,count=1)
          if n != 1:
              raise SystemExit('CURRENT_PROJECT_VERSION replacement failed')
          q.write_text(s,encoding='utf-8')
          PY2
          xcodegen generate
'''
if '      - name: Set CI build number and generate Xcode project\n' not in block:
    if old_generate not in block:
        raise SystemExit('HM1 Generate Xcode project step not found')
    block = block.replace(old_generate, new_generate, 1)

signing_anchor = '''      - name: Apply App Store signing profiles
        script: |
          cd "$CM_BUILD_DIR/ios/health-manager-1"
          xcode-project use-profiles --custom-export-options='{"testFlightInternalTestingOnly": true}'
'''
verify_inputs = '''      - name: Verify HM1 release inputs
        script: |
          python3 - <<'PY2'
          from pathlib import Path
          import collections,json,re
          root=Path("$CM_BUILD_DIR/ios/health-manager-1")
          q=json.loads((root/'Resources/questions.json').read_text(encoding='utf-8'))
          html=(root/'Resources/index.html').read_text(encoding='utf-8')
          assert len(q)==264, len(q)
          assert len({x['id'] for x in q})==264
          assert collections.Counter(x['round'] for x in q)=={'2026-04':44,'2025-10':44,'2025-04':44,'practice-A':44,'practice-B':44,'practice-C':44}
          assert 'practice-C-Q44' in html and '合計264問' in html
          assert (root/'Resources/PrivacyInfo.xcprivacy').is_file()
          assert (root/'Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png').is_file()
          print('PASS: HM1 audited release inputs contain 264 questions / 6x44 sets')
          PY2
'''
# Use environment expansion in Python by passing the path instead of literal $CM_BUILD_DIR.
verify_inputs = verify_inputs.replace("python3 - <<'PY2'", "python3 - \"$CM_BUILD_DIR/ios/health-manager-1\" <<'PY2'")
verify_inputs = verify_inputs.replace('root=Path("$CM_BUILD_DIR/ios/health-manager-1")', 'import sys\n          root=Path(sys.argv[1])')
if '      - name: Verify HM1 release inputs\n' not in block:
    if signing_anchor not in block:
        raise SystemExit('HM1 signing anchor not found')
    block = block.replace(signing_anchor, verify_inputs + signing_anchor, 1)

artifact_anchor = '''    artifacts:
      - build/ios/ipa/*.ipa
'''
verify_packaged = '''      - name: Verify packaged HM1 IPA content
        script: |
          IPA_PATH="$(find build/ios/ipa -type f -name '*.ipa' -print -quit)"
          test -n "$IPA_PATH"
          VERIFY_DIR="$(mktemp -d)"
          unzip -q "$IPA_PATH" -d "$VERIFY_DIR"
          APP_DIR="$(find "$VERIFY_DIR/Payload" -maxdepth 1 -type d -name '*.app' -print -quit)"
          python3 - "$APP_DIR" <<'PY2'
          from pathlib import Path
          import collections,json,plistlib,re,sys
          app=Path(sys.argv[1])
          index=(app/'index.html').read_text(encoding='utf-8')
          m=re.search(r'const QUESTIONS=(\[.*?\]);\\nconst DOMAINS=',index,re.S)
          assert m, 'embedded QUESTIONS not found'
          q=json.loads(m.group(1))
          assert len(q)==264, len(q)
          assert len({x['id'] for x in q})==264
          assert collections.Counter(x['round'] for x in q)=={'2026-04':44,'2025-10':44,'2025-04':44,'practice-A':44,'practice-B':44,'practice-C':44}
          assert 'practice-C-Q44' in index and '合計264問' in index
          info=plistlib.loads((app/'Info.plist').read_bytes())
          assert info.get('CFBundleIdentifier')=='jp.allsunday1122.healthmanager1'
          assert str(info.get('CFBundleVersion','')).isdigit()
          assert (app/'Assets.car').is_file()
          assert (app/'embedded.mobileprovision').is_file()
          assert (app/'_CodeSignature').is_dir()
          print('PASS: signed HM1 IPA contains audited 264-question bundle')
          PY2
'''
if '      - name: Verify packaged HM1 IPA content\n' not in block:
    if artifact_anchor not in block:
        raise SystemExit('HM1 artifacts anchor not found')
    block = block.replace(artifact_anchor, verify_packaged + artifact_anchor, 1)

required = [
    'Prepare audited 264-question bundle and icon',
    'Set CI build number and generate Xcode project',
    'Verify HM1 release inputs',
    'Verify packaged HM1 IPA content',
    'submit_to_testflight: true',
    'submit_to_app_store: false',
]
for item in required:
    if item not in block:
        raise SystemExit(f'missing HM1 release requirement: {item}')

p.write_text(text[:start] + block + text[end:], encoding='utf-8')
print('PASS: patched root Codemagic HM1 final release workflow')
