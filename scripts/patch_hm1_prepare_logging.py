from pathlib import Path

p=Path('codemagic.yaml')
text=p.read_text(encoding='utf-8')
start=text.index('  health-manager-1-testflight:')
end=text.index('\n  health-manager-2-ios:',start)
block=text[start:end]
old='''      - name: Prepare audited 264-question bundle and icon
        script: |
          bash "$CM_BUILD_DIR/ios/health-manager-1/prepare-ios.sh"
'''
new='''      - name: Prepare audited 264-question bundle and icon
        script: |
          set -o pipefail
          bash -x "$CM_BUILD_DIR/ios/health-manager-1/prepare-ios.sh" 2>&1 | tee /tmp/hm1-prepare.log
'''
if old in block:
    block=block.replace(old,new,1)
elif new not in block:
    raise SystemExit('HM1 prepare step not found')

artifact_marker='''    artifacts:
      - build/ios/ipa/*.ipa
      - /tmp/xcodebuild_logs/*.log
'''
artifact_new='''    artifacts:
      - build/ios/ipa/*.ipa
      - /tmp/xcodebuild_logs/*.log
      - /tmp/hm1-prepare.log
'''
if '/tmp/hm1-prepare.log' not in block:
    if artifact_marker not in block:
        raise SystemExit('HM1 artifact marker not found')
    block=block.replace(artifact_marker,artifact_new,1)

p.write_text(text[:start]+block+text[end:],encoding='utf-8')
print('PASS: HM1 Codemagic prepare logging enabled')
