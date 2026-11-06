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
assert.match(ocrEnhance, /stretchedThreshold/, 'binary OCR threshold must be aligned with contrast stretching');
assert.match(ocrEnhance, /passPlan/, 'enhanced OCR must compare multiple recognition passes');
assert.match(ocrEnhance, /confidence/, 'enhanced OCR must expose a recognition confidence indicator');
assert.match(ocrEnhance, /補正なし（比較基準）/, 'enhanced OCR must include an unprocessed baseline');
assert.match(ocrEnhance, /ocrComparison/, 'enhanced OCR must render side-by-side result comparison');
assert.match(ocrEnhance, /renderComparison\(candidates, best\)/, 'enhanced OCR must show every recognition candidate');
assert.match(ocrEnhance, /この結果を本文に使う/, 'enhanced OCR must allow the user to choose a result');
assert.match(ocrEnhance, /cloneNode\(true\)/, 'enhanced OCR must replace the original OCR action instead of running twice');
assert.doesNotMatch(ocrEnhance, /OPENAI_API_KEY|workers\.dev|EXPO_PUBLIC_AI_API_URL|fetch\([^)]*generate/, 'enhanced OCR must not require an AI backend');

const scoreFunctionMatch = ocrEnhance.match(
  /function scoreText\(text, confidence\) \{([\s\S]*?)\r?\n  \}\r?\n\r?\n  function passPlan/
);
assert.ok(scoreFunctionMatch, 'OCR candidate scoring function must be extractable for regression testing');
const scoreText = new Function('text', 'confidence', scoreFunctionMatch[1]);
const fragmentedBaseline = [
  '日本国憲)',
  'F5月3',
  '1947 =',
  'に施行された。',
  '三大原則は次の三つ。',
  '1. 臣',
  '2. 基本的人権の豊重',
  '3. 平和主義',
  '民主権'
].join('\n');
const coherentEnhanced = [
  '日本国憲法',
  '1947年5月3日に施行された。',
  '三大原則は次の三つ。',
  '1. 国民主権',
  '2. 基本的人権の豊重',
  '3. 平和王和'
].join('\n');
assert.ok(
  scoreText(coherentEnhanced, 86) > scoreText(fragmentedBaseline, 84),
  'coherent enhanced OCR must outrank a fragmented baseline'
);

console.log('Safari value-test launcher and enhanced OCR smoke checks passed');
