const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const source=fs.readFileSync('src/services/geminiOcr.ts','utf8');
const config=fs.readFileSync('app.config.ts','utf8');
const pkg=require('../package.json');
test('OCR uses JPEG conversion and bounded input',()=>{
 assert.match(source,/SaveFormat.JPEG/);
 assert.match(source,/edge: 1280, quality: 0.6/);
 assert.match(source,/MAX_BASE64_CHARS = 1_300_000/);
});
test('native networking uses XMLHttpRequest, not fetch',()=>{
 assert.match(source,/new XMLHttpRequest/);
 assert.doesNotMatch(source,/await fetch\(/);
});
test('one request contains exactly one compressed photo',()=>{
 assert.match(source,/images:\[jpeg\]/);
});
test('Build 17 has image manipulator',()=>{
 assert.match(config,/buildNumber: '17'/);
 assert.ok(pkg.dependencies['expo-image-manipulator']);
});