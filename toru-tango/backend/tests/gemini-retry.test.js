import assert from 'node:assert/strict';
import test from 'node:test';
import { generateWithRetry } from '../src/gemini-retry.js';
import worker from '../src/index.js';

const input={text:'日本の首都は東京都です。日本国憲法は1947年5月3日に施行されました。',count:1,type:'qa',difficulty:'normal'};
const validGenerate=()=>Response.json({modelVersion:'gemini-3.5-flash-lite',candidates:[{content:{parts:[{text:JSON.stringify({questions:[{question:'日本の首都はどこですか？',answer:'東京都',type:'qa',factKey:'capital'}]})}]}}]});
const validOcr=()=>Response.json({candidates:[{content:{parts:[{text:'写真の文字を認識しました'}]}}]});
const usageEnv=()=>{
  const map=new Map();let writes=0;
  return {map,get writes(){return writes;},env:{GEMINI_API_KEY:'test-only',USAGE_KV:{
    get:async k=>map.get(k)??null,
    put:async(k,v)=>{writes++;map.set(k,v);}
  }}};
};
function req(path,body){return new Request('https://example.invalid'+path,{
  method:'POST',headers:{'Content-Type':'application/json','X-Toru-Tango-Anonymous-Id':'retry-test-user-0001'},
  body:JSON.stringify(body)
});}

test('all retryable HTTP statuses use at most three upstream requests and jittered delays',async()=>{
  for(const status of [429,500,502,503,504]){
    let requests=0;const delays=[];
    const result=await generateWithRetry({url:'https://example.invalid',headers:{},body:'{}',operation:'generate',
      fetchFn:async()=>{requests++;return requests===3?Response.json({ok:true}):Response.json({error:{status:'UNAVAILABLE'}},{status});},
      sleepFn:async ms=>delays.push(ms),randomFn:()=>0.5});
    assert.equal(result.response.status,200);
    assert.equal(result.attempts,3);assert.equal(requests,3);
    assert.deepEqual(delays,[800,2000]);
  }
});

test('nonretryable statuses return without retry',async()=>{
  for(const status of [400,401,403,404,422]){
    let calls=0;
    const r=await generateWithRetry({url:'https://example.invalid',headers:{},body:'{}',operation:'ocr',
      fetchFn:async()=>{calls++;return Response.json({error:'bad'}, {status});},
      sleepFn:async()=>{throw Error('unexpected wait');}});
    assert.equal(r.response.status,status);assert.equal(calls,1);
  }
});

test('retryable errors exhausted after exactly three calls and two bounded sleeps',async()=>{
  let calls=0;const delays=[];
  const r=await generateWithRetry({url:'https://example.invalid',headers:{},body:'{}',operation:'generate',
    fetchFn:async()=>{calls++;return Response.json({error:{status:'UNAVAILABLE'}},{status:503});},
    sleepFn:async ms=>delays.push(ms),randomFn:()=>1});
  assert.equal(calls,3);assert.equal(r.response.status,503);
  assert.deepEqual(delays,[960,2400]);
});

test('/generate retries 503 then succeeds and writes quota only once',async(t)=>{
  const original=globalThis.fetch;t.after(()=>{globalThis.fetch=original;});
  let upstream=0;
  globalThis.fetch=async()=>{upstream++;return upstream===1?Response.json({error:{status:'UNAVAILABLE'}},{status:503}):validGenerate();};
  const kv=usageEnv();
  const response=await worker.fetch(req('/generate',input),kv.env);
  const payload=await response.json();
  assert.equal(response.status,200);assert.equal(upstream,2);assert.equal(kv.writes,1);
  assert.equal(payload.usageLimit.used,1);assert.equal(payload.questions.length,1);
});

test('/ocr retries 502 then succeeds and writes quota only once',async(t)=>{
  const original=globalThis.fetch;t.after(()=>{globalThis.fetch=original;});
  let upstream=0;
  globalThis.fetch=async()=>{upstream++;return upstream===1?Response.json({error:{status:'BAD_GATEWAY'}},{status:502}):validOcr();};
  const kv=usageEnv();
  const response=await worker.fetch(req('/ocr',{images:[{mimeType:'image/jpeg',data:'aGVsbG8='}]}),kv.env);
  const payload=await response.json();
  assert.equal(response.status,200);assert.equal(upstream,2);assert.equal(kv.writes,1);
  assert.match(payload.text,/写真/);
});

test('failed generation and OCR exhaust retries and do not charge KV',async(t)=>{
  const original=globalThis.fetch;t.after(()=>{globalThis.fetch=original;});
  let upstream=0;
  globalThis.fetch=async()=>{upstream++;return Response.json({error:{status:'UNAVAILABLE'}},{status:503});};
  const kv=usageEnv();
  for(const [path,body] of [['/generate',input],['/ocr',{images:[{mimeType:'image/jpeg',data:'aGVsbG8='}]}]]){
    const response=await worker.fetch(req(path,body),kv.env);
    assert.equal(response.status,502);assert.equal((await response.json()).code,'GEMINI_UPSTREAM_HTTP_503');
  }
  assert.equal(upstream,6);assert.equal(kv.writes,0);
});
