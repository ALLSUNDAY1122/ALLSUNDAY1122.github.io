#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RIGAKU = ROOT / "rigaku-sprint"


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    if old not in text:
        raise SystemExit(f"required source not found in {path}: {old[:100]!r}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


app_model = RIGAKU / "ios/Sources/RigakuAppModel.swift"
replace_once(
    app_model,
    '''    var canAccessFullWeakReview: Bool {\n        RigakuAccessPolicy.canAccessFullWeakReview(isPremium: premiumAccess)\n    }\n\n    var accessibleQuestions: [LearningQuestion] {''',
    '''    var canAccessFullWeakReview: Bool {\n        RigakuAccessPolicy.canAccessFullWeakReview(isPremium: premiumAccess)\n    }\n\n    var resumeRequiresPremium: Bool {\n        guard !premiumAccess, let snapshot = state.resumeSession else { return false }\n        switch snapshot.kind {\n        case .mock, .weak:\n            return true\n        case .sprint, .subject:\n            let freeIDs = RigakuAccessPolicy.freeQuestionIDs(from: questions)\n            return snapshot.questionIDs.contains { !freeIDs.contains($0) }\n        }\n    }\n\n    var accessibleQuestions: [LearningQuestion] {''',
)

study = RIGAKU / "ios/Sources/RigakuStudyView.swift"
replace_once(
    study,
    '''    private var accessLocked: Bool {\n        switch kind {''',
    '''    private var accessLocked: Bool {\n        if resumeExisting && appModel.resumeRequiresPremium {\n            return true\n        }\n        switch kind {''',
)

root = RIGAKU / "ios/Sources/RigakuRootViewV2.swift"
replace_once(
    root,
    '''                    subtitle: appModel.isSessionAvailable(snapshot.kind) ? "前回の続きから" : "必要な監査済み問題が揃うまで再開できません",''',
    '''                    subtitle: appModel.resumeRequiresPremium ? "月額プランで続きから再開" : (appModel.isSessionAvailable(snapshot.kind) ? "前回の続きから" : "必要な監査済み問題が揃うまで再開できません"),''',
)
replace_once(
    root,
    '''            .disabled(!appModel.isSessionAvailable(snapshot.kind))''',
    '''            .disabled(!appModel.isSessionAvailable(snapshot.kind) && !appModel.resumeRequiresPremium)''',
)
replace_once(
    root,
    '''        .disabled(!appModel.isSessionAvailable(.weak))''',
    '''        .disabled(appModel.premiumAccess && appModel.weakCount == 0)''',
)

static_audit = RIGAKU / "ios/static_audit.py"
replace_once(
    static_audit,
    '''    "canAccessFullWeakReview",\n    "premiumLockedView",''',
    '''    "canAccessFullWeakReview",\n    "resumeRequiresPremium",\n    "premiumLockedView",''',
)

metadata = RIGAKU / "metadata/APP_STORE_METADATA_JA.md"
replace_once(metadata, "- SKU：未確定", "- SKU：`rigakuryouhoushi-ios-001`")

codemagic = ROOT / "codemagic.yaml"
text = codemagic.read_text(encoding="utf-8")
marker = "  rigaku-sprint-native-ios:"
if marker not in text:
    block = r'''

  rigaku-sprint-native-ios:
    name: 理学療法士 - Native Internal TestFlight
    max_build_duration: 80
    instance_type: mac_mini_m2
    integrations:
      app_store_connect: "Codemagic Shiwake Swipe"
    environment:
      ios_signing:
        provisioning_profiles:
          - rigakuryouhoushi_appstore
      vars:
        BUNDLE_ID: jp.allsunday1122.rigakuryouhoushi
        EXPECTED_CODEMAGIC_PROFILE: rigakuryouhoushi_appstore
        XCODE_PROJECT: rigaku-sprint/ios/RigakuSprint.xcodeproj
        XCODE_SCHEME: RigakuSprint
      xcode: latest
    scripts:
      - name: Release preflight before signed build
        script: |
          set -euo pipefail
          cd "$CM_BUILD_DIR"
          test "$BUNDLE_ID" = "jp.allsunday1122.rigakuryouhoushi"
          test "$EXPECTED_CODEMAGIC_PROFILE" = "rigakuryouhoushi_appstore"
          python3 rigaku-sprint/ios/static_audit.py
          python3 rigaku-sprint/ios/privacy_audit.py
          python3 rigaku-sprint/product-content/validate_exam_structure.py
          python3 rigaku-sprint/product-content/validate_official_answers.py
          python3 rigaku-sprint/product-content/validate_question_batches.py
          python3 rigaku-sprint/product-content/validate_evidence_quality.py
          python3 rigaku-sprint/release_preflight.py --phase internal-testflight
      - name: Install XcodeGen
        script: HOMEBREW_NO_AUTO_UPDATE=1 brew install xcodegen
      - name: Set CI build number and generate Xcode project
        script: |
          set -euo pipefail
          cd "$CM_BUILD_DIR/rigaku-sprint/ios"
          python3 - <<'PY'
          from pathlib import Path
          import os
          p = Path('project.yml')
          text = p.read_text(encoding='utf-8')
          build_number = os.environ.get('CM_BUILD_NUMBER') or os.environ.get('BUILD_NUMBER')
          if not build_number:
              raise RuntimeError('Codemagic build number is unavailable')
          text = text.replace('CURRENT_PROJECT_VERSION: 1', 'CURRENT_PROJECT_VERSION: ' + build_number, 1)
          p.write_text(text, encoding='utf-8')
          PY
          xcodegen generate
      - name: Verify signed release inputs
        script: |
          set -euo pipefail
          test -f "$CM_BUILD_DIR/rigaku-sprint/ios/PrivacyInfo.xcprivacy"
          test -f "$CM_BUILD_DIR/rigaku-sprint/ios/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
          test "$(shasum -a 256 "$CM_BUILD_DIR/rigaku-sprint/ios/Assets.xcassets/AppIcon.appiconset/AppIcon.png" | awk '{print $1}')" = "5ffc2de874d6f22b0fd6ee121e7c691ae7a7caee30844fad059439846dfefca9"
          grep -F 'PRODUCT_BUNDLE_IDENTIFIER: jp.allsunday1122.rigakuryouhoushi' "$CM_BUILD_DIR/rigaku-sprint/ios/project.yml"
          grep -F 'RigakuPremiumProductID: jp.allsunday1122.rigakuryouhoushi.monthly' "$CM_BUILD_DIR/rigaku-sprint/ios/project.yml"
      - name: Apply App Store signing profile for Internal TestFlight only
        script: |
          set -euo pipefail
          cd "$CM_BUILD_DIR/rigaku-sprint/ios"
          echo "Expected Codemagic profile reference: $EXPECTED_CODEMAGIC_PROFILE"
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
    codemagic.write_text(text.rstrip() + block + "\n", encoding="utf-8")
