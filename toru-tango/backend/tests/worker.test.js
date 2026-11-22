import assert from 'node:assert/strict';
import test from 'node:test';

import realWorker from '../src/index.js';

// Unit tests supply a deterministic anonymous ID and an in-memory KV stand-in.
// The production Worker rejects usage without the configured storage binding.
const worker = {
  fetch(request, env) {
    const testEnv=env?.GEMINI_API_KEY && !env.USAGE_KV ? {...env,USAGE_KV:{get:async()=>null,put:async()=>{}}} : env;
    const headers=new Headers(request.headers);
    if(testEnv?.GEMINI_API_KEY && !headers.has('X-Toru-Tango-Anonymous-Id'))headers.set('X-Toru-Tango-Anonymous-Id','anon-unit-test-00001');
    return realWorker.fetch(new Request(request,{headers}),testEnv);
  }
};

const validInput = {
  text: '日本国憲法は1947年5月3日に施行され、国民主権、基本的人権の尊重、平和主義を基本原理とする。',
  count: 5,
  type: 'mix',
  difficulty: 'normal'
};

function request(body = validInput, init = {}) {
  return new Request('https://worker.example/generate', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...(init.headers || {}) },
    body: JSON.stringify(body),
    ...init
  });
}

function geminiResponse(questions) {
  return {
    candidates: [{ content: { parts: [{ text: JSON.stringify({ questions }) }] } }],
    modelVersion: 'gemini-3.5-flash-lite',
    usageMetadata: {
      promptTokenCount: 42,
      candidatesTokenCount: 21,
      totalTokenCount: 63
    }
  };
}

test('returns generated questions and Gemini metadata', async (t) => {
  const originalFetch = globalThis.fetch;
  let upstream;
  globalThis.fetch = async (url, init) => {
    upstream = { url, init };
    return Response.json(
      geminiResponse([
        {
          question: '日本国憲法が施行された日はいつですか？',
          answer: '1947年5月3日',
          type: 'qa',
          factKey: '憲法施行日',
          evidence: '1947年5月3日に施行'
        }
      ])
    );
  };
  t.after(() => {
    globalThis.fetch = originalFetch;
  });

  const response = await worker.fetch(request(), { GEMINI_API_KEY: 'test-key' });
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(body.provider, 'Google Gemini');
  assert.equal(body.model, 'gemini-3.5-flash-lite');
  assert.equal(body.questions.length, 1);
  assert.deepEqual(body.usage, { inputTokens: 42, outputTokens: 21, totalTokens: 63 });
  assert.match(upstream.url, /gemini-3\.5-flash-lite:generateContent$/);
  assert.equal(upstream.init.headers['x-goog-api-key'], 'test-key');
  const sent = JSON.parse(upstream.init.body);
  assert.equal(sent.generationConfig.responseMimeType, 'application/json');
  assert.equal(sent.generationConfig.responseSchema.properties.questions.maxItems, 5);
  assert.equal(sent.generationConfig.maxOutputTokens, 2048);
  const systemInstructions = sent.systemInstruction.parts[0].text;
  assert.match(systemInstructions, /answerの文字列をquestionへ含めない/);
  assert.match(systemInstructions, /見出し・列名・行名を教材どおりに扱い/);
  assert.match(systemInstructions, /短い教材でも確認可能な事実が一つ以上あれば/);
  assert.match(systemInstructions, /必ず5枚を返してください/);
  assert.equal(
    Object.hasOwn(sent.generationConfig.responseSchema.properties.questions.items.properties, 'evidence'),
    false
  );
});

