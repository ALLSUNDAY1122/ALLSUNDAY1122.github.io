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
  const systemInstructions = sent.systemInstruction.parts[0].text;
  assert.match(systemInstructions, /answerの文字列をquestionへ含めない/);
  assert.match(systemInstructions, /見出し・列名・行名を教材どおりに扱い/);
  assert.match(systemInstructions, /短い教材でも確認可能な事実が一つ以上あれば/);
});

test('rejects missing Gemini secret without calling upstream', async () => {
  const response = await worker.fetch(request(), {});
  assert.equal(response.status, 503);
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
