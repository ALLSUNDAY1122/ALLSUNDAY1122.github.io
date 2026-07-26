const ALLOWED_ORIGIN = 'https://allsunday1122.github.io';
const MAX_BODY_BYTES = 100_000;

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

    if (source.length < 20) {
      return json({ error: '教材本文を20文字以上入力してください。' }, 400, origin);
    }

    const instructions =
      'あなたは日本語教材から短時間学習用の問題を作る専門家です。\n' +
      `教材本文だけを根拠に、最大${count}問作成してください。推測で事実を追加しないでください。\n` +
      `形式: ${type}。難易度: ${difficulty}。1問は15秒以内で答えられる短さにしてください。\n` +
      '重複、曖昧な問題、答えが複数ある問題、長文問題は禁止です。';

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 45_000);

    try {
      const response = await fetch('https://api.openai.com/v1/responses', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${env.OPENAI_API_KEY}`,
          'Content-Type': 'application/json'
        },
        signal: controller.signal,
        body: JSON.stringify({
          model: env.OPENAI_MODEL || 'gpt-5-mini',
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
                    items: {
                      type: 'object',
                      properties: {
                        question: { type: 'string' },
                        answer: { type: 'string' },
                        type: { type: 'string', enum: ['qa', 'cloze'] }
                      },
                      required: ['question', 'answer', 'type'],
                      additionalProperties: false
                    }
                  }
                },
                required: ['questions'],
                additionalProperties: false
              }
            }
          },
          max_output_tokens: 2500
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
      const questions = Array.isArray(parsed.questions)
        ? parsed.questions
            .map((question) => ({
              question: cleanText(question.question, 180),
              answer: cleanText(question.answer, 120),
              type: question.type === 'cloze' ? 'cloze' : 'qa'
            }))
            .filter((question) => question.question && question.answer)
            .slice(0, count)
        : [];

      if (!questions.length) {
        return json(
          { error: '問題を生成できませんでした。教材文を見直してください。' },
          422,
          origin
        );
      }
      return json({ questions }, 200, origin);
    } catch (error) {
      console.error(error);
      const message = error?.name === 'AbortError' ? 'AIの応答が時間切れになりました。' : 'サーバー内部でエラーが発生しました。';
      return json({ error: message }, 500, origin);
    } finally {
      clearTimeout(timeout);
    }
  }
};
