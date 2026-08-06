const ALLOWED_ORIGIN = 'https://allsunday1122.github.io';
const MAX_BODY_BYTES = 100_000;
const OCR_MAX_BODY_BYTES = 12_000_000;
const MAX_OCR_IMAGES = 10;
const MAX_OCR_IMAGE_BYTES = 5_000_000;
const DEFAULT_MODEL = 'gemini-3.5-flash-lite';
const FREE_MONTHLY_AI_LIMIT = 5;
const GEMINI_API_BASE = 'https://generativelanguage.googleapis.com/v1beta/models';

function cors(origin) {
  return {
    'Access-Control-Allow-Origin': origin || ALLOWED_ORIGIN,
    'Access-Control-Allow-Methods': 'POST,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, X-Toru-Tango-Anonymous-Id',
    Vary: 'Origin',
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store'
  };
}

function json(data, status = 200, origin = ALLOWED_ORIGIN) {
  return new Response(JSON.stringify(data), { status, headers: cors(origin) });
}

function cleanText(value, max) {
  return String(value ?? '')
    .replace(/\u0000/g, '')
    .trim()
    .slice(0, max);
}

function normalizeKey(value) {
  return cleanText(value, 240)
    .toLocaleLowerCase('ja-JP')
    .replace(/[\s「」『』（）()、，。・：:！？!?＿＿＿_]/g, '');
}

function extractOutputText(payload) {
  const parts = payload?.candidates?.[0]?.content?.parts;
  if (!Array.isArray(parts)) return '';
  return parts
    .map((part) => (typeof part?.text === 'string' ? part.text : ''))
    .join('')
    .trim();
}

function deduplicateQuestions(items, count) {
  const sourceItems = Array.isArray(items) ? items : [];
  const factKeys = new Set();
  const questionKeys = new Set();
  const pairs = new Set();
  const questions = [];
  let duplicateCount = 0;
  let rejectedCount = 0;

  for (const item of sourceItems) {
    const question = cleanText(item?.question, 180);
    const answer = cleanText(item?.answer, 120);
    const type = item?.type === 'cloze' ? 'cloze' : 'qa';
    const factKey = normalizeKey(item?.factKey || `${answer}-${question}`);
    const questionKey = normalizeKey(question);
    const answerKey = normalizeKey(answer);
    const pairKey = `${questionKey}|${answerKey}`;

    if (!question || !answer || !factKey || !questionKey || !answerKey) {
      rejectedCount += 1;
      continue;
    }
    if (question.length < 5 || (questionKey.includes(answerKey) && type === 'qa')) {
      rejectedCount += 1;
      continue;
    }
    if (factKeys.has(factKey) || questionKeys.has(questionKey) || pairs.has(pairKey)) {
      duplicateCount += 1;
      continue;
    }

    factKeys.add(factKey);
    questionKeys.add(questionKey);
    pairs.add(pairKey);
    questions.push({ question, answer, type });
    if (questions.length >= count) break;
  }

  return {
    questions,
    rawCount: sourceItems.length,
    duplicateCount,
    rejectedCount
  };
}

function normalizeUsage(rawUsage) {
  const inputTokens = Number(rawUsage?.promptTokenCount) || 0;
  const outputTokens = Number(rawUsage?.candidatesTokenCount) || 0;
  const totalTokens = Number(rawUsage?.totalTokenCount) || inputTokens + outputTokens;
  return { inputTokens, outputTokens, totalTokens };
}

function anonymousIdFrom(request) {
  const value = request.headers.get('X-Toru-Tango-Anonymous-Id') || '';
  return /^[a-zA-Z0-9._:-]{8,128}$/.test(value) ? value : '';
}

function usageKey(anonymousId) {
  const month = new Date().toISOString().slice(0, 7);
  return `ai-usage:${month}:${anonymousId}`;
}

