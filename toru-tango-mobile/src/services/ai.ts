import type { Difficulty, QuestionCandidate, QuestionType } from '@/src/types';

function isCandidate(value: unknown): value is QuestionCandidate {
  if (!value || typeof value !== 'object') return false;
  const candidate = value as Record<string, unknown>;
  return (
    typeof candidate.question === 'string' &&
    candidate.question.trim().length > 0 &&
    typeof candidate.answer === 'string' &&
    candidate.answer.trim().length > 0
  );
}

export async function generateAiQuestions(input: {
  text: string;
  count: number;
  type: QuestionType;
  difficulty: Difficulty;
}): Promise<QuestionCandidate[]> {
  const configuredUrl = process.env.EXPO_PUBLIC_AI_API_URL?.trim();
  if (!configuredUrl) throw new Error('AI_API_NOT_CONFIGURED');

  const endpoint = configuredUrl.endsWith('/generate')
    ? configuredUrl
    : `${configuredUrl.replace(/\/$/, '')}/generate`;

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 30000);

  try {
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(input),
      signal: controller.signal
    });

    if (!response.ok) {
      throw new Error(`AI_API_${response.status}`);
    }

    const payload = (await response.json()) as { questions?: unknown };
    if (!Array.isArray(payload.questions)) {
      throw new Error('AI_API_INVALID_RESPONSE');
    }

    return payload.questions.filter(isCandidate).slice(0, input.count);
  } finally {
    clearTimeout(timeout);
  }
}
