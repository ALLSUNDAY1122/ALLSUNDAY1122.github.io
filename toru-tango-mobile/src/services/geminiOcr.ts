import * as ImageManipulator from 'expo-image-manipulator';
import { getAnonymousId } from './anonymousId';
import { getTransactionJws } from './iap';

export type SelectedStudyImage = {
  uri: string;
  mimeType?: string | null;
  width?: number;
  height?: number;
};

const MAX_IMAGES = 10;
const TARGET_LONG_EDGE = 1600;
const MAX_BASE64_CHARS_PER_IMAGE = 1_500_000;
const MAX_REQUEST_BYTES = 9_000_000;
const COMPRESSION_ATTEMPTS = [
  { edge: 1600, quality: 0.7 },
  { edge: 1280, quality: 0.55 },
  { edge: 1024, quality: 0.4 },
  { edge: 800, quality: 0.35 }
] as const;

function getOcrEndpoint(): string {
  const configuredUrl = process.env.EXPO_PUBLIC_AI_API_URL?.trim();
  if (!configuredUrl) throw new Error('AI_API_NOT_CONFIGURED');
  const endpoint = configuredUrl.replace(/\/generate\/?$/, '/ocr');
  if (endpoint === configuredUrl || !endpoint.startsWith('https://')) {
    throw new Error('OCR_URL_INVALID');
  }
  return endpoint;
}

function countBase64Bytes(data: string): number {
  return Math.floor(data.length * 3 / 4) - (data.endsWith('==') ? 2 : data.endsWith('=') ? 1 : 0);
}

async function encodeJpeg(image: SelectedStudyImage, index: number) {
  const width = image.width ?? 0;
  const height = image.height ?? 0;
  // The ImagePicker normally provides both dimensions. If not, the native
  // manipulator's first pass will still resize to 1600 pixels wide; retry
  // passes reduce the size further if needed.
  const longEdge = Math.max(width, height);
  for (const { edge, quality } of COMPRESSION_ATTEMPTS) {
    const resize = longEdge > 0
      ? (longEdge > edge
        ? { resize: width >= height ? { width: edge } : { height: edge } }
        : null)
      : { resize: { width: edge } };
    const result = await ImageManipulator.manipulateAsync(
      image.uri,
      resize ? [resize] : [],
      { format: ImageManipulator.SaveFormat.JPEG, compress: quality, base64: true }
    );
    const data = result.base64;
    if (!data || !/^[A-Za-z0-9+/]+={0,2}$/.test(data)) {
      throw new Error(`OCR_IMAGE_ENCODING_FAILED image=${index + 1}`);
    }
    if (data.length <= MAX_BASE64_CHARS_PER_IMAGE) {
      return {
        data,
        mimeType: 'image/jpeg' as const,
        diagnostic: { image: index + 1, width: result.width, height: result.height,
          jpegBytes: countBase64Bytes(data), base64Chars: data.length }
      };
    }
  }
  throw new Error(`OCR_IMAGE_TOO_LARGE image=${index + 1} limitBase64Chars=${MAX_BASE64_CHARS_PER_IMAGE}`);
}

export async function recognizeWithGemini(images: SelectedStudyImage[]): Promise<string> {
  if (!images.length) throw new Error('画像を選択してください。');
  if (images.length > MAX_IMAGES) throw new Error(`画像は${MAX_IMAGES}枚まで選択できます。`);

  // Process sequentially: avoid retaining 10 simultaneously decoded full-size
  // camera photos on iOS while the request is being constructed.
  const encodedImages: { data: string; mimeType: 'image/jpeg' }[] = [];
  const diagnostics: { image: number; width: number; height: number; jpegBytes: number; base64Chars: number }[] = [];
  let requestBytes = '{"images":[]}'.length;
  for (let index = 0; index < images.length; index += 1) {
    const compressed = await encodeJpeg(images[index], index);
    requestBytes += compressed.data.length + 45;
    if (requestBytes > MAX_REQUEST_BYTES) {
      throw new Error(`OCR_REQUEST_TOO_LARGE estimatedBytes=${requestBytes} limitBytes=${MAX_REQUEST_BYTES} images=${index + 1}`);
    }
    encodedImages.push({ data: compressed.data, mimeType: compressed.mimeType });
    diagnostics.push(compressed.diagnostic);
  }
  const body = JSON.stringify({ images: encodedImages });
  const bodyBytes = new TextEncoder().encode(body).byteLength;
  if (bodyBytes > MAX_REQUEST_BYTES) {
    throw new Error(`OCR_REQUEST_TOO_LARGE bytes=${bodyBytes} limitBytes=${MAX_REQUEST_BYTES}`);
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 60_000);
  let stage = 'prepare';
  try {
    const anonymousId = await getAnonymousId();
    const transactionJws = await getTransactionJws();
    const endpoint = getOcrEndpoint();
    stage = 'fetch';
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Toru-Tango-Anonymous-Id': anonymousId,
        ...(transactionJws ? { 'X-Toru-Tango-Transaction-JWS': transactionJws } : {})
      },
      body,
      signal: controller.signal
    });
    stage = 'response';
    const payload = (await response.json()) as Record<string, unknown>;
    if (!response.ok) {
      const message = response.status === 429 && payload.code === 'AI_MONTHLY_LIMIT'
        ? 'AI_MONTHLY_LIMIT'
        : typeof payload.code === 'string' && payload.code.startsWith('GEMINI_UPSTREAM_HTTP_')
        ? `${payload.code} (${payload.upstreamCode ?? 'UNKNOWN'})`
        : typeof payload.error === 'string' ? payload.error : `AI_API_${response.status}`;
      throw new Error(`${message} HTTP=${response.status} bodyBytes=${bodyBytes}`);
    }
    const text = typeof payload.text === 'string' ? payload.text.trim() : '';
    if (!text) throw new Error('文字を認識できませんでした。写真を撮り直してください。');
    return text;
  } catch (error) {
    // A transport failure has no HTTP response. Include only sizes/metadata,
    // never OCR content, base64 data, anonymous IDs, or transaction JWS.
    if (stage === 'fetch') {
      const compressedSizes = diagnostics.map(item => item.jpegBytes).join(',');
      const kind = controller.signal.aborted ? 'TIMEOUT' : 'NETWORK_OR_NATIVE_FETCH';
      const detail = error instanceof Error ? error.message.slice(0, 180) : 'unknown';
      throw new Error(`OCR_${kind} stage=${stage} images=${images.length} bodyBytes=${bodyBytes} jpegBytes=[${compressedSizes}] detail=${detail}`);
    }
    throw error;
  } finally {
    clearTimeout(timeout);
  }
}
