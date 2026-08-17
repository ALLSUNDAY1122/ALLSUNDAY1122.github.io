import { createClient } from '@supabase/supabase-js';

const url = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_PUBLISHABLE_KEY;
const testEmail = process.env.SUPABASE_TEST_EMAIL;
const testPassword = process.env.SUPABASE_TEST_PASSWORD;
if (!url || !key) throw new Error('missing supabase runtime env');

const supabase = createClient(url, key, {
  auth: { persistSession: false, autoRefreshToken: false },
});

let userId = null;
let scanId = null;
const assert = (condition, message) => { if (!condition) throw new Error(message); };

async function createFixtureSession() {
  if (testEmail && testPassword) {
    const password = await supabase.auth.signInWithPassword({ email: testEmail, password: testPassword });
    if (password.error) throw new Error(`fixture_password_auth_failed:${password.error.message}`);
    if (!password.data.session?.access_token) throw new Error('fixture_password_auth_missing_session');
    return password.data;
  }

  const anonymous = await supabase.auth.signInAnonymously();
  if (anonymous.error) {
    throw new Error(`fixture_auth_unavailable:${anonymous.error.message}; configure SCANLAB_RUNTIME_TEST_EMAIL/PASSWORD for explicit production runtime verification`);
  }
  if (!anonymous.data.session?.access_token) throw new Error('fixture_anonymous_auth_missing_session');
  return anonymous.data;
}

try {
  const authData = await createFixtureSession();
  userId = authData.user?.id ?? null;
  assert(userId, 'fixture user missing');

  const { data: initData, error: initError } = await supabase.functions.invoke('scanlab-upload', {
    body: { action: 'init', title: 'D2-015 runtime fixture', caption: 'ephemeral integration fixture' },
  });
  if (initError) throw new Error(`upload_init_failed:${initError.message}`);
  scanId = initData?.scanId;
  assert(scanId, 'scan id missing');

  const scene = new Uint8Array(128).fill(7);
  const manifest = JSON.stringify({ version: 1, scene: 'scene.spz' });
  const sceneUpload = await supabase.storage.from('scanlab-assets').upload(initData.paths.scene, scene, {
    contentType: 'application/octet-stream', upsert: false,
  });
  if (sceneUpload.error) throw new Error(`scene_upload_failed:${sceneUpload.error.message}`);
  const manifestUpload = await supabase.storage.from('scanlab-assets').upload(initData.paths.manifest, manifest, {
    contentType: 'application/json', upsert: false,
  });
  if (manifestUpload.error) throw new Error(`manifest_upload_failed:${manifestUpload.error.message}`);

  const { data: validateData, error: validateError } = await supabase.functions.invoke('scanlab-upload', {
    body: { action: 'validate', scanId },
  });
  if (validateError) throw new Error(`validate_failed:${validateError.message}`);
  assert(validateData?.ready === true, 'trusted package not ready');

  const folder = `${userId}/${scanId}`;
  const before = await supabase.storage.from('scanlab-assets').list(folder, { limit: 20 });
  if (before.error) throw new Error(`pre_delete_list_failed:${before.error.message}`);
  assert((before.data ?? []).length >= 2, 'fixture assets missing before delete');

  const first = await supabase.functions.invoke('scanlab-delete-scan', { body: { scanId } });
  if (first.error) throw new Error(`delete_failed:${first.error.message}`);
  assert(first.data?.deleted === true, 'first delete did not succeed');

  const row = await supabase.from('scanlab_scans').select('id').eq('id', scanId);
  if (row.error) throw new Error(`metadata_check_failed:${row.error.message}`);
  assert((row.data ?? []).length === 0, 'metadata row remained after delete');

  const after = await supabase.storage.from('scanlab-assets').list(folder, { limit: 20 });
  if (after.error) throw new Error(`post_delete_list_failed:${after.error.message}`);
  assert((after.data ?? []).length === 0, 'storage objects remained after delete');

  const retry = await supabase.functions.invoke('scanlab-delete-scan', { body: { scanId } });
  if (retry.error) throw new Error(`retry_failed:${retry.error.message}`);
  assert(retry.data?.deleted === true && retry.data?.recovered === true, 'idempotent retry contract failed');

  console.log(JSON.stringify({ ok: true, userId, scanId, first: first.data, retry: retry.data }));
} finally {
  // The runtime account is intentionally retained when password credentials are supplied.
  // Only scan/package fixtures are ephemeral; account lifecycle is owned by D2-016.
  if (userId && !testEmail && !testPassword) {
    const cleanup = await supabase.functions.invoke('scanlab-delete-account', { body: {} });
    if (cleanup.error) console.error(`fixture_account_cleanup_failed:${cleanup.error.message}`);
    else console.log(JSON.stringify({ cleanup: cleanup.data }));
  }
}
