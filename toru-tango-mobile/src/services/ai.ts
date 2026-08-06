import type { Difficulty, QuestionCandidate, QuestionType } from '@/src/types';
import { getAnonymousId } from './anonymousId';

type AiUsage = {
  inputTokens: number;
  outputTokens: number;
  totalTokens: number;
};

type AiQuality = {
  requestedCount: number;
  rawCount: number;
  acceptedCount: number;
  duplicateCount: number;
  rejectedCount: number;
};

export type AiGenerationResult = {
  questions: QuestionCandidate[];
  provider: string;
  model: string;
  generationMode: string;
  usage: AiUsage;
  quality: AiQuality;
  elapsedMs: number;
};

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

function numberValue(value: unknown): number {
  const result = Number(value);
  return Number.isFinite(result) && result >= 0 ? result : 0;
}

export async function generateAiQuestions(input: {
  text: string;
  count: number;
  type: QuestionType;
  difficulty: Difficulty;
}): Promise<AiGenerationResult> {
  const configuredUrl = process.env.EXPO_PUBLIC_AI_API_URL?.trim();
  if (!configuredUrl) throw new Error('AI_API_NOT_CONFIGURED');

  const endpoint = configuredUrl.endsWith('/generate')
    ? configuredUrl
    : `${configuredUrl.replace(/\/$/, '')}/generate`;

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 45_000);

  try {
    const anonymousId = await getAnonymousId();
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-Toru-Tango-Anonymous-Id': anonymousId },
      body: JSON.stringify(input),
      signal: controller.signal
    });

    const payload = (await response.json()) as Record<string, unknown>;
    if (!response.ok) {
      const message = typeof payload.error === 'string' ? payload.error : `AI_API_${response.status}`;
      throw new Error(message);
    }

    if (!Array.isArray(payload.questions)) {
      throw new Error('AI_API_INVALID_RESPONSE');
    }

    const questions = payload.questions.filter(isCandidate).slice(0, input.count);
    if (!questions.length) throw new Error('AI_API_EMPTY');

    const usage =
      payload.usage && typeof payload.usage === 'object'
        ? (payload.usage as Record<string, unknown>)
        : {};
    const quality =
      payload.quality && typeof payload.quality === 'object'
        ? (payload.quality as Record<string, unknown>)
        : {};

    return {
      questions,
      provider: typeof payload.provider === 'string' ? payload.provider : 'AI',
      model: typeof payload.model === 'string' ? payload.model : 'unknown',
      generationMode:
        typeof payload.generationMode === 'string' ? payload.generationMode : 'unknown',
      usage: {
        inputTokens: numberValue(usage.inputTokens),
        outputTokens: numberValue(usage.outputTokens),
        totalTokens: numberValue(usage.totalTokens)
      },
      quality: {
        requestedCount: numberValue(quality.requestedCount) || input.count,
        rawCount: numberValue(quality.rawCount),
        acceptedCount: numberValue(quality.acceptedCount) || questions.length,
        duplicateCount: numberValue(quality.duplicateCount),
        rejectedCount: numberValue(quality.rejectedCount)
      },
      elapsedMs: numberValue(payload.elapsedMs)
    };
  } finally {
    clearTimeout(timeout);
  }
}
