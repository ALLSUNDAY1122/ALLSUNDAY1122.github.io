const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

const launcher = fs.readFileSync(path.join(__dirname, 'value-test-launch.html'), 'utf8');
const ocrEnhance = fs.readFileSync(path.join(__dirname, 'ocr-enhance-v2.js'), 'utf8');

assert.match(launcher, /fetch\(['"]value-test\.html['"]/, 'launcher must load the prototype from the same pinned revision');
assert.match(launcher, /source\.replace\(oldGenerator, ['"]generator-v2\.js['"]\)/, 'launcher must switch to the validated generator in the same revision');
assert.match(launcher, /ocr-enhance-v2\.js/, 'launcher must inject the enhanced OCR module');
assert.match(launcher, /document\.write\(prepared\)/, 'launcher must render the prepared prototype');
assert.doesNotMatch(launcher, /OPENAI_API_KEY|workers\.dev|EXPO_PUBLIC_AI_API_URL/, 'launcher must not require backend configuration');

const scripts = [...launcher.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi)].map((match) => match[1]);
assert.equal(scripts.length, 1, 'launcher must have exactly one inline script');
assert.doesNotThrow(() => new Function(scripts[0]), 'launcher JavaScript must compile');
assert.doesNotThrow(() => new Function(ocrEnhance), 'enhanced OCR JavaScript must compile');
assert.match(ocrEnhance, /createWorker\(['"]jpn\+eng['"]/, 'enhanced OCR must use Japanese and English recognition');
assert.match(ocrEnhance, /otsuThreshold/, 'enhanced OCR must include automatic thresholding');
assert.match(ocrEnhance, /passPlan/, 'enhanced OCR must compare multiple recognition passes');
assert.match(ocrEnhance, /confidence/, 'enhanced OCR must expose a recognition confidence indicator');
assert.match(ocrEnhance, /cloneNode\(true\)/, 'enhanced OCR must replace the original OCR action instead of running twice');
assert.doesNotMatch(ocrEnhance, /OPENAI_API_KEY|workers\.dev|EXPO_PUBLIC_AI_API_URL|fetch\([^)]*generate/, 'enhanced OCR must not require an AI backend');

console.log('Safari value-test launcher and enhanced OCR smoke checks passed');
