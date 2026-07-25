import fs from 'node:fs';
import path from 'node:path';

const ROOT = 'jichitai-compare';
const MUNICIPALITY_ROOT = path.join(ROOT, 'data', 'municipalities');
const TASK_ROOT = path.join(ROOT, 'operations', 'tasks');
const PAGE_ROOT = path.join(ROOT, 'municipality');
const REPORT_PATH = path.join(ROOT, 'operations', 'audits', 'central-a-cause-based-rescan-20260725.json');
const CONTROL_PATH = path.join(ROOT, 'operations', 'control', 'central-a-scope-verification-20260724.json');
const GENERATED_PATH = path.join(ROOT, 'data', 'generated', 'municipalities.json');

const TARGET_PREFECTURES = {
  '16': '富山県', '17': '石川県', '18': '福井県', '21': '岐阜県', '22': '静岡県',
  '23': '愛知県', '24': '三重県', '25': '滋賀県', '27': '大阪府', '28': '兵庫県'
};
const SERVICE_KEYS = [
  'childMedical', 'sickChildCare', 'childcareFee', 'schoolMeals', 'postpartumCare',
  'temporaryChildcare', 'housingSupport', 'bulkyWaste', 'disasterPrevention'
];
const HIGH_RISK = new Set(['sickChildCare', 'schoolMeals', 'postpartumCare', 'temporaryChildcare', 'housingSupport']);
const TERMINAL = new Set(['verified', 'unavailable']);
const ISSUE_3141 = [
  ['21207','temporaryChildcare'],['21504','temporaryChildcare'],['22219','temporaryChildcare'],
  ['22305','temporaryChildcare'],['22424','temporaryChildcare'],['22429','temporaryChildcare'],
  ['23235','schoolMeals'],['23427','schoolMeals'],['23561','schoolMeals'],['23562','schoolMeals'],
  ['23563','temporaryChildcare'],['24205','schoolMeals'],['24205','temporaryChildcare'],
  ['24212','temporaryChildcare'],['24441','schoolMeals'],['24461','temporaryChildcare'],
  ['24543','schoolMeals'],['25441','temporaryChildcare'],['25442','temporaryChildcare'],
  ['27232','sickChildCare'],['27321','sickChildCare'],['27322','schoolMeals'],['27366','sickChildCare']
].map(([code, service]) => ({ code, service }));
const ISSUE_SET = new Set(ISSUE_3141.map(x => `${x.code}:${x.service}`));

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}
function textOf(value) {
  return JSON.stringify(value ?? {}, null, 0);
}
function normalizeUrl(url) {
  try {
    const u = new URL(url);
    u.hash = '';
    return u.toString().replace(/\/$/, '');
  } catch {
    return String(url ?? '').trim().replace(/\/$/, '');
  }
}
function officialHost(url) {
  try { return new URL(url).hostname.toLowerCase(); } catch { return ''; }
}
function isRootUrl(url) {
  try {
    const u = new URL(url);
    return (!u.pathname || u.pathname === '/') && !u.search;
  } catch { return false; }
}
function primarySource(service) {
  return service?.source?.url ?? null;
}
function countStatuses(services) {
  const out = { verified: 0, unavailable: 0, researching: 0, needs_medium_review: 0, other: 0 };
  for (const key of SERVICE_KEYS) {
    const status = services?.[key]?.status;
    if (Object.hasOwn(out, status)) out[status] += 1;
    else out.other += 1;
  }
  return out;
}
function addCandidate(store, category, municipality, serviceKey, reasons) {
  const key = `${municipality.code}:${serviceKey}`;
  if (ISSUE_SET.has(key)) return;
  store[category] ??= [];
  if (store[category].some(x => x.code === municipality.code && x.service === serviceKey)) return;
  store[category].push({
    code: municipality.code,
    name: municipality.name,
    prefecture: municipality.prefecture,
    service: serviceKey,
    status: municipality.services?.[serviceKey]?.status ?? null,
    sourceUrl: primarySource(municipality.services?.[serviceKey]),
    reasons: Array.isArray(reasons) ? reasons : [reasons]
  });
}
function hasAny(text, patterns) {
  return patterns.some(p => p.test(text));
}

