import { readFileSync } from 'node:fs';
const host = 'https://toru-tango-ai.kohei3615.workers.dev';
const payload = readFileSync('photo-smoke/request.json');
const size = payload.byteLength;
if (size > 9_000_000) throw Error('Request too large');
const response = await fetch(host + '/ocr', {
  method:'POST', signal:AbortSignal.timeout(60000),
  headers:{
    'Content-Type':'application/json',
    'X-Toru-Tango-Anonymous-Id': 'photo-16-' + process.env.GITHUB_RUN_ID
  },
  body:payload
});
const result = await response.json();
const chars = typeof result.text==='string' ? result.text.trim().length : 0;
const summary = {status:response.status,chars,requestBytes:size,
  code:result.code??null,upstreamCode:result.upstreamCode??null};
console.log(JSON.stringify(summary));
if(response.status!==200 || chars<3)throw Error('PHOTO_OCR_LIVE_200_REQUIRED');
console.log('PHOTO_4032x3024_RESIZED_JPEG_OCR_200_PASS');
