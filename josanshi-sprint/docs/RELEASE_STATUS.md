# Release Status — #14 助産師国家試験｜学びスプリント

Updated: 2026-08-12 JST
Owner: ChatGPT project アプリ開発

## Canonical implementation rules

- UI master: Notion Golden Master v2.1; v1.0 compatibility is documentary only.
- Native implementation: SwiftUI; no WKWebView/WebKit as primary UI.
- Shared core: `native-ios/LearningSprintCore`.
- Internal TestFlight only until explicit user approval.
- External TestFlight review and App Store review submission are prohibited before explicit approval.

## Acceptance gates

### Foundation gate
- [x] Market size checked from MHLW primary sources.
- [x] Current competitors checked on the Japanese App Store.
- [x] MHLW/PDL1.0 copyright terms checked.
- [x] Current official subjects confirmed.
- [x] Latest 109th item count confirmed as 55 morning + 55 afternoon = 110.
- [x] R5 question standard confirmed as current baseline in 2026 review.
- [x] Production identifiers left unset rather than guessed.

### Native UI gate
- [x] Native SwiftUI feature package created without Bundle ID dependency.
- [x] Golden Master colors/components supplied by `LearningSprintCore` are used.
- [x] 4-tab information architecture represented: Home / Mock / History / Settings.
- [x] Standard sprint count = 8, selectable targets = 4 / 8 / 16.
- [x] Official four subjects represented in configuration.
- [ ] Full question-session UI wired to audited production question JSON.
- [ ] Weak-review flow integrated with persisted LearningStateStore.
- [ ] JSON export/import wired to document picker/share sheet.
- [ ] StoreKit 2 UI wired after Product ID confirmation.
- [ ] iPhone small/large UI tests PASS.

### Content gate
- [ ] Blueprint coverage of R5 question standard finalized.
- [ ] 330 original production questions generated (3 × 110).
- [ ] Exact duplicate = 0.
- [ ] High-similarity duplicate = 0.
- [ ] Answer mismatch = 0.
- [ ] Missing explanation = 0.
- [ ] Missing primary source = 0.
- [ ] Missing evidence check date = 0.
- [ ] Missing law/system baseline = 0.
- [ ] Missing rights basis = 0.
- [ ] Medical-currentness audit PASS.

### Release gate
- [ ] Bundle ID confirmed in canonical source.
- [ ] App Store Connect App ID confirmed.
- [ ] IAP Product ID confirmed if monetization is enabled.
- [ ] Canonical #14 AppIcon PNG located and used; no lookalike regeneration.
- [ ] Privacy manifest final audit PASS.
- [ ] Signed archive / IPA PASS.
- [ ] Internal TestFlight install PASS.
- [ ] Purchase / restore real-device test PASS if monetization enabled.

## Current blockers requiring human/canonical values

1. Bundle ID — 要確認
2. App Store Connect App ID — 要確認
3. IAP Product ID — 要確認
4. Canonical #14 AppIcon PNG exact asset — 要確認

These blockers do not stop question design, native feature development or source-level tests.
