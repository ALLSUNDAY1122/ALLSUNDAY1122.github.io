# RELEASE PROVENANCE BLOCKER｜第二種衛生管理者

Updated: 2026-09-16 JST

## Decision

Build 21 MUST NOT be used as evidence that the current product HEAD is ready for Human Test #1.

## Fresh canonical evidence

- `RELEASE_CHECKLIST.md` states that as of 2026-09-13 there are product deltas in `apps/sanitary-manager-2/gm2.js`, `gm3.js`, `gm4.js`, including the 30-question mock exam, pass/fail logic, StoreKit UI updates, and the learning loop.
- The repository's Codemagic evidence for Build 21 is from 2026-09-04, therefore it predates those product deltas.
- ASC `VALID / APP_STORE_ELIGIBLE / expired=false` proves Apple artifact validity, not inclusion of later product changes.

## Release rule

Before Human Test #1:

1. AI Preflight PASS.
2. Learning Acceptance Contract PASS.
3. StoreKit UI Regression Gate PASS.
4. Visual Gate PASS.
5. Build exactly one release artifact from a commit that includes the current accepted product deltas.
6. Record the Codemagic build commit SHA.
7. Read back ASC `VALID / APP_STORE_ELIGIBLE / expired=false` and the intended Version/Internal Testing attachment.
8. Only then may that build become the Human Test #1 candidate.

Do not bypass this blocker because an older build remains VALID in App Store Connect. Do not submit for App Review automatically.
