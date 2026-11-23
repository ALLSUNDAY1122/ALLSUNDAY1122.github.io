# FP2 App Privacy review — 2026-11-23

## Target identifier
- App ID 6797228406; bundle com.allsunday1122.fp2manabisprint.
- The legacy branch feature/fp2-kakomon-coach has bundle com.allsunday1122.fp2kakomoncoach and app version 1.0.0/build 1, and is NOT target binary evidence.
- The ios/sprint-study/project.yml is also a different bundle jp.allsunday1122.sprintstudy.

## Direct source evidence — current target Web sample only
- fp2-manabi-sprint/index.html uses the localStorage key fp2_manabi_sprint_restore_v130 to store answers, correct counts, weak questions, session progress and font setting; includes localStorage.getItem, setItem and removeItem.
- This HTML contains no fetch(), HTTP URLs, payment/StoreKit integration, sign-in, analytics or advertisement SDK reference.
- HTML review cannot exclude network/telemetry by an unlocated future native wrapper, linked libraries or OS-level reporting.

## Provisional App Store Connect App Privacy proposal
- 'Data Not Collected' is only a CANDIDATE, conditional on inspecting the exact target iOS native code, SDK/dependency tree, traffic, crash/analytics opt-ins and IAP at final build.
- For current eight-question HTML, learning records are on device and not transmitted to the developer by its JS.
- Tracking: not seen in inspected HTML; do not mark final ATT/tracking until target binary reviewed.
- Identifiers, diagnostics, purchases, usage data: not shown transmitted in inspected HTML; final declaration remains UNVERIFIED.
- Site support links open GitHub; third-party GitHub collection is governed by GitHub, distinct from app's first-party data collection.

## Blocking checks
- No target iOS native project with matching bundle ID found under ios/ in audited branch; legacy iOS app.json belongs to a DIFFERENT app.
- StoreKit transaction/config/product IDs for current target build not found; release MVP scope says no IAP, but binary and ASC need reconciliation.
- Need current App Store Connect App Privacy answer readback without interactive login, if available via approved API.
- Need verification that public support/privacy URL serves expected pages (site deployment not done in this branch).

Conclusion: App Privacy declaration is a draft and NOT READY FOR APP STORE CONNECT WRITE.
