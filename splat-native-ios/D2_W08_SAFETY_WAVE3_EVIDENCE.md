# D2-008 Safety Wave 3 Evidence

- Recorded: 2026-08-16 23:56 JST
- Scope: rate-limit / abuse hardening
- Work branch: `scaniverse/d2-w08-safety`
- Base: `scaniverse/d2-share-discover`
- Pre-wave HEAD: `ddf2b09ca78625c106900ce10fe3fb4538801257`
- Production Supabase project inspected read-only: `gybchnyqlqwmajwkhsly`

## Latest source-of-truth check

Notion still assigns `rate limit`, `moderation/reporting`, and `abuse/privacy` to D.

GitHub coordination check found D2-W06 PR #4180 actively owns Discover/feed and has deployed
`scanlab-public` production version 4. Wave 3 therefore does not edit or deploy the
`scanlab-public` Edge Function.

## Pre-fix evidence

Read-only production inspection confirmed:

1. `scanlab_private.publish_guard()` rate-limits by counting rows that are *currently*
   `published` with `published_at` inside the last hour.
2. Unpublishing clears `published_at`, so unpublish -> republish can remove the prior event
   from that count and evade the intended publish-event limit.
3. `scanlab_reports` has no time-based per-reporter mutation limit.
4. `scanlab_blocks` has no time-based block/unblock mutation limit.
5. Production currently contains 0 scans, 0 reports, 0 blocks, and 0 likes.
6. Existing database CHECK constraints already enforce content confirmation and the public
   location/privacy/rights attestations for a published shared scan; Wave 3 does not duplicate them.

## Implemented contract

Migration: `supabase/migrations/20260816145500_scanlab_d2_write_rate_limits_v11.sql`

A private, bounded per-user/per-action token bucket is introduced:

- `publish_shared`: capacity 10, refill 10 tokens/hour.
- `report`: capacity 20, refill 20 tokens/hour.
- `block_mutation`: capacity 60, refill 60 tokens/hour.

Security and concurrency invariants:

- Bucket storage lives in `scanlab_private`, not an exposed public table.
- Direct `public` / `anon` / `authenticated` table privileges are revoked.
- RLS is enabled as defense in depth.
- Mutations serialize by user + action with a transaction-scoped advisory lock, then lock the
  bucket row before refill/consume.
- Helper/trigger functions are `SECURITY DEFINER`, use an empty `search_path`, and have direct
  execution revoked from public client roles.
- A failed outer insert/update/delete rolls back the bucket mutation in the same transaction.

Boundary placement:

- Shared publish consumes by `NEW.owner_id`, not `auth.uid()`, because the trusted publish Edge
  Function performs its database update with service-role credentials after separately verifying
  ownership.
- Entering public/unlisted publication consumes the publish bucket, including
  already-published private -> public/unlisted transitions.
- public <-> unlisted switching while already shared does not consume another publish token.
- Unpublish does not refund a token; republishing consumes again and resets `published_at`.
- Report insert consumes the reporter bucket before insert.
- Block insert and unblock delete share one mutation bucket, preventing toggle spam.
- Existing report availability across a block relationship remains unchanged so a content owner
  cannot suppress a legitimate report merely by blocking the reporter.

## Harsh review

Two alternative limiter designs were rejected before commit:

1. Unbounded event-history tables: exact but allow persistent write amplification/storage growth.
2. Fixed one-hour windows: bounded but permit a rollover burst near the window boundary.

The retained token bucket bounds storage to one row per user/action and removes the fixed-window
rollover reset while still allowing a deliberately capped initial burst.

A separate suspected visibility-transition safety bypass was checked against production constraints
and rejected as a duplicate fix: the existing CHECK constraints already fail closed for published
public/shared safety requirements.

## Regression model

Read-only SQL models were executed without inserting production data:

- publish bucket empty immediately: limited.
- publish bucket after 6 minutes: one token refilled.
- publish bucket after one hour: clamped to capacity 10.
- report bucket after 3 minutes: one token refilled.
- block bucket after 1 minute: one token refilled.
- capacity refill never exceeds its configured maximum.
- draft/shared -> published/shared: consumes publish bucket.
- published/private -> published/shared: consumes publish bucket.
- public <-> unlisted while already published/shared: does not consume.
- unpublish: does not consume.

All model cases passed.

## Deployment boundary

Wave 3 adds a forward migration to the worker branch only. It does not apply DDL to production,
does not redeploy any Edge Function, and does not modify another worker branch.
