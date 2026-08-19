#!/usr/bin/env python3
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CODEMAGIC = ROOT / "codemagic.yaml"
TRIGGER = ROOT / "automation/app2-010-codemagic-install-trigger.json"
RESULT_DIR = ROOT / "automation/codemagic-results"
WORKFLOW_ID = "touhan-ios"

BLOCK = r'''

  touhan-ios:
    name: 登録販売者 - iOS Internal TestFlight
    max_build_duration: 60
    instance_type: mac_mini_m2
    integrations:
      app_store_connect: "Codemagic Shiwake Swipe"
    environment:
      groups:
        - app2_010_touhan_signing
      vars:
        BUNDLE_ID: com.allsunday1122.tourokuhanbaisha
        APP_STORE_CONNECT_APP_ID: "6802119268"
        CODEMAGIC_PROFILE_REF: tourokuhanbaisha_appstore
        APPICON_SHA256: c0cefbae22cdcd7b614d213ddca7942c7d693f02ead758b11b66d447a66bff03
        XCODE_PROJECT: touroku-hanbaisha-ios/native-ios/TouhanSprint.xcodeproj
        XCODE_SCHEME: TouhanSprint
      xcode: latest
    scripts:
      - name: Install native build tools
        script: |
          HOMEBREW_NO_AUTO_UPDATE=1 brew install xcodegen
          python3 -m pip install --disable-pip-version-check 'cairosvg==2.8.2'
      - name: Audit registration seller release inputs
        script: |
          set -euo pipefail
          cd "$CM_BUILD_DIR"
          node touroku-hanbaisha-sprint/validate-history-calendar.mjs
          bash -n touroku-hanbaisha-ios/native-ios/prepare-ios.sh
          test "$BUNDLE_ID" = "com.allsunday1122.tourokuhanbaisha"
          test "$APP_STORE_CONNECT_APP_ID" = "6802119268"
          test "$CODEMAGIC_PROFILE_REF" = "tourokuhanbaisha_appstore"
          test -n "${CERTIFICATE_PRIVATE_KEY:-}"
          bash touroku-hanbaisha-ios/native-ios/prepare-ios.sh
          python3 touroku-hanbaisha-ios/scripts/validate_release.py
      - name: Set CI build number and generate native project
        script: |
          set -euo pipefail
          cd "$CM_BUILD_DIR/touroku-hanbaisha-ios/native-ios"
          python3 - <<'PYBUILD'
          from pathlib import Path
          import os
          p=Path('project.yml')
          text=p.read_text(encoding='utf-8')
          build_number = os.environ.get('CM_BUILD_NUMBER') or os.environ.get('BUILD_NUMBER')
          if not build_number:
              raise RuntimeError('Codemagic build number is unavailable')
          text=text.replace('CURRENT_PROJECT_VERSION: 1', 'CURRENT_PROJECT_VERSION: '+build_number, 1)
          p.write_text(text, encoding='utf-8')
          PYBUILD
          xcodegen generate
      - name: Verify native inputs before signing
        script: |
          set -euo pipefail
          test -f "$CM_BUILD_DIR/touroku-hanbaisha-ios/native-ios/PrivacyInfo.xcprivacy"
          test -f "$CM_BUILD_DIR/touroku-hanbaisha-ios/native-ios/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
          echo "$APPICON_SHA256  $CM_BUILD_DIR/touroku-hanbaisha-ios/native-ios/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png" | shasum -a 256 -c -
          grep -q 'com.allsunday1122.tourokuhanbaisha' "$CM_BUILD_DIR/$XCODE_PROJECT/project.pbxproj"
          grep -q 'MN3D2ZM44N' "$CM_BUILD_DIR/$XCODE_PROJECT/project.pbxproj"
      - name: Initialize signing keychain
        script: |
          set -euo pipefail
          keychain initialize
      - name: Fetch managed App Store signing files
        script: |
          set -euo pipefail
          test -n "${CERTIFICATE_PRIVATE_KEY:-}"
          app-store-connect fetch-signing-files "$BUNDLE_ID" \
            --type IOS_APP_STORE
      - name: Add signing certificate to keychain
        script: |
          set -euo pipefail
          keychain add-certificates
      - name: Apply App Store signing profiles for internal TestFlight only
        script: |
          set -euo pipefail
          cd "$CM_BUILD_DIR/touroku-hanbaisha-ios/native-ios"
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


def replace_workflow(text: str) -> tuple[str, bool]:
    marker = f"\n  {WORKFLOW_ID}:\n"
    start = text.find(marker)
    if start < 0:
        return text.rstrip() + BLOCK + "\n", True

    body_start = start + 1
    search_from = body_start + len(f"  {WORKFLOW_ID}:\n")
    match = re.search(r"(?m)^  [A-Za-z0-9_-]+:\s*$", text[search_from:])
    end = search_from + match.start() if match else len(text)
    replacement = BLOCK.lstrip("\n").rstrip() + "\n"
    current = text[body_start:end]
    if current == replacement:
        return text, False
    return text[:body_start] + replacement + text[end:], True


def main() -> int:
    trigger = json.loads(TRIGGER.read_text(encoding="utf-8"))
    request_id = str(trigger["request_id"])
    if not request_id.startswith("app2-010-"):
        raise SystemExit("unexpected request_id")

    text = CODEMAGIC.read_text(encoding="utf-8")
    if not text.startswith("workflows:\n") and "\nworkflows:\n" not in text:
        raise SystemExit("codemagic.yaml has no workflows root")

    updated, changed = replace_workflow(text)
    if changed:
        CODEMAGIC.write_text(updated, encoding="utf-8")

    final = CODEMAGIC.read_text(encoding="utf-8")
    workflow = final[final.index("  touhan-ios:\n"):]
    next_workflow = re.search(r"(?m)^  [A-Za-z0-9_-]+:\s*$", workflow[len("  touhan-ios:\n"):])
    if next_workflow:
        workflow = workflow[:len("  touhan-ios:\n") + next_workflow.start()]

    required = [
        "  touhan-ios:\n",
        "- app2_010_touhan_signing",
        "BUNDLE_ID: com.allsunday1122.tourokuhanbaisha",
        'APP_STORE_CONNECT_APP_ID: "6802119268"',
        "CODEMAGIC_PROFILE_REF: tourokuhanbaisha_appstore",
        "APPICON_SHA256: c0cefbae22cdcd7b614d213ddca7942c7d693f02ead758b11b66d447a66bff03",
        "os.environ.get('CM_BUILD_NUMBER') or os.environ.get('BUILD_NUMBER')",
        'test -n "${CERTIFICATE_PRIVATE_KEY:-}"',
        "keychain initialize",
        'app-store-connect fetch-signing-files "$BUNDLE_ID"',
        "--type IOS_APP_STORE",
        "keychain add-certificates",
        "xcode-project use-profiles",
        "submit_to_testflight: true",
        "submit_to_app_store: false",
    ]
    forbidden = ["--create", "ios_signing:"]
    for token in required:
        if token not in workflow:
            raise SystemExit(f"missing required Touhan token: {token}")
    for token in forbidden:
        if token in workflow:
            raise SystemExit(f"obsolete Touhan signing token remains: {token}")

    RESULT_DIR.mkdir(parents=True, exist_ok=True)
    result = {
        "request_id": request_id,
        "ok": True,
        "action": "install_touhan_workflow",
        "workflow_id": WORKFLOW_ID,
        "changed": changed,
        "build_number_mode": "CM_BUILD_NUMBER_or_BUILD_NUMBER",
        "signing_mode": "managed_certificate_private_key_plus_asc_profile_fetch",
        "codemagic_group_name": "app2_010_touhan_signing",
        "bundle_id": "com.allsunday1122.tourokuhanbaisha",
        "app_store_connect_app_id": "6802119268",
        "codemagic_profile_ref": "tourokuhanbaisha_appstore",
        "apple_profile_id": "7B328C2DU4",
        "apple_certificate_id": "K2A3VCP583",
        "create_signing_files": False,
        "submit_to_testflight": True,
        "submit_to_app_store": False,
    }
    (RESULT_DIR / f"{request_id}.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
