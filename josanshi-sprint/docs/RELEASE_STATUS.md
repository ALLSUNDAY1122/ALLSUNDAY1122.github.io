# Release Status — #14 助産師国家試験｜学びスプリント

Updated: 2026-08-14 JST
Owner: ChatGPT project アプリ開発

## Canonical implementation rules

- UI master: Notion Golden Master v2.1; v1.0 compatibility is documentary only.
- Native implementation: genuine SwiftUI; no WKWebView/WebKit primary UI.
- Shared core: `native-ios/LearningSprintCore`.
- Internal TestFlight only until explicit user approval.
- External TestFlight review and App Store review submission are prohibited before explicit approval.
- Canonical production identity approved on 2026-08-14:
  - Bundle ID: `jp.allsunday1122.josanshi`
  - Codemagic profile: `josanshi_appstore`
  - IAP: `jp.allsunday1122.josanshi.premium`
  - App Store Connect numeric App ID: Apple-issued actual value only; currently unset.

## Content gate — FULL PASS

- [x] Latest confirmed exam structure: 55 morning + 55 afternoon = 110.
- [x] 3 original exam-equivalent mocks = 330 questions.
- [x] R5 blueprint: 66 large topics × 5 distinct semantic intents = 330.
- [x] 225 general + 105 situation-setting.
- [x] 36 linked scenarios.
- [x] Subject design totals: 基礎助産学100 / 助産診断・技術学185 / 地域母子保健20 / 助産管理25. These are internal coverage-design totals, not official subject quotas.
- [x] Exact duplicate = 0.
- [x] Same-topic similarity warnings = 9; independently reviewed as distinct intents.
- [x] Missing answer / explanation / source / checked date / baseline / rights basis = 0.
- [x] 330 / 330 questions independently audited PASS.
- [x] 36 / 36 scenarios independently audited PASS.
- [x] Neonatal semantic misassignment was detected before release; DIAGNOSIS-26..37 was rebuilt as 60 questions + 9 scenarios.
- [x] Source registry: 66 evidence anchors / 57 restricted or direct-reproduction guards.

## Monetization gate — PASS

- [x] Purchase model: StoreKit 2 Non-Consumable / buy-once Premium.
- [x] Free pool: 60 general questions = 15 per official subject, derived deterministically from the audited 330-question bank.
- [x] Premium pool: 270 questions; all 105 situation-setting questions remain Premium so linked cases are never partially exposed.
- [x] Free mode: `今日のスプリント`, daily target 4 / 8 / 16, basic progress, exam countdown.
- [x] Premium: all 330, subject practice, weak review, 3 mocks, detailed history, JSON backup / restore.
- [x] Free standard sprint filters Premium questions at the LearningEngine boundary.
- [x] Subject / weak / mock / detailed-history / backup routes remain visible but open the Premium paywall when not entitled.
- [x] Purchase and restore are wired through the shared StoreKit 2 `PurchaseController`.
- [x] Verified current entitlement controls Premium unlock.
- [x] Pending / user-cancelled / unavailable / failed states have explicit UI handling.
- [x] Purchase price shown to the user is StoreKit `displayPrice`; no hard-coded display price.
- [x] `validate_monetization.py` enforces exact identity, free60/Premium270, general-only free pool, no free scenario leakage, purchase/restore contract.
- [ ] Japan base price: human decision pending.
- [ ] App Store Connect IAP record creation: Apple-side task pending.

## Golden Master v2.1 native UI gate — PASS

- [x] Home fixed order: brand → qualification → `今日も1問、力に変える。` → countdown → today ring → resume → sprint → weak → mock → subjects → 3 statistics.
- [x] Standard sprint default 8; selectable daily targets 4 / 8 / 16.
- [x] Subject practice supports randomized selection and deterministic non-shuffle mode.
- [x] Incomplete session is protected from silent overwrite.
- [x] Single-choice options grade immediately on tap.
- [x] Choice shuffle preserves original answer indices and displayed A/B/C/D mapping.
- [x] Feedback uses animated `○ / ×`, with `ここだけ覚える` before collapsible `詳しい解説`.
- [x] Weak review uses 3-consecutive-correct release rule; `わからない` joins weak review.
- [x] Result CTA order: weak review if present → replay exact completed N questions → home.
- [x] History fixed blocks: achievement ring → subject accuracy → 5-week heatmap → weak list → recent sessions.
- [x] Recent session summaries are retained up to 20 entries.
- [x] Exam date countdown and calculated required daily pace are wired; <=14 days uses the urgent accent.
- [x] Settings fixed order: text size → daily target → question shuffle → choice shuffle → exam date → learning data → memory rule → material info → reset.
- [x] Text size has standard / large / extra-large controls while preserving higher OS accessibility sizes.
- [x] JSON backup envelope includes learning state plus #14 UI preferences and recent session history; legacy core backup remains importable.
- [x] Learning reset clears answers / weak / resume / session history while preserving learning preferences.
- [x] `validate_native_golden_master.py` enforces the critical Golden Master structure in CI.

## Native App gate — PASS at unsigned Simulator stage

