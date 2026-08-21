import assert from 'node:assert/strict';
import test from 'node:test';

import worker from '../src/index.js';

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
