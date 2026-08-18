import assert from 'node:assert/strict';

const optIn = process.env.D2_DURABLE_ASSET_E2E === '1';
assert.ok(optIn, 'refusing live E2E without D2_DURABLE_ASSET_E2E=1');

const url = (process.env.SUPABASE_URL ?? '').replace(/\/+$/, '');
const serviceRole = process.env.SUPABASE_SERVICE_ROLE_KEY ?? '';
const publishable = process.env.SUPABASE_PUBLISHABLE_KEY ?? '';
const waitSeconds = Number(process.env.SCANLAB_DURABLE_WAIT_SECONDS ?? '125');
assert.ok(url && serviceRole && publishable, 'missing Supabase live E2E credentials');
assert.ok(Number.isFinite(waitSeconds) && waitSeconds >= 121 && waitSeconds <= 300, 'wait must exceed the 120s internal signed URL TTL');

const runID = crypto.randomUUID();
const email = `d2-durable-e2e-${runID}@example.com`;
const password = `D2!${crypto.randomUUID()}aA9`;
let userID = null;
let accessToken = null;
let scanID = null;
let scenePath = null;
let manifestPath = null;
let cleanupComplete = false;

function headers(token, key, extra = {}) {
  return { apikey: key, Authorization: `Bearer ${token}`, ...extra };
}

async function jsonResponse(response, label, allowed = [200]) {
  const text = await response.text();
  let body = null;
  try { body = text ? JSON.parse(text) : null; } catch {}
  assert.ok(allowed.includes(response.status), `${label} failed: ${response.status} ${text.slice(0, 500)}`);
  return body;
}

async function invoke(name, body, token = accessToken) {
  return jsonResponse(await fetch(`${url}/functions/v1/${name}`, {
    method: 'POST',
    headers: headers(token, publishable, { 'Content-Type': 'application/json' }),
    body: JSON.stringify(body),
  }), name, [200, 201]);
}

async function storageList(prefix) {
  return jsonResponse(await fetch(`${url}/storage/v1/object/list/scanlab-assets`, {
    method: 'POST',
    headers: headers(serviceRole, serviceRole, { 'Content-Type': 'application/json' }),
    body: JSON.stringify({ prefix, limit: 100, offset: 0 }),
  }), 'storage list', [200]);
}

async function cleanup() {
  if (cleanupComplete || !userID) return;
  if (accessToken) {
    try {
      const body = await invoke('scanlab-delete-account', { confirm: true });
      if (body?.deleted === true) cleanupComplete = true;
    } catch (error) {
      console.error(`delete-account cleanup failed: ${error.message}`);
    }
  }
  if (!cleanupComplete) {
    const adminDelete = await fetch(`${url}/auth/v1/admin/users/${encodeURIComponent(userID)}`, {
      method: 'DELETE',
      headers: headers(serviceRole, serviceRole),
    });
    if (![200, 204, 404].includes(adminDelete.status)) {
      console.error(`admin auth cleanup failed: ${adminDelete.status} ${await adminDelete.text()}`);
    }
  }
}

