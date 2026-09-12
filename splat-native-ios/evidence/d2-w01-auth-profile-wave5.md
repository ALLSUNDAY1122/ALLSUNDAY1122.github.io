# D2 W01 Auth / Session / Profile — Wave 5 Evidence

Date: 2026-08-17 JST
Branch: `scaniverse/d2-w01-auth-profile`
Base: `scaniverse/d2-share-discover`
Wave start HEAD: `8e922b20788740ec43c4208535363c8d70b3460c`
Base HEAD at Wave start: `c47329211f5ec9495f29d0c171dbfe95323f5bd9`

## Scope

This Wave only hardens authenticated profile-handle updates. It does not modify trusted upload, visibility, browser viewer, Map, Discover, moderation, or another worker branch.

## Canonical refresh before implementation

Notion `Scaniverse同等化｜4開発班＋統合本部 v2.0`, GitHub worker/base branches, PR #4145, and production Supabase were re-read before selecting the Wave.

- Worker HEAD remained `8e922b20788740ec43c4208535363c8d70b3460c` immediately before write.
- D2 base remained `c47329211f5ec9495f29d0c171dbfe95323f5bd9`.
- Production remained `auth.users=0`, confirmed users `0`, `auth.sessions=0`, `scanlab_profiles=0` at Wave selection.
- Live real-auth E2E therefore remained blocked by the absence of a stable real test identity/mailbox and hosted Auth callback/email configuration verification.
- No production SQL mutation, Auth admin mutation, Edge Function deploy, or test-email send was performed.

## Largest implementable gap selected

Profile handle format was already validated, but a case-insensitive duplicate handle would be rejected by the database and surface as a raw backend/PostgREST error in the Account UI.

Production schema inspection confirmed:

- `scanlab_profiles_handle_lower_uidx` is a UNIQUE index on `lower(handle)`.
- The profile primary key is `id` and the existing profile update does not mutate `id`.
- The only non-internal UPDATE trigger is `scanlab_profiles_touch_updated_at`, which calls the timestamp-touch function.

A client-side availability query was deliberately rejected. RLS does not naturally expose other users' private profile rows, and a preflight read would still have a TOCTOU race. The database unique index remains authoritative.

## Pinned SDK verification

The app pins Supabase Swift revision `21d3aaf21ee98f41611f9f75070489fc8b23d882`.

At that exact revision:

- PostgREST non-2xx JSON responses are decoded and thrown as `PostgrestError`.
- The SDK itself reads `error.code` when handling PostgREST errors.
- The `Supabase` product re-exports `PostgREST`, so the application can type-match `PostgrestError` without adding another package dependency.

No implementation relies on English database-message text.

## Implementation

1. Added `ScanLabProfilePolicy` with one exact mapping rule: PostgreSQL SQLSTATE `23505` means handle-unavailable in this profile-update path.
2. Added `ScanLabProfileUpdateError.handleUnavailable` with the user-facing Japanese message:
   `このユーザーIDは使用されています。別のIDを入力してください。`
3. Added `ScanLabBackend.updateProfileWithConflictMapping(...)` as a thin wrapper around the existing profile update.
4. The wrapper catches `PostgrestError` only. If `code == "23505"`, it throws the domain/user-facing handle conflict. Every other PostgREST error is rethrown unchanged.
5. The signed-in Account UI now uses the mapped profile-update method; after a conflict the fields remain editable and the existing inline error presentation shows the actionable message.
6. Added pure policy XCTest coverage and test-target source wiring.

## Harsh review

Three unsafe shortcuts were rejected:

- **No preflight availability lookup:** it would be RLS-hostile and race-prone.
- **No English message parsing:** PostgreSQL/PostgREST message wording is not an API contract.
- **No blanket backend-error remapping:** authorization, connectivity, server and unrelated PostgREST failures must remain distinguishable.

Mapping `23505` to handle conflict is grounded in the current production schema for this exact UPDATE path: the update writes `handle`, `display_name`, and timestamp data; `id` is not changed; the relevant writable unique constraint is `lower(handle)`; the UPDATE trigger only touches `updated_at`.

If future schema changes add another writable UNIQUE constraint or trigger that can emit `23505` on this path, this mapping must be revisited.

## Regression gates before commit

- Swift parse: `ScanLabProfilePolicy.swift` — PASS.
- Swift parse: `ScanLabBackend+ProfileConflict.swift` — PASS.
- Pure policy + XCTest typecheck — PASS.
- Executable policy smoke — PASS:
  - `23505` maps to handle conflict.
  - `23503`, `42501`, `PGRST116`, and `nil` do not map.
  - stable user-facing conflict message verified.
- Existing Account UI change is a single call-site substitution from the raw update to the mapped wrapper.
- No service-role key, password, email, access token, refresh token, or production fixture was introduced.
- `ScanLabProfilePolicy.swift` added to the existing test target source list.

A full Xcode/iOS module build was not available in this Wave; iOS-dependent integration is therefore not claimed as a full build PASS.

## Live E2E status

`LIVE_E2E_BLOCKED_BY_TEST_IDENTITY`

Production has no stable real Auth user at Wave selection, so a live duplicate-handle collision under authenticated RLS was not manufactured. Doing so would require production identity/data mutation and would not be honest evidence for the still-unavailable real-auth test path.

The broader real-auth E2E gate still requires a stable login-capable test identity/mailbox plus hosted callback allow-list and email-template verification.
