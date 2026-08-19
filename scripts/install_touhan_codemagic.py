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
          text=text.replace('CURRENT_PROJECT_VERSION: 1', 'CURRENT_PROJECT_VERSION: '+os.environ['CM_BUILD_NUMBER'], 1)
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
      - name: Fetch or create App Store signing files
        script: |
          set -euo pipefail
          app-store-connect fetch-signing-files "$BUNDLE_ID" \
            --type IOS_APP_STORE \
            --create
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

    tail_start = start + 1
    match = re.search(r"(?m)^  [A-Za-z0-9_-]+:\s*$", text[tail_start + len(f'  {WORKFLOW_ID}:\n'):])
    if match:
        end = tail_start + len(f"  {WORKFLOW_ID}:\n") + match.start()
        suffix = text[end:]
    else:
        suffix = ""
    replacement = BLOCK.lstrip("\n").rstrip() + "\n"
    current = text[tail_start:end] if match else text[tail_start:]
    if current == replacement:
        return text, False
    return text[:tail_start] + replacement + suffix, True


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
    required = [
        "  touhan-ios:\n",
        "BUNDLE_ID: com.allsunday1122.tourokuhanbaisha",
        'APP_STORE_CONNECT_APP_ID: "6802119268"',
        "CODEMAGIC_PROFILE_REF: tourokuhanbaisha_appstore",
        "APPICON_SHA256: c0cefbae22cdcd7b614d213ddca7942c7d693f02ead758b11b66d447a66bff03",
        'app-store-connect fetch-signing-files "$BUNDLE_ID"',
        "--type IOS_APP_STORE",
        "--create",
        "keychain add-certificates",
        "submit_to_testflight: true",
        "submit_to_app_store: false",
    ]
    for token in required:
        if token not in final:
            raise SystemExit(f"missing required Touhan token: {token}")

    RESULT_DIR.mkdir(parents=True, exist_ok=True)
    result = {
        "request_id": request_id,
        "ok": True,
        "action": "install_touhan_workflow",
        "workflow_id": WORKFLOW_ID,
        "changed": changed,
        "signing_mode": "runtime_fetch_or_create",
        "bundle_id": "com.allsunday1122.tourokuhanbaisha",
        "app_store_connect_app_id": "6802119268",
        "codemagic_profile_ref": "tourokuhanbaisha_appstore",
        "submit_to_testflight": True,
        "submit_to_app_store": False,
    }
    (RESULT_DIR / f"{request_id}.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