- [x] Actual `@main` SwiftUI application target exists: `JosanshiSprint`.
- [x] XcodeGen produces local `LearningSprintCore → JosanshiSprintFeature → JosanshiSprint` targets.
- [x] Canonical Bundle ID and Team ID are present in generated release build settings.
- [x] In-App Purchase capability is normalized and verified in the generated PBX project.
- [x] FULL-audited 330-question / 36-scenario resource is bundled and runtime-gated.
- [x] Audited source bank ↔ Swift resource byte-for-byte parity is enforced.
- [x] `PrivacyInfo.xcprivacy` is included in the actual app target and linted from the built `.app`.
- [x] No WebView primary implementation.
- [x] Swift package tests after monetization: **24 / 24 PASS**.
- [x] Actual iOS Simulator application build after release/simulator split: PASS.
- [x] Monetization + canonical-identity + release-configuration safety gates: PASS.
- [ ] 30-state screenshot audit / small-large real-device visual audit: execute at Internal TestFlight checkpoint.

## AppIcon gate

- [x] Canonical source located: Google Drive `14_助産師国家試験.png`, file ID `134DG19Lknp2p1AFvDAkLPA2zocyj2nOP`.
- [x] Authenticated Google Drive raw fetch re-confirmed the canonical source bytes.
- [x] Canonical metadata pinned: 1024×1024 RGB PNG, 590870 bytes, SHA-256 `07668a08a0703b76ecbeca38bbc5b396a248f822de594947ddccd383f0898579`.
- [x] Release helper `ios/prepare-app-icon.sh` accepts only an authenticated staged file or encrypted `JOSANSHI_APPICON_BASE64`, then refuses any file whose byte size, SHA-256, or dimensions differ.
- [x] Debug/Simulator XcodeGen spec is AppIcon-independent.
- [x] Release-only XcodeGen spec requires the exact generated `Assets.xcassets/AppIcon.appiconset`.
- [x] Public Drive download routes are not used because they return HTML rather than the authenticated original PNG.
- [ ] Codemagic secret `JOSANSHI_APPICON_BASE64` must be configured from the authenticated canonical PNG before signed Archive.

## Privacy gate

- [x] Current learning data remains local JSON; no analytics, tracking, or off-device learning-data transmission.
- [x] Current source contains no selected Required Reason API candidates guarded by CI.
- [x] `ios/PrivacyInfo.xcprivacy`: tracking=false / collected data=[] / accessed APIs=[] for the current code path.
- [x] Built Simulator app contains and passes lint for the privacy manifest.
- [x] StoreKit wiring does not add a developer-operated payment server or collect card/payment credentials.
- [ ] Re-audit the signed built app before Internal TestFlight.

## Release / Codemagic gate — PREPARED, APPLE-SIDE INPUT PENDING

- [x] `ios/codemagic-josanshi.yml` prepared for `josanshi_appstore`.
- [x] Exact Bundle ID / Team ID / product ID / AppIcon SHA are fixed.
- [x] Internal-only export option `testFlightInternalTestingOnly` is fixed.
- [x] Automatic TestFlight upload is OFF.
- [x] Automatic App Store submission is OFF.
- [x] Signed build fails before Archive if canonical AppIcon secret is missing or mismatched.
- [x] `validate_release_configuration.py` guards the release safety contract.
- [ ] App Store Connect App record must exist and return the real numeric App ID.
- [ ] Non-Consumable IAP record must exist with the approved product ID and a human-approved price.
- [ ] Codemagic App Store Connect integration/profile and encrypted AppIcon secret must exist.
- [ ] Signed Archive / IPA PASS.
- [ ] Built-app privacy re-audit PASS.
- [ ] Internal TestFlight install PASS.
- [ ] Sandbox/TestFlight purchase + restore real-device PASS.

## App Store metadata gate — PREPARED

- [x] `APP_STORE_METADATA_JA.md` prepared: name, subtitle, promotional text, description, keywords, review notes, App Privacy draft, IAP registration draft.
- [x] `support.html` prepared.
- [x] `privacy.html` prepared.
- [x] `terms.html` prepared.
- [x] IAP price intentionally remains unresolved rather than guessed.

## Latest validation evidence

- Native Foundation / full content / Golden Master / monetization / release safety / **24 XCTest PASS**: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/31773707715
- iOS App Simulator build after release/AppIcon split: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/31773658496
- Draft PR: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/pull/4137

## Genuine human / Apple-side checkpoint

Technical work that does not need Apple-side records is complete at the current branch state. The next blockers are external/canonical rather than source implementation:

1. **Premium Japan base price** — human decision required.
2. Create the App Store Connect app record for Bundle ID `jp.allsunday1122.josanshi`; write back the actual Apple-issued numeric App ID. Never guess it.
3. Create Non-Consumable `jp.allsunday1122.josanshi.premium` and set the approved price.
4. Confirm Paid Apps Agreement / tax / banking readiness for paid IAP.
5. Configure Codemagic App Store Connect integration/profile `josanshi_appstore` and encrypted `JOSANSHI_APPICON_BASE64`.
6. Run signed Archive / IPA → built-app privacy audit → Internal TestFlight → purchase/restore + 30-state small/large iPhone real-device audit.

External Beta Review and App Store review submission remain blocked until explicit user approval.
