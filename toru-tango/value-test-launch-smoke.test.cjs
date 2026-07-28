const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

const launcher = fs.readFileSync(path.join(__dirname, 'value-test-launch.html'), 'utf8');

assert.match(launcher, /fetch\(['"]value-test\.html['"]/, 'launcher must load the prototype from the same pinned revision');
assert.match(launcher, /source\.replace\(oldGenerator, ['"]generator-v2\.js['"]\)/, 'launcher must switch to the validated generator in the same revision');
assert.match(launcher, /document\.write\(prepared\)/, 'launcher must render the prepared prototype');
assert.doesNotMatch(launcher, /OPENAI_API_KEY|workers\.dev|EXPO_PUBLIC_AI_API_URL/, 'launcher must not require backend configuration');

const scripts = [...launcher.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi)].map((match) => match[1]);
assert.equal(scripts.length, 1, 'launcher must have exactly one inline script');
assert.doesNotThrow(() => new Function(scripts[0]), 'launcher JavaScript must compile');

console.log('Safari value-test launcher smoke checks passed');
