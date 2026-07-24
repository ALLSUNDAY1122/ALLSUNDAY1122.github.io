import { mkdir, readFile, writeFile } from 'node:fs/promises';

const PREFECTURE_CODES = new Set(['33', '37', '39', '40', '43', '46']);
const TIMEOUT_MS = 8000;
const CONCURRENCY = 40;
const MAX_ATTEMPTS = 2;
const REPORT_PATH = new URL('../operations/audits/west-a-source-link-health-20260725.json', import.meta.url);

const generated = JSON.parse(
  await readFile(new URL('../data/generated/municipalities.json', import.meta.url), 'utf8')
);

const municipalities = generated.municipalities.filter((item) => PREFECTURE_CODES.has(item.prefectureCode));
const urlMap = new Map();
let referenceCount = 0;

function addUrl(url, reference) {
  if (typeof url !== 'string' || !url.startsWith('https://')) return;
  referenceCount += 1;
  const current = urlMap.get(url) ?? [];
  current.push(reference);
  urlMap.set(url, current);
}

for (const municipality of municipalities) {
  addUrl(municipality.officialUrl, {
    code: municipality.code,
    name: municipality.name,
    field: 'officialUrl'
  });

  for (const [serviceId, service] of Object.entries(municipality.services ?? {})) {
    addUrl(service?.source?.url, {
      code: municipality.code,
      name: municipality.name,
      field: `services.${serviceId}.source`,
      service: serviceId
    });
    for (const [index, source] of (service?.additionalSources ?? []).entries()) {
      addUrl(source?.url, {
        code: municipality.code,
        name: municipality.name,
        field: `services.${serviceId}.additionalSources[${index}]`,
        service: serviceId
      });
    }
  }
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function request(url) {
  let lastResult;
  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt += 1) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), TIMEOUT_MS);
    const startedAt = Date.now();
    try {
      const response = await fetch(url, {
        method: 'GET',
        redirect: 'follow',
        signal: controller.signal,
        headers: {
          'user-agent': 'Mozilla/5.0 (compatible; JichitaiCompareLinkAudit/1.0; +https://allsunday1122.github.io/jichitai-compare/)',
          accept: 'text/html,application/pdf,application/json;q=0.9,*/*;q=0.8',
          range: 'bytes=0-4095',
          'cache-control': 'no-cache'
        }
      });
      clearTimeout(timeout);
      await response.body?.cancel().catch(() => {});
      lastResult = {
        status: response.status,
        ok: response.ok,
        finalUrl: response.url,
        redirected: response.redirected,
        durationMs: Date.now() - startedAt,
        attempt
      };
      if (![429, 500, 502, 503, 504].includes(response.status) || attempt === MAX_ATTEMPTS) return lastResult;
    } catch (error) {
      clearTimeout(timeout);
      lastResult = {
        status: null,
        ok: false,
        error: error?.name === 'AbortError' ? 'timeout' : String(error?.message ?? error),
        durationMs: Date.now() - startedAt,
        attempt
      };
      if (attempt === MAX_ATTEMPTS) return lastResult;
    }
    await sleep(300);
  }
  return lastResult;
}

const queue = [...urlMap.entries()];
const results = new Array(queue.length);
let cursor = 0;

async function worker() {
  while (true) {
    const index = cursor;
    cursor += 1;
    if (index >= queue.length) return;
    const [url, references] = queue[index];
    const result = await request(url);
    results[index] = { url, references, ...result };
  }
}

await Promise.all(Array.from({ length: Math.min(CONCURRENCY, queue.length) }, worker));

const hardFailures = results.filter((item) => item.status === 404 || item.status === 410);
const softWarnings = results.filter((item) => !item.ok && !hardFailures.includes(item));
const redirects = results.filter((item) => item.redirected && item.finalUrl && item.finalUrl !== item.url);
const statusCounts = {};
for (const item of results) {
  const key = item.status === null ? `error:${item.error ?? 'unknown'}` : String(item.status);
  statusCounts[key] = (statusCounts[key] ?? 0) + 1;
}

const report = {
  schemaVersion: '1.0.0',
  auditId: 'west-a-source-link-health-20260725',
  auditedAt: new Date().toISOString(),
  scope: {
    prefectureCodes: [...PREFECTURE_CODES],
    municipalityCount: municipalities.length,
    referenceCount,
    uniqueUrlCount: queue.length
  },
  configuration: {
    timeoutMs: TIMEOUT_MS,
    concurrency: CONCURRENCY,
    maxAttempts: MAX_ATTEMPTS,
    hardFailureStatuses: [404, 410]
  },
  statusCounts,
  hardFailureCount: hardFailures.length,
  softWarningCount: softWarnings.length,
  redirectCount: redirects.length,
  hardFailures,
  softWarnings,
  redirects
};

await mkdir(new URL('../operations/audits/', import.meta.url), { recursive: true });
await writeFile(REPORT_PATH, `${JSON.stringify(report, null, 2)}\n`);

console.log(`WEST_A_LINK_AUDIT_SUMMARY ${JSON.stringify({
  municipalityCount: municipalities.length,
  referenceCount,
  uniqueUrlCount: queue.length,
  hardFailureCount: hardFailures.length,
  softWarningCount: softWarnings.length,
  redirectCount: redirects.length,
  statusCounts
})}`);

for (const failure of hardFailures) {
  console.error(`HARD_LINK_FAILURE ${JSON.stringify(failure)}`);
}
for (const warning of softWarnings.slice(0, 200)) {
  console.warn(`SOFT_LINK_WARNING ${JSON.stringify(warning)}`);
}
if (softWarnings.length > 200) {
  console.warn(`SOFT_LINK_WARNING_TRUNCATED ${softWarnings.length - 200}`);
}

if (hardFailures.length > 0) {
  throw new Error(`西日本A公式出典に404/410が${hardFailures.length}件あります`);
}
