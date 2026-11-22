import { File } from 'expo-file-system';
import { getAnonymousId } from './anonymousId';
import { getTransactionJws } from './iap';

export type SelectedStudyImage = {
  uri: string;
  mimeType?: string | null;
};

const MAX_IMAGES = 10;

function getOcrEndpoint(): string {
  const configuredUrl = process.env.EXPO_PUBLIC_AI_API_URL?.trim();
  if (!configuredUrl) throw new Error('AI_API_NOT_CONFIGURED');
  return configuredUrl.replace(/\/generate\/?$/, '/ocr');
}

export async function recognizeWithGemini(images: SelectedStudyImage[]): Promise<string> {
  if (!images.length) throw new Error('画像を選択してください。');
  if (images.length > MAX_IMAGES) throw new Error(`画像は${MAX_IMAGES}枚まで選択できます。`);

  const encodedImages = await Promise.all(
    images.map(async ({ uri, mimeType }) => ({
      data: await new File(uri).base64(),
      mimeType: mimeType?.startsWith('image/') ? mimeType : 'image/jpeg'
    }))
  );

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 60_000);
  try {
    const anonymousId = await getAnonymousId();
    const transactionJws = await getTransactionJws();
    const response = await fetch(getOcrEndpoint(), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-Toru-Tango-Anonymous-Id': anonymousId, ...(transactionJws ? { 'X-Toru-Tango-Transaction-JWS': transactionJws } : {}) },
      body: JSON.stringify({ images: encodedImages }),
      signal: controller.signal
    });
    const payload = (await response.json()) as Record<string, unknown>;
    if (!response.ok) {
      throw new Error(response.status === 429 && payload.code === 'AI_MONTHLY_LIMIT' ? 'AI_MONTHLY_LIMIT' : typeof payload.code === 'string' && payload.code.startsWith('GEMINI_UPSTREAM_HTTP_') ? `${payload.code} (${payload.upstreamCode ?? 'UNKNOWN'})` : typeof payload.error === 'string' ? payload.error : `AI_API_${response.status}`);
    }
    const text = typeof payload.text === 'string' ? payload.text.trim() : '';
    if (!text) throw new Error('文字を認識できませんでした。写真を撮り直してください。');
    return text;
  } finally {
    clearTimeout(timeout);
  }
}
