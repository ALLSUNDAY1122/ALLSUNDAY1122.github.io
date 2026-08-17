import assert from 'node:assert/strict';
import fs from 'node:fs';

const publish = fs.readFileSync(new URL('../supabase/functions/scanlab-publish/index.ts', import.meta.url), 'utf8');
const viewer = fs.readFileSync(new URL('../viewer/viewer.js', import.meta.url), 'utf8');
const html = fs.readFileSync(new URL('../viewer/index.html', import.meta.url), 'utf8');

assert.match(publish, /title\?: string; description\?: string/);
assert.match(publish, /metadata\.title = title/);
assert.match(publish, /metadata\.caption = description/);
assert.match(publish, /description: updated\.caption/);
assert.match(publish, /hasPreview: Boolean\(updated\.preview_path\)/);
assert.match(publish, /visibility === "public"[\s\S]*\?id=/);
assert.match(publish, /visibility === "unlisted"[\s\S]*\?token=/);

assert.match(html, /property="og:title"/);
assert.match(html, /property="og:description"/);
assert.match(html, /name="twitter:card" content="summary_large_image"/);
assert.match(html, /id="status-preview"/);
assert.match(viewer, /applyShareMetadata\(item\)/);
assert.match(viewer, /revealPreview\(item\)/);
assert.match(viewer, /await import\('@mkkellogg\/gaussian-splats-3d'\)/);
assert.ok(viewer.indexOf('applyShareMetadata(item)') < viewer.indexOf("await import('@mkkellogg/gaussian-splats-3d')"), 'metadata must render before 3D runtime import');
assert.ok(viewer.indexOf('revealPreview(item)') < viewer.indexOf("await import('@mkkellogg/gaussian-splats-3d')"), 'preview must render before 3D runtime import');
assert.match(viewer, /navigator\.share\(shareData\)/);
assert.match(viewer, /text: caption\.textContent \|\| undefined/);

console.log('share metadata contract: PASS');
