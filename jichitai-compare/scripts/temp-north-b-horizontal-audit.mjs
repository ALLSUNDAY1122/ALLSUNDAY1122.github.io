import fs from 'node:fs';
import path from 'node:path';

const projectDir = path.resolve('jichitai-compare');
const prefectures = new Set(['01', '04', '05', '06']);
const outputPath = path.join(projectDir, 'operations', 'audits', 'north-b-horizontal-url-year-numeric-20260725.json');
const focusServices = new Set(['temporaryChildcare', 'schoolMeals', 'postpartumCare', 'sickChildCare', 'childcareFee', 'housingSupport']);

function listJsonFiles(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) return listJsonFiles(full);
    return entry.isFile() && entry.name.endsWith('.json') ? [full] : [];
  });
}

function flattenStrings(value, out = []) {
  if (typeof value === 'string') out.push(value);
  else if (Array.isArray(value)) value.forEach((item) => flattenStrings(item, out));
  else if (value && typeof value === 'object') Object.values(value).forEach((item) => flattenStrings(item, out));
  return out;
}

function collectSources(service) {
  const sources = [];
  if (service?.source?.url) sources.push({ url: service.source.url, checkedAt: service.source.checkedAt || null, role: 'primary' });
  for (const source of service?.additionalSources || []) {
    if (source?.url) sources.push({ url: source.url, checkedAt: source.checkedAt || null, role: 'additional' });
  }
  return sources;
}

const municipalities = listJsonFiles(path.join(projectDir, 'data', 'municipalities'))
  .map((file) => JSON.parse(fs.readFileSync(file, 'utf8')))
  .filter((item) => prefectures.has(item.prefectureCode));

const urlOwners = new Map();
const yearCandidates = [];
const numericCandidates = [];
const anyoneCompletenessCandidates = [];

for (const municipality of municipalities) {
  if (municipality.officialUrl) {
    if (!urlOwners.has(municipality.officialUrl)) urlOwners.set(municipality.officialUrl, []);
    urlOwners.get(municipality.officialUrl).push({ code: municipality.code, municipality: municipality.name, service: 'officialUrl', role: 'municipality' });
  }

  for (const [serviceId, service] of Object.entries(municipality.services || {})) {
    const sources = collectSources(service);
    for (const source of sources) {
      if (!urlOwners.has(source.url)) urlOwners.set(source.url, []);
      urlOwners.get(source.url).push({ code: municipality.code, municipality: municipality.name, service: serviceId, role: source.role, checkedAt: source.checkedAt });
    }

    const text = flattenStrings({ summary: service.summary, eligibility: service.eligibility, details: service.details }).join(' ');
    const oldFiscalMatches = [...new Set(text.match(/(?:令和[67]年度|202[45]年度)/g) || [])];
    const oldUrlSources = sources.filter((source) => /(?:2024|2025|r6|r7|reiwa6|reiwa7)/i.test(source.url));
    if (oldFiscalMatches.length || oldUrlSources.length) {
      yearCandidates.push({
        code: municipality.code,
        municipality: municipality.name,
        service: serviceId,
        status: service.status,
        updatedAt: municipality.updatedAt,
        fiscalReferences: oldFiscalMatches,
        oldYearUrls: oldUrlSources.map((item) => item.url),
        summary: service.summary
      });
    }

    if (focusServices.has(serviceId) && service.status === 'verified') {
      const numberTokens = [...new Set(text.match(/\d[\d,.]*(?:円|時間|回|日|歳|か月|ヶ月|月|％|%)/g) || [])];
      const missingCheckedAt = sources.length === 0 || sources.some((source) => !source.checkedAt);
      if (numberTokens.length && missingCheckedAt) {
        numericCandidates.push({
          code: municipality.code,
          municipality: municipality.name,
          service: serviceId,
          reason: sources.length === 0 ? 'source-url-missing' : 'checkedAt-missing',
          numberTokens,
          summary: service.summary
        });
      }
    }

    if (serviceId === 'temporaryChildcare' && service.status === 'verified' && /誰でも通園|乳児等通園支援/.test(text)) {
      const completeness = {
        startYear: /2026|令和8|4月開始|開始/.test(text),
        targetAge: /(?:生後)?\d+か月|\d+ヶ月|満?3歳未満/.test(text),
        fee: /\d[\d,]*円|無料|免除/.test(text),
        facility: /保育園|保育所|こども園|幼稚園|センター|施設/.test(text),
        hoursOrLimit: /月\s*\d+時間|\d+時間|\d+時/.test(text)
      };
      const missing = Object.entries(completeness).filter(([, value]) => !value).map(([key]) => key);
      if (missing.length) {
        anyoneCompletenessCandidates.push({
          code: municipality.code,
          municipality: municipality.name,
          status: service.status,
          missing,
          summary: service.summary,
          sourceUrls: sources.map((item) => item.url)
        });
      }
    }
  }
}

