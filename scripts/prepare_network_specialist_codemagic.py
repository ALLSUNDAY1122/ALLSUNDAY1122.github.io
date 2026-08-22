#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
path = ROOT / 'codemagic.yaml'
text = path.read_text(encoding='utf-8')
marker = '\n  network-specialist-native-ios:\n'
if marker in text:
    print('network-specialist-native-ios already present')
    raise SystemExit(0)

block = r'''

  network-specialist-native-ios:
    name: ネットワークスペシャリスト - Native Internal TestFlight
    max_build_duration: 80
    instance_type: mac_mini_m2
    integrations:
      app_store_connect: "Codemagic Shiwake Swipe"
    environment:
      vars:
        BUNDLE_ID: jp.allsunday1122.networkspecialist
        APP_STORE_CONNECT_APP_ID: "6799754573"
        CODEMAGIC_PROFILE_REF: networkspecialist_appstore
        IAP_PRODUCT_ID: jp.allsunday1122.networkspecialist.premium
        APPICON_SHA256: 5b53032021cea4a3e71e737c1a48e1aa8d6495b3647cb770b0e5d917bb0d8729
        XCODE_PROJECT: network-specialist-sprint/ios/NetworkSpecialist.xcodeproj
        XCODE_SCHEME: NetworkSpecialist
      xcode: latest
    scripts:
      - name: Install native build tools
        script: HOMEBREW_NO_AUTO_UPDATE=1 brew install xcodegen
      - name: Materialize and verify canonical AppIcon
        script: |
          set -euo pipefail
          cd "$CM_BUILD_DIR"
          SRC='network-specialist-sprint/07_ネットワークスペシャリスト試験.png'
          DEST='network-specialist-sprint/ios/NetworkSpecialist/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png'
          test -f "$SRC"
          test "$(stat -f%z "$SRC")" = '678310'
          test "$(shasum -a 256 "$SRC" | awk '{print $1}')" = "$APPICON_SHA256"
          mkdir -p "$(dirname "$DEST")"
          cp "$SRC" "$DEST"
          python3 network-specialist-sprint/scripts/build_native_questions.py
          python3 network-specialist-sprint/scripts/materialize_appicon.py
          python3 network-specialist-sprint/scripts/validate_release.py
          python3 network-specialist-sprint/scripts/validate_native_release.py --require-icon --require-iap
          test "$BUNDLE_ID" = 'jp.allsunday1122.networkspecialist'
          test "$APP_STORE_CONNECT_APP_ID" = '6799754573'
          test "$CODEMAGIC_PROFILE_REF" = 'networkspecialist_appstore'
          test "$IAP_PRODUCT_ID" = 'jp.allsunday1122.networkspecialist.premium'
      - name: Generate Xcode project and set build number
        script: |
          set -euo pipefail
          cd "$CM_BUILD_DIR/network-specialist-sprint/ios"
          python3 - <<'PY'
          from pathlib import Path
          import os
          p=Path('project.yml')
          s=p.read_text(encoding='utf-8')
          s=s.replace('CURRENT_PROJECT_VERSION: "1"', 'CURRENT_PROJECT_VERSION: "'+os.environ['CM_BUILD_NUMBER']+'"', 1)
          p.write_text(s, encoding='utf-8')
          PY
          xcodegen generate
      - name: Run native unit and UI regression
        script: |
          set -euo pipefail
          cd "$CM_BUILD_DIR/network-specialist-sprint"
          bash scripts/run_native_ui_tests.sh
      - name: Unsigned Release build gate
        script: |
          set -euo pipefail
          cd "$CM_BUILD_DIR/network-specialist-sprint"
          xcodebuild build -project ios/NetworkSpecialist.xcodeproj -scheme NetworkSpecialist -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
      - name: Initialize signing keychain
        script: keychain initialize
      - name: Fetch or create App Store signing files
        script: app-store-connect fetch-signing-files "$BUNDLE_ID" --type IOS_APP_STORE --create
      - name: Add signing certificate to keychain
        script: keychain add-certificates
      - name: Apply App Store signing profiles for Internal TestFlight only
        script: |
          cd "$CM_BUILD_DIR/network-specialist-sprint/ios"
          xcode-project use-profiles --custom-export-options='{"testFlightInternalTestingOnly": true}'
      - name: Build signed IPA
        script: |
          xcode-project build-ipa --project "$CM_BUILD_DIR/$XCODE_PROJECT" --scheme "$XCODE_SCHEME"
    artifacts:
      - build/ios/ipa/*.ipa
      - /tmp/xcodebuild_logs/*.log
    publishing:
      app_store_connect:
        auth: integration
        submit_to_testflight: true
        submit_to_app_store: false
'''
path.write_text(text.rstrip() + block + '\n', encoding='utf-8')
print('added network-specialist-native-ios')
