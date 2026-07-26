const ALLOWED_ORIGIN = 'https://allsunday1122.github.io';
const MAX_BODY_BYTES = 100_000;
const DEFAULT_MODEL = 'gpt-5-nano';
const DEFAULT_REASONING_EFFORT = 'medium';

function cors(origin) {
  return {
    'Access-Control-Allow-Origin': origin || ALLOWED_ORIGIN,
    'Access-Control-Allow-Methods': 'POST,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
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
  if (typeof payload?.output_text === 'string') return payload.output_text;
  if (!Array.isArray(payload?.output)) return '';

  for (const item of payload.output) {
    if (!Array.isArray(item?.content)) continue;
    for (const content of item.content) {
      if (content?.type === 'output_text' && typeof content.text === 'string') {
        return content.text;
      }
    }
  }
  return '';
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
    const evidence = cleanText(item?.evidence, 240);
    const factKey = normalizeKey(item?.factKey || `${answer}-${evidence || question}`);
    const questionKey = normalizeKey(question);
    const answerKey = normalizeKey(answer);
    const pairKey = `${questionKey}|${answerKey}`;

    if (!question || !answer || !factKey || !questionKey || !answerKey) {
      rejectedCount += 1;
      continue;
    }
    if (question.length < 5 || answer.length < 1) {
      rejectedCount += 1;
      continue;
    }
    if (questionKey.includes(answerKey) && type === 'qa') {
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
  const inputTokens = Number(rawUsage?.input_tokens) || 0;
  const outputTokens = Number(rawUsage?.output_tokens) || 0;
  const totalTokens = Number(rawUsage?.total_tokens) || inputTokens + outputTokens;
  return { inputTokens, outputTokens, totalTokens };
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
    if (url.pathname !== '/generate') {
      return json({ error: 'Not found' }, 404, origin);
    }
    if (!env.OPENAI_API_KEY) {
      return json({ error: 'サーバー設定が完了していません。' }, 503, origin);
    }

    const contentLength = Number(request.headers.get('Content-Length') || 0);
    if (contentLength > MAX_BODY_BYTES) {
      return json({ error: '送信内容が大きすぎます。' }, 413, origin);
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return json({ error: 'JSON形式が正しくありません。' }, 400, origin);
    }

    const source = cleanText(body.text ?? body.source, 12_000);
    const type = ['qa', 'cloze', 'mix'].includes(body.type) ? body.type : 'mix';
    const difficulty = ['easy', 'normal', 'hard'].includes(body.difficulty)
      ? body.difficulty
      : 'normal';
    const count = Math.max(1, Math.min(Number(body.count) || 10, 20));
    const model = cleanText(env.OPENAI_MODEL || DEFAULT_MODEL, 80) || DEFAULT_MODEL;
    const reasoningEffort = ['none', 'low', 'medium', 'high'].includes(
      env.OPENAI_REASONING_EFFORT
    )
      ? env.OPENAI_REASONING_EFFORT
      : DEFAULT_REASONING_EFFORT;

    if (source.length < 20) {
      return json({ error: '教材本文を20文字以上入力してください。' }, 400, origin);
    }

    const instructions = [
      'あなたは日本語教材から、表と裏で学習する単語カードを作る編集者です。',
      `教材本文だけを根拠に、最大${count}枚のカードを作成してください。推測で事実を追加しないでください。`,
      `希望形式は${type}、難易度は${difficulty}です。1枚は15秒以内で答えられる短さにしてください。`,
      '各カードを作る前に、本文中の「一つの確認可能な事実」を特定してください。事実を特定できない文からは作問しないでください。',
      '最重要ルール: 同じ事実を一問一答と穴埋めの両方にしないでください。同じ年代、名称、場所、定義、因果関係は1回だけ出題してください。',
      '見出し、文の途中、不完全な語句、英語表記だけ、答えが問題文に残る問題、答えが複数ある問題は禁止です。',
      '問題数を満たすために低品質な問題を追加しないでください。意味のある事実が少なければ出力件数を減らしてください。',
      'factKeyには、問題文の形式に依存しない事実の識別子を日本語または短い英数字で入れてください。',
      'evidenceには、答えの根拠となる教材本文の該当部分を短くそのまま入れてください。'
    ].join('\n');

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 45_000);
    const startedAt = Date.now();

    try {
      const response = await fetch('https://api.openai.com/v1/responses', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${env.OPENAI_API_KEY}`,
          'Content-Type': 'application/json'
        },
        signal: controller.signal,
        body: JSON.stringify({
          model,
          reasoning: { effort: reasoningEffort },
          instructions,
          input: source,
          store: false,
          text: {
            format: {
              type: 'json_schema',
              name: 'quiz_questions',
              strict: true,
              schema: {
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
                        factKey: { type: 'string' },
                        evidence: { type: 'string' }
                      },
                      required: ['question', 'answer', 'type', 'factKey', 'evidence'],
                      additionalProperties: false
                    }
                  }
                },
                required: ['questions'],
                additionalProperties: false
              }
            }
          },
          max_output_tokens: 3000
        })
      });

      const raw = await response.json();
      if (!response.ok) {
        console.error('OpenAI error', raw);
        return json(
          { error: 'AI作問に失敗しました。しばらくしてから再試行してください。' },
          502,
          origin
        );
      }

      const outputText = extractOutputText(raw);
      if (!outputText) {
        return json({ error: 'AIから有効な結果を取得できませんでした。' }, 502, origin);
      }

      const parsed = JSON.parse(outputText);
      const result = deduplicateQuestions(parsed.questions, count);

      if (!result.questions.length) {
        return json(
          { error: '問題を生成できませんでした。教材文を見直してください。' },
          422,
          origin
        );
      }

      return json(
        {
          questions: result.questions,
          model: cleanText(raw?.model || model, 80),
          reasoningEffort,
          usage: normalizeUsage(raw?.usage),
          quality: {
            requestedCount: count,
            rawCount: result.rawCount,
            acceptedCount: result.questions.length,
            duplicateCount: result.duplicateCount,
            rejectedCount: result.rejectedCount
          },
          elapsedMs: Date.now() - startedAt
        },
        200,
        origin
      );
    } catch (error) {
      console.error(error);
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
