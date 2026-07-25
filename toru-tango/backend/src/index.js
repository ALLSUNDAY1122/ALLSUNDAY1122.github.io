const ALLOWED_ORIGIN = 'https://allsunday1122.github.io';

function cors(origin) {
  const allowed = origin === ALLOWED_ORIGIN ? origin : ALLOWED_ORIGIN;
  return {
    'Access-Control-Allow-Origin': allowed,
    'Access-Control-Allow-Methods': 'POST,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Vary': 'Origin',
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store'
  };
}

function json(data, status = 200, origin = ALLOWED_ORIGIN) {
  return new Response(JSON.stringify(data), { status, headers: cors(origin) });
}

function cleanText(value, max) {
  return String(value ?? '').replace(/\u0000/g, '').trim().slice(0, max);
}

export default {
  async fetch(request, env) {
    const origin = request.headers.get('Origin') || ALLOWED_ORIGIN;
    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors(origin) });
    if (request.method !== 'POST') return json({ error: 'POSTのみ対応しています。' }, 405, origin);

    const url = new URL(request.url);
    if (url.pathname !== '/generate') return json({ error: 'Not found' }, 404, origin);
    if (!env.OPENAI_API_KEY) return json({ error: 'サーバー設定が完了していません。' }, 503, origin);

    let body;
    try { body = await request.json(); }
    catch { return json({ error: 'JSON形式が正しくありません。' }, 400, origin); }

    const source = cleanText(body.source, 12000);
    const type = ['qa', 'cloze', 'mix'].includes(body.type) ? body.type : 'mix';
    const difficulty = ['easy', 'normal', 'hard'].includes(body.difficulty) ? body.difficulty : 'normal';
    const count = Math.max(1, Math.min(Number(body.count) || 10, 20));

    if (source.length < 30) return json({ error: '教材本文を30文字以上入力してください。' }, 400, origin);

    const instructions = `あなたは日本語教材から短時間学習用の問題を作る専門家です。\n` +
      `教材本文だけを根拠に、${count}問作成してください。推測で事実を追加しないでください。\n` +
      `形式: ${type}。難易度: ${difficulty}。1問は15秒以内で答えられる短さにしてください。\n` +
      `出力はJSONのみ。形式は {"questions":[{"question":"...","answer":"...","type":"qa|cloze"}]}。\n` +
      `重複、曖昧な問題、答えが複数ある問題、長文問題は禁止です。`;

    try {
      const response = await fetch('https://api.openai.com/v1/responses', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${env.OPENAI_API_KEY}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          model: env.OPENAI_MODEL || 'gpt-5-mini',
          instructions,
          input: source,
          text: { format: { type: 'json_object' } },
          max_output_tokens: 2500
        })
      });

      const raw = await response.json();
      if (!response.ok) {
        console.error('OpenAI error', raw);
        return json({ error: 'AI作問に失敗しました。しばらくしてから再試行してください。' }, 502, origin);
      }

      const outputText = raw.output_text || raw.output?.flatMap(x => x.content || []).find(x => x.type === 'output_text')?.text;
      if (!outputText) return json({ error: 'AIから有効な結果を取得できませんでした。' }, 502, origin);

      const parsed = JSON.parse(outputText);
      const questions = Array.isArray(parsed.questions) ? parsed.questions
        .map(q => ({
          question: cleanText(q.question, 180),
          answer: cleanText(q.answer, 120),
          type: q.type === 'cloze' ? 'cloze' : 'qa'
        }))
        .filter(q => q.question && q.answer)
        .slice(0, count) : [];

      if (!questions.length) return json({ error: '問題を生成できませんでした。教材文を見直してください。' }, 422, origin);
      return json({ questions }, 200, origin);
    } catch (error) {
      console.error(error);
      return json({ error: 'サーバー内部でエラーが発生しました。' }, 500, origin);
    }
  }
};
