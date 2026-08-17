import assert from 'node:assert/strict';
import fs from 'node:fs';
import { normalizeShareURL, parseShareKey } from '../viewer/share-url.js';

const publish = fs.readFileSync(new URL('../supabase/functions/scanlab-publish/index.ts', import.meta.url), 'utf8');
const viewer = fs.readFileSync(new URL('../viewer/viewer.js', import.meta.url), 'utf8');
const html = fs.readFileSync(new URL('../viewer/index.html', import.meta.url), 'utf8');

assert.match(publish, /title\?: string; description\?: string/);
assert.match(publish, /metadata\.title = title/);
assert.match(publish, /metadata\.caption = description/);
assert.match(publish, /description: updated\.caption/);
assert.match(publish, /hasPreview: Boolean\(updated\.preview_path\)/);
assert.match(publish, /visibility === "public"[\s\S]*\?id=/);
assert.match(publish, /visibility === "unlisted"[\s\S]*#token=/);
assert.doesNotMatch(publish, /visibility === "unlisted"[\s\S]*\?token=/);

// Preserve production publish safety/lifecycle gates while adding D2-009 metadata behavior.
assert.match(publish, /const expectedFolder = `\$\{user\.id\}\/\$\{scan\.id\}`/);
assert.match(publish, /scan\.asset_path !== `\$\{expectedFolder\}\/scene\.spz`/);
assert.match(publish, /invalid_preview_path/);
assert.match(publish, /scene\.metadata\?\.size < 64/);
assert.match(publish, /manifest\.metadata\.size > 65536/);
assert.match(publish, /asset_mime_invalid/);
assert.match(publish, /manifest_mime_invalid/);
assert.match(publish, /\.neq\("status", "published"\)/);
assert.match(publish, /alreadyPublished: true/);
assert.match(publish, /alreadyPublished: false/);

assert.match(html, /property="og:title"/);
assert.match(html, /property="og:description"/);
assert.match(html, /name="twitter:card" content="summary_large_image"/);
assert.match(html, /name="referrer" content="no-referrer"/);
assert.match(html, /rel="canonical"/);
assert.match(html, /id="status-preview"/);

const legacy = parseShareKey('https://example.test/viewer/?token=11111111-1111-1111-1111-111111111111');
assert.equal(legacy.token, '11111111-1111-1111-1111-111111111111');
assert.equal(legacy.legacyToken, legacy.token);
assert.equal(legacy.fragmentToken, null);
assert.equal(
  normalizeShareURL('https://example.test/viewer/?token=11111111-1111-1111-1111-111111111111', legacy),
  'https://example.test/viewer/#token=11111111-1111-1111-1111-111111111111',
);

const fragment = parseShareKey('https://example.test/viewer/#token=22222222-2222-2222-2222-222222222222');
assert.equal(fragment.token, '22222222-2222-2222-2222-222222222222');
assert.equal(fragment.legacyToken, null);
assert.equal(fragment.fragmentToken, fragment.token);
assert.equal(
  normalizeShareURL('https://example.test/viewer/#token=22222222-2222-2222-2222-222222222222', fragment),
  'https://example.test/viewer/#token=22222222-2222-2222-2222-222222222222',
);

const publicShare = parseShareKey('https://example.test/viewer/?id=33333333-3333-3333-3333-333333333333');
assert.equal(publicShare.id, '33333333-3333-3333-3333-333333333333');
assert.equal(publicShare.token, null);
assert.equal(
  normalizeShareURL('https://example.test/viewer/?id=33333333-3333-3333-3333-333333333333', publicShare),
  'https://example.test/viewer/?id=33333333-3333-3333-3333-333333333333',
);

assert.match(viewer, /parseShareKey\(location\.href\)/);
assert.match(viewer, /normalizeShareURL\(location\.href, \{ id, token \}\)/);
assert.match(viewer, /history\.replaceState\(null, '', shareURL\)/);
assert.match(viewer, /applyShareMetadata\(item\)/);
assert.match(viewer, /revealPreview\(item\)/);
assert.match(viewer, /await import\('@mkkellogg\/gaussian-splats-3d'\)/);
assert.ok(viewer.indexOf('applyShareMetadata(item)') < viewer.indexOf("await import('@mkkellogg/gaussian-splats-3d')"), 'metadata must render before 3D runtime import');
assert.ok(viewer.indexOf('revealPreview(item)') < viewer.indexOf("await import('@mkkellogg/gaussian-splats-3d')"), 'preview must render before 3D runtime import');
assert.match(viewer, /navigator\.share\(shareData\)/);
assert.match(viewer, /url: shareURL/);
assert.match(viewer, /navigator\.clipboard\.writeText\(shareURL\)/);

console.log('share metadata contract: PASS');
