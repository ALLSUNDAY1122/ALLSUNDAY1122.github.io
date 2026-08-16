# D2-008 Safety Wave 1 Evidence

- Recorded: 2026-08-16 21:51 JST
- Scope: report / moderation / abuse hardening
- Work branch: `scaniverse/d2-w08-safety`
- Base commit: `c47329211f5ec9495f29d0c171dbfe95323f5bd9`

## Pre-fix evidence

Read-only inspection of the linked Supabase project confirmed:

1. `scanlab_private.auto_hide_reported_scan()` immediately changed a reported `published` scan to `hidden` after a single report.
2. `scanlab_private.is_reportable_scan(uuid)` allowed a scan owner to satisfy the reportability helper for their own public/unlisted approved scan.
3. `public.scanlab_reports` already had both the unique `(scan_id, reporter_id)` index and `(scan_id, created_at DESC)` index, so no new index is required for this Wave.

## Implemented invariants

Migration: `supabase/migrations/20260816125138_scanlab_d2_report_abuse_hardening_v9.sql`

- Preserve reportability to public/unlisted + published + approved scans.
- Reject self-reporting at the database policy helper boundary.
- Restore auto-hide threshold to 3 distinct reporters within 30 days.
- Serialize moderation evaluation per scan with a row lock before counting reports.
- Only auto-hide scans that are still `published` and `approved`, so a concurrent moderator decision is not overwritten back to `pending`.
- Preserve `SECURITY DEFINER`, empty `search_path`, and restricted function execution privileges.
- Do not recreate triggers, tables, or indexes.

## Regression gate

Static invariant gate after harsh review: PASS.

Checked: self-report guard, authentication guard, visibility/status/moderation predicates, 30-day window, distinct reporter count, threshold 3, per-scan row lock, moderator-decision guard, empty search path, privilege revokes/grant, no table/index DDL, and no trigger recreation.

## Deployment boundary

This Wave does not apply DDL to the live Supabase project. The live database remains unchanged until this branch is integrated and its migration is deployed through the normal release path.
