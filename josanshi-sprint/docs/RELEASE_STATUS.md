# Release Status — #14 助産師国家試験｜学びスプリント

Updated: 2026-08-13 JST
Owner: ChatGPT project アプリ開発

## Canonical implementation rules

- UI master: Notion Golden Master v2.1; v1.0 compatibility is documentary only.
- Native implementation: SwiftUI; no WKWebView/WebKit as primary UI.
- Shared core: `native-ios/LearningSprintCore`.
- Internal TestFlight only until explicit user approval.
- External TestFlight review and App Store review submission are prohibited before explicit approval.
- Production Bundle ID / App Store Connect App ID / IAP Product ID must never be guessed.

## Acceptance gates

### Foundation gate
- [x] Market size checked from MHLW primary sources.
- [x] Current competitors checked on the Japanese App Store.
- [x] MHLW/PDL1.0 copyright terms checked.
- [x] Current official subjects confirmed.
- [x] Latest 109th item count confirmed as 55 morning + 55 afternoon = 110.
- [x] R5 question standard confirmed as current baseline in 2026 review.
- [x] Production identifiers left unset rather than guessed.
- [x] Canonical #14 AppIcon located: Drive file `14_助産師国家試験.png` / ID `134DG19Lknp2p1AFvDAkLPA2zocyj2nOP`.
- [x] Exact AppIcon source pinned in `ios/AppIconSource.json`: 1024×1024 PNG, SHA-256 `07668a08a0703b76ecbeca38bbc5b396a248f822de594947ddccd383f0898579`.

### Native UI gate
- [x] Native SwiftUI feature package created without production Bundle ID dependency.
- [x] Golden Master colors/components supplied by `LearningSprintCore` are used.
- [x] 4-tab information architecture: Home / Mock / History / Settings.
- [x] Standard sprint count = 8, selectable targets = 4 / 8 / 16.
- [x] Official four subjects are data-driven.
- [x] FULL-audited bundled question bank runtime validation: status audited / 330 questions / 36 scenarios / every auditStatus pass.
- [x] Standard sprint wired to production bank.
- [x] Subject practice wired to production bank.
- [x] Three original 110-question mock exams wired.
- [x] Weak-review flow wired with 3-consecutive-correct release rule.
- [x] Unknown/unsure marking wired.
- [x] Resume session wired to local persistent store.
- [x] 35-day heatmap and subject accuracy wired.
- [x] JSON backup export/import wired to system document UI.
- [x] Swift resource is deterministically regenerated from the audited bank; Native CI requires byte-for-byte parity.
- [x] Static guard confirms no WKWebView/WebKit/SFSafariViewController in #14 feature sources.
- [x] Static guard confirms no guessed production identifier is hard-coded in #14 feature sources.
- [x] Swift package compilation and unit tests PASS on macOS 15 CI with bundled production JSON.
- [x] XCTest 14 / 14 PASS, including full bundled bank, 110-question mock, weak-release rule, unknown/resume, local persistence and backup round-trip.
- [ ] StoreKit 2 production UI/product wiring after canonical Product ID confirmation.
- [ ] Small/large iPhone UI test on a signed/simulator app target after canonical Bundle ID/app target creation.

### Content gate — FULL PASS
- [x] R5 blueprint: 66 large topics × 5 distinct semantic intents = 330.
- [x] 330 original production questions authored.
- [x] 225 general + 105 situation-setting.
- [x] 36 linked scenarios.
- [x] Subject totals: Basic 100 / Diagnosis 185 / Community 20 / Management 25. These are internal coverage-design totals, not official MHLW subject quotas.
- [x] Exact duplicate = 0.
- [x] Same-topic similarity warnings reviewed = 9 / 9; each review bound to exact prompt SHA-256.
- [x] Answer mismatch = 0.
- [x] Missing explanation = 0.
- [x] Missing primary/source anchor = 0.
- [x] Missing evidence check date = 0.
- [x] Missing law/system baseline = 0.
- [x] Missing rights basis = 0.
- [x] All 330 questions independently audited PASS.
- [x] All 36 scenarios independently audited PASS.
- [x] Post-audit Git blob drift invalidates previous approvals automatically.
- [x] Neonatal semantic misassignment detected before release; superseded batches retired and DIAGNOSIS-26..37 rebuilt as 60 questions + 9 scenarios.
- [x] Medical-currentness audit PASS for the current content baseline.
- [x] Current source registry: 66 anchors / 57 direct-reproduction or restricted-use guards.

### Privacy gate
- [x] Current code path reviewed: local JSON persistence; no analytics, tracking, or off-device learning-data transmission.
- [x] Current source contains no `UserDefaults` use or file-timestamp Required Reason API access.
- [x] Canonical `ios/PrivacyInfo.xcprivacy` prepared with tracking=false, collected data=[], accessed APIs=[].
- [x] Native CI lints the manifest and fails if selected Required Reason API candidates are introduced without re-audit.
- [ ] Final privacy report / built-app manifest placement audit after signed iOS App target exists.
- [ ] Re-audit if StoreKit, networking, analytics, crash SDK, or any new data flow is added.

### Release gate
- [ ] Bundle ID confirmed in canonical source.
- [ ] App Store Connect App ID confirmed.
- [ ] Codemagic profile confirmed.
- [ ] IAP Product ID confirmed if monetization is enabled.
- [x] Canonical identifier registry contains a #14 row explicitly marked `未記載・推測禁止` for unresolved values.
- [x] Canonical #14 AppIcon PNG located; no lookalike regeneration.
- [x] AppIcon filename / Drive ID / dimensions / SHA-256 pinned for exact-file verification.
- [ ] Canonical AppIcon copied into the final iOS AppIcon asset catalog after target creation.
- [ ] Privacy manifest installed in the final app target and built-app privacy report audited.
- [ ] Signed archive / IPA PASS.
- [ ] Internal TestFlight install PASS.
- [ ] Purchase / restore real-device test PASS if monetization enabled.

## Latest validation evidence

- Content FULL CI PASS: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/31698323947
  - 330 / 330 authored; remaining 0; 225 general + 105 situation; 36 / 36 scenarios; unique intents 330 / 330.
  - 9 same-topic similarity warnings independently reviewed as distinct semantic intents.
  - Full structural / source / rights / duplication gate PASS.
- Native Foundation PASS: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/31698323951
  - Audited bank ↔ bundled Swift resource byte-for-byte parity PASS.
  - `PrivacyInfo.xcprivacy` lint PASS and Required Reason API candidate scan PASS.
  - No WebView primary implementation.
  - XCTest 14 tests / 0 failures.
  - Production-identifier hard-code guard PASS.
- Draft PR: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/pull/4137

## Current blockers requiring human/canonical values

1. Bundle ID — 要確認
2. App Store Connect App ID — 要確認
3. Codemagic profile — 要確認
4. IAP Product ID — 要確認 if monetization is enabled

The highest-priority identifier source is Notion `【正本】対象アプリ識別情報｜App Store Connect / Codemagic`. As of 2026-08-13, #14 is explicitly present there with unresolved values marked `未記載・推測禁止`.

All non-signing content and source-level native work is now at FULL-audited state. The remaining identifiers are required to create/verify the final production app identity, place the exact canonical AppIcon and privacy manifest into the signed app target, connect StoreKit production products, create an archive, and proceed to Internal TestFlight.