const municipalities = [];
const structural = [];
for (const [prefCode, prefName] of Object.entries(TARGET_PREFECTURES)) {
  const dir = path.join(MUNICIPALITY_ROOT, prefCode);
  if (!fs.existsSync(dir)) {
    structural.push({ type: 'missing_prefecture_directory', prefectureCode: prefCode });
    continue;
  }
  for (const file of fs.readdirSync(dir).filter(f => /^\d{5}\.json$/.test(f)).sort()) {
    const full = path.join(dir, file);
    const municipality = readJson(full);
    municipalities.push(municipality);
    const fileCode = file.replace('.json', '');
    if (municipality.code !== fileCode) structural.push({ type: 'filename_code_mismatch', file: full, actual: municipality.code });
    if (municipality.prefectureCode !== prefCode) structural.push({ type: 'prefecture_code_mismatch', code: municipality.code, expected: prefCode, actual: municipality.prefectureCode });
    if (municipality.prefecture !== prefName) structural.push({ type: 'prefecture_name_mismatch', code: municipality.code, expected: prefName, actual: municipality.prefecture });
    const keys = Object.keys(municipality.services ?? {});
    const missing = SERVICE_KEYS.filter(k => !keys.includes(k));
    const extra = keys.filter(k => !SERVICE_KEYS.includes(k));
    if (missing.length || extra.length) structural.push({ type: 'service_key_mismatch', code: municipality.code, missing, extra });

    const taskPath = path.join(TASK_ROOT, `${municipality.code}.json`);
    if (!fs.existsSync(taskPath)) {
      structural.push({ type: 'missing_task', code: municipality.code });
      continue;
    }
    const task = readJson(taskPath);
    const counts = countStatuses(municipality.services);
    if (task.municipalityCode !== municipality.code) structural.push({ type: 'task_code_mismatch', code: municipality.code, actual: task.municipalityCode });
    if (task.municipalityName !== municipality.name) structural.push({ type: 'task_name_mismatch', code: municipality.code, expected: municipality.name, actual: task.municipalityName });
    if (task.prefectureCode !== municipality.prefectureCode || task.prefectureName !== municipality.prefecture) structural.push({ type: 'task_prefecture_mismatch', code: municipality.code });
    if (task.status !== 'merged') structural.push({ type: 'task_status_not_merged', code: municipality.code, status: task.status });
    if (task.nextServiceIndex !== 9 || task.currentService !== null) structural.push({ type: 'task_progress_mismatch', code: municipality.code, nextServiceIndex: task.nextServiceIndex, currentService: task.currentService });
    if (!Array.isArray(task.completedServices) || SERVICE_KEYS.some(k => !task.completedServices.includes(k)) || task.completedServices.length !== 9) structural.push({ type: 'task_completed_services_mismatch', code: municipality.code, completedServices: task.completedServices });
    for (const [field, expected] of [['verifiedCount', counts.verified], ['unavailableCount', counts.unavailable], ['researchingCount', counts.researching], ['needsMediumReviewCount', counts.needs_medium_review]]) {
      if (task[field] !== expected) structural.push({ type: 'task_count_mismatch', code: municipality.code, field, expected, actual: task[field] });
    }
    const expectedSources = SERVICE_KEYS.map(k => normalizeUrl(primarySource(municipality.services?.[k])));
    const actualSources = Array.isArray(task.officialSources) ? task.officialSources.map(normalizeUrl) : [];
    if (expectedSources.some((u, i) => u !== actualSources[i]) || actualSources.length !== 9) structural.push({ type: 'task_official_sources_mismatch', code: municipality.code, expectedSources, actualSources });
    const allTerminal = SERVICE_KEYS.every(k => TERMINAL.has(municipality.services?.[k]?.status));
    if (allTerminal && municipality.status !== 'verified') structural.push({ type: 'top_level_status_mismatch', code: municipality.code, status: municipality.status });
    const pagePath = path.join(PAGE_ROOT, municipality.code, 'index.html');
    if (!fs.existsSync(pagePath)) structural.push({ type: 'missing_static_page', code: municipality.code });
    else {
      const html = fs.readFileSync(pagePath, 'utf8');
      if (!html.includes(municipality.name)) structural.push({ type: 'static_page_name_mismatch', code: municipality.code });
      for (const key of SERVICE_KEYS) {
        const summary = municipality.services?.[key]?.summary;
        if (summary && !html.includes(summary)) structural.push({ type: 'static_page_summary_mismatch', code: municipality.code, service: key });
      }
    }
  }
}
municipalities.sort((a, b) => a.code.localeCompare(b.code));

