// Retries provider HTTP 429/500/502/503/504, not app quota errors.
export const RETRY_STATUSES = new Set([429, 500, 502, 503, 504]);
const ATTEMPT_TIMEOUT_MS = 12_000;
const BASE_DELAYS_MS = [800, 2000];
const wait = ms => new Promise(resolve => setTimeout(resolve, ms));

// Three upstream attempts, each bounded at 12 seconds, plus jittered
// delays <=3.36 seconds: worst case < 40 seconds (iOS timeout 45s).
export async function generateWithRetry({ url, headers, body, operation,
  fetchFn = fetch, sleepFn = wait, randomFn = Math.random,
  attemptTimeoutMs = ATTEMPT_TIMEOUT_MS }) {
  for (let attempt = 0; attempt < 3; attempt++) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), attemptTimeoutMs);
    let response, raw;
    try {
      response = await fetchFn(url, { method: 'POST', headers, body, signal: controller.signal });
      raw = await response.json();
    } finally {
      clearTimeout(timeout);
    }
    if (response.ok || !RETRY_STATUSES.has(response.status) || attempt === 2) {
      return { response, raw, attempts: attempt + 1 };
    }
    console.warn(JSON.stringify({ event: 'gemini_retryable_response',
      operation, status: response.status, attempt: attempt + 1 }));
    const random = Math.max(0, Math.min(1, randomFn()));
    await sleepFn(Math.round(BASE_DELAYS_MS[attempt] * (0.8 + 0.4 * random)));
  }
  throw Error('GEMINI_RETRY_EXHAUSTED_UNREACHABLE');
}
