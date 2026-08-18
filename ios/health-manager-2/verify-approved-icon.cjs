'use strict';
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const repoRoot = path.resolve(__dirname, '..', '..');
const partsDir = path.join(repoRoot, 'apps', 'sanitary-manager-2', 'approved-icon-v4');
const expectedParts = ['part01.b64','part02.b64','part03.b64','part04.b64'];
const expectedBytes = 28904;
const expectedSha256 = '4cefe840198dde91fddb6c5fe0fdece7d41a8bebfed415eb034752491cd7977c';

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

console.log(`PASS: approved Health Manager 2 icon transport v4 is complete (${expectedParts.length} parts, ${expectedBytes} bytes, SHA-256 ${expectedSha256}).`);
console.log('NOTE: v4 is a compression-only derivative of the exact user-approved Drive PNG; release preparation must never redraw, relabel, or substitute the artwork.');
