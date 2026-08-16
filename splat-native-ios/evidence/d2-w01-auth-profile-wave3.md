# D2 W01 Auth / Session / Profile — Wave 3 Evidence

Date: 2026-08-16 JST
Branch: `scaniverse/d2-w01-auth-profile`
Base: `scaniverse/d2-share-discover`
Wave start HEAD: `0de0018a1cba917fa16eeefa5d98e5c2ec089590`
Base HEAD at Wave start: `c47329211f5ec9495f29d0c171dbfe95323f5bd9`

## Scope

This Wave only changes Auth/session/profile account-recovery behavior. It does not modify trusted upload, visibility, browser viewer, Map, Discover, moderation, or any other worker branch.

## Canonical refresh before implementation

Notion `Scaniverse同等化｜4開発班＋統合本部 v2.0`, GitHub worker/base branches, PR #4145, and production Supabase were re-read before selecting the Wave.

- Worker HEAD remained `0de0018a1cba917fa16eeefa5d98e5c2ec089590` immediately before write.
- D2 base remained `c47329211f5ec9495f29d0c171dbfe95323f5bd9` at Wave selection.
- PR #4145 still listed real auth → trusted upload → durable browser URL as the first remaining D2 gate.
- Production Supabase project remained `ACTIVE_HEALTHY`.
- Production counts at Wave selection: `auth.users=0`, confirmed users `0`, `auth.sessions=0`, `scanlab_profiles=0`.
- Auth logs in the available 24-hour window were empty.
- Supabase security advisors returned no findings.
- No production SQL mutation, Auth admin mutation, or Edge Function deploy was performed.

## Largest implementable gap selected

The live E2E remains blocked by the absence of a real test identity, so repeating the same wait would not create progress. The largest remaining implementable Auth gap was password recovery:

1. The sign-in UI had no forgot-password action.
2. There was no recovery-email request wired to the native callback.
3. There was no mandatory new-password screen after a recovery callback.
4. The existing callback handler would label any accepted Auth callback as email confirmation.

The pinned Supabase Swift revision `21d3aaf21ee98f41611f9f75070489fc8b23d882` supports `resetPasswordForEmail(_:redirectTo:)`, creates a PKCE verifier/challenge for recovery, accepts the returned PKCE code through `session(from:)`, and updates the password through `auth.update(user: UserAttributes(password: ...))`.

## Implementation

- Added a dedicated recovery callback destination: `jp.allsunday1122.splatlab://password-recovery`.
- Kept signup confirmation on the existing `jp.allsunday1122.splatlab://auth-callback` route.
- Extended `ScanLabAuthCallbackPolicy` so signup and recovery routes are exact and cannot be confused.
- Added `ScanLabPasswordRecoveryPolicy` with deterministic states:
  - `idle`
  - `linkRequested`
  - `passwordUpdateRequired`
- Persisted only the recovery phase in `UserDefaults`; email addresses, PKCE codes, access tokens, refresh tokens, and passwords are not persisted by the app recovery state.
- Added `ScanLabPasswordRecoveryCoordinator`:
  - requests reset email with the dedicated redirect URL,
  - consumes only recovery callbacks,
  - exchanges the callback through the pinned Supabase PKCE session API,
  - forces the Account tab into a new-password screen,
  - updates the password through Supabase Auth,
  - supports cancel + sign-out.
- Added a generic reset-email success notice so the UI does not disclose whether an account exists for the entered email.
- Added “パスワードを忘れた場合” to the sign-in UI.
- Normal sign-in/signup clears stale local recovery intent before starting a different auth flow.
- Added policy/store/XCTest coverage and test-target source wiring.

## Harsh review and correction

The first draft classified a recovery callback only by a locally persisted `linkRequested` flag. That is insufficient: after app reinstall, UserDefaults loss, or device migration, a valid recovery link could arrive without that flag and be misclassified as ordinary email confirmation.

The design was corrected before commit:

- signup callback remains on host `auth-callback`;
- recovery callback uses host `password-recovery` under the already-registered app scheme;
- recovery handling is selected from the callback URL itself, not from local state;
- persisted state is now only for continuity of the UI requirement across app relaunches.

This avoids relying on ephemeral local state for security-sensitive callback routing.

## Regression gates executed before commit

- Swift parser: PASS for all Wave 3 Swift files.
- Existing callback policy + existing callback XCTest typecheck: PASS.
- Recovery policy + new recovery XCTest typecheck: PASS.
- Combined callback/recovery policy typecheck: PASS.
- Executable recovery smoke: PASS.
  - reset request → `linkRequested`
  - recovery callback → `passwordUpdateRequired`
  - unexpected callback does not enter recovery
  - signup and recovery hosts remain separated
  - recovery phase persists through `UserDefaults`
- YAML parse: PASS.
- Existing generated Info.plist and URL scheme configuration remain unchanged: PASS.
- Test target includes the new recovery policy source: PASS.
- No service-role/secret key was introduced: PASS.

## Live E2E status

`LIVE_E2E_BLOCKED_BY_TEST_IDENTITY`

Production still has zero Auth users at Wave selection, so password reset email delivery, callback allow-list acceptance, password update, subsequent password sign-in, profile RLS, token refresh, and sign-out cannot be truthfully marked live PASS.

Two hosted Supabase configuration points remain external to the available connector and must be verified before claiming live recovery PASS:

1. Auth URL Configuration must allow both exact app callback URLs:
   - `jp.allsunday1122.splatlab://auth-callback`
   - `jp.allsunday1122.splatlab://password-recovery`
2. Hosted confirmation/recovery email templates must preserve the intended redirect/PKCE flow.

No fake identity, fake email-delivery evidence, or fake live PASS was created.
