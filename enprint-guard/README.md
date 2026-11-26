# 園プリント見落としガード

iOS native app source. Bundle ID: `jp.allsunday1122.enprintguard`.

## Current vertical slice

- SwiftUI four-tab shell: Home / Calendar / Tasks / Documents
- Camera and photo-library import
- Apple Vision Japanese OCR
- Review-before-activation task candidates
- Local persistence and local notification scheduling
- StoreKit 2 monthly / annual product wiring

## Explicitly incomplete release gates

This branch is a first implementation slice, not a TestFlight-ready release.

1. Cloud AI extraction is not connected. Current extraction is local OCR plus conservative keyword rules and is labelled as provisional.
2. Household account / two-parent sync is not connected. Local assignee text is not cross-device sharing.
3. Supabase backend project and security policies are not provisioned.
4. App Store Connect app record is not created. Numeric App ID is intentionally unset.
5. Subscription products, App Icon, support URL, privacy policy URL and real-device acceptance are not release-verified.

Do not describe this build as complete or submit it to App Review. TestFlight upload must remain disabled until the required release gates pass. App Store submission is prohibited by project instruction.
