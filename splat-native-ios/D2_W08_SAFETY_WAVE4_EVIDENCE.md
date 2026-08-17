# D2-008 Safety Wave 4 Evidence

- Recorded: 2026-08-17 JST
- Scope: production deployment + live regression for report / block / moderation / rate-limit / abuse controls
- Work branch: `scaniverse/d2-w08-safety`
- Base: `scaniverse/d2-share-discover`
- Pre-wave worker HEAD: `4d5d5abd18d996be5fed50c4fb12e3b05833540f`
- Production Supabase project: `gybchnyqlqwmajwkhsly`

## Latest source-of-truth / coordination check

Notion still assigns `rate limit`, `moderation/reporting`, and `abuse/privacy` to D.

Production already contained D2-W03 migration `scanlab_visibility_boundary_v9`. Its contract was re-read before deployment: it restricts authenticated `scanlab_scans` grants/RLS but does not replace the moderation helpers or `publish_guard`, so the W08 migrations are semantically compatible.

D2-W06 still owns active Discover/feed work and production `scanlab-public` v4. Wave 4 does not edit or redeploy that Edge Function.

## Production deployment

Applied through Supabase migration tooling, in order:

1. `20260816154923_scanlab_d2_report_abuse_hardening_v9`
2. `20260816154931_scanlab_d2_block_boundary_hardening_v10`
3. `20260816154947_scanlab_d2_write_rate_limits_v11`

The deployed functions were re-fetched from Postgres after migration. The live definitions match the worker contracts:

- self-report helper rejects the owner;
- report auto-hide locks the scan and hides only after 3 distinct reporters in 30 days;
- moderation transition is `published/approved -> hidden/pending` only;
- `is_public_scan` rejects either-direction block relationships;
- token buckets protect shared publish, report, and block/unblock mutation paths;
- publish/unpublish event accounting no longer depends on currently published row count.

Live triggers were also re-read and confirmed:

- `scanlab_reports_rate_limit` BEFORE report insert;
- `scanlab_reports_auto_hide` AFTER report insert;
- `scanlab_blocks_rate_limit` BEFORE block insert/delete;
- existing `scanlab_scan_publish_guard` continues to call the replaced `publish_guard`.

## Security regression

Post-deploy inspection confirmed:

- W03 least-privilege boundary remains intact: authenticated can update only `scanlab_scans.status` directly; publish-critical columns are not directly updateable;
- `scanlab_private.rate_limit_buckets` has RLS enabled;
- anon/authenticated cannot directly execute the internal rate-limit/report/block trigger helpers;
- production contained 0 real auth users / scans / reports / blocks before the live transactional test.

## Live transactional gate

A transaction-only synthetic runtime gate was executed against production and ended with `ROLLBACK`, so no test users or content were persisted.

Final successful gate verified the actual deployed functions/triggers:

- owner self-report helper: rejected;
- non-owner report helper: allowed;
- report #1: remains published/approved;
- report #2: remains published/approved;
- report #3 from a third distinct reporter: becomes hidden/pending;
- outgoing block: public helper denies visibility;
- incoming block: public helper denies visibility;
- shared publish token bucket: first 10 accepted, 11th rejected;
- report token bucket: first 20 accepted, 21st rejected;
- block mutation token bucket: first 60 accepted, 61st rejected.

Two fixture-only failures occurred before the final PASS and caused no persistent change:

1. synthetic UUIDs initially collided in the existing profile-handle generator;
2. the test initially supplied a value for the GENERATED ALWAYS report identity column.

The fixture was corrected rather than altering production behavior. Final post-rollback counts were verified as:

- auth users: 0
- scans: 0
- reports: 0
- blocks: 0
- rate-limit buckets: 0

## Harsh review repair: migration history drift

Supabase MCP assigns migration versions at apply time. The production history therefore uses `20260816154923`, `20260816154931`, and `20260816154947`, while the pre-deploy worker files used earlier local timestamps.

Leaving those old filenames in Git would cause future migration tooling to see already-deployed DDL as separate unapplied migrations; v11 would then try to create the existing private bucket table again. Wave 4 therefore renames the three repository migrations to the exact production versions without changing their blob contents.

## Remaining integration boundary

Wave 2 also hardened `scanlab-public` API behavior for bilateral block/share/cache/auth handling, but D2-W06 now owns a newer production `scanlab-public` v4 with pagination/fresh-open work. Wave 4 intentionally does not overwrite it. HQ integration must merge W06 Discover semantics with W08 bilateral public-API safety semantics rather than taking either whole file blindly.
