import assert from 'node:assert/strict';
import { parseScanLabAssetPath, assetContentType } from '../supabase/functions/scanlab-public/asset_delivery.mjs';

const owner = '11111111-1111-4111-8111-111111111111';
const scan = '22222222-2222-4222-8222-222222222222';
assert.deepEqual(parseScanLabAssetPath(`${owner}/${scan}/scene.spz`, owner, scan), { ownerId: owner, scanId: scan, path: `${owner}/${scan}/scene.spz` });
assert.equal(parseScanLabAssetPath(`${owner}/${scan}/manifest.json`, owner, scan), null);
assert.equal(parseScanLabAssetPath(`33333333-3333-4333-8333-333333333333/${scan}/scene.spz`, owner, scan), null);
assert.equal(parseScanLabAssetPath(`${owner}/33333333-3333-4333-8333-333333333333/scene.spz`, owner, scan), null);
assert.equal(parseScanLabAssetPath(`${owner}/${scan}/../scene.spz`, owner, scan), null);
assert.equal(assetContentType(`${owner}/${scan}/scene.spz`), 'application/octet-stream');
console.log('scanlab public durable asset delivery contract: PASS');
