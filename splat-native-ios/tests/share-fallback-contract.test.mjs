import assert from 'node:assert/strict';
import fs from 'node:fs';

const viewer = fs.readFileSync(new URL('../viewer/viewer.js', import.meta.url), 'utf8');

assert.match(viewer, /async function copyShareURL\(\)/);
assert.match(viewer, /navigator\.clipboard\?\.writeText/);
assert.match(viewer, /document\.createElement\('textarea'\)/);
assert.match(viewer, /document\.execCommand\('copy'\)/);
assert.match(viewer, /textarea\.remove\(\)/);
assert.match(viewer, /function showCopiedFeedback\(\)/);
assert.match(viewer, /if \(navigator\.share\)/);
assert.match(viewer, /if \(error\?\.name === 'AbortError'\) return/);
assert.match(viewer, /if \(await copyShareURL\(\)\)/);
assert.match(viewer, /window\.prompt\('共有URLをコピーしてください', shareURL\)/);
assert.match(viewer, /const shareData = \{ title: document\.title, text: caption\.textContent \|\| undefined, url: shareURL \}/);
assert.doesNotMatch(viewer, /window\.prompt\([^\n]*location\.href/);

const nativeShareIndex = viewer.indexOf('if (navigator.share)');
const copyIndex = viewer.indexOf('if (await copyShareURL())');
const promptIndex = viewer.indexOf("window.prompt('共有URLをコピーしてください', shareURL)");
assert.ok(nativeShareIndex >= 0 && nativeShareIndex < copyIndex && copyIndex < promptIndex, 'share fallback order must be native share -> copy -> manual prompt');

console.log('share fallback contract: PASS');
