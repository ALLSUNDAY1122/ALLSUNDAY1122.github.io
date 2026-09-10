#!/usr/bin/env python3
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROOT_CODEMAGIC = ROOT / "codemagic.yaml"
NESTED_CODEMAGIC = ROOT / "network-specialist-sprint/codemagic.yaml"

BUNDLE_ID = "jp.allsunday1122.networkspecialist"
APP_STORE_CONNECT_APP_ID = "6799754573"
IAP_PRODUCT_ID = "jp.allsunday1122.networkspecialist.premium"
APPICON_SHA256 = "5b53032021cea4a3e71e737c1a48e1aa8d6495b3647cb770b0e5d917bb0d8729"

ROOT_BLOCK = r'''  network-specialist-native-ios:
    name: ネットワークスペシャリスト - Native Internal TestFlight
    max_build_duration: 80
    instance_type: mac_mini_m2
    integrations:
      app_store_connect: "Codemagic Shiwake Swipe"
    environment:
      ios_signing:
        distribution_type: app_store
        bundle_identifier: jp.allsunday1122.networkspecialist
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
          cd "$CM_BUILD_DIR/network-specialist-sprint"
          python3 scripts/build_native_questions.py
          python3 scripts/materialize_appicon.py
          python3 scripts/validate_release.py
          python3 scripts/validate_native_release.py --require-icon --require-iap
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
      - name: Apply App Store signing profiles for Internal TestFlight only
        script: |
          set -euo pipefail
          cd "$CM_BUILD_DIR/network-specialist-sprint/ios"
          xcode-project use-profiles --custom-export-options='{"testFlightInternalTestingOnly": true}'
      - name: Build signed IPA
        script: |
          set -euo pipefail
          xcode-project build-ipa --project "$CM_BUILD_DIR/$XCODE_PROJECT" --scheme "$XCODE_SCHEME"
    artifacts:
      - build/ios/ipa/*.ipa
      - /tmp/xcodebuild_logs/*.log
    publishing:
      app_store_connect:
        auth: integration
        submit_to_testflight: false
        submit_to_app_store: false
'''

NESTED = r'''workflows:
  network-specialist-native-ios:
    name: Network Specialist Native iOS
    max_build_duration: 60
    instance_type: mac_mini_m2
    integrations:
      app_store_connect: networkspecialist_appstore
    environment:
      ios_signing:
        distribution_type: app_store
        bundle_identifier: jp.allsunday1122.networkspecialist
      xcode: latest
      vars:
        XCODE_PROJECT: "network-specialist-sprint/ios/NetworkSpecialist.xcodeproj"
        XCODE_SCHEME: "NetworkSpecialist"
        BUNDLE_ID: "jp.allsunday1122.networkspecialist"
        APP_STORE_CONNECT_APP_ID: "6799754573"
        IAP_PRODUCT_ID: "jp.allsunday1122.networkspecialist.premium"
        APPLE_TEAM_ID: "MN3D2ZM44N"
    scripts:
      - name: Build native question payload
        script: |
          cd network-specialist-sprint
          python3 scripts/build_native_questions.py
      - name: Materialize canonical AppIcon
        script: |
          cd network-specialist-sprint
          python3 scripts/materialize_appicon.py
      - name: Legacy content and rights validation
        script: |
          cd network-specialist-sprint
          python3 scripts/validate_release.py
      - name: Native Release Gate
        script: |
          cd network-specialist-sprint
          python3 scripts/validate_native_release.py --require-icon --require-iap
      - name: Install XcodeGen
        script: HOMEBREW_NO_AUTO_UPDATE=1 brew install xcodegen
      - name: Generate Xcode project
        script: |
          cd network-specialist-sprint/ios
          xcodegen generate
      - name: Simulator tests
        script: |
          cd network-specialist-sprint
          bash scripts/run_native_ui_tests.sh
      - name: Unsigned Release build gate
        script: |
          cd network-specialist-sprint
          xcodebuild build \
            -project ios/NetworkSpecialist.xcodeproj \
            -scheme NetworkSpecialist \
            -configuration Release \
            -destination 'generic/platform=iOS' \
            CODE_SIGNING_ALLOWED=NO \
            CODE_SIGNING_REQUIRED=NO
      - name: Apply App Store signing profiles for Internal TestFlight only
        script: |
          cd network-specialist-sprint/ios
          xcode-project use-profiles \
            --project "$XCODE_PROJECT" \
            --custom-export-options='{"testFlightInternalTestingOnly": true}'
      - name: Build signed IPA
        script: |
          xcode-project build-ipa \
            --project "$XCODE_PROJECT" \
            --scheme "$XCODE_SCHEME"
    artifacts:
      - build/ios/ipa/*.ipa
      - /tmp/xcodebuild_logs/*.log
    publishing:
      app_store_connect:
        auth: integration
        submit_to_testflight: false
        submit_to_app_store: false
'''


def patch_root() -> None:
    text = ROOT_CODEMAGIC.read_text(encoding="utf-8")
    pattern = re.compile(r"(?ms)^  network-specialist-native-ios:\n.*?(?=^  [A-Za-z0-9_-]+:\n|\Z)")
    if not pattern.search(text):
        raise SystemExit("network-specialist-native-ios root workflow not found")
    updated = pattern.sub(ROOT_BLOCK, text, count=1)
    ROOT_CODEMAGIC.write_text(updated, encoding="utf-8")


def require_scalar(text: str, key: str, expected: str, path: Path) -> None:
    pattern = rf"(?m)^\s*{re.escape(key)}:\s*[\"']?{re.escape(expected)}[\"']?\s*$"
    if not re.search(pattern, text):
        raise SystemExit(f"{path}: missing or mismatched {key}={expected}")


def validate(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    required = [
        "distribution_type: app_store",
        "xcode-project use-profiles",
        "submit_to_testflight: false",
        "submit_to_app_store: false",
    ]
    for token in required:
        if token not in text:
            raise SystemExit(f"{path}: missing required token {token}")

    require_scalar(text, "bundle_identifier", BUNDLE_ID, path)
    require_scalar(text, "BUNDLE_ID", BUNDLE_ID, path)
    require_scalar(text, "APP_STORE_CONNECT_APP_ID", APP_STORE_CONNECT_APP_ID, path)
    require_scalar(text, "IAP_PRODUCT_ID", IAP_PRODUCT_ID, path)

    forbidden = [
        'app-store-connect fetch-signing-files "$BUNDLE_ID"',
        "keychain initialize",
        "keychain add-certificates",
        "drive.google.com/uc?export=download",
    ]
    for token in forbidden:
        if token in text:
            raise SystemExit(f"{path}: obsolete release token remains: {token}")


def main() -> int:
    patch_root()
    NESTED_CODEMAGIC.write_text(NESTED, encoding="utf-8")
    validate(NESTED_CODEMAGIC)

    root = ROOT_CODEMAGIC.read_text(encoding="utf-8")
    match = re.search(r"(?ms)^  network-specialist-native-ios:\n.*?(?=^  [A-Za-z0-9_-]+:\n|\Z)", root)
    if not match:
        raise SystemExit("patched root workflow missing")
    tmp = ROOT / ".network-specialist-workflow.tmp"
    tmp.write_text(match.group(0), encoding="utf-8")
    try:
        validate(tmp)
    finally:
        tmp.unlink(missing_ok=True)

    print("PASS network specialist release workflow method-family patch")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
