# FP2級｜学びスプリント iOS native wrapper

- XcodeGen project: `fp2-manabi-sprint/ios/project.yml`
- SwiftUI + WKWebView: `App.swift`; local file only, external links open in Safari
- Bundle ID: `com.allsunday1122.fp2manabisprint`
- Version 1.0.0 / Build 1, iPhone only
- IAP: none; `Review.storekit` has zero products, no StoreKit runtime bridge.
- Build resources: `python3 fp2-manabi-sprint/ios/prepare-ios.py` regenerates `Web/` and embeds the exact canonical content-review bank into index.html to avoid WKWebView file:// fetch errors.
- Source: `fp2-manabi-sprint/index.html`, `fp2-approved-bank.js`, `questions/canonical/approved-questions-20261123.json`.
- Important: 122 questions are independently CONTENT PASS, but zero have publication clearance. This target is for technical build verification only; do not send to TestFlight or publish until Q0–Q5 and 120-question MVP constraints are satisfied.
- AppIcon candidate asset is carried from legacy FP2 coach only if blob provenance is confirmed; App Store registered icon hash comparison is still mandatory. CI checks local existence/dimensions but cannot prove App Store Connect correspondence.
- For local unsigned iOS Simulator compile: `brew install xcodegen && cd fp2-manabi-sprint/ios && xcodegen generate && xcodebuild -project FP2ManabiSprint.xcodeproj -scheme FP2ManabiSprint -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build`.