const urls = [...urlOwners.keys()];
const results = new Array(urls.length);
let cursor = 0;

async function request(url, method) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 15000);
  try {
    const response = await fetch(url, {
      method,
      redirect: 'follow',
      signal: controller.signal,
      headers: {
        'user-agent': 'Mozilla/5.0 (compatible; JichitaiCompareAudit/1.0; +https://allsunday1122.github.io/jichitai-compare/)',
        ...(method === 'GET' ? { range: 'bytes=0-2047' } : {})
      }
    });
    return { ok: true, status: response.status, finalUrl: response.url, redirected: response.redirected };
  } catch (error) {
    return { ok: false, error: error?.name === 'AbortError' ? 'timeout' : String(error?.message || error) };
  } finally {
    clearTimeout(timer);
  }
}

async function checkUrl(url) {
  let result = await request(url, 'HEAD');
  if (!result.ok || [400, 403, 405, 406, 429, 500, 501, 502, 503, 504].includes(result.status)) {
    const fallback = await request(url, 'GET');
    if (fallback.ok || !result.ok) result = fallback;
  }
  return result;
}

async function worker() {
  while (true) {
    const index = cursor++;
    if (index >= urls.length) return;
    const url = urls[index];
    const result = await checkUrl(url);
    results[index] = { url, ...result, owners: urlOwners.get(url) };
    console.log(`${index + 1}/${urls.length} ${result.ok ? result.status : result.error} ${url}`);
  }
}

await Promise.all(Array.from({ length: 10 }, () => worker()));

const broken = results.filter((item) => item.ok && [404, 410].includes(item.status));
const serverErrors = results.filter((item) => item.ok && item.status >= 500);
const restricted = results.filter((item) => item.ok && [401, 403, 429].includes(item.status));
const networkErrors = results.filter((item) => !item.ok);
const redirects = results.filter((item) => item.ok && item.redirected && item.finalUrl !== item.url);
const successful = results.filter((item) => item.ok && item.status >= 200 && item.status < 400);

const report = {
  schemaVersion: '1.0.0',
  auditId: 'north-b-horizontal-url-year-numeric-20260725',
  sessionId: 'north-b',
  createdAt: new Date().toISOString(),
  status: 'machine_scan_completed',
  scope: {
    prefectureCodes: [...prefectures],
    municipalityCount: municipalities.length,
    uniqueUrlCount: urls.length,
    focusServices: [...focusServices]
  },
  summary: {
    successfulUrlCount: successful.length,
    brokenUrlCount: broken.length,
    serverErrorCount: serverErrors.length,
    restrictedUrlCount: restricted.length,
    networkErrorCount: networkErrors.length,
    redirectCount: redirects.length,
    fiscalYearCandidateCount: yearCandidates.length,
    numericSourceMetadataCandidateCount: numericCandidates.length,
    anyoneChildcareCompletenessCandidateCount: anyoneCompletenessCandidates.length
  },
  definiteBrokenUrls: broken,
  serverErrors,
  restrictedUrls: restricted,
  networkErrors,
  redirects,
  fiscalYearCandidates: yearCandidates,
  numericSourceMetadataCandidates: numericCandidates,
  anyoneChildcareCompletenessCandidates,
  decisionRule: '404/410のみを確定URL切れ候補とする。403/429、タイムアウト、サーバーエラーは公式サイト側の制限・一時障害の可能性があるため、人手再確認なしにURL切れと断定しない。年度・数値候補も自動的に誤りと判定しない。'
};

fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, `${JSON.stringify(report, null, 2)}\n`);
console.log(JSON.stringify(report.summary, null, 2));
