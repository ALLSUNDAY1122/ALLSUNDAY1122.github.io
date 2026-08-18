'use strict';
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const repoRoot = path.resolve(__dirname, '..', '..');
const partsDir = path.join(repoRoot, 'apps', 'sanitary-manager-2', 'approved-icon-v3');
const expectedParts = ['part01.b64','part02.b64','part03.b64','part04.b64','part05.b64'];
const expectedBytes = 49326;
const expectedSha256 = 'b07c6c54e4f7c690a3a1454f586972f3a28298f284a916f93ecda2976e8ac7e3';

for (const name of expectedParts) {
  const p = path.join(partsDir, name);
  if (!fs.existsSync(p)) throw new Error(`Missing approved icon transport: ${name}`);
}
const unexpected = fs.readdirSync(partsDir).filter(n => n.endsWith('.b64') && !expectedParts.includes(n));
if (unexpected.length) throw new Error(`Unexpected approved icon transport parts: ${unexpected.join(',')}`);

const encoded = expectedParts.map(n => fs.readFileSync(path.join(partsDir, n), 'utf8').replace(/\s+/g, '')).join('');
const bytes = Buffer.from(encoded, 'base64');
if (bytes.length !== expectedBytes) throw new Error(`Approved icon byte length mismatch: ${bytes.length}/${expectedBytes}`);
if (bytes.length < 12 || bytes.subarray(0,4).toString() !== 'RIFF' || bytes.subarray(8,12).toString() !== 'WEBP') {
  throw new Error('Approved icon transport is not a WebP RIFF container');
}
const riffBytes = bytes.readUInt32LE(4) + 8;
if (riffBytes !== expectedBytes) throw new Error(`WebP RIFF length mismatch: ${riffBytes}/${expectedBytes}`);
const sha = crypto.createHash('sha256').update(bytes).digest('hex');
if (sha !== expectedSha256) throw new Error(`Approved icon SHA-256 mismatch: ${sha}`);

console.log(`PASS: approved Health Manager 2 icon transport is complete (${expectedParts.length} parts, ${expectedBytes} bytes, SHA-256 ${expectedSha256}).`);
console.log('NOTE: this transport is a compression-only derivative of the user-approved 1024px artwork; release preparation must not regenerate or substitute artwork.');
