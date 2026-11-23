# FP2 iOS native wrapper implementation — 2026-11-23 JST

## Source and identity
- Branch: feature/fp2-swiftui-wkwebview-release-20261123; product PR #5717 unchanged.
- Project: `fp2-manabi-sprint/ios/project.yml`.
- SwiftUI + WKWebView: `fp2-manabi-sprint/ios/App.swift`.
- Source Bundle ID `com.allsunday1122.fp2manabisprint`, Version `1.0.0`, Build `1`.
- StoreKit: `fp2-manabi-sprint/ios/Review.storekit`, `products=[]`, subscription groups empty, no native StoreKit purchase/restore bridge.
- Existing FP2 asset candidate copied from `feature/fp2-kakomon-coach:fp2-kakomon-coach/ios-app/assets/icon.png`, Git Blob SHA `ce0cb5bc61296d7ca2ebde213c729ae5d1e4ab9d`. Target App Store Connect icon hash match NOT VERIFIED. This is a provisional existing FP2 icon; do not claim registered icon hash match until canonical hash checked.

## Offline bundle
- `prepare-ios.py` reads product `index.html` and `fp2-approved-bank.js`, verifies 122 content-review-approved questions in canonical JSON, writes the identical source JSON to `Web/questions/canonical` and embeds it for WKWebView local file behavior.
- Native JavaScript fetch shim serves that precise canonical path from local embedded JSON and rejects other network fetch.
- Native URL navigation only allows local file and about; http/https taps open external Safari.
- Release publication gate is **blocked**: all 122 are content approved, **0** release clear. Max initial MVP 120, so cannot use this artifact for production/TestFlight approval.
- `PrivacyInfo.xcprivacy`: tracking false, zero collected data types at source; target binary SDK audit and Apple Privacy answer readback remain necessary.

## CI
- Workflow: `.github/workflows/fp2-ios-native-ci.yml`; macos-15 unsigned iOS Simulator XcodeGen build, source/Info.plist/asset contract readback.
- Run URL: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45146663362
- GitHub push trigger on native branch; **run 45146663362 completed SUCCESS**: source and offline bundle PASS, XcodeGen PASS, unsigned iOS Simulator xcodebuild PASS, compiled Info.plist and canonical bank readback PASS. This is NOT a signed device IPA or TestFlight acceptance. No signing, IPA upload or App Store submission.
- Registry: `automation/app-release-registry.json` entry `fp2` with version 1.0.0/build 1/IAP false, `readback:false` (not ASC confirmed).

## Blockers
1. CI macOS unsigned iOS Simulator build and bundled source readback: **PASS** (run 45146663362, source SHA e763d61ebb93d5bfd95f637e219936d2bac49354). Signed device IPA still pending.
2. Correct AppIcon hash / 1024x1024 opaque PNG verification against user-registered asset.
3. Signed device IPA provisioning and Apple build/Version readback, TestFlight routing and real-device acceptance.
4. Q0/Q1 rights and 120-question release bank selection, Q2/Q3 actual experience, Q4/Q5 independent acceptance.
5. Public support/privacy URL HTTP200, screenshot set, privacy declaration and metadata Apple readback.
6. Final explicit user approval before submission.
