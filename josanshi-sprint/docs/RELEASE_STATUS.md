# Release Status — #14 助産師国家試験｜学びスプリント

Updated: 2026-08-14 JST
Owner: ChatGPT project アプリ開発

## Canonical implementation rules

- UI master: Notion Golden Master v2.1; v1.0 compatibility is documentary only.
- Native implementation: genuine SwiftUI; no WKWebView/WebKit primary UI.
- Shared core: `native-ios/LearningSprintCore`.
- Internal TestFlight only until explicit user approval.
- External TestFlight review and App Store review submission are prohibited before explicit approval.
- Production Bundle ID / App Store Connect App ID / Codemagic profile / IAP Product ID are canonical values and must never be guessed.

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
- [x] XcodeGen produces local `LearningSprintCore → JosanshiSprintFeature → JosanshiSprint` targets without a production Bundle ID dependency.
- [x] FULL-audited 330-question / 36-scenario resource is bundled and runtime-gated.
- [x] Audited source bank ↔ Swift resource byte-for-byte parity is enforced.
- [x] `PrivacyInfo.xcprivacy` is included in the actual app target and linted from the built `.app`.
- [x] No WebView primary implementation.
- [x] Swift package tests: 21 / 21 PASS.
- [x] Actual iOS Simulator application build: PASS.
- [x] Production identifier hard-code guard: PASS.
- [ ] 30-state screenshot audit / small-large real-device visual audit: execute at Internal TestFlight checkpoint.

## AppIcon gate

- [x] Canonical source located: Google Drive `14_助産師国家試験.png`, file ID `134DG19Lknp2p1AFvDAkLPA2zocyj2nOP`.
- [x] Canonical metadata pinned: 1024×1024 RGB PNG, 590870 bytes, SHA-256 `07668a08a0703b76ecbeca38bbc5b396a248f822de594947ddccd383f0898579`.
- [x] Release helper `ios/prepare-app-icon.sh` refuses any file whose byte size, SHA-256, or dimensions differ.
- [x] Public Drive download routes were tested and correctly rejected because they returned HTML rather than the authenticated original PNG.
- [ ] Exact authenticated canonical PNG must be staged into the release build environment before Archive; lookalike/regenerated icons are prohibited.

## Privacy gate

- [x] Current learning data remains local JSON; no analytics, tracking, or off-device learning-data transmission.
- [x] Current source contains no selected Required Reason API candidates guarded by CI.
- [x] `ios/PrivacyInfo.xcprivacy`: tracking=false / collected data=[] / accessed APIs=[] for the current code path.
- [x] Built Simulator app contains and passes lint for the privacy manifest.
- [ ] Re-audit after StoreKit production wiring or any new network / analytics / crash SDK.

## Latest validation evidence

- Content FULL PASS: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/31760418839
- Native Foundation + Golden Master v2.1 + 21 XCTest PASS: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/31760418826
- Actual iOS App Simulator build + built Privacy Manifest PASS: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/31760418821
- Shared Learning Sprint Native Core PASS: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/31760418841
- Draft PR: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/pull/4137

## Human / canonical decisions still required

Top-level Notion `【正本】対象アプリ識別情報｜App Store Connect / Codemagic` still marks #14 production values unresolved. Do not infer them from other apps.

1. Bundle ID — user value or explicit naming delegation required.
2. Codemagic profile — user value or explicit naming delegation required.
3. IAP Product ID — only after monetization is enabled; user value or explicit naming delegation required.
4. Free / paid boundary and purchase model — qualification-specific monetization decision; not fixed by the common Golden Master.
5. App Store Connect numeric App ID — Apple-issued actual value only; never guess.

After those decisions: register canonical identifiers → stage exact AppIcon → connect StoreKit 2 if enabled → signed Archive / IPA → built-app privacy re-audit → Internal TestFlight → 30-state / small-large real-device audit → user TestFlight approval. External Beta Review / App Store review remain blocked until explicit approval.
