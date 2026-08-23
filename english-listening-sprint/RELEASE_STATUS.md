# Release status — English Listening Sprint

Updated: 2026-08-23 (JST)

## Canonical baseline

- Product source: this directory.
- UI reference: `index.html` from the user-supplied distribution. It is retained unchanged as the visual and interaction reference.
- Content: 30 lessons / 90 questions / 312 bundled MP3 files.
- Native route: SwiftUI. A WebView is not the primary user interface.

## State

`CODE_NOT_READY`

Completed preflight work:

- Restored the Claude handoff source and the distributed complete assets.
- Verified the distributed audio inventory and retained the reference UI unchanged.
- Recorded the native/TestFlight execution decision in the Notion canonical project page.

Open gates:

1. Complete SwiftUI implementation and cloud archive.
2. Identify the canonical individual AppIcon PNG for this app; do not substitute or generate one.
3. Create/verify Apple identifiers and App Store Connect record through the authorized Apple account.
4. Process a cloud-built archive and complete internal TestFlight device acceptance.

Human-required gates are Apple sign-in/2FA, legal agreements if requested by Apple, device acceptance on an iPhone, and the final App Store review submission approval. Internal TestFlight is the target; no public App Store submission is authorized automatically.
