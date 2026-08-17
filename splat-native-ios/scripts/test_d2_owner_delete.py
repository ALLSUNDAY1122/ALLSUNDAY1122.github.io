#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]
fn = (root / "supabase/functions/scanlab-delete-scan/index.ts").read_text()
migration = (root / "supabase/migrations/20260817072000_scanlab_d2_owner_delete_v9.sql").read_text()
public = (root / "supabase/functions/scanlab-public/index.ts").read_text()

required = [
    'update({ status: "hidden", moderation_status: "pending" })',
    'asset_cleanup_pending',
    'asset_cleanup_limit_exceeded',
    'for (let offset = 0; offset < 1000; offset += pageSize)',
    'limit: 1,',
    'offset: 1000,',
    'if ((overflow ?? []).length === 0) return { paths, error: null }',
    'const folder = `${ownerId}/${scanId}`',
    'assetPath !== `${folder}/scene.spz`',
    'previewPath !== `${folder}/preview.jpg`',
    'previewPath !== `${folder}/preview.png`',
    'for (let i = 0; i < paths.length; i += 100)',
    '.from("scanlab-assets").remove(batch)',
    'async function cleanupCanonicalFolder(ownerId: string, scanId: string',
    'paths.add(`${folder}/scene.spz`)',
    'paths.add(`${folder}/manifest.json`)',
    '.eq("id", body.scanId)\n    .eq("owner_id", user.id)',
    'if (!scan) {',
    'cleanupCanonicalFolder(user.id, body.scanId)',
    '.from("scanlab_scans")\n    .delete()',
]
for needle in required:
    assert needle in fn, f"missing delete recovery invariant: {needle}"

for forbidden in [
    'safeOwnedPath(scan.asset_path, user.id)',
    '.remove(paths)',
    'if (!scan) return json({ deleted: true',
    'if (scan.owner_id !== user.id)',
    'return json({ error: "forbidden" }, 403)',
]:
    assert forbidden not in fn, f"unsafe delete behavior remains: {forbidden}"

assert 'drop policy if exists "scanlab owner scan delete"' in migration
assert 'revoke delete on public.scanlab_scans from authenticated' in migration
assert '.eq("status", "published")' in public
assert '.eq("moderation_status", "approved")' in public
print("D2-015 owner-delete regression gate PASS")