const generated = readJson(GENERATED_PATH);
const generatedMap = new Map((generated.municipalities ?? []).map(x => [x.code, x]));
for (const municipality of municipalities) {
  const generatedItem = generatedMap.get(municipality.code);
  if (!generatedItem) structural.push({ type: 'missing_generated_municipality', code: municipality.code });
  else if (JSON.stringify(generatedItem) !== JSON.stringify(municipality)) structural.push({ type: 'source_generated_mismatch', code: municipality.code });
}

const control = readJson(CONTROL_PATH);
const correctedCodes = [...new Set((control.batches ?? []).flatMap(batch => batch.correctedMunicipalityCodes ?? []))].sort();
const correctedSet = new Set(correctedCodes);
const candidates = {};

for (const municipality of municipalities) {
  for (const serviceKey of SERVICE_KEYS) {
    const service = municipality.services?.[serviceKey] ?? {};
    const text = textOf(service);
    const sourceUrl = primarySource(service);
    const reasons = [];

    if (serviceKey === 'temporaryChildcare') {
      const ordinary = hasAny(text, [/一時預かり/, /一時保育/, /一時的保育/]);
      const anyChild = hasAny(text, [/誰でも通園/, /乳児等通園支援/, /月10時間/, /10時間.*月/, /1時間300円/, /300円.*時間/]);
      if (service.status === 'verified' && ordinary && !anyChild) addCandidate(candidates, 'fy2026AnyChildOmission', municipality, serviceKey, '通常の一時預かり記述はあるが、誰でも通園・乳児等通園支援の記録が見当たらない');
      if (service.status === 'unavailable' && anyChild) addCandidate(candidates, 'verifiedUnavailableRisk', municipality, serviceKey, 'unavailableだが制度固有語が記録内に存在する');
      const missing = [];
      if (anyChild && !hasAny(text, [/生後\d+か月/, /満?\d歳/, /対象/])) missing.push('target');
      if (anyChild && !hasAny(text, [/\d+円/, /無料/, /料金/, /利用料/])) missing.push('fee');
      if (anyChild && !hasAny(text, [/保育園/, /保育所/, /こども園/, /幼稚園/, /施設/])) missing.push('facility');
      if (anyChild && !hasAny(text, [/月10時間/, /利用時間/, /時間まで/, /開始/, /2026年/, /令和8年/])) missing.push('period_or_limit');
      if (missing.length) addCandidate(candidates, 'numericOrConditionCompleteness', municipality, serviceKey, missing.map(x => `誰でも通園の${x}記載不足`));
    }

    if (serviceKey === 'schoolMeals') {
      const onlyAssistance = /就学援助/.test(text) && !hasAny(text, [/一般世帯/, /月額/, /年額/, /1食/, /全額/, /無償/, /保護者負担/, /徴収/]);
      const onlyThirdChild = /第3子/.test(text) && !hasAny(text, [/全児童/, /全生徒/, /全額/, /一般世帯/, /第1子/, /第2子/, /通常/]);
      const lacksScope = !hasAny(text, [/全額/, /無償/, /一部/, /補助/, /月額/, /年額/, /1食/, /保護者負担/, /徴収/]);
      if (onlyAssistance || onlyThirdChild || lacksScope) {
        const r = [];
        if (onlyAssistance) r.push('就学援助だけで一般世帯条件がない');
        if (onlyThirdChild) r.push('第3子以降だけで一般世帯・全体範囲がない');
        if (lacksScope) r.push('無償・部分助成・負担額の区別に必要な記述がない');
        addCandidate(candidates, 'schoolMealScopeAmbiguity', municipality, serviceKey, r);
      }
    }

    if (serviceKey === 'postpartumCare' && service.status === 'verified') {
      const missing = [];
      if (!hasAny(text, [/\d+円/, /無料/, /料金/, /自己負担/])) missing.push('fee');
      if (!hasAny(text, [/\d+回/, /\d+日/, /上限/, /以内/])) missing.push('limit');
      if (!hasAny(text, [/産後\d+/, /生後\d+/, /1年以内/, /月未満/])) missing.push('target_period');
      if (missing.length >= 2) addCandidate(candidates, 'numericOrConditionCompleteness', municipality, serviceKey, missing.map(x => `産後ケアの${x}記載不足`));
    }

    if (serviceKey === 'housingSupport' && service.status === 'verified') {
      const general = hasAny(text, [/耐震/, /空き家/, /移住/, /定住/, /住宅取得/, /改修/, /リフォーム/]);
      const childSpecific = hasAny(text, [/子育て/, /若年/, /新婚/, /多子/, /三世代/, /18歳以下/, /子ども/]);
      if (general && !childSpecific) addCandidate(candidates, 'generalHousingMisclassification', municipality, serviceKey, '一般住宅・耐震・空き家・移住支援のみで子育て固有条件が見当たらない');
    }

    if (service.status === 'verified' && HIGH_RISK.has(serviceKey)) {
      if (!sourceUrl) reasons.push('主出典URLなし');
      if (sourceUrl && isRootUrl(sourceUrl)) reasons.push('自治体トップページが主出典');
      if (sourceUrl && /(?:reiki|条例|jourei|計画|keikaku|plan|yosan|予算|議案|gian)/i.test(sourceUrl)) reasons.push('条例・計画・予算・議案URLが主出典候補');
      if (reasons.length) addCandidate(candidates, 'weakPrimarySource', municipality, serviceKey, reasons);
    }

    const checkedAt = service?.source?.checkedAt ?? '';
    const fy2025Only = hasAny(text, [/2025年度/, /令和7年度/, /令和7年4月/]) && !hasAny(text, [/2026年度/, /令和8年度/, /令和8年4月/]);
    if ((checkedAt && checkedAt.startsWith('2025-')) || fy2025Only) addCandidate(candidates, 'fiscalYearRisk', municipality, serviceKey, checkedAt.startsWith('2025-') ? '主出典確認日が2025年' : '2025年度記述のみで2026年度記述がない');

    const eligibility = service?.eligibility ?? {};
    if (typeof eligibility.maxAgeYears === 'number' && eligibility.maxAgeYears > 30 && serviceKey !== 'housingSupport') addCandidate(candidates, 'numericOrConditionCompleteness', municipality, serviceKey, `maxAgeYears=${eligibility.maxAgeYears}が制度種別として異常値候補`);
    if (typeof eligibility.minAgeMonths === 'number' && eligibility.minAgeMonths < 0) addCandidate(candidates, 'numericOrConditionCompleteness', municipality, serviceKey, `minAgeMonths=${eligibility.minAgeMonths}が負値`);
  }
}