async function reserveMonthlyUsage(env, anonymousId) {
  // KV未設定の開発環境や既存アプリは、課金基盤を有効化するまで従来どおり動かす。
  if (!anonymousId || !env.USAGE_KV) return { allowed: true, tracked: false };
  const key = usageKey(anonymousId);
  const used = Number(await env.USAGE_KV.get(key)) || 0;
  if (used >= FREE_MONTHLY_AI_LIMIT) {
    return { allowed: false, tracked: true, used, limit: FREE_MONTHLY_AI_LIMIT };
  }
  const next = used + 1;
  await env.USAGE_KV.put(key, String(next), { expirationTtl: 60 * 60 * 24 * 45 });
  return { allowed: true, tracked: true, used: next, limit: FREE_MONTHLY_AI_LIMIT };
}

function imageParts(images) {
  if (!Array.isArray(images) || !images.length || images.length > MAX_OCR_IMAGES) {
    return null;
  }
  const parts = [];
  for (const image of images) {
    const data = cleanText(image?.data, MAX_OCR_IMAGE_BYTES * 2);
    const mimeType = cleanText(image?.mimeType, 80);
    if (!/^image\/(jpeg|png|webp|heic)$/i.test(mimeType) || !/^[a-z0-9+/]+={0,2}$/i.test(data)) {
      return null;
    }
    if (Math.floor((data.length * 3) / 4) > MAX_OCR_IMAGE_BYTES) return null;
    parts.push({ inlineData: { mimeType, data } });
  }
  return parts;
}

function questionSchema(count) {
  return {
    type: 'object',
    properties: {
      questions: {
        type: 'array',
        maxItems: count,
        items: {
          type: 'object',
          properties: {
            question: { type: 'string' },
            answer: { type: 'string' },
            type: { type: 'string', enum: ['qa', 'cloze'] },
            factKey: { type: 'string' }
          },
          required: ['question', 'answer', 'type', 'factKey']
        }
      }
    },
    required: ['questions']
  };
}