test('allocates a larger output budget for a 20-card request', async (t) => {
  const originalFetch = globalThis.fetch;
  let upstream;
  globalThis.fetch = async (url, init) => {
    upstream = { url, init };
    return Response.json(
      geminiResponse([
        { question: '日本国憲法の施行日はいつですか？', answer: '1947年5月3日', type: 'qa', factKey: '憲法施行日' }
      ])
    );
  };
  t.after(() => {
    globalThis.fetch = originalFetch;
  });

  await worker.fetch(request({ ...validInput, count: 20 }), { GEMINI_API_KEY: 'test-key' });
  const sent = JSON.parse(upstream.init.body);
  assert.equal(sent.generationConfig.responseSchema.properties.questions.maxItems, 20);
  assert.equal(sent.generationConfig.maxOutputTokens, 7200);
  assert.match(sent.systemInstruction.parts[0].text, /必ず20枚を返してください/);
});

test('includes generation diagnostics when every generated card is rejected', async (t) => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => Response.json(geminiResponse([]));
  t.after(() => {
    globalThis.fetch = originalFetch;
  });

  const response = await worker.fetch(request(), { GEMINI_API_KEY: 'test-key' });
  const body = await response.json();
  assert.equal(response.status, 422);
  assert.deepEqual(body.quality, {
    requestedCount: 5,
    rawCount: 0,
    duplicateCount: 0,
    rejectedCount: 0
  });
});

test('rejects missing Gemini secret without calling upstream', async () => {
  const response = await worker.fetch(request(), {});
  assert.equal(response.status, 503);
});

test('enforces the monthly anonymous AI limit with KV', async (t) => {
  const originalFetch = globalThis.fetch;
  const values = new Map();
  globalThis.fetch = async () => Response.json(geminiResponse([
    { question: '日本国憲法が施行された日はいつですか？', answer: '1947年5月3日', type: 'qa', factKey: '施行日' }
  ]));
  t.after(() => {
    globalThis.fetch = originalFetch;
  });
  const kv = {
    get: async (key) => values.get(key) || null,
    put: async (key, value) => values.set(key, value)
  };
  const init = { GEMINI_API_KEY: 'test-key', USAGE_KV: kv };
  const headers = { 'X-Toru-Tango-Anonymous-Id': 'anon-test-user' };

  for (let index = 0; index < 5; index += 1) {
    const response = await worker.fetch(request(validInput, { headers }), init);
    assert.equal(response.status, 200);
  }
  const limited = await worker.fetch(request(validInput, { headers }), init);
  const body = await limited.json();
  assert.equal(limited.status, 429);
  assert.equal(body.code, 'AI_MONTHLY_LIMIT');
  assert.equal(body.usage.used, 5);
  assert.equal(body.usage.limit, 5);
});

test('rejects short text and disallowed browser origins', async () => {
  const short = await worker.fetch(request({ ...validInput, text: '短い文章' }), {
    GEMINI_API_KEY: 'test-key'
  });
  assert.equal(short.status, 400);

  const forbidden = await worker.fetch(
    request(validInput, { headers: { Origin: 'https://evil.example' } }),
    { GEMINI_API_KEY: 'test-key' }
  );
  assert.equal(forbidden.status, 403);
});

test('extracts text from Gemini OCR image input', async (t) => {
  const originalFetch = globalThis.fetch;
  let upstream;
  globalThis.fetch = async (url, init) => {
    upstream = { url, init };
    return Response.json({
      candidates: [{ content: { parts: [{ text: '日本国憲法\n1947年5月3日施行' }] } }],
      modelVersion: 'gemini-3.5-flash-lite'
    });
  };
  t.after(() => {
    globalThis.fetch = originalFetch;
  });

  const response = await worker.fetch(
    new Request('https://worker.example/ocr', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ images: [{ mimeType: 'image/jpeg', data: 'aGVsbG8=' }] })
    }),
    { GEMINI_API_KEY: 'test-key' }
  );
  const body = await response.json();
  assert.equal(response.status, 200);
  assert.match(body.text, /日本国憲法/);
  const sent = JSON.parse(upstream.init.body);
  assert.equal(sent.contents[0].parts[1].inlineData.mimeType, 'image/jpeg');
});

test('rejects unsafe Gemini OCR image input', async () => {
  const response = await worker.fetch(
    new Request('https://worker.example/ocr', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ images: [{ mimeType: 'text/plain', data: 'not-image' }] })
    }),
    { GEMINI_API_KEY: 'test-key' }
  );
  assert.equal(response.status, 400);
});