const candidatePairs = new Set(Object.values(candidates).flat().map(x => `${x.code}:${x.service}`));
const urlTargets = new Map();
function addUrlTarget(code, service, url, reason) {
  if (!url) return;
  const normalized = normalizeUrl(url);
  if (!/^https?:\/\//.test(normalized)) return;
  if (!urlTargets.has(normalized)) urlTargets.set(normalized, { url: normalized, references: [] });
  urlTargets.get(normalized).references.push({ code, service, reason });
}
for (const municipality of municipalities) {
  for (const serviceKey of SERVICE_KEYS) {
    const shouldCheck = correctedSet.has(municipality.code) || candidatePairs.has(`${municipality.code}:${serviceKey}`) || ISSUE_SET.has(`${municipality.code}:${serviceKey}`);
    if (shouldCheck) addUrlTarget(municipality.code, serviceKey, primarySource(municipality.services?.[serviceKey]), correctedSet.has(municipality.code) ? 'past_corrected_recheck' : (ISSUE_SET.has(`${municipality.code}:${serviceKey}`) ? 'issue_3141_recheck' : 'cause_candidate_recheck'));
  }
}

const KEYWORDS = {
  childMedical: /医療|助成|受給者証/,
  sickChildCare: /病児|病後児/,
  childcareFee: /保育料|利用者負担/,
  schoolMeals: /給食/,
  postpartumCare: /産後ケア|産後支援/,
  temporaryChildcare: /誰でも通園|乳児等通園|一時預かり|一時保育/,
  housingSupport: /住宅|空き家|耐震|住まい|移住|定住/,
  bulkyWaste: /粗大ごみ|大型ごみ|ごみ/,
  disasterPrevention: /防災|ハザード|避難/
};
async function checkUrl(target) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 15000);
  try {
    const response = await fetch(target.url, {
      redirect: 'follow',
      signal: controller.signal,
      headers: { 'user-agent': 'jichitai-compare-quality-audit/1.0 (+GitHub Actions)' }
    });
    const contentType = response.headers.get('content-type') ?? '';
    let body = '';
    if (/text\/(html|plain)|application\/(json|xml)/i.test(contentType)) body = (await response.text()).slice(0, 500000);
    const keywordResults = {};
    for (const ref of target.references) {
      const k = `${ref.code}:${ref.service}`;
      if (!(k in keywordResults)) keywordResults[k] = body ? KEYWORDS[ref.service].test(body) : null;
    }
    return {
      url: target.url,
      host: officialHost(target.url),
      ok: response.ok,
      status: response.status,
      finalUrl: response.url,
      contentType,
      keywordResults,
      references: target.references
    };
  } catch (error) {
    return { url: target.url, host: officialHost(target.url), ok: false, status: null, error: String(error?.name === 'AbortError' ? 'timeout' : error), references: target.references };
  } finally {
    clearTimeout(timer);
  }
}
async function mapLimit(items, limit, fn) {
  const results = new Array(items.length);
  let cursor = 0;
  async function worker() {
    while (true) {
      const index = cursor++;
      if (index >= items.length) return;
      results[index] = await fn(items[index]);
    }
  }
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker));
  return results;
}
const officialChecks = await mapLimit([...urlTargets.values()], 12, checkUrl);

