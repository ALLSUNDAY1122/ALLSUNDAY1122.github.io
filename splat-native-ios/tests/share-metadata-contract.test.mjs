import assert from 'node:assert/strict';
import fs from 'node:fs';
import { normalizeShareURL, parseShareKey } from '../viewer/share-url.js';

const publish = fs.readFileSync(new URL('../supabase/functions/scanlab-publish/index.ts', import.meta.url), 'utf8');
const viewer = fs.readFileSync(new URL('../viewer/viewer.js', import.meta.url), 'utf8');
const html = fs.readFileSync(new URL('../viewer/index.html', import.meta.url), 'utf8');
const backend = fs.readFileSync(new URL('../SplatNative/ScanLabBackend.swift', import.meta.url), 'utf8');

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

// Already-published shares must accept owner metadata refresh without republishing assets.
assert.match(publish, /if \(scan\.status === "published"\)/);
assert.match(publish, /Object\.keys\(metadata\)\.length > 0/);
assert.match(publish, /\.update\(metadata\)/);
assert.match(publish, /\.eq\("status", "published"\)/);
assert.match(publish, /current = \{ \.\.\.scan, \.\.\.refreshed \}/);
assert.match(publish, /metadataUpdated: Object\.keys\(metadata\)\.length > 0/);
const publishedBranch = publish.indexOf('if (scan.status === "published")');
const metadataRefresh = publish.indexOf('.update(metadata)', publishedBranch);
const freshPublishMutation = publish.indexOf('.update({ ...metadata, status: "published", moderation_status: "approved" })');
assert.ok(publishedBranch >= 0 && metadataRefresh > publishedBranch && metadataRefresh < freshPublishMutation, 'published metadata refresh must not reuse fresh publish mutation');

// A share URL is only valid when the browser viewer is actually deployed.
assert.match(publish, /async function viewerIsReady\(\)/);
assert.match(publish, /method: "HEAD"/);
assert.match(publish, /Accept: "text\/html"/);
assert.match(publish, /controller\.abort\(\), 2500/);
assert.match(publish, /contentType\.toLowerCase\(\)\.includes\("text\/html"\)/);
assert.match(publish, /viewerReadyUntil = Date\.now\(\) \+ 60_000/);
assert.match(publish, /error: "viewer_unavailable"/);
const readinessGate = publish.indexOf('if (["public", "unlisted"].includes(scan.visibility) && !(await viewerIsReady()))');
const publishMutation = publish.indexOf('.update({ ...metadata, status: "published", moderation_status: "approved" })');
assert.ok(readinessGate >= 0 && readinessGate < publishMutation, 'viewer readiness must fail closed before publish mutation');

// Native owner re-share must preserve the same capability-token privacy contract.
assert.match(backend, /case ScanLabVisibility\.unlisted\.rawValue:[\s\S]*components\.queryItems = nil[\s\S]*components\.fragment = "token=\\\(scan\.shareToken\.uuidString\.lowercased\(\)\)"/);
assert.doesNotMatch(backend, /case ScanLabVisibility\.unlisted\.rawValue:[^\n]*queryItems = \[URLQueryItem\(name: "token"/);

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
