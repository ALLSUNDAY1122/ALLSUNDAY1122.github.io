const assert=require('node:assert/strict');
const test=require('node:test');
const fs=require('node:fs');
const source=fs.readFileSync('src/services/geminiOcr.ts','utf8');
const config=fs.readFileSync('app.config.ts','utf8');
const pkg=require('../package.json');

test('Gemini OCR recompresses all camera input as JPEG',()=>{
 assert.match(source,/ImageManipulator\.manipulateAsync/);
 assert.match(source,/SaveFormat\.JPEG/);
 assert.match(source,/mimeType: 'image\/jpeg'/);
 assert.doesNotMatch(source,/new File\(uri\)\.base64/);
});
test('every image and aggregate request have explicit caps before fetch',()=>{
 assert.match(source,/MAX_BASE64_CHARS_PER_IMAGE = 1_500_000/);
 assert.match(source,/MAX_REQUEST_BYTES = 9_000_000/);
 assert.match(source,/if \(requestBytes > MAX_REQUEST_BYTES\)/);
 assert.match(source,/if \(bodyBytes > MAX_REQUEST_BYTES\)/);
});
test('network transport error contains compressed payload size diagnostics',()=>{
 assert.match(source,/OCR_\$\{kind\} stage=\$\{stage\} images=/);
 assert.match(source,/bodyBytes=\$\{bodyBytes\} jpegBytes=/);
});
test('base64 images processed sequentially and size checked',()=>{
 assert.match(source,/for \(let index = 0; index < images\.length; index \+= 1\)/);
 assert.match(source,/data\.length <= MAX_BASE64_CHARS_PER_IMAGE/);
});
test('Build 16 and image manipulator dependency are pinned',()=>{
 assert.match(config,/buildNumber: '16'/);
 assert.ok(pkg.dependencies['expo-image-manipulator']);
});
