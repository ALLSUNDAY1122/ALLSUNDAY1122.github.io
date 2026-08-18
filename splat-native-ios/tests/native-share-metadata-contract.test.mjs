import assert from 'node:assert/strict';
import fs from 'node:fs';

const account = fs.readFileSync(new URL('../SplatNative/ScanLabAccountView.swift', import.meta.url), 'utf8');

assert.match(
  account,
  /ShareLink\(item: shareURL, subject: Text\(scan\.title\), message: Text\(scan\.caption\)\)/,
  'native owner share must carry the persisted title and description with the URL',
);
assert.match(account, /Label\("リンク共有", systemImage: "link"\)/);

console.log('native share metadata contract: PASS');