export default {
  async fetch(request, env) {
    const requestOrigin = request.headers.get('Origin');
    if (requestOrigin && requestOrigin !== ALLOWED_ORIGIN) {
      return json({ error: '許可されていないアクセス元です。' }, 403, ALLOWED_ORIGIN);
    }
    const origin = requestOrigin || ALLOWED_ORIGIN;

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: cors(origin) });
    }
    if (request.method !== 'POST') {
      return json({ error: 'POSTのみ対応しています。' }, 405, origin);
    }

    const url = new URL(request.url);
    if (url.pathname !== '/generate' && url.pathname !== '/ocr') {
      return json({ error: 'Not found' }, 404, origin);
    }
    if (!env.GEMINI_API_KEY) {
      return json({ error: 'サーバー設定が完了していません。' }, 503, origin);
    }

    const contentLength = Number(request.headers.get('Content-Length') || 0);
    const maxBodyBytes = url.pathname === '/ocr' ? OCR_MAX_BODY_BYTES : MAX_BODY_BYTES;
    if (contentLength > maxBodyBytes) {
      return json({ error: '送信内容が大きすぎます。' }, 413, origin);
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return json({ error: 'JSON形式が正しくありません。' }, 400, origin);
    }

    const model = cleanText(env.GEMINI_MODEL || DEFAULT_MODEL, 80) || DEFAULT_MODEL;

    if (url.pathname === '/ocr') {
      const parts = imageParts(body.images);
      if (!parts) {
        return json({ error: '画像はJPEG・PNG・WebP・HEICを10枚まで、1枚5MB以下で送信してください。' }, 400, origin);
      }
      const usage = await reserveMonthlyUsage(env, anonymousIdFrom(request));
      if (!usage.allowed) {
        return json({ error: '今月のAI利用枠を使い切りました。追加利用はProプランをご利用ください。', code: 'AI_MONTHLY_LIMIT', usage }, 429, origin);
      }
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 60_000);
      try {
        const response = await fetch(
          `${GEMINI_API_BASE}/${encodeURIComponent(model)}:generateContent`,
          {
            method: 'POST',
            headers: {
              'x-goog-api-key': env.GEMINI_API_KEY,
              'Content-Type': 'application/json'
            },
            signal: controller.signal,
            body: JSON.stringify({
              systemInstruction: {
                parts: [{ text: '画像内の日本語教材を、ページ順にそのまま文字起こししてください。推測で補わず、読めない箇所は［判読不能］としてください。見出し・表・箇条書きの改行は可能な限り保ってください。' }]
              },
              contents: [{ role: 'user', parts: [{ text: 'この教材写真を文字起こししてください。' }, ...parts] }],
              generationConfig: { temperature: 0, maxOutputTokens: 12000 }
            })
          }
        );
        const raw = await response.json();
        if (!response.ok) {
          console.error('Gemini OCR request failed', response.status);
          return json({ error: 'Gemini OCRに失敗しました。少し時間を置いて再試行してください。' }, 502, origin);
        }
        const text = extractOutputText(raw);
        if (!text) return json({ error: '画像から文字を認識できませんでした。' }, 422, origin);
        return json(
          {
            text: cleanText(text, 50_000),
            provider: 'Google Gemini',
            model: cleanText(raw?.modelVersion || model, 80),
            usage
          },
          200,
          origin
        );
      } catch (error) {
        console.error(error?.name === 'AbortError' ? 'Gemini OCR timed out' : 'Gemini OCR request failed');
        return json(
          { error: error?.name === 'AbortError' ? 'Gemini OCRの応答が時間切れになりました。' : 'Gemini OCRへ接続できませんでした。' },
          500,
          origin
        );
      } finally {
        clearTimeout(timeout);
      }
    }

    const source = cleanText(body.text ?? body.source, 12_000);
    const type = ['qa', 'cloze', 'mix'].includes(body.type) ? body.type : 'mix';
    const difficulty = ['easy', 'normal', 'hard'].includes(body.difficulty)
      ? body.difficulty
      : 'normal';
    const count = Math.max(1, Math.min(Number(body.count) || 10, 20));

    if (source.length < 20) {
      return json({ error: '教材本文を20文字以上入力してください。' }, 400, origin);
    }

    const usage = await reserveMonthlyUsage(env, anonymousIdFrom(request));
    if (!usage.allowed) {
      return json({ error: '今月のAI利用枠を使い切りました。追加利用はProプランをご利用ください。', code: 'AI_MONTHLY_LIMIT', usage }, 429, origin);
    }

    const instructions = [
      'あなたは日本語教材から、表と裏で学習する単語カードを作る編集者です。',
      `教材本文だけを根拠に、最大${count}枚のカードを作成してください。推測で事実を追加しないでください。`,
      `本文に${count}個以上の独立した確認可能な事実がある場合は、必ず${count}枚を返してください。作問数を任意に4枚などへ減らさず、本文全体から事実を拾って指定枚数を優先してください。`,
      `希望形式は${type}、難易度は${difficulty}です。1枚は15秒以内で答えられる短さにしてください。`,
      '各カードを作る前に、本文中の「一つの確認可能な事実」を特定してください。事実を特定できない文からは作問しないでください。',
      '最重要ルール: 同じ事実を一問一答と穴埋めの両方にしないでください。同じ年代、名称、場所、定義、因果関係は1回だけ出題してください。',
      '一問一答では、answerの文字列をquestionへ含めないでください。答えが主語の文は、他の条件や説明から答えを尋ねる形へ言い換えてください。',
      '穴埋めでは、答えの箇所を必ず「____」へ置き換え、元の答えをquestionへ残さないでください。',
      '表やOCR文では見出し・列名・行名を教材どおりに扱い、別の概念へ言い換えたり、欠けている見出しを推測したりしないでください。',
      'questionとanswerを教材本文と照合し、教材にない用語・分類・関係を一語でも追加しないでください。',
      '見出しだけ、文の途中、不完全な語句、英語表記だけ、答えが問題文に残る問題、答えが複数ある問題は禁止です。',
      `意味のある事実が${count}個に満たない場合だけ、出力件数を減らしてください。問題数を満たすための重複や、低品質な問題の追加は禁止です。`,
      '短い教材でも確認可能な事実が一つ以上あれば、その事実だけを使って少数の有効なカードを作成してください。',
      '例: 「水は標準気圧で0℃で凍る」なら、questionは「標準気圧で0℃に凍る物質は何ですか？」、answerは「水」です。',
      'questionとanswerは短く、各120文字以内を目安にしてください。',
      'factKeyには、問題文の形式に依存しない事実の識別子を日本語または短い英数字で入れてください。'
    ].join('\n');

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 45_000);
    const startedAt = Date.now();

    try {
      const response = await fetch(
        `${GEMINI_API_BASE}/${encodeURIComponent(model)}:generateContent`,
        {
          method: 'POST',
          headers: {
            'x-goog-api-key': env.GEMINI_API_KEY,
            'Content-Type': 'application/json'
          },
          signal: controller.signal,
          body: JSON.stringify({
            systemInstruction: { parts: [{ text: instructions }] },
            contents: [{ role: 'user', parts: [{ text: source }] }],
            generationConfig: {
              responseMimeType: 'application/json',
              responseSchema: questionSchema(count),
              // 20枚でも途中で打ち切られないよう、カード枚数に応じて出力枠を確保する。
              maxOutputTokens: Math.min(8192, Math.max(2048, count * 360)),
              temperature: 0.2
            }
          })
        }
      );

      const raw = await response.json();
      if (!response.ok) {
        console.error('Gemini request failed', response.status);
        return json(
          { error: 'AI作問に失敗しました。しばらくしてから再試行してください。' },
          502,
          origin
        );
      }

      const outputText = extractOutputText(raw);
      if (!outputText) {
        const blocked = raw?.promptFeedback?.blockReason || raw?.candidates?.[0]?.finishReason;
        return json(
          {
            error: blocked
              ? '安全設定によりAIの結果を取得できませんでした。'
              : 'AIから有効な結果を取得できませんでした。'
          },
          502,
          origin
        );
      }

      let parsed;
      try {
        parsed = JSON.parse(outputText);
      } catch {
        return json({ error: 'AIから有効なJSONを取得できませんでした。' }, 502, origin);
      }
      const result = deduplicateQuestions(parsed.questions, count);

      if (!result.questions.length) {
        return json(
          {
            error: '問題を生成できませんでした。教材文を見直してください。',
            quality: {
              requestedCount: count,
              rawCount: result.rawCount,
              duplicateCount: result.duplicateCount,
              rejectedCount: result.rejectedCount
            }
          },
          422,
          origin
        );
      }

      return json(
        {
          questions: result.questions,
          provider: 'Google Gemini',
          model: cleanText(raw?.modelVersion || model, 80),
          generationMode: 'structured-output',
          usage: normalizeUsage(raw?.usageMetadata),
          quality: {
            requestedCount: count,
            rawCount: result.rawCount,
            acceptedCount: result.questions.length,
            duplicateCount: result.duplicateCount,
            rejectedCount: result.rejectedCount
          },
          elapsedMs: Date.now() - startedAt,
          usageLimit: usage
        },
        200,
        origin
      );
    } catch (error) {
      console.error(error?.name === 'AbortError' ? 'Gemini request timed out' : 'Gemini request failed');
      const message =
        error?.name === 'AbortError'
          ? 'AIの応答が時間切れになりました。'
          : 'サーバー内部でエラーが発生しました。';
      return json({ error: message }, 500, origin);
    } finally {
      clearTimeout(timeout);
    }
  }
};
