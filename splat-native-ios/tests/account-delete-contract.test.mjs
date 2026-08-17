import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const source = readFileSync(new URL('../supabase/functions/scanlab-delete-account/index.ts', import.meta.url), 'utf8');
const live = readFileSync(new URL('./account-delete-live-e2e.ts', import.meta.url), 'utf8');
const client = readFileSync(new URL('../SplatNative/ScanLabBackend.swift', import.meta.url), 'utf8');

assert.match(source, /admin\.auth\.getUser\(token\)/, 'deletion must authenticate the bearer token');
assert.match(source, /\.eq\("owner_id", user\.id\)/, 'scan lookup must be scoped to the authenticated owner');
assert.match(source, /const pending = \[userID\]/, 'storage cleanup must start from the owner prefix');
assert.match(source, /pending\.push\(path\)/, 'nested storage folders must be traversed recursively');
assert.match(source, /if \(entry\.id\) files\.push\(path\)/, 'only concrete storage objects should be scheduled for deletion');
assert.match(source, /path\.startsWith\(`\$\{userID\}\//, 'storage deletion must enforce the owner prefix');
assert.match(source, /admin\.storage\.from\("scanlab-assets"\)\.remove\(batch\)/, 'owned storage must be removed before auth cleanup');
assert.match(source, /admin\.auth\.admin\.signOut\(token, "global"\)/, 'all refresh-token sessions must be revoked');
assert.match(source, /admin\.auth\.admin\.deleteUser\(user\.id\)/, 'auth principal must be deleted');
const storageIndex = source.indexOf('.remove(batch)');
const revokeIndex = source.indexOf('admin.auth.admin.signOut(token, "global")');
const deleteIndex = source.indexOf('deleteUser(user.id)');
assert.ok(storageIndex >= 0 && storageIndex < revokeIndex, 'storage cleanup must precede session revocation so cleanup retries remain authorized');
assert.ok(revokeIndex < deleteIndex, 'session revocation must precede auth-principal deletion');
assert.match(source, /session_revoke_failed/, 'session revocation failure must stop destructive completion');
assert.match(source, /retryable: true/, 'pre-auth deletion failures must be explicitly retryable');
assert.match(source, /"Cache-Control": "no-store"/, 'account deletion responses must not be cached');

assert.match(client, /func deleteAccount\(\) async throws/, 'native client must expose account deletion');
assert.match(client, /guard response\.deleted/, 'client must verify server deletion success before local cleanup');
assert.match(client, /try await client\.auth\.signOut\(\)/, 'client must attempt to clear persisted auth session after deletion');
assert.match(client, /isAuthenticated = false/, 'client UI auth state must be cleared even if post-delete sign-out observes the deleted principal');
assert.match(client, /currentUserEmail = nil/, 'deleted account email must be cleared from memory');
assert.match(client, /ownerScans = \[\]/, 'deleted account scan cache must be cleared');
assert.match(client, /profile = nil/, 'deleted account profile cache must be cleared');

assert.match(live, /D2_ACCOUNT_DELETE_E2E.*!== "1"/, 'live destructive gate must require explicit opt-in');
assert.match(live, /SUPABASE_SERVICE_ROLE_KEY/, 'live E2E must use server-only admin credentials');
assert.match(live, /admin\.auth\.admin\.createUser/, 'live E2E must provision an isolated disposable account');
assert.match(live, /@example\.com/, 'live E2E must use a non-delivery reserved email domain');
assert.match(live, /nested\/orphan\.bin/, 'live E2E must exercise a nested orphan storage object');
assert.match(live, /functions\.invoke\("scanlab-delete-account"/, 'live E2E must invoke the deployed deletion function');
assert.match(live, /admin\.auth\.admin\.getUserById/, 'live E2E must verify auth-principal absence');
assert.match(live, /assertNoStoragePrefix/, 'live E2E must verify storage-prefix absence');
assert.match(live, /refreshSession\(\)/, 'live E2E must verify refresh-token invalidation');
assert.match(live, /signInWithPassword/, 'live E2E must verify deleted credentials cannot reauthenticate');
assert.match(live, /finally/, 'live E2E must contain emergency cleanup');

console.log('account-delete-contract: PASS');
