# FP2級｜学びスプリント iOS native wrapper

- XcodeGen project: `fp2-manabi-sprint/ios/project.yml`
- SwiftUI + WKWebView: `App.swift`; local file only, external links open in Safari
- Bundle ID: `com.allsunday1122.fp2manabisprint`
- Version 1.0.0 / Build 1, iPhone only
- IAP: none; `Review.storekit` has zero products, no StoreKit runtime bridge.
- Build resources: `python3 fp2-manabi-sprint/ios/prepare-ios.py` verifies canonical **309 independently content-PASS** entries, derives an exact **300 selected** release-only payload (six domains × 50; 2024 exam 59/58 valid + 3 independently-authored replacements), excludes all **9 audited original-question reserves** from the native distributable, and embeds the same 300 payload into WKWebView `index.html` for file:// fetch compatibility. Manifest records SHA-256 for both full source and release-only payload.
- Source: `fp2-manabi-sprint/index.html`, `fp2-approved-bank.js`, `questions/canonical/approved-questions-20261123.json`.
- Important: recovered exam questions content audit PASS180/180 and 2024 verbatim audit PASS117/FAIL2/HOLD1 with three quarantined outside bank, canonical bank PASS309, selected300 (297 exam +3 original), reserves9, publication clearance **0**. Native unsigned Simulator CI and automated browser E2E are distinct from signed IPA, TestFlight, real iPhone acceptance and operator-rights authorization. Do not submit to App Review before Q0–Q5 and final user approval.
- AppIcon candidate asset is carried from legacy FP2 coach only if blob provenance is confirmed; App Store registered icon hash comparison is still mandatory. CI checks local existence/dimensions but cannot prove App Store Connect correspondence.
- For local unsigned iOS Simulator compile: `brew install xcodegen && cd fp2-manabi-sprint/ios && xcodegen generate && xcodebuild -project FP2ManabiSprint.xcodeproj -scheme FP2ManabiSprint -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build`.
