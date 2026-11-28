# Release status — English Listening Sprint

Updated: 2026-11-28 (JST)

## Canonical baseline

- Repository: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- Release branch: `codex/english-listening-testflight-v2`
- Product source: this directory
- Content: 100 lessons / 300 questions / 1,040 bundled MP3 files
- Native route: SwiftUI; WebView is not the primary interface
- Bundle ID: `jp.allsunday1122.englishlistening`
- App Store Connect App ID: `6840230101`
- App Store provisioning profile: `English Listening Sprint App Store` (Active; expires 2027-08-19)
- Version / Build: `1.0.0 (3)`

## State

`APPLE_READY_CI_PENDING`

Completed:

- Restored and verified the complete product assets.
- Confirmed the delivered Web reference matches the supplied v8 archive.
- Verified 100 unique lesson IDs, 300 valid questions, and 1,040 unique audio references with no missing MP3 files.
- Added SwiftUI source, app icon, Privacy Manifest, UserDefaults required-reason declaration, and export-compliance declaration.
- Published the support and privacy pages.
- Added the release metadata, checklist, and handoff record.
- Added a root-level Codemagic workflow that builds an internal-only signed IPA, audits the packaged content, uploads to TestFlight, and does not submit to App Store review.

Open gates:

1. Apple Developer / App Store Connect app record exists (App ID `6840230101`); distribution profile `English Listening Sprint App Store` is Active through 2027-08-19.
2. Run `english-listening-sprint-testflight` from `codex/english-listening-testflight-v2` in Codemagic.
3. Confirm Apple processing and verify the build appears in the internal TestFlight group.
4. Complete device acceptance on an iPhone.

Human-required actions are Apple login/2FA, legal or account agreements if Apple requests them, and iPhone TestFlight acceptance. App Store review submission remains unauthorized.
