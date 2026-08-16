# D2-008 Safety Wave 2 Evidence

- Recorded: 2026-08-16 22:50 JST
- Scope: block enforcement / personalized public API cache safety
- Work branch: `scaniverse/d2-w08-safety`
- Parent commit: `3ca60e7f3b54db234ddc2d31deca27ff84a5e5d4`

## Pre-fix evidence

Latest-source inspection found that `scanlab_blocks` already existed with owner-only RLS, a `(blocker_id, blocked_id)` primary key, and a reverse `blocked_id` index. The remaining gap was enforcement:

1. `scanlab-public?mode=feed` removed only users that the viewer had blocked. A user who had blocked the viewer was still returned.
2. `scanlab-public?mode=share` did not apply block relationships at all.
3. The public function returned `Cache-Control: public` even when an Authorization header personalized the feed by block state.
4. `scanlab_likes` used `scanlab_private.is_public_scan()` without a block-pair check, so blocked peers could still create new likes through the direct authenticated table path.

## Implemented invariants

Edge function `supabase/functions/scanlab-public/index.ts`:

- Resolve bilateral block peers for an authenticated viewer: viewer-blocked-owner OR owner-blocked-viewer.
- Apply the same peer exclusion to feed and share lookup.
- Return 404 for an authenticated blocked peer on share lookup rather than revealing existence details.
- Fail closed with 503 if block-state lookup fails for an authenticated viewer.
- Reject malformed/invalid bearer authentication with 401 instead of silently falling back to anonymous personalized behavior.
- Use `Cache-Control: no-store` and `Vary: Authorization` to prevent personalized block state and short-lived signed URLs from being replayed through shared caches.

Migration `20260816135000_scanlab_d2_block_boundary_hardening_v10.sql`:

- Extend `scanlab_private.is_public_scan(uuid)` so authenticated direct-like creation is denied when either account has blocked the other.
- Preserve public + published + approved predicates, `SECURITY DEFINER`, empty `search_path`, and restricted execute privileges.
- Reuse existing block indexes; no new table/index/trigger is created.

## Harsh-review correction

The report helper is intentionally **not** changed to reject reports across a block relationship. Otherwise an abusive publisher could block a target first and suppress that target's ability to report the scan. Wave 1's self-report prohibition and 3-distinct-reporters/30-day moderation threshold remain the report-abuse controls.

## Regression gate

Required invariants for this Wave:

- outgoing block hides owner from feed: required
- incoming block hides owner from feed: required
- either-direction block hides authenticated share lookup: required
- either-direction block denies new like insert through `is_public_scan`: required
- report path remains available across block relationship: required
- anonymous public access semantics remain unchanged: required
- authenticated block lookup failure fails closed: required
- personalized API responses are not shared-cacheable: required

## Deployment boundary

This Wave does not deploy the Edge Function or apply DDL to the live Supabase project. Live behavior remains unchanged until normal integration/deployment.
