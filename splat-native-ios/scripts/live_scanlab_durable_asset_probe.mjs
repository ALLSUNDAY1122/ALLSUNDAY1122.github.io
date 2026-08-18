import assert from 'node:assert/strict';

const api = process.env.SCANLAB_PUBLIC_API ?? 'https://gybchnyqlqwmajwkhsly.supabase.co/functions/v1/scanlab-public';
const id = process.env.SCANLAB_SHARE_ID ?? '';
const token = process.env.SCANLAB_SHARE_TOKEN ?? '';
const waitSeconds = Number(process.env.SCANLAB_DURABLE_WAIT_SECONDS ?? '0');
const expectGone = process.env.SCANLAB_EXPECT_GONE === '1';

assert.notEqual(Boolean(id), Boolean(token), 'set exactly one of SCANLAB_SHARE_ID or SCANLAB_SHARE_TOKEN');
assert.ok(Number.isFinite(waitSeconds) && waitSeconds >= 0 && waitSeconds <= 900, 'invalid SCANLAB_DURABLE_WAIT_SECONDS');

const key = id ? `id=${encodeURIComponent(id)}` : `token=${encodeURIComponent(token)}`;
const shareUrl = `${api}?mode=share&${key}`;
const durableUrl = `${api}?mode=asset&${key}`;

async function metadata() {
  return fetch(shareUrl, { headers: { Accept: 'application/json' }, cache: 'no-store' });
}

async function probeAsset(modelUrl) {
  const head = await fetch(modelUrl, { method: 'HEAD', cache: 'no-store' });
  assert.equal(head.status, 200, `asset HEAD failed: ${head.status}`);
  assert.match(head.headers.get('content-type') ?? '', /application\/octet-stream/i);
  assert.match(head.headers.get('cache-control') ?? '', /no-store/i, 'asset endpoint must not cache published bytes');

  const ranged = await fetch(modelUrl, { headers: { Range: 'bytes=0-15' }, cache: 'no-store' });
  assert.equal(ranged.status, 206, `asset Range request must return 206, got ${ranged.status}`);
  assert.match(ranged.headers.get('content-range') ?? '', /^bytes 0-15\//i);
  const bytes = new Uint8Array(await ranged.arrayBuffer());
  assert.equal(bytes.byteLength, 16, `expected 16 range bytes, got ${bytes.byteLength}`);
}

if (expectGone) {
  const [shareResponse, assetResponse] = await Promise.all([
    metadata(),
    fetch(durableUrl, { headers: { Range: 'bytes=0-15' }, cache: 'no-store' }),
  ]);
  assert.equal(shareResponse.status, 404, `share endpoint must return 404 after unpublish/delete, got ${shareResponse.status}`);
  assert.equal(assetResponse.status, 404, `same durable asset URL must return 404 after unpublish/delete, got ${assetResponse.status}`);
  console.log('scanlab durable asset live probe: GONE PASS');
  process.exit(0);
}

const firstResponse = await metadata();
assert.equal(firstResponse.status, 200, `share metadata failed: ${firstResponse.status}`);
const firstBody = await firstResponse.json();
assert.ok(firstBody?.item?.modelUrl, 'metadata did not return modelUrl');
assert.equal(firstBody.item.modelUrl, durableUrl, 'metadata modelUrl is not the deterministic durable asset URL');
await probeAsset(durableUrl);

if (waitSeconds > 0) {
  await new Promise((resolve) => setTimeout(resolve, waitSeconds * 1000));
  const secondResponse = await metadata();
  assert.equal(secondResponse.status, 200, `share metadata failed after wait: ${secondResponse.status}`);
  const secondBody = await secondResponse.json();
  assert.equal(secondBody?.item?.modelUrl, durableUrl, 'durable modelUrl changed after wait');
  await probeAsset(durableUrl);
}

console.log(`scanlab durable asset live probe: PASS${waitSeconds > 0 ? ` after ${waitSeconds}s` : ''}`);
