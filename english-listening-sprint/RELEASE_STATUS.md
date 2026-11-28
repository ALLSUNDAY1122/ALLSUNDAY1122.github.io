# Release status — English Listening Sprint

Updated: 2026-11-28 (JST)

## Canonical baseline

- Repository: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- Release branch: `codex/english-listening-testflight-v2`
- Product source: `english-listening-sprint/`
- Content: 100 lessons / 20 themes × 5 regions / 300 questions
- Bundled audio: 1,040 audio references/files
- Free tier: themes 01–06 across all five regions = 30 lessons
- Premium tier: themes 07–20 across all five regions = 70 lessons
- Native route: SwiftUI; WebView is not the primary interface
- Bundle ID: `jp.allsunday1122.englishlistening`
- App Store Connect App ID: `6840230101`
- App Store provisioning profile: `English Listening Sprint App Store` (Active; expires 2027-08-19)
- Version / Build: `1.0.0 (6)`

## In-app purchases

| Product | Product ID | StoreKit type | Price / offer |
|---|---|---|---|
| Monthly Premium | `jp.allsunday1122.englishlistening.premium.monthly` | Auto-renewable subscription (1 month) | JPY 200/month; introductory free trial 7 days |
| Lifetime Premium | `jp.allsunday1122.englishlistening.premium.lifetime` | Non-consumable | JPY 980 |

StoreKit 2 implementation:
- Loads and validates the two product IDs and their product types.
- Checks the monthly subscription period and reads the seven-day free-trial offer from StoreKit product metadata.
- Shows the paywall from locked lesson selection and Settings.
- Provides purchase and restore actions.
- Rechecks entitlements repeatedly after purchase and restore.
- Observes `Transaction.updates` and refreshes entitlements when the app returns to the active state.
- Keeps lesson content and bundled audio unchanged.

App Store Connect product records, prices, subscription group, and introductory-offer configuration must be confirmed in App Store Connect. The app's displayed price and trial wording are based on the StoreKit product information returned by Apple; a source-code check does not prove that the products are available for sale in App Store Connect.

## State

`IMPLEMENTED_CI_PENDING`

Completed in the release branch:
- Confirmed 100 unique lesson IDs, 300 questions, and 1,040 unique audio references/files.
- Implemented the 30-lesson free tier and premium lock/paywall access gate.
- Implemented StoreKit 2 monthly and lifetime product handling, purchase, restore, entitlement refresh, and foreground recheck.
- Added paywall pricing/trial information, privacy-policy and terms links, and subscription renewal/cancellation disclosure.
- Updated App Store metadata and this release-status record for version 1.0.0 build 6.
- Extended the Codemagic content audit to check product IDs, product types, free-tier coverage, and build number while retaining the 100 / 300 / 1,040 content checks.

## Verification status

Source-level checks completed:
- 100 lessons / 300 questions / 1,040 audio references.
- 30 free lessons, with exactly six free themes in each of the five regions.
- Both product IDs are present.
- Monthly auto-renewable and lifetime non-consumable product-type checks are present.
- Seven-day introductory-offer metadata check is present.
- Locked lesson access gate, paywall, purchase/restore, and foreground entitlement refresh are present.
- Project build setting is 6.

Not yet verified by this source audit:
- Successful Xcode/Codemagic archive and signed IPA for build 6.
- App Store Connect availability of both in-app purchase products and the monthly seven-day introductory offer.
- Successful Sandbox purchase, restore, subscription renewal/expiry, and lifetime purchase tests.
- Apple processing and appearance of build 6 in the internal TestFlight group.
- Device acceptance on an iPhone.

## Open gates

1. Confirm in App Store Connect that the monthly product `jp.allsunday1122.englishlistening.premium.monthly` is configured as a JPY 200 monthly auto-renewable subscription with a seven-day introductory free trial.
2. Confirm that `jp.allsunday1122.englishlistening.premium.lifetime` is configured as a JPY 980 non-consumable product.
3. Run `english-listening-sprint-testflight` from `codex/english-listening-testflight-v2` in Codemagic.
4. Confirm the build uses version 1.0.0 / build 6, completes signing and upload, and appears in the internal TestFlight group.
5. Test both purchase paths, restore, locked/free lesson access, and entitlement refresh on a device.

Human-required actions include Apple login/2FA, legal or account agreements if Apple requests them, App Store Connect product configuration/confirmation, and iPhone TestFlight acceptance. App Store review submission remains unauthorized.