test('handles Gemini errors and invalid structured output', async (t) => {
  const originalFetch = globalThis.fetch;
  t.after(() => {
    globalThis.fetch = originalFetch;
  });

  globalThis.fetch = async () => Response.json({ error: { message: 'quota' } }, { status: 429 });
  const upstreamError = await worker.fetch(request(), { GEMINI_API_KEY: 'test-key' });
  assert.equal(upstreamError.status, 502);
  const diagnostic = await upstreamError.json();
  assert.equal(diagnostic.code, 'GEMINI_UPSTREAM_HTTP_429');
  assert.equal(diagnostic.upstreamStatus, 429);
  assert.equal(diagnostic.upstreamCode, 'UNKNOWN');

  globalThis.fetch = async () =>
    Response.json({ candidates: [{ content: { parts: [{ text: 'not-json' }] } }] });
  const invalidJson = await worker.fetch(request(), { GEMINI_API_KEY: 'test-key' });
  assert.equal(invalidJson.status, 502);
});

test('removes duplicate and answer-leaking questions', async (t) => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () =>
    Response.json(
      geminiResponse([
        {
          question: '日本国憲法が施行された日はいつですか？',
          answer: '1947年5月3日',
          type: 'qa',
          factKey: '憲法施行日',
          evidence: '1947年5月3日に施行'
        },
        {
          question: '憲法の施行日はいつですか？',
          answer: '1947年5月3日',
          type: 'qa',
          factKey: '憲法施行日',
          evidence: '1947年5月3日に施行'
        },
        {
          question: '1947年5月3日は何の日ですか？',
          answer: '1947年5月3日',
          type: 'qa',
          factKey: '答え漏れ',
          evidence: '1947年5月3日に施行'
        }
      ])
    );
  t.after(() => {
    globalThis.fetch = originalFetch;
  });

  const response = await worker.fetch(request(), { GEMINI_API_KEY: 'test-key' });
  const body = await response.json();
  assert.equal(response.status, 200);
  assert.equal(body.questions.length, 1);
  assert.equal(body.quality.duplicateCount, 1);
  assert.equal(body.quality.rejectedCount, 1);
});

test('CORS advertises StoreKit transaction header', async ()=>{
  const r=await worker.fetch(new Request('https://worker.example/generate',{method:'OPTIONS'}),{});
  assert.equal(r.status,204);
  assert.match(r.headers.get('Access-Control-Allow-Headers'),/X-Toru-Tango-Transaction-JWS/);
});
test('invalid subscription JWS returns 401 and never calls Gemini',async()=>{
  const r=await worker.fetch(request(validInput,{headers:{
    'X-Toru-Tango-Anonymous-Id':'anonymous-signed-test',
    'X-Toru-Tango-Transaction-JWS':'a.b.c'
  }}),{GEMINI_API_KEY:'test-key',USAGE_KV:{get:async()=>null,put:async()=>{throw Error('must not store');}}});
  assert.equal(r.status,401);
  assert.equal((await r.json()).code,'INVALID_TRANSACTION_JWS');
});
test('unauthenticated entitlement reports free tier without consuming usage',async()=>{
  const r=await worker.fetch(new Request('https://worker.example/entitlement',{method:'POST',body:'{}'}),{});
  assert.deepEqual(await r.json(),{active:false,tier:'free',limit:5});
});
test('signed-transaction endpoint rejects untrusted JWS',async()=>{
  const r=await worker.fetch(new Request('https://worker.example/entitlement',{
    method:'POST',headers:{'X-Toru-Tango-Transaction-JWS':'a.b.c'},body:'{}'
  }),{});
  assert.equal(r.status,401);
});
test('monthly limit responses include free tier and do not advertise Pro', async t=>{
  const before=globalThis.fetch;
  globalThis.fetch=async()=>Response.json(geminiResponse([{question:'憲法の施行日はいつ？',answer:'1947年5月3日',factKey:'start'}]));
  t.after(()=>{globalThis.fetch=before;});
  const values=new Map([['ai-usage:'+new Date().toISOString().slice(0,7)+':anon-test-user','5']]);
  const r=await worker.fetch(request(validInput,{headers:{'X-Toru-Tango-Anonymous-Id':'anon-test-user'}}),{
    GEMINI_API_KEY:'key',USAGE_KV:{get:async k=>values.get(k),put:async()=>{}}
  });
  const payload=await r.json();
  assert.equal(r.status,429);
  assert.deepEqual(payload.usage,{used:5,limit:5,tier:'free'});
  assert.equal(payload.code,'AI_MONTHLY_LIMIT');
  assert.doesNotMatch(payload.error,/Proプラン/);
});

