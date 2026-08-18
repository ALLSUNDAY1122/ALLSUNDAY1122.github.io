import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { normalizeShareURL, parseShareKey } from '../viewer/share-url.js';
import { parseScanLabFeedCursor, makeScanLabFeedCursor } from '../supabase/functions/scanlab-public/feed_cursor.mjs';
import { parseScanLabBoundingBox } from '../supabase/functions/scanlab-public/bbox.mjs';

const publicApi = readFileSync(new URL('../supabase/functions/scanlab-public/index.ts', import.meta.url), 'utf8');
const trustedPublish = readFileSync(new URL('../SplatNative/ScanLabBackend+TrustedPublish.swift', import.meta.url), 'utf8');
const safety = readFileSync(new URL('../supabase/migrations/20260818084300_scanlab_d2_w19_safety.sql', import.meta.url), 'utf8');
const visibility = readFileSync(new URL('../supabase/functions/scanlab-visibility/index.ts', import.meta.url), 'utf8');
const viewer = readFileSync(new URL('../viewer/viewer.js', import.meta.url), 'utf8');

// Supabase migration versions are primary keys in production history. Reject the
// duplicate timestamp problem produced by independent workers before any deploy.
const migrationsDirectory = new URL('../supabase/migrations/', import.meta.url);
const migrationFiles = readdirSync(migrationsDirectory).filter((name) => name.endsWith('.sql'));
const versions = new Map();
for (const name of migrationFiles) {
  const match = name.match(/^(\d{14})_/);
  assert.ok(match, `migration filename must start with a 14-digit version: ${name}`);
  const version = match[1];
  assert.ok(!versions.has(version), `duplicate migration version ${version}: ${versions.get(version)} and ${name}`);
  versions.set(version, name);
}
assert.equal(versions.get('20260817230440'), '20260817230440_scanlab_d2_w17_report_contract.sql');
assert.equal(versions.get('20260817214236'), '20260817214236_scanlab_d2_owner_delete_v18.sql');
assert.equal(versions.get('20260817214331'), '20260817214331_scanlab_d2_block_interaction_suppression_v18.sql');
assert.equal(versions.get('20260818000539'), '20260818000539_scanlab_d2_delete_lifecycle_marker_v1.sql');
assert.equal(versions.get('20260818000622'), '20260818000622_scanlab_d2_delete_publish_guard_v1.sql');
assert.equal(versions.get('20260818002528'), '20260818002528_scanlab_d2_delete_upload_guard.sql');
assert.equal(versions.get('20260818201300'), '20260818201300_scanlab_d2_profile_v9.sql');

// D2-009: capability token must end up in the fragment, never a normalized query string.
const legacy = 'https://allsunday1122.github.io/splat-native-ios/viewer/?token=22222222-2222-4222-8222-222222222222';
const parsedLegacy = parseShareKey(legacy);
assert.equal(parsedLegacy.legacyToken, '22222222-2222-4222-8222-222222222222');
const normalized = normalizeShareURL(legacy, parsedLegacy);
assert.match(normalized, /#token=22222222-2222-4222-8222-222222222222$/);
assert.doesNotMatch(normalized, /[?&]token=/);
assert.match(visibility, /#token=\$\{encodeURIComponent\(shareToken\)\}/);
assert.match(viewer, /history\.replaceState\(null, '', shareURL\)/);
assert.match(viewer, /item\.previewImageUrl \|\| \(id \? item\.previewUrl : null\)/);
assert.match(publicApi, /mode=preview&id=\$\{encodeURIComponent\(scanId\)\}/);
assert.match(publicApi, /previewImageUrl: scan\.visibility === "public"/);

// D2-012: deterministic cursor contract.
const cursor = makeScanLabFeedCursor({ id: '22222222-2222-4222-8222-222222222222', published_at: '2026-08-18T10:00:00Z' });
assert.ok(cursor);
assert.deepEqual(parseScanLabFeedCursor(cursor).value, {
  id: '22222222-2222-4222-8222-222222222222',
  publishedAt: '2026-08-18T10:00:00.000Z',
});
const bboxParams = new URLSearchParams({ minLat: '35', maxLat: '36', minLon: '139', maxLon: '140' });
assert.deepEqual(parseScanLabBoundingBox(bboxParams).value, { minLat: 35, maxLat: 36, minLon: 139, maxLon: 140 });
assert.match(publicApi, /\.order\("published_at", \{ ascending: false \}\)/);
assert.match(publicApi, /\.order\("id", \{ ascending: false \}\)/);
assert.match(publicApi, /nextCursor/);

// D2-018: both directions of a block suppress discovery/share access.
assert.match(publicApi, /blockedUserIds/);
assert.match(publicApi, /blocked\.has\(data\.owner_id\)/);
assert.match(publicApi, /blocked\.has\(scan\.owner_id\)/);
assert.match(publicApi, /access_check_unavailable/);

// D2-004 + D2-015: draft must exist before authenticated Storage upload.
const initIndex = trustedPublish.indexOf('"scanlab-upload"');
const uploadIndex = trustedPublish.indexOf('.storage.from("scanlab-assets").upload');
assert.ok(initIndex >= 0 && uploadIndex > initIndex, 'trusted draft init must precede Storage upload');
assert.match(trustedPublish, /ScanLabUploadValidateRequest/);
assert.match(trustedPublish, /cleanupFailedDraft/);
assert.match(trustedPublish, /if visibility == \.private/);
assert.match(trustedPublish, /visibility: ScanLabVisibility\.private\.rawValue/);

// D2-019: authenticated writes bind actor identity while service-role trigger writes remain possible.
assert.match(safety, /caller_uid := \(select auth\.uid\(\)\)/);
assert.match(safety, /caller_uid is not null and p_actor <> caller_uid/);
assert.match(safety, /pg_advisory_xact_lock/);
assert.match(safety, /new\.visibility <> 'public'/);
assert.match(safety, /new\.latitude := null/);
assert.match(safety, /new\.visibility='private'/);
assert.match(safety, /count\(distinct reporter_id\)/);
assert.match(safety, /report_count >= 3/);
assert.match(safety, /tgname='scanlab_reports_rate_limit'/);

console.log('D2 HQ cross-worker integration contracts: PASS');
