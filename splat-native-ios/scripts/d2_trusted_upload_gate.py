#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]
migration = (root / "supabase/migrations/20260817214149_scanlab_d2_trusted_upload_v17.sql").read_text()
exec_fix = (root / "supabase/migrations/20260817220410_scanlab_d2_trusted_upload_policy_exec_v18.sql").read_text()
service_fix = (root / "supabase/migrations/20260817220721_scanlab_d2_trusted_upload_service_role_v19.sql").read_text()
constraint_fix = (root / "supabase/migrations/20260817220810_scanlab_d2_trusted_asset_constraint_v20.sql").read_text()
upload = (root / "supabase/functions/scanlab-upload/index.ts").read_text()
publish = (root / "supabase/functions/scanlab-publish/index.ts").read_text()
workflow = (root.parent / ".github/workflows/splat-native-ios.yml").read_text()

required_migration = [
    "scanlab_private.is_trusted_upload_path",
    "storage.filename(object_name) in ('scene.spz', 'manifest.json', 'preview.jpg', 'preview.png')",
    'create policy "scanlab storage trusted owner insert"',
    "scanlab_private.trusted_scan_asset_guard",
    "storage.filename(new.asset_path) <> 'scene.spz'",
]
required_upload = [
    'const action = body.action ?? "init";',
    "const scanId = crypto.randomUUID();",
    "asset_path: assetPath",
    'required: ["scene.spz", "manifest.json"]',
    'if (action === "validate")',
    'admin.storage.from("scanlab-assets").list(folder',
]
required_publish = [
    "const expectedFolder = `${user.id}/${scan.id}`;",
    "scan.asset_path !== `${expectedFolder}/scene.spz`",
    'byName.get("scene.spz")',
    'byName.get("manifest.json")',
]
for needle in required_migration:
    assert needle in migration, f"missing migration guard: {needle}"
for needle in required_upload:
    assert needle in upload, f"missing upload entry/validation: {needle}"
for needle in required_publish:
    assert needle in publish, f"missing publish validation: {needle}"

assert "grant execute on function scanlab_private.is_trusted_upload_path(text) to authenticated;" in exec_fix
assert "grant usage on schema scanlab_private to service_role;" in service_fix
assert "grant execute on function scanlab_private.is_trusted_upload_path(text) to service_role;" in service_fix
assert "asset_path = owner_id::text || '/' || id::text || '/scene.spz'" in constraint_fix
assert "python3 splat-native-ios/scripts/d2_trusted_upload_gate.py" in workflow

for forbidden in ["result.splat", "startsWith(`${user.id}/`)"]:
    assert forbidden not in publish, f"legacy permissive path remains: {forbidden}"

print("D2 trusted upload gate: PASS")
