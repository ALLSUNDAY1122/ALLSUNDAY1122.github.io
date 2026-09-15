# D2 W01 Auth / Session / Profile — Wave 4 Evidence

Date: 2026-08-17 JST
Branch: `scaniverse/d2-w01-auth-profile`
Base: `scaniverse/d2-share-discover`
Wave start HEAD: `fd4442504c6ab3248c7722d88219a0019c5ae038`
Base HEAD at Wave start: `c47329211f5ec9495f29d0c171dbfe95323f5bd9`

## Scope

This Wave only changes email-confirmation resilience inside Auth / session / profile. It does not modify trusted upload, visibility, browser viewer, Map, Discover, moderation, or any other worker branch.

## Canonical refresh before implementation

Notion `Scaniverse同等化｜4開発班＋統合本部 v2.0`, GitHub worker/base branches, PR #4145, and production Supabase were re-read before selecting the Wave.

- Worker HEAD remained `fd4442504c6ab3248c7722d88219a0019c5ae038` before write.
- D2 base remained `c47329211f5ec9495f29d0c171dbfe95323f5bd9`.
- Production Supabase remained `auth.users=0`, confirmed users `0`, `auth.sessions=0`, `scanlab_profiles=0`.
- Therefore live password auth E2E was still blocked by the absence of a real test identity and hosted redirect/email configuration verification.
- No production SQL mutation, Auth admin mutation, Edge Function deploy, or test-email send was performed.

## Largest implementable gap selected

The native app could request the initial signup confirmation email, but it had no user-facing recovery path when that email was lost, expired, filtered, or consumed by an email scanner. Repeating signup was the only available retry and could collide with Auth rate limits.

The pinned Supabase Swift revision `21d3aaf21ee98f41611f9f75070489fc8b23d882` provides `auth.resend(email:type:emailRedirectTo:)` with `.signup`. The implementation creates a fresh PKCE verifier/challenge and deliberately succeeds without revealing whether the email exists. Supabase's current production checklist documents a default 60-second window for signup-confirmation requests; hosted project settings remain authoritative and can be configured differently.

## Implementation

1. Added a dedicated signup-confirmation resend method using the existing exact native callback URL.
2. Kept the response enumeration-safe: the UI says the request was accepted and that mail arrives only for a registration-pending address; it does not confirm account existence.
3. Added a local 60-second minimum resend cooldown with a live countdown. This is a client-side anti-spam floor, not a replacement for Supabase server rate limits.
4. Persisted only the last-send timestamp in `UserDefaults`; no email address, password, PKCE code, access token, or refresh token is persisted by this feature.
5. After a successful signup that still needs email confirmation, the primary signup button changes to a sent state so repeated taps do not create duplicate signup requests in the same UI session.
6. A user can resend the confirmation email after the cooldown, and the UI explicitly instructs them to use the newest email link because resend replaces the PKCE verifier.
7. The user can switch to another registration email after the cooldown.
8. Successful immediate signup, normal password sign-in, and successful email-confirmation callback clear the local confirmation-send timestamp.
9. Added deterministic cooldown/store regression coverage to the already-included auth callback policy test target; no project.yml target expansion was required.

## Harsh review and correction

Signup confirmation resend and password recovery both use the same Supabase PKCE verifier storage. Starting one email flow can invalidate a link issued by the other flow.

The initial implementation added resend without coordinating these flows. Review caught that this could leave the password-recovery UI believing an old recovery link was valid after signup resend had replaced its verifier.

Correction before commit:

- starting signup resend explicitly clears the password-recovery local intent through `prepareForStandardAuth()` before Supabase creates the new signup verifier;
- starting password recovery clears the local signup-confirmation pending/cooldown state before Supabase creates the recovery verifier;
- the UI already tells users that after resend they must use the newest confirmation email.

The server remains authoritative for actual token validity and configured rate limits.

## Regression gates executed before commit

- Swift parser: PASS for modified `ScanLabAuthCallbackPolicy.swift`.
- Swift parser: PASS for modified `ScanLabBackend+AuthCallback.swift`.
- Swift parser: PASS for modified `ScanLabAccountView.swift` after the PKCE-flow review correction.
- Existing callback-policy + expanded XCTest source typecheck: PASS.
- Executable email-confirmation policy smoke: PASS.
  - first send allowed;
  - 30 seconds remaining at +30s;
  - 1 second remaining at +59.2s;
  - resend allowed at +60s;
  - clock rollback is capped to a 60-second local lockout rather than producing an unbounded wait.
- No service-role or secret key introduced.
- Existing signup and password-recovery callback hosts remain unchanged.
- No project.yml target/source mutation required.

## Live E2E status

`LIVE_E2E_BLOCKED_BY_TEST_IDENTITY`

Production still has no Auth user, so real signup email delivery, resend delivery, callback allow-list acceptance, callback PKCE exchange, profile trigger/RLS, password sign-in, token refresh, password recovery, and sign-out cannot be truthfully marked live PASS.

Hosted Supabase configuration still must be verified before claiming live E2E PASS:

1. Auth URL Configuration accepts:
   - `jp.allsunday1122.splatlab://auth-callback`
   - `jp.allsunday1122.splatlab://password-recovery`
2. Confirmation and recovery email templates preserve the intended redirect/PKCE flow.
3. A real test mailbox/identity is available to receive and open the emails.

No fake user, fake email-delivery evidence, or fake live PASS was created.
