import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const source = readFileSync(new URL('../supabase/functions/scanlab-delete-account/index.ts', import.meta.url), 'utf8');

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

console.log('account-delete-contract: PASS');
