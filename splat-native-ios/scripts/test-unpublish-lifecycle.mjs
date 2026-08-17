import fs from 'node:fs';
import assert from 'node:assert/strict';

const unpublish = fs.readFileSync(new URL('../supabase/functions/scanlab-unpublish/index.ts', import.meta.url), 'utf8');
const publish = fs.readFileSync(new URL('../supabase/functions/scanlab-publish/index.ts', import.meta.url), 'utf8');
const lifecycle = fs.readFileSync(new URL('../SplatNative/ScanLabBackend+PublishLifecycle.swift', import.meta.url), 'utf8');
const account = fs.readFileSync(new URL('../SplatNative/ScanLabAccountView.swift', import.meta.url), 'utf8');

assert.match(unpublish, /scan\.owner_id !== user\.id/);
assert.match(unpublish, /\.eq\("status", "published"\)/);
assert.match(unpublish, /\.update\(\{ status: "hidden" \}\)/);
assert.doesNotMatch(unpublish, /share_token\s*:/, 'unpublish must not rotate share token');
assert.match(unpublish, /lifecycle_conflict/);

assert.match(publish, /scan\.status === "published"/);
assert.match(publish, /alreadyPublished: true/);
assert.match(publish, /\.neq\("status", "published"\)/);
assert.match(publish, /lifecycle_conflict/);
assert.match(publish, /moderation_hold/);
assert.match(publish, /trusted_package_required/);
assert.match(publish, /invalid_preview_path/);
assert.match(publish, /asset_invalid/);
assert.match(publish, /manifest_invalid/);
assert.match(publish, /content_confirmation_required/);
assert.match(publish, /public_safety_confirmation_required/);

assert.match(lifecycle, /functions\.invoke\(\s*"scanlab-unpublish"/s);
assert.match(lifecycle, /functions\.invoke\(\s*"scanlab-publish"/s);
assert.match(lifecycle, /response\.status != "published"/);
assert.match(account, /Button\("非公開化"\)/);
assert.match(account, /Button\("再公開"\)/);
assert.match(account, /backend\.unpublishPublishedScan\(scan\)/);
assert.match(account, /backend\.republish\(scan\)/);

console.log('PASS owner hidden/unpublish/republish lifecycle regression gate');
