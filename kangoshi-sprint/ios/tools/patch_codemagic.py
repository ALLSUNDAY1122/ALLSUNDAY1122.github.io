#!/usr/bin/env python3
from pathlib import Path

p=Path('codemagic.yaml')
s=p.read_text(encoding='utf-8')
if '\n  kangoshi-ios:\n' in s:
    print('PASS: kangoshi-ios already present')
    raise SystemExit(0)

block='''

  kangoshi-ios:
    name: 看護師国家試験 - iOS Internal TestFlight
    max_build_duration: 60
    instance_type: mac_mini_m2
    integrations:
      app_store_connect: codemagic
    environment:
      ios_signing:
        distribution_type: app_store
        bundle_identifier: jp.allsunday1122.kangoshi
      vars:
        BUNDLE_ID: jp.allsunday1122.kangoshi
        CODEMAGIC_PROFILE_REF: kangoshi_appstore
        IAP_PRODUCT_ID: jp.allsunday1122.kangoshi.monthly
        XCODE_PROJECT: kangoshi-sprint/ios/KangoshiSprint.xcodeproj
        XCODE_SCHEME: KangoshiSprint
      xcode: latest
    scripts:
      - name: Install native build tools
        script: |
          HOMEBREW_NO_AUTO_UPDATE=1 brew install xcodegen cairo pango
          python3 -m pip install 'CairoSVG>=2.7,<3'
      - name: Audit and prepare canonical nursing release inputs
        script: |
          cd "$CM_BUILD_DIR"
          python3 kangoshi-sprint/ios/tools/normalize_swift_numeric_literals.py
          python3 kangoshi-sprint/ios/tools/prepare_native_content.py
          python3 -m py_compile kangoshi-sprint/ios/apply-xcode-capabilities.py
          test "$BUNDLE_ID" = "jp.allsunday1122.kangoshi"
          test "$CODEMAGIC_PROFILE_REF" = "kangoshi_appstore"
          test "$IAP_PRODUCT_ID" = "jp.allsunday1122.kangoshi.monthly"
          test -f kangoshi-sprint/ios/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
          echo '6afe16483852c98e0e030874ce7829f0e1a42fe017bb2f854eee1d9410f8ee80  kangoshi-sprint/ios/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png' | shasum -a 256 -c -
          python3 -c "import json;d=json.load(open('kangoshi-sprint/ios/GeneratedResources/native-content-audit.json',encoding='utf-8'));assert d['pass'] and d['questions']==720 and d['byExam']=={'115':240,'114':240,'113':240} and d['mediaQuestions']==38 and d['copiedMediaAssets']==38;print('PASS: canonical native payload')"
      - name: Set CI build number and generate project
        script: |
          cd "$CM_BUILD_DIR/kangoshi-sprint/ios"
          python3 -c "from pathlib import Path;import os;p=Path('project.yml');s=p.read_text(encoding='utf-8');p.write_text(s.replace('CURRENT_PROJECT_VERSION: 1','CURRENT_PROJECT_VERSION: '+os.environ['CM_BUILD_NUMBER'],1),encoding='utf-8')"
          xcodegen generate
          python3 apply-xcode-capabilities.py KangoshiSprint.xcodeproj/project.pbxproj
          grep -q 'com.apple.InAppPurchase' KangoshiSprint.xcodeproj/project.pbxproj
      - name: Apply App Store signing profiles for internal TestFlight only
        script: |
          cd "$CM_BUILD_DIR/kangoshi-sprint/ios"
          xcode-project use-profiles --custom-export-options='{"testFlightInternalTestingOnly": true}'
      - name: Build signed IPA
        script: |
          xcode-project build-ipa --project "$CM_BUILD_DIR/$XCODE_PROJECT" --scheme "$XCODE_SCHEME"
    artifacts:
      - build/ios/ipa/*.ipa
      - /tmp/xcodebuild_logs/*.log
      - $HOME/Library/Developer/Xcode/DerivedData/**/Build/**/*.app
      - $HOME/Library/Developer/Xcode/DerivedData/**/Build/**/*.dSYM
    publishing:
      app_store_connect:
        auth: integration
        submit_to_testflight: false
        submit_to_app_store: false
'''
p.write_text(s.rstrip()+block+'\n',encoding='utf-8')
print('PASS: appended kangoshi-ios')
