#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]
fn = (root / "supabase/functions/scanlab-delete-scan/index.ts").read_text()
migrations = "\n".join(p.read_text() for p in sorted((root / "supabase/migrations").glob("*.sql")))
upload_guard = (root / "supabase/migrations/20260818002528_scanlab_d2_delete_upload_guard.sql").read_text()
public = (root / "supabase/functions/scanlab-public/index.ts").read_text()

required = [
    'update({status:"hidden",moderation_status:"pending",deletion_requested_at:deletionRequestedAt})',
    'deletion_requested_at',
    'asset_cleanup_pending',
    'asset_cleanup_limit_exceeded',
    'for(let offset=0;offset<1000;offset+=pageSize)',
    'limit:1,offset:1000',
    'if((overflow??[]).length===0)return{paths,error:null}',
    'const folder=`${ownerId}/${scanId}`',
    'assetPath!==`${folder}/scene.spz`',
    'previewPath!==`${folder}/preview.jpg`',
    'previewPath!==`${folder}/preview.png`',
    'for(let i=0;i<paths.length;i+=100)',
    '.from("scanlab-assets").remove(batch)',
    'async function cleanupCanonicalFolder(ownerId:string,scanId:string',
    'paths.add(`${folder}/scene.spz`)',
    'paths.add(`${folder}/manifest.json`)',
    '.eq("id",body.scanId).eq("owner_id",user.id)',
    'if(!scan){',
    'cleanupCanonicalFolder(user.id,body.scanId)',
    '.not("deletion_requested_at","is",null)',
    '.from("scanlab_scans").delete()',
]
for needle in required:
    assert needle in fn, f"missing delete recovery invariant: {needle}"

for migration_contract in [
    'drop policy if exists "scanlab owner scan delete"',
    'revoke delete on public.scanlab_scans from authenticated',
    'add column if not exists deletion_requested_at timestamptz',
    'revoke update (deletion_requested_at) on public.scanlab_scans from authenticated',
    'constraint scanlab_no_publish_while_deleting',
    "check (deletion_requested_at is null or status <> 'published')",
]:
    assert migration_contract in migrations, f"missing migration contract: {migration_contract}"

for upload_contract in [
    'create or replace function scanlab_private.is_trusted_upload_path(object_name text)',
    'stable',
    'security definer',
    's.owner_id = (select auth.uid())',
    "s.status = 'draft'",
    's.deletion_requested_at is null',
    'storage.foldername(s.asset_path) = storage.foldername(object_name)',
    'revoke all on function scanlab_private.is_trusted_upload_path(text) from public, anon',
    'grant execute on function scanlab_private.is_trusted_upload_path(text) to authenticated, service_role',
]:
    assert upload_contract in upload_guard, f"missing upload/delete race guard: {upload_contract}"
assert 'immutable' not in upload_guard.lower(), "trusted upload lifecycle guard must not be IMMUTABLE"
assert '.eq("status", "published")' in public
assert '.eq("moderation_status", "approved")' in public
print("D2-015 owner-delete regression gate PASS")
