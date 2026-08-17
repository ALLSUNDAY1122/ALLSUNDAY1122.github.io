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

async function metadata() {
  const response = await fetch(shareUrl, { headers: { Accept: 'application/json' }, cache: 'no-store' });
  if (expectGone) {
    assert.equal(response.status, 404, `expected 404 after unpublish/delete, got ${response.status}`);
    return null;
  }
  assert.equal(response.status, 200, `share metadata failed: ${response.status}`);
  const body = await response.json();
  assert.ok(body?.item?.modelUrl, 'metadata did not return modelUrl');
  return body.item;
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

const first = await metadata();
if (!first) {
  console.log('scanlab durable asset live probe: GONE PASS');
  process.exit(0);
}

const durableUrl = first.modelUrl;
assert.match(durableUrl, /\/functions\/v1\/scanlab-public\?mode=asset&(?:id|token)=/);
assert.ok(!/[?&]token=[^&]+.*[?&]token=/.test(durableUrl), 'duplicate token parameter');
await probeAsset(durableUrl);

if (waitSeconds > 0) {
  await new Promise((resolve) => setTimeout(resolve, waitSeconds * 1000));
  const second = await metadata();
  assert.equal(second.modelUrl, durableUrl, 'durable modelUrl changed after wait');
  await probeAsset(durableUrl);
}

console.log(`scanlab durable asset live probe: PASS${waitSeconds > 0 ? ` after ${waitSeconds}s` : ''}`);