test('reports Gemini upstream 401, 403, 404, 429 without exposing provider message or credentials', async (t) => {
  const originalFetch = globalThis.fetch;
  t.after(() => { globalThis.fetch = originalFetch; });
  for (const status of [401, 403, 404, 429]) {
    globalThis.fetch = async () => Response.json({
      error: { status: status === 429 ? 'RESOURCE_EXHAUSTED' : 'PERMISSION_DENIED',
        message: 'secret key=AIzaVerySensitiveCredentialDataMustNotLeak' }
    }, { status });
    const response = await worker.fetch(request(validInput), { GEMINI_API_KEY: 'test-key' });
    const payload = await response.json();
    assert.equal(response.status, 502);
    assert.equal(payload.code, 'GEMINI_UPSTREAM_HTTP_' + status);
    assert.equal(payload.upstreamStatus, status);
    assert.doesNotMatch(JSON.stringify(payload), /AIza|VerySensitiveCredential|key=/);
  }
});

test('usage counter is not consumed when Gemini rejects the request', async (t) => {
  const previous = globalThis.fetch;
  t.after(() => { globalThis.fetch = previous; });
  const state = new Map();
  const env = { GEMINI_API_KEY:'test-key', USAGE_KV:{
    get: async key => state.get(key) ?? null,
    put: async (key,value) => { state.set(key,value); }
  }};
  globalThis.fetch = async () => Response.json({ error:{status:'RESOURCE_EXHAUSTED'} },{status:429});
  const req = () => request(validInput,{headers:{'X-Toru-Tango-Anonymous-Id':'quota-failure-00001'}});
  for(let i=0;i<6;i++){
    const res=await worker.fetch(req(),env);
    assert.equal(res.status,502);
  }
  assert.equal(state.size,0);
  const u=await worker.fetch(new Request('https://worker.example/usage',{
    method:'POST',headers:{'X-Toru-Tango-Anonymous-Id':'quota-failure-00001'}
  }),env);
  assert.deepEqual(await u.json(),{used:0,limit:5,tier:'free'});
});
test('only successful generation counts toward usage and /usage reports it',async(t)=>{
  const previous=globalThis.fetch;
  t.after(()=>{globalThis.fetch=previous;});
  const state=new Map();
  const env={GEMINI_API_KEY:'test-key',USAGE_KV:{get:async k=>state.get(k)??null,
    put:async(k,v)=>state.set(k,v)}};
  globalThis.fetch=async()=>Response.json({candidates:[{content:{parts:[{text:JSON.stringify({questions:[{question:'日本の首都はどこですか？',answer:'東京',type:'qa',factKey:'capital'}]})}]}}]});
  const req=()=>request(validInput,{headers:{'X-Toru-Tango-Anonymous-Id':'quota-success-00001'}});
  const res=await worker.fetch(req(),env);
  assert.equal(res.status,200);
  assert.equal((await res.json()).usageLimit.used,1);
  const u=await worker.fetch(new Request('https://worker.example/usage',{method:'POST',headers:{'X-Toru-Tango-Anonymous-Id':'quota-success-00001'}}),env);
  assert.equal((await u.json()).used,1);
});
