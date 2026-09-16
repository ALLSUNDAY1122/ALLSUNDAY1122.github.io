# Release status — English Listening Sprint

Updated: 2026-08-29 (JST)

## Canonical baseline

- Repository: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- Release branch: `codex/english-listening-testflight-v2`
- Product source: this directory
- Content: 30 lessons / 90 questions / 312 bundled MP3 files
- Native route: SwiftUI; WebView is not the primary interface
- Bundle ID: `jp.allsunday1122.englishlistening`
- Version / Build: `1.0.0 (1)`

## State

`APPLE_LOGIN_REQUIRED`

Completed:

- Restored and verified the complete product assets.
- Confirmed the delivered Web reference matches the supplied v8 archive.
- Verified 30 unique lesson IDs, 90 valid questions, and 312 unique audio references with no missing MP3 files.
- Added SwiftUI source, app icon, Privacy Manifest, UserDefaults required-reason declaration, and export-compliance declaration.
- Published the support and privacy pages.
- Added the release metadata, checklist, and handoff record.
- Added a root-level Codemagic workflow that builds an internal-only signed IPA, audits the packaged content, uploads to TestFlight, and does not submit to App Store review.

Open gates:

1. Sign in to Apple Developer and App Store Connect, then create or verify the Explicit App ID and app record.
2. Record the App Store Connect App ID.
3. Push the release branch and run `english-listening-sprint-testflight` in Codemagic.
4. Confirm Apple processing and assign Build 1 to the internal tester group.
5. Complete device acceptance on an iPhone.

Human-required actions are Apple login/2FA, legal or account agreements if Apple requests them, and iPhone TestFlight acceptance. App Store review submission remains unauthorized.
