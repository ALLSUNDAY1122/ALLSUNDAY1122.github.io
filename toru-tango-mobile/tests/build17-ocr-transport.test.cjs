const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const ocr=fs.readFileSync('src/services/geminiOcr.ts','utf8');
const worker=fs.readFileSync('../toru-tango/backend/src/index.js','utf8');
test('native XHR transport, retries and one-photo requests',()=>{
 assert.match(ocr,/new XMLHttpRequest\(\)/);
 assert.match(ocr,/for\(let attempt=1;attempt<=3;attempt\+\+\)/);
 assert.match(ocr,/await sleep\(500\*2\*\*\(attempt-1\)\)/);
 assert.match(ocr,/images:\[jpeg\]/);
 assert.match(ocr,/results\.join/);
 assert.match(ocr,/edge: 1280, quality: 0\.6/);
});
test('usage is only committed after successful output validation',()=>{
 const firstWrite=worker.indexOf('commitSuccessfulUsage(env,usage)',worker.indexOf("if (url.pathname === '/ocr')"));
 assert.ok(firstWrite>worker.indexOf('if (!text) return json',worker.indexOf("if (url.pathname === '/ocr')")));
 assert.match(worker,/url\.pathname === '\/usage'/);
});
