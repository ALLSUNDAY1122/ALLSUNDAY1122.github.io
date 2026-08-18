#!/usr/bin/env node
/**
 * Optional live smoke for D2-009.
 *
 * Usage:
 *   LIVE_VIEWER_URL=https://example/viewer/?id=<published-id> node tests/live-viewer-smoke.mjs
 *
 * The test is intentionally opt-in because a real published scan is required.
 * It never creates, mutates, or deletes publish data.
 */
const target = process.env.LIVE_VIEWER_URL;
if (!target) {
  console.log('SKIP: LIVE_VIEWER_URL is not set; live smoke requires a real published viewer URL');
  process.exit(0);
}

const url = new URL(target);
if (!/^https?:$/.test(url.protocol)) throw new Error('LIVE_VIEWER_URL must use http or https');

const response = await fetch(url, { redirect: 'follow' });
const contentType = response.headers.get('content-type') || '';
const body = await response.text();

if (!response.ok) throw new Error(`viewer HTTP ${response.status}`);
if (!contentType.toLowerCase().includes('text/html')) {
  throw new Error(`viewer content-type is not HTML: ${contentType}`);
}

const required = [
  '<meta property="og:title"',
  '<meta property="og:description"',
  '<meta property="og:image"',
  '<meta name="twitter:card"',
  'id="viewer"',
  'id="title"',
  'id="caption"',
];
for (const marker of required) {
  if (!body.includes(marker)) throw new Error(`viewer HTML missing ${marker}`);
}

const token = url.hash;
if (token && !token.startsWith('#token=')) {
  throw new Error('unlisted viewer URLs must use #token= fragment form');
}

console.log(`PASS: live viewer ${response.status}, HTML metadata/viewer contract present`);
