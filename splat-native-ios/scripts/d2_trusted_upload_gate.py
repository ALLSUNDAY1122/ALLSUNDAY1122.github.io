#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]
migration = (root / "supabase/migrations/20260817072000_scanlab_d2_trusted_upload_v9.sql").read_text()
publish = (root / "supabase/functions/scanlab-publish/index.ts").read_text()

required_migration = [
    "scanlab_private.is_trusted_upload_path",
    "storage.filename(object_name) in ('scene.spz', 'manifest.json', 'preview.jpg', 'preview.png')",
    'drop policy if exists "scanlab storage owner insert"',
    'create policy "scanlab storage trusted owner insert"',
    "(storage.foldername(name))[1] = (select auth.uid())::text",
    "scanlab_private.trusted_scan_asset_guard",
    "parts[2] <> new.id::text",
    "storage.filename(new.asset_path) <> 'scene.spz'",
]
required_publish = [
    "const expectedFolder = `${user.id}/${scan.id}`;",
    "scan.asset_path !== `${expectedFolder}/scene.spz`",
    'admin.storage.from("scanlab-assets").list(expectedFolder',
    'byName.get("scene.spz")',
    'byName.get("manifest.json")',
    'scene.metadata.size < 64',
    'manifest.metadata.size > 65536',
]
for needle in required_migration:
    assert needle in migration, f"missing migration guard: {needle}"
for needle in required_publish:
    assert needle in publish, f"missing publish validation: {needle}"

for forbidden in ["result.splat", "startsWith(`${user.id}/`)"]:
    assert forbidden not in publish, f"legacy permissive path remains: {forbidden}"

print("D2 trusted upload gate: PASS")
