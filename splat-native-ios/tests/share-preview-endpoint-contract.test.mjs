import assert from 'node:assert/strict';
import fs from 'node:fs';

const publish = fs.readFileSync(new URL('../supabase/functions/scanlab-public/index.ts', import.meta.url), 'utf8');
const viewer = fs.readFileSync(new URL('../viewer/viewer.js', import.meta.url), 'utf8');

// Public crawler previews must use a deterministic endpoint rather than a short-lived signed URL.
assert.match(publish, /mode === "preview"/);
assert.match(publish, /visibility", "public"/);
assert.match(publish, /status", "published"/);
assert.match(publish, /moderation_status", "approved"/);
assert.match(publish, /storage\.from\("scanlab-assets"\)\.download\(scan\.preview_path\)/);
assert.match(publish, /Content-Type.*image\/png/);
assert.match(publish, /Content-Type.*image\/jpeg/);
assert.match(publish, /status: 404/);
assert.match(publish, /previewImageUrl: scan\.visibility === "public" && scan\.preview_path/);

// Unlisted capability tokens must never be embedded into the deterministic preview endpoint.
assert.doesNotMatch(publish, /previewImageUrl: scan\.visibility === "unlisted"/);
assert.match(viewer, /item\.previewImageUrl \|\| \(id \? item\.previewUrl : null\)/);
assert.match(viewer, /Unlisted shares intentionally omit og:image/);

console.log('share preview endpoint contract: PASS');
