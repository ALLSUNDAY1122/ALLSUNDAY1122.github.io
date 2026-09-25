import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const source = readFileSync(new URL('../supabase/functions/scanlab-delete-account/index.ts', import.meta.url), 'utf8');
const live = readFileSync(new URL('./account-delete-live-e2e.ts', import.meta.url), 'utf8');
const client = readFileSync(new URL('../SplatNative/ScanLabBackend.swift', import.meta.url), 'utf8');

assert.match(source, /admin\.auth\.getUser\(token\)/, 'deletion must authenticate bearer token');
assert.match(source, /\.eq\("owner_id",\s*user\.id\)/, 'scan lookup must be scoped to owner');
assert.match(source, /const pending = \[userID\]/, 'storage cleanup must start from owner prefix');
assert.match(source, /pending\.push\(path\)/, 'nested storage folders must be traversed');
assert.match(source, /if \(entry\.id\) files\.push\(path\)/, 'only concrete objects are scheduled');
assert.match(source, /path\.startsWith\(`\$\{userID\}\//, 'deletion must enforce owner prefix');
assert.match(source, /admin\.storage\.from\("scanlab-assets"\)\.remove\(batch\)/, 'storage is removed before auth cleanup');
assert.match(source, /admin\.auth\.admin\.signOut\(token, "global"\)/, 'all sessions must be revoked');
assert.match(source, /admin\.auth\.admin\.deleteUser\(user\.id\)/, 'auth principal must be deleted');
const storageIndex = source.indexOf('.remove(batch)');
const revokeIndex = source.indexOf('admin.auth.admin.signOut(token, "global")');
const deleteIndex = source.indexOf('deleteUser(user.id)');
assert.ok(storageIndex >= 0 && storageIndex < revokeIndex, 'storage cleanup precedes session revocation');
assert.ok(revokeIndex < deleteIndex, 'session revocation precedes principal deletion');
assert.match(source, /session_revoke_failed/, 'revocation failure stops completion');
assert.match(source, /retryable: true/, 'pre-auth deletion failures are retryable');
assert.match(source, /"Cache-Control": "no-store"/, 'delete responses are no-store');

assert.match(client, /func deleteAccount\(\) async throws/, 'native client exposes deletion');
assert.match(client, /guard response\.deleted/, 'client verifies server success');
assert.match(client, /clearAuthenticatedState\(requireSignInNotice: false\)/, 'client clears authenticated state');
assert.match(client, /try\? await client\.auth\.signOut\(\)/, 'client clears persisted session best-effort');

assert.match(live, /D2_ACCOUNT_DELETE_E2E.*!== "1"/, 'destructive live gate requires explicit opt-in');
assert.match(live, /SUPABASE_SERVICE_ROLE_KEY/, 'live E2E uses server-only admin credentials');
assert.match(live, /admin\.auth\.admin\.createUser/, 'live E2E provisions isolated disposable account');
assert.match(live, /@example\.com/, 'live E2E uses reserved non-delivery email domain');
assert.match(live, /nested\/orphan\.bin/, 'live E2E exercises historical nested orphan');
assert.match(live, /admin\.storage[\s\S]*\.upload\(orphanPath/, 'historical orphan must be seeded only with admin authority');
assert.match(live, /functions\.invoke\("scanlab-delete-account"/, 'live E2E invokes deployed function');
assert.match(live, /admin\.auth\.admin\.getUserById/, 'live E2E verifies auth-principal absence');
assert.match(live, /assertNoStoragePrefix/, 'live E2E verifies storage-prefix absence');
assert.match(live, /refreshSession\(\)/, 'live E2E verifies refresh invalidation');
assert.match(live, /signInWithPassword/, 'live E2E verifies credentials cannot reauthenticate');
assert.match(live, /finally/, 'live E2E contains emergency cleanup');

console.log('account-delete-contract: PASS');
