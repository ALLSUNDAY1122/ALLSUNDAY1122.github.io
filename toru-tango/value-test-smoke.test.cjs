const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

const htmlPath = path.join(__dirname, 'value-test.html');
const html = fs.readFileSync(htmlPath, 'utf8');

const requiredIds = [
  'createPanel','cardsPanel','studyPanel','photoInput','photoPreview','rotationControls',
  'rotateLeft','rotateRight','runOcr','ocrStatus','sourceText','sampleText','clearText',
  'questionType','difficulty','cardLimit','generateCards','generateStatus','generatedLabel',
  'generatedCards','saveGenerated','manualFront','manualBack','saveManual','cardCount',
  'cardList','clearAll','startStudy','shuffleStudy','progressBar','studyEmpty','studyArea',
  'flashcard','flashSide','flashText','flipHint','studyCounter','speakFront','speakBack',
  'gradeButtons','again','known','feedbackStatus'
];

for (const id of requiredIds) {
  assert.match(html, new RegExp(`id=["']${id}["']`), `missing #${id}`);
}

assert.match(html, /capture="environment"/, 'camera capture hint is required');
assert.match(html, /tesseract\.js@5\.1\.1/, 'Tesseract version must be pinned');
assert.match(html, /generator-v2\.js/, 'local question generator must be loaded');
assert.match(html, /localStorage/, 'cards must persist locally');
assert.match(html, /speechSynthesis/, 'speech playback must be available');
assert.doesNotMatch(html, /OPENAI_API_KEY|workers\.dev|Cloudflare Worker|EXPO_PUBLIC_AI_API_URL/, 'value test must not require backend configuration');
assert.doesNotMatch(html, /\bfetch\s*\(/, 'value test application code must not call a backend');

const idSet = new Set([...html.matchAll(/\bid=["']([^"']+)["']/g)].map((match) => match[1]));
const selectorIds = [...html.matchAll(/\$\(['"]#([^'"]+)['"]\)/g)].map((match) => match[1]);
for (const id of selectorIds) {
  assert.ok(idSet.has(id), `script references missing #${id}`);
}

const inlineScripts = [...html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi)].map((match) => match[1]);
assert.equal(inlineScripts.length, 1, 'exactly one inline application script is expected');
assert.doesNotThrow(() => new Function(inlineScripts[0]), 'inline JavaScript must compile');

for (const phrase of ['写真から文字を読む','カード候補を作る','単語帳へ保存','学習を開始','継続して使いたい']) {
  assert.ok(html.includes(phrase), `missing core flow phrase: ${phrase}`);
}

console.log('Safari value-test smoke checks passed');
