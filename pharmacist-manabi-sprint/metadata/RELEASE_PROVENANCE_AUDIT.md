# RELEASE PROVENANCE AUDIT｜薬剤師国家試験｜学びスプリント

Updated: 2026-09-16 JST

## Current discrepancy

- App Store Connect readback reports Build `202609140032` as `VALID / APP_STORE_ELIGIBLE / expired=false`.
- Canonical `RELEASE_STATUS.md` and `RELEASE_CHECKLIST.md` still describe Build 5 as the next/current no-IAP release flow.
- Therefore the ASC build number alone is insufficient evidence that the selected binary contains the current accepted product HEAD.

## Required reconciliation

Before Human Test #1, resolve and record:

1. Codemagic build ID and source commit SHA corresponding to ASC Build `202609140032`.
2. Product-file diff between that source commit and current main.
3. Current no-IAP Static Gate / XCTest / iOS Preflight PASS.
4. Learning Acceptance Contract PASS.
5. Visual Gate PASS.
6. P0=0, P1=0, unverified major journeys=0, known display gaps=0.

If there are no product deltas after the build commit and all gates pass, reuse the existing ASC build; do not rebuild merely to refresh evidence. If product deltas exist, create exactly one new release build only after all AI gates pass.

Do not mutate IAP/ASC metadata or submit for App Review as part of this reconciliation. Human Test remains a Human Gate.
