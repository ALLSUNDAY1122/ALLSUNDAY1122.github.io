const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const src=fs.readFileSync('src/services/cloudUsage.ts','utf8');
const create=fs.readFileSync('app/(tabs)/create.tsx','utf8');
const records=fs.readFileSync('app/(tabs)/records.tsx','utf8');
const ai=fs.readFileSync('src/services/ai.ts','utf8');
const ocr=fs.readFileSync('src/services/geminiOcr.ts','utf8');
const config=fs.readFileSync('app.config.ts','utf8');
test('record and create screens use the same observable quota state',()=>{
 assert.match(create,/useCloudUsage\(\)/);
 assert.match(records,/useCloudUsage\(\)/);
 assert.match(src,/useSyncExternalStore\(subscribe,snapshot,snapshot\)/);
 assert.match(create,/formatCloudUsage\(cloudUsage\.usage\)/);
 assert.match(records,/formatCloudUsage\(cloudUsage\.usage\)/);
});
test('create displays plan link at the actual usage limit',()=>{
 assert.match(create,/isCloudUsageLimited\(cloudUsage\.usage\)/);
 assert.match(create,/router\.push\('\/paywall'\)/);
 assert.match(src,/usage\.used>=usage\.limit/);
});
test('successful generate response updates shared usage immediately',()=>{
 assert.match(ai,/usageLimit\?:/);
 assert.match(ai,/usageLimit: payload\.usageLimit/);
 assert.match(create,/updateCloudUsageFromResponse\(result\.usageLimit\)/);
});
test('successful multi-image OCR refreshes server-authoritative usage',()=>{
 assert.match(create,/await refreshCloudUsage\(\);/);
 assert.match(src,/getTransactionJws\(\)/);
 assert.match(src,/\/usage/);
});
test('working Build17 XHR transport and endpoint remain untouched',()=>{
 assert.match(ocr,/new XMLHttpRequest\(\)/);
 assert.match(ocr,/for\(let attempt=1;attempt<=3;attempt\+\+\)/);
 assert.match(config,/buildNumber: '(?:18|19|20)'/);
});
