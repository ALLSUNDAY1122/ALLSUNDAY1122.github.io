#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]
fn = (root / "supabase/functions/scanlab-delete-scan/index.ts").read_text()
migration = (root / "supabase/migrations/20260817072000_scanlab_d2_owner_delete_v9.sql").read_text()
public = (root / "supabase/functions/scanlab-public/index.ts").read_text()

required = [
    'update({ status: "hidden", moderation_status: "pending" })',
    'error: "asset_cleanup_pending", retryable: true',
    'asset_cleanup_limit_exceeded',
    'for (let offset = 0; offset < 1000; offset += pageSize)',
    'offset,',
    '.from("scanlab-assets").remove(paths)',
    '.from("scanlab_scans")\n    .delete()',
    'if (!scan) return json({ deleted: true',
    'safeOwnedPath(scan.asset_path, user.id)',
]
for needle in required:
    assert needle in fn, f"missing delete recovery invariant: {needle}"

assert 'drop policy if exists "scanlab owner scan delete"' in migration
assert 'revoke delete on public.scanlab_scans from authenticated' in migration
assert '.eq("status", "published")' in public
assert '.eq("moderation_status", "approved")' in public
print("D2-015 owner-delete regression gate PASS")
