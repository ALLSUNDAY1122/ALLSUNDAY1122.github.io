#!/usr/bin/env python3
from __future__ import annotations

import re
from pathlib import Path

P = Path("codemagic.yaml")
BLOCK = r'''
  kangoshi-ios:
    name: 看護師国家試験 - iOS App Store Submission
    max_build_duration: 60
    instance_type: mac_mini_m2
    environment:
      groups:
        - app2_010_touhan_signing
      vars:
        BUNDLE_ID: jp.allsunday1122.kangoshi
        APP_STORE_CONNECT_APP_ID: "6801792293"
        CODEMAGIC_PROFILE_REF: kangoshi_appstore_20260822
        IAP_PRODUCT_ID: jp.allsunday1122.kangoshi.monthly
        IAP_LIFETIME_PRODUCT_ID: jp.allsunday1122.kangoshi.lifetime
        APPICON_SHA256: 6afe16483852c98e0e030874ce7829f0e1a42fe017bb2f854eee1d9410f8ee80
        XCODE_PROJECT: kangoshi-sprint/ios/KangoshiSprint.xcodeproj
        XCODE_SCHEME: KangoshiSprint
      xcode: latest
    scripts:
      - name: Install native build tools
        script: |
          HOMEBREW_NO_AUTO_UPDATE=1 brew install xcodegen
          python3 -m pip install --disable-pip-version-check 'cairosvg==2.8.2'
      - name: Audit Kangoshi release inputs
        script: |
          set -euo pipefail
          cd "$CM_BUILD_DIR"
          test -n "${CERTIFICATE_PRIVATE_KEY:-}"
          test -n "${APP_STORE_CONNECT_PRIVATE_KEY:-}"
          test -n "${APP_STORE_CONNECT_KEY_IDENTIFIER:-}"
          test -n "${APP_STORE_CONNECT_ISSUER_ID:-}"
          test "$BUNDLE_ID" = "jp.allsunday1122.kangoshi"
          test "$IAP_PRODUCT_ID" = "jp.allsunday1122.kangoshi.monthly"
          test "$IAP_LIFETIME_PRODUCT_ID" = "jp.allsunday1122.kangoshi.lifetime"
          node kangoshi-sprint/audit-official-difficulty.mjs
          python3 kangoshi-sprint/ios/tools/normalize_swift_numeric_literals.py
          python3 kangoshi-sprint/ios/tools/prepare_native_content.py
          test -f kangoshi-sprint/ios/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
          echo "$APPICON_SHA256  kangoshi-sprint/ios/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png" | shasum -a 256 -c -
          python3 -c "import json;d=json.load(open('kangoshi-sprint/ios/GeneratedResources/native-content-audit.json',encoding='utf-8'));assert d['pass'] and d['questions']==720 and d['byExam']=={'115':240,'114':240,'113':240};print('PASS: canonical 720-question payload')"
      - name: Set CI build number and generate native project
        script: |
          set -euo pipefail
          cd "$CM_BUILD_DIR/kangoshi-sprint/ios"
          BUILD_NUM="${CM_BUILD_NUMBER:?CM_BUILD_NUMBER is required}"
          python3 - "$BUILD_NUM" <<'PYBUILD'
          from pathlib import Path
          import re,sys
          p=Path('project.yml')
          text=p.read_text(encoding='utf-8')
          text,n=re.subn(r'CURRENT_PROJECT_VERSION:\s*\d+', 'CURRENT_PROJECT_VERSION: '+sys.argv[1], text, count=1)
          if n!=1: raise RuntimeError('CURRENT_PROJECT_VERSION replacement failed')
          p.write_text(text,encoding='utf-8')
          PYBUILD
          xcodegen generate
      - name: Initialize signing keychain
        script: |
          set -euo pipefail
          keychain initialize
      - name: Fetch managed App Store signing files
        script: |
          set -euo pipefail
          app-store-connect fetch-signing-files "$BUNDLE_ID" --type IOS_APP_STORE
      - name: Add signing certificate to keychain
        script: |
          set -euo pipefail
          keychain add-certificates
      - name: Apply App Store signing profile
        script: |
          set -euo pipefail
          cd "$CM_BUILD_DIR/kangoshi-sprint/ios"
          xcode-project use-profiles
      - name: Build signed IPA
        script: |
          set -euo pipefail
          xcode-project build-ipa --project "$CM_BUILD_DIR/$XCODE_PROJECT" --scheme "$XCODE_SCHEME"
      - name: Upload signed IPA to App Store Connect
        script: |
          set -euo pipefail
          IPA_PATH="$(find "$CM_BUILD_DIR/build/ios/ipa" -maxdepth 1 -type f -name '*.ipa' -print -quit)"
          test -n "$IPA_PATH"
          app-store-connect publish --path "$IPA_PATH" --altool-retries 3 --altool-retry-wait 2
    artifacts:
      - build/ios/ipa/*.ipa
      - /tmp/xcodebuild_logs/*.log
'''


def main() -> int:
    text = P.read_text(encoding="utf-8")
    match = re.search(r"(?ms)^  kangoshi-ios:\n.*?(?=^  \S[^\n]*:\n|\Z)", text)
    if not match:
        raise SystemExit("kangoshi-ios block not found")
    out = text[:match.start()] + BLOCK.lstrip("\n") + text[match.end():]
    P.write_text(out, encoding="utf-8")
    check = P.read_text(encoding="utf-8")
    required = [
        "name: 看護師国家試験 - iOS App Store Submission",
        "- app2_010_touhan_signing",
        "CODEMAGIC_PROFILE_REF: kangoshi_appstore_20260822",
        "jp.allsunday1122.kangoshi.monthly",
        "jp.allsunday1122.kangoshi.lifetime",
        'app-store-connect fetch-signing-files "$BUNDLE_ID" --type IOS_APP_STORE',
        "keychain add-certificates",
        "xcode-project use-profiles",
        "app-store-connect publish",
    ]
    for token in required:
        if token not in check:
            raise SystemExit(f"missing submission workflow token: {token}")
    print("PASS: explicit Kangoshi App Store submission workflow installed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