const correctedMunicipalityCoverage = correctedCodes.map(code => {
  const municipality = municipalities.find(x => x.code === code);
  const refs = officialChecks.flatMap(x => x.references?.filter(r => r.code === code).map(r => ({ ...r, url: x.url, ok: x.ok, status: x.status, finalUrl: x.finalUrl, error: x.error })) ?? []);
  return {
    code,
    name: municipality?.name ?? null,
    sourceCountExpected: 9,
    sourceCountChecked: refs.length,
    reachableCount: refs.filter(x => x.ok).length,
    nonReachable: refs.filter(x => !x.ok)
  };
});

const candidateCounts = Object.fromEntries(Object.entries(candidates).map(([k, v]) => [k, v.length]));
const report = {
  schemaVersion: '1.0.0',
  auditId: 'central-a-cause-based-rescan-20260725',
  generatedAt: new Date().toISOString(),
  session: '中日本調査班A',
  baseBranch: 'region/central',
  scope: {
    prefectureCodes: Object.keys(TARGET_PREFECTURES),
    municipalityCount: municipalities.length,
    serviceCount: municipalities.length * SERVICE_KEYS.length,
    expectedMunicipalityCount: 314,
    expectedServiceCount: 2826
  },
  policy: [
    '過去訂正原因を機械条件へ変換し、同種誤り候補を全314自治体から抽出する',
    'Issue #3141の23項目は利用者向け公式条件が揃うまで自動確定しない',
    '条例・計画・予算・議案のみで利用可能制度と断定しない',
    '候補抽出だけではデータ変更せず、公式情報で確定した項目だけ修正する'
  ],
  issue3141: {
    issueNumber: 3141,
    pendingItemCount: ISSUE_3141.length,
    items: ISSUE_3141,
    excludedFromAutomaticConfirmation: true
  },
  previousAudit: {
    campaignFile: CONTROL_PATH,
    correctedMunicipalityCount: correctedCodes.length,
    correctedMunicipalityCodes: correctedCodes,
    officialSourceRecheck: correctedMunicipalityCoverage
  },
  structuralAudit: {
    findingCount: structural.length,
    findings: structural
  },
  causeCandidates: {
    counts: candidateCounts,
    categories: candidates
  },
  officialUrlRecheck: {
    uniqueUrlCount: officialChecks.length,
    reachableCount: officialChecks.filter(x => x.ok).length,
    nonReachableCount: officialChecks.filter(x => !x.ok).length,
    results: officialChecks
  },
  nextAction: '構造不整合は即時修正し、原因候補は自治体公式の利用者向けページで確定確認する。Issue #3141は公開条件が揃った項目のみ解消する。'
};
fs.mkdirSync(path.dirname(REPORT_PATH), { recursive: true });
fs.writeFileSync(REPORT_PATH, `${JSON.stringify(report, null, 2)}\n`);
console.log(JSON.stringify({
  report: REPORT_PATH,
  municipalityCount: report.scope.municipalityCount,
  serviceCount: report.scope.serviceCount,
  structuralFindingCount: structural.length,
  correctedMunicipalityCount: correctedCodes.length,
  candidateCounts,
  officialUrlReachable: report.officialUrlRecheck.reachableCount,
  officialUrlNonReachable: report.officialUrlRecheck.nonReachableCount
}, null, 2));
