# D2 W01 Auth / Session / Profile — Wave 1 Evidence

Date: 2026-08-16 JST
Branch: `scaniverse/d2-w01-auth-profile`
Base: `scaniverse/d2-share-discover`
Base HEAD at Wave start: `c47329211f5ec9495f29d0c171dbfe95323f5bd9`

## Scope

This Wave only changes Auth / session / profile behavior and the live-auth E2E gate. It does not change publish, Map, Discover, moderation, or other workers' branches.

## Canonical-state checks before implementation

Production Supabase project `gybchnyqlqwmajwkhsly` was inspected read-only.

- `scanlab_profiles`, `scanlab_scans`, `scanlab_likes`, `scanlab_reports`, and `scanlab_blocks`: RLS enabled.
- `scanlab_profiles`: authenticated users have own-row SELECT / INSERT / UPDATE policies keyed by `auth.uid() = id`.
- `storage.objects`: `scanlab-assets` owner policies are scoped to the authenticated user's first path segment.
- `auth.users`: `scanlab_auth_user_created` trigger exists and calls `scanlab_private.handle_new_user()`.
- `scanlab_private.handle_new_user()` creates the corresponding `scanlab_profiles` row and is idempotent on user id.
- Auth user count at Wave start: `0` (confirmed user count: `0`).

No production SQL mutation was performed.

## Implementation

1. Added explicit `ScanLabAuthPhase` state: `resolving`, `signedOut`, `signedIn`.
2. Initial UI no longer assumes signed-out while Supabase is still restoring the local session.
3. Auth events now cover initial session, sign-in, token refresh, user update, password recovery, MFA verification, sign-out, and user deletion.
4. Session refresh does not fan out redundant profile/owner/public reloads.
5. Signed-out/user-deleted transitions clear owner/profile state and reload the public feed anonymously.
6. Account view no longer duplicates the auth observer's profile/owner hydration.
7. Added deterministic auth-state reducer tests.
8. Added `scripts/scanlab_auth_e2e.mjs` for the real production gate. Credentials are only accepted through:
   - `SCANLAB_E2E_EMAIL`
   - `SCANLAB_E2E_PASSWORD`

The live runner verifies password sign-in, own-profile RLS read, own-profile RLS update, refresh-token session renewal, profile read after refresh, and sign-out. It never prints access or refresh tokens.

## Regression gate executed before commit

- Swift parser: PASS for `ScanLabBackend.swift`, `ScanLabAccountView.swift`, and `ScanLabAuthStatePolicy.swift`.
- Swift typecheck: PASS for auth-state policy + XCTest source.
- Auth policy executable smoke assertions: PASS.
- Node syntax check for live E2E runner: PASS.
- Missing-credential fail-closed behavior: PASS (exit 2, no network request).
- `project.yml` YAML parse and test-target source inclusion: PASS.

## Live E2E status

`BLOCKED_BY_TEST_IDENTITY`

The production Auth user count is zero, so a real password sign-in / refresh / sign-out cycle cannot be truthfully marked PASS in this Wave without first creating and confirming a production test identity. No credentials or fake PASS evidence were manufactured.

The runner is ready to execute immediately once a confirmed production test identity is available:

```bash
SCANLAB_E2E_EMAIL='...' SCANLAB_E2E_PASSWORD='...' \
node splat-native-ios/scripts/scanlab_auth_e2e.mjs
```

A successful run emits a token-free JSON result with gate name `scanlab-auth-session-profile-live-e2e` and status `PASS`.
