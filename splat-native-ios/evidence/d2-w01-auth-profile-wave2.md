# D2 W01 Auth / Session / Profile — Wave 2 Evidence

Date: 2026-08-16 JST
Branch: `scaniverse/d2-w01-auth-profile`
Base: `scaniverse/d2-share-discover`
Wave start HEAD: `62741eb9a27ee1547a0009e13b25430f3083ee20`
Base HEAD at Wave start: `c47329211f5ec9495f29d0c171dbfe95323f5bd9`

## Scope

This Wave only changes the first-account email-confirmation callback path for Auth / session / profile. It does not modify publish, Map, Discover, moderation, trusted upload, or any other worker branch.

## Canonical refresh before implementation

Notion `Scaniverse同等化｜4開発班＋統合本部 v2.0`, GitHub branch state, PR #4145, and the production Supabase project were re-read before selecting the Wave.

- Worker HEAD remained `62741eb9a27ee1547a0009e13b25430f3083ee20`.
- D2 base remained `c47329211f5ec9495f29d0c171dbfe95323f5bd9`.
- Production `auth.users`: 0 users, 0 confirmed users.
- Production `scanlab_profiles`: 0 rows.
- No production SQL mutation was performed.

## Largest remaining gap selected

The app had a signup UI but no complete native confirmation-return path:

1. `ScanLabBackend.signUp` did not supply a Supabase `redirectTo` URL.
2. `SplatNativeApp` had no `.onOpenURL` handler.
3. The application declared no custom auth callback URL scheme.

The pinned Supabase Swift revision `21d3aaf21ee98f41611f9f75070489fc8b23d882` supports the required flow: password signup accepts `redirectTo`, signup uses PKCE, and the official Swift example passes the returned URL to `auth.session(from:)`.

## Implementation

Canonical callback: `jp.allsunday1122.splatlab://auth-callback`

1. Added `ScanLabAuthCallbackPolicy` with an exact callback contract.
2. Signup UI now calls `signUpWithAuthCallback`, which supplies the canonical callback through Supabase `redirectTo`.
3. `SplatNativeApp` receives URLs through `.onOpenURL` and delegates only accepted auth callbacks to the backend.
4. Accepted callbacks are handed to `client.auth.session(from:)`, allowing the pinned SDK to complete the PKCE session flow.
5. The callback policy rejects a wrong scheme, wrong host, unexpected path, userinfo, and a port.
6. Callback URLs, access tokens, refresh tokens, and auth codes are never logged.
7. The existing generated Info.plist mode is preserved. Only `CFBundleURLTypes` is added, registering the exact custom scheme.
8. Added deterministic callback-policy XCTest coverage and included the policy source in the test target.

## Harsh review and correction

An initial draft considered migrating the target away from generated Info.plist configuration so that URL types could be represented as a full plist block. That approach was rejected because it increased regression risk: camera permission text, location permission text, encryption declaration, scene/launch-screen generation, display name, and orientation settings could be lost or drift.

The final implementation keeps `GENERATE_INFOPLIST_FILE: YES` and every existing `INFOPLIST_KEY_*` setting unchanged, adding only `INFOPLIST_KEY_CFBundleURLTypes` plus the test-target source entry.

The custom-scheme callback is also treated as an authentication-only input rather than a generic deep-link router. Non-matching URLs are ignored and are never passed to Supabase Auth.

## Regression gates executed before commit

- Swift parser: PASS for `ScanLabAuthCallbackPolicy.swift`.
- Swift parser: PASS for `ScanLabBackend+AuthCallback.swift`.
- Swift parser: PASS for modified `ScanLabAccountView.swift`.
- Swift parser: PASS for modified `SplatNativeApp.swift`.
- Swift typecheck: PASS for callback policy + XCTest source.
- Callback policy executable smoke assertions: PASS.
  - The first smoke invocation used a non-`main.swift` filename and Swift rejected top-level test expressions; the gate runner filename was corrected and the same assertions reran PASS. No product-code change was required.
- YAML parse: PASS.
- Existing generated-Info.plist mode preserved: PASS.
- Existing camera/location/encryption/scene/launch-screen/orientation settings preserved: PASS.
- `CFBundleURLTypes` OpenStep plist payload lint: PASS.
- Account view diff audit: PASS; signup routing is the only functional change in that file.
- App entrypoint diff audit: PASS; `.onOpenURL` callback wiring is the only change.

## Production/live E2E status

`LIVE_E2E_BLOCKED_BY_TEST_IDENTITY`

Production still has zero Auth users, so a password sign-in → profile RLS → refresh → sign-out run cannot be truthfully marked PASS yet. Wave 1's credential-driven live runner remains ready and no fake test identity or fake PASS evidence was created.

There is one external configuration item that cannot be verified or mutated by the available Supabase connector: the Auth URL Configuration allow-list (and, depending on the project's email template, use of `RedirectTo` in the confirmation template). Before claiming end-to-end email-confirmation PASS, the dashboard configuration must accept the exact callback `jp.allsunday1122.splatlab://auth-callback` and the confirmation template must honor the intended redirect.

The app-side deep-link contract is now implemented and statically gated; the remaining live gate stays open until a real confirmed test identity and the production redirect configuration are available for verification.
