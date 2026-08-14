#!/usr/bin/env python3
from pathlib import Path

path = Path("codemagic.yaml")
text = path.read_text(encoding="utf-8")
marker = "\n  hokenshi_appstore:\n"
if marker in text:
    print("PASS: hokenshi_appstore already exists")
    raise SystemExit(0)

payload = r'''

  hokenshi_appstore:
    name: 保健師国家試験 - SwiftUI Native Internal TestFlight
    max_build_duration: 80
    instance_type: mac_mini_m2
    integrations:
      app_store_connect: codemagic
    environment:
      ios_signing:
        distribution_type: app_store
        bundle_identifier: jp.allsunday1122.hokenshi
      vars:
        BUNDLE_ID: jp.allsunday1122.hokenshi
        CODEMAGIC_PROFILE_REF: hokenshi_appstore
        IAP_PRODUCT_ID: jp.allsunday1122.hokenshi.premium
        XCODE_PROJECT: hokenshi-sprint/ios/HokenshiSprint.xcodeproj
        XCODE_SCHEME: HokenshiSprint
      xcode: latest
    scripts:
      - name: Audit canonical release inputs
        script: |
          set -euo pipefail
          cd "$CM_BUILD_DIR"
          python3 hokenshi-sprint/scripts/build_question_plan.py
          python3 hokenshi-sprint/scripts/validate_question_plan.py
          python3 hokenshi-sprint/scripts/build_canonical_questions.py
          python3 hokenshi-sprint/scripts/validate_canonical_questions.py
          python3 hokenshi-sprint/scripts/validate_current_guidance_canonical.py
          python3 hokenshi-sprint/scripts/promote_release_resource.py
          python3 hokenshi-sprint/scripts/validate_native_product_shell.py
          test "$BUNDLE_ID" = "jp.allsunday1122.hokenshi"
          test "$CODEMAGIC_PROFILE_REF" = "hokenshi_appstore"
          test "$IAP_PRODUCT_ID" = "jp.allsunday1122.hokenshi.premium"
      - name: Install XcodeGen
        script: HOMEBREW_NO_AUTO_UPDATE=1 brew install xcodegen
      - name: Verify canonical AppIcon
        script: |
          set -euo pipefail
          ICON="$CM_BUILD_DIR/hokenshi-sprint/ios/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
          test -f "$ICON"
          test "$(shasum -a 256 "$ICON" | awk '{print $1}')" = "34c1ec303ef5420947bf13ab4b05d2045a70b79417ac40ebd667e05c8f2f2c64"
      - name: Set build number and generate Xcode project
        script: |
          set -euo pipefail
          cd "$CM_BUILD_DIR/hokenshi-sprint/ios"
          python3 - <<'PY'
          from pathlib import Path
          import os
          p=Path('project.yml')
          text=p.read_text(encoding='utf-8')
          text=text.replace('CURRENT_PROJECT_VERSION: 1', 'CURRENT_PROJECT_VERSION: '+os.environ['CM_BUILD_NUMBER'], 1)
          p.write_text(text, encoding='utf-8')
          PY
          xcodegen generate
          python3 apply-xcode-capabilities.py HokenshiSprint.xcodeproj/project.pbxproj
          grep -q 'com.apple.InAppPurchase' HokenshiSprint.xcodeproj/project.pbxproj
          ! grep -q 'SystemCapabilities = "' HokenshiSprint.xcodeproj/project.pbxproj
      - name: Apply App Store signing for Internal TestFlight only
        script: |
          set -euo pipefail
          cd "$CM_BUILD_DIR/hokenshi-sprint/ios"
          xcode-project use-profiles --custom-export-options='{"testFlightInternalTestingOnly": true}'
      - name: Build signed IPA
        script: |
          set -euo pipefail
          xcode-project build-ipa \
            --project "$CM_BUILD_DIR/$XCODE_PROJECT" \
            --scheme "$XCODE_SCHEME"
    artifacts:
      - build/ios/ipa/*.ipa
      - /tmp/xcodebuild_logs/*.log
      - $HOME/Library/Developer/Xcode/DerivedData/**/Build/**/*.app
      - $HOME/Library/Developer/Xcode/DerivedData/**/Build/**/*.dSYM
    publishing:
      app_store_connect:
        auth: integration
        submit_to_testflight: true
        submit_to_app_store: false
'''

path.write_text(text.rstrip() + payload + "\n", encoding="utf-8")
print("PASS: appended hokenshi_appstore to codemagic.yaml")
