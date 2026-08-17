# D2-008 Safety Wave 5 Evidence

- Recorded: 2026-08-17 02:13 JST
- Scope: moderation resolution / report lifecycle / abuse recovery
- Work branch: `scaniverse/d2-w08-safety`
- Base: `scaniverse/d2-share-discover`
- Pre-wave W08 HEAD: `41b216fbf974d3333e29c5750414eb2d6ea0dda2`
- Production Supabase: `gybchnyqlqwmajwkhsly`

## Fresh source-of-truth check

Notion still assigns `moderation/reporting`, `rate limit`, and `abuse/privacy` to D.

At Wave 5 start:

- W08 was ahead 6 / behind 0 from the unchanged D2 base `c47329211f5ec9495f29d0c171dbfe95323f5bd9`.
- Draft PR #4181 was open and mergeable.
- W06 had advanced production `scanlab-public` to v6 with pagination/fresh-open/lean feed changes.
- W05 had advanced production geotag safety and the latest `publish_guard` contract.
- W03 had applied production storage mutation protection for published scan folders.
- W02 had no branch delta from base.

Wave 5 does not edit or deploy `scanlab-public`, `scanlab-publish`, or any other worker branch.

## Largest pre-fix moderation gap

Production `scanlab-publish` v4 rejected publication whenever *any* row existed in `scanlab_reports` for the scan:

`reportCount > 0 -> moderation_hold`.

But `scanlab_reports` had no resolution state, review audit, or moderator workflow. The only automatic lifecycle was:

- reporter INSERTs a report;
- at 3 distinct reporters in 30 days the scan becomes `hidden/pending`;
- there was no supported approve/reject path afterward.

This made report moderation one-way. A single historic report could also block a future owner republish forever after an owner unpublish, even when the report should be dismissed.

## Production migrations

Applied in order and recorded with the actual Supabase migration versions:

1. `20260816165339_scanlab_d2_moderation_resolution_v14`
2. `20260816165524_scanlab_d2_moderation_owner_republish_v15`
3. `20260816165659_scanlab_d2_moderation_fk_indexes_v16`

### v14

Adds private moderation state:

- `scanlab_private.moderation_reviews`: durable decision audit with scan, decision, active report count, reason counts, reviewer role, note, timestamp.
- `scanlab_private.report_dismissals`: temporary per-scan/per-reporter suppression after an approved false-positive review.
- direct `public` / `anon` / `authenticated` table privileges revoked; RLS enabled as deny-all defense in depth.

Adds service-role-only RPCs:

- `public.scanlab_moderation_queue(limit_count)` exposes active report evidence to the trusted moderation backend only.
- `public.scanlab_moderate_scan(target, decision, note)` supports `approve` / `reject`, serializes on the scan row, and creates an audit record.
- `anon` and `authenticated` have no EXECUTE; `service_role` does.

Report lifecycle:

- queue includes every scan with at least one active report, not only the 3-report auto-hidden case.
- approve deletes active false-positive reports so existing `scanlab-publish` no longer sees a permanent historic hold.
- approve stores a 30-day dismissal for the reporters whose reports were rejected; those reporters cannot immediately rebuild the same auto-hide cohort.
- a different reporter remains able to report the republished scan.
- reject sets `hidden/rejected` and keeps the original report rows as evidence.

### v15 harsh-review repair

The initial v14 approval path automatically restored an auto-hidden scan to published state.

That was rejected during harsh review: after auto-hide, there is no durable signal that distinguishes "owner wants it published again" from "owner wants to leave it private/hidden". Automatically republishing after moderator approval could therefore override the owner's later intent.

v15 changes the contract:

- moderator approve clears the report hold and changes `pending -> approved`, but **never changes hidden status back to published**;
- hidden scans return `requiresOwnerRepublish=true`;
- the owner must explicitly call the normal trusted publish flow to republish;
- that explicit republish consumes the ordinary owner publish quota;
- the latest W05 optional-public-geotag `publish_guard` is restored exactly, with no moderation bypass flag.

### v16 advisor repair

Supabase performance advisor found two new unindexed foreign keys after v14. v16 adds:

- `scanlab_moderation_reviews_scan_idx`
- `scanlab_report_dismissals_review_idx`

The foreign-key advisor findings then disappeared. Remaining unused-index INFO is expected on an empty production database and includes the pre-existing Map index.

## Live production regression

All behavioral tests used transaction-only synthetic data and ended with `ROLLBACK`.

Final owner-controlled moderation gate: **PASS**.

Verified with the real production functions/triggers:

1. Three distinct reports auto-hide `published/approved -> hidden/pending`.
2. The auto-hidden scan appears in the service moderation queue with report count 3.
3. Approve creates an audit row, clears active reports, creates three 30-day dismissals, and leaves the scan `hidden/approved`.
4. Moderator approval does not consume or mutate the owner's publish rate bucket.
5. Explicit owner republish is separate and consumes the normal publish token.
6. After explicit republish, a dismissed reporter is not reportable for that scan, while a new unrelated reporter is reportable.
7. A scan with only one active report appears in the queue before the auto-hide threshold.
8. If the owner hid that one-report scan, moderator approval resolves the report but leaves `hidden/approved` and requires owner republish.
9. Reject with one active report changes the scan to `hidden/rejected`, keeps the report evidence, and writes a reject audit row.
10. Moderator RPC EXECUTE is false for `anon` and `authenticated`, true for `service_role`.

Post-rollback production counts:

- auth users: 0
- scans: 0
- reports: 0
- blocks: 0
- rate-limit buckets: 0
- moderation reviews: 0
- report dismissals: 0

## Production boundary

No Edge Function was redeployed in Wave 5.

Production remains:

- `scanlab-public` v6 (W06-owned public feed implementation)
- `scanlab-publish` v4
- `scanlab-visibility` v2
- `scanlab-delete-account` v1

This deliberately avoids whole-file conflicts with W05/W06 and makes moderation resolution compatible with the existing `scanlab-publish` `reportCount > 0` hold: approved reports are resolved transactionally, after which the owner may explicitly publish again.

## Remaining W08 integration boundary

W08 Wave 2's bilateral block/share/cache/auth semantics are still not present in production `scanlab-public` v6. HQ must semantically merge those safety semantics into the newer W06 implementation rather than taking either whole file.