async function probe(durableUrl) {
  const head = await fetch(durableUrl, { method: 'HEAD', cache: 'no-store' });
  assert.equal(head.status, 200, `asset HEAD failed: ${head.status}`);
  assert.match(head.headers.get('cache-control') ?? '', /no-store/i);
  assert.match(head.headers.get('content-type') ?? '', /application\/octet-stream/i);

  const ranged = await fetch(durableUrl, {
    headers: { Range: 'bytes=0-31' },
    cache: 'no-store',
  });
  assert.equal(ranged.status, 206, `asset Range must return 206, got ${ranged.status}`);
  assert.match(ranged.headers.get('content-range') ?? '', /^bytes 0-31\//i);
  const bytes = new Uint8Array(await ranged.arrayBuffer());
  assert.equal(bytes.byteLength, 32, `expected 32 bytes, got ${bytes.byteLength}`);
  return bytes;
}

try {
  const created = await jsonResponse(await fetch(`${url}/auth/v1/admin/users`, {
    method: 'POST',
    headers: headers(serviceRole, serviceRole, { 'Content-Type': 'application/json' }),
    body: JSON.stringify({ email, password, email_confirm: true }),
  }), 'create disposable auth user', [200, 201]);
  userID = created?.id ?? created?.user?.id;
  assert.ok(userID, 'admin user creation did not return an id');

  const signedIn = await jsonResponse(await fetch(`${url}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: { apikey: publishable, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  }), 'password sign-in', [200]);
  accessToken = signedIn?.access_token;
  assert.ok(accessToken, 'sign-in did not return access_token');

  const init = await invoke('scanlab-upload', {
    action: 'init',
    title: `D2 durable E2E ${runID.slice(0, 8)}`,
    caption: 'Ephemeral transport fixture; removed by the same test.',
  });
  scanID = init?.scanId;
  scenePath = init?.paths?.scene;
  manifestPath = init?.paths?.manifest;
  assert.ok(scanID && scenePath && manifestPath, 'upload init did not return trusted package paths');

  const scene = new Uint8Array(256);
  for (let i = 0; i < scene.length; i += 1) scene[i] = (i * 29 + 17) & 0xff;
  const uploadScene = await fetch(`${url}/storage/v1/object/scanlab-assets/${scenePath.split('/').map(encodeURIComponent).join('/')}`, {
    method: 'POST',
    headers: headers(accessToken, publishable, {
      'Content-Type': 'application/octet-stream',
      'x-upsert': 'false',
    }),
    body: scene,
  });
  assert.ok([200, 201].includes(uploadScene.status), `scene upload failed: ${uploadScene.status} ${await uploadScene.text()}`);

  const manifestBytes = new TextEncoder().encode(JSON.stringify({
    schemaVersion: 1,
    mediaType: 'application/octet-stream',
    byteCount: scene.byteLength,
    purpose: 'd2-durable-transport-e2e',
    runID,
  }));
  const uploadManifest = await fetch(`${url}/storage/v1/object/scanlab-assets/${manifestPath.split('/').map(encodeURIComponent).join('/')}`, {
    method: 'POST',
    headers: headers(accessToken, publishable, {
      'Content-Type': 'application/json',
      'x-upsert': 'false',
    }),
    body: manifestBytes,
  });
  assert.ok([200, 201].includes(uploadManifest.status), `manifest upload failed: ${uploadManifest.status} ${await uploadManifest.text()}`);

  const validated = await invoke('scanlab-upload', { action: 'validate', scanId: scanID });
  assert.equal(validated?.ready, true, 'trusted upload validation did not report ready');

  const prepared = await jsonResponse(await fetch(`${url}/rest/v1/scanlab_scans?id=eq.${encodeURIComponent(scanID)}`, {
    method: 'PATCH',
    headers: headers(serviceRole, serviceRole, {
      'Content-Type': 'application/json',
      Prefer: 'return=representation',
    }),
    body: JSON.stringify({
      visibility: 'public',
      content_confirmed: true,
      privacy_confirmed: true,
      rights_confirmed: true,
      public_place_confirmed: false,
      latitude: null,
      longitude: null,
      location_label: null,
    }),
  }), 'prepare public visibility', [200]);
  assert.equal(prepared?.[0]?.id, scanID, 'visibility preparation did not return the scan');

  const published = await invoke('scanlab-publish', { scanId: scanID });
  assert.equal(published?.id, scanID, 'publish returned wrong scan id');
  assert.equal(published?.visibility, 'public', 'fixture was not published publicly');

  const durableUrl = `${url}/functions/v1/scanlab-public?mode=asset&id=${encodeURIComponent(scanID)}`;
  const shareUrl = `${url}/functions/v1/scanlab-public?mode=share&id=${encodeURIComponent(scanID)}`;

  const firstShare = await jsonResponse(await fetch(shareUrl, { cache: 'no-store' }), 'share metadata', [200]);
  assert.equal(firstShare?.item?.modelUrl, durableUrl, 'metadata did not return deterministic durable asset URL');
  const firstBytes = await probe(durableUrl);
  assert.deepEqual(Array.from(firstBytes), Array.from(scene.slice(0, 32)), 'range bytes differ from uploaded Storage object');

  await new Promise((resolve) => setTimeout(resolve, waitSeconds * 1000));

  const secondShare = await jsonResponse(await fetch(shareUrl, { cache: 'no-store' }), 'share metadata after TTL', [200]);
  assert.equal(secondShare?.item?.modelUrl, durableUrl, 'durable URL changed after internal signed URL TTL');
  const secondBytes = await probe(durableUrl);
  assert.deepEqual(Array.from(secondBytes), Array.from(firstBytes), 'bytes changed after internal signed URL rotation');

  const unpublished = await invoke('scanlab-unpublish', { scanId: scanID });
  assert.equal(unpublished?.unpublished, true, 'unpublish did not transition published scan');

  const gone = await fetch(durableUrl, { headers: { Range: 'bytes=0-31' }, cache: 'no-store' });
  assert.equal(gone.status, 404, `same durable URL must return 404 after unpublish, got ${gone.status}`);

  await cleanup();
  const remaining = await storageList(userID);
  assert.equal(remaining?.length ?? 0, 0, 'disposable storage prefix survived cleanup');

  const userCheck = await fetch(`${url}/auth/v1/admin/users/${encodeURIComponent(userID)}`, {
    headers: headers(serviceRole, serviceRole),
  });
  assert.equal(userCheck.status, 404, `disposable auth user survived cleanup: ${userCheck.status}`);

  console.log(`scanlab durable asset self-contained live E2E: PASS after ${waitSeconds}s`);
} finally {
  await cleanup();
}
