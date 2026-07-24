import { access, readFile, writeFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const PROJECT_DIR = resolve(SCRIPT_DIR, '..');
const AUDIT_PATH = join(PROJECT_DIR, 'operations', 'audits', 'central-b-accuracy-audit-20260725.json');
const DEFINITIONS_PATH = join(PROJECT_DIR, 'data', 'service-definitions.json');
const OUTPUT_PATH = join(PROJECT_DIR, 'operations', 'audits', 'central-b-accuracy-round-output.json');
const VALID_STATUSES = new Set(['verified', 'unavailable']);
const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;
const DATETIME_PATTERN = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:Z|[+-]\d{2}:\d{2})$/;

const audit = JSON.parse(await readFile(AUDIT_PATH, 'utf8'));
const definitions = JSON.parse(await readFile(DEFINITIONS_PATH, 'utf8')).services ?? [];
const expectedServices = definitions.map((item) => item.id);
const ageRangeServices = new Set(
  definitions.filter((item) => item.eligibilityRule === 'ageRange').map((item) => item.id)
);
const batch = audit.batches.find((item) => item.status === 'in_progress');

if (!batch) {
  const result = { status: 'waiting', message: 'in_progress の監査バッチはありません' };
  await writeFile(OUTPUT_PATH, JSON.stringify(result, null, 2) + '\n', 'utf8');
  console.log(JSON.stringify(result, null, 2));
  process.exit(0);
}

const errors = [];
const warnings = [];
const rows = [];

for (const code of batch.codes) {
  const prefectureCode = code.slice(0, 2);
  const municipalityPath = join(PROJECT_DIR, 'data', 'municipalities', prefectureCode, `${code}.json`);
  const taskPath = join(PROJECT_DIR, 'operations', 'tasks', `${code}.json`);

  for (const [label, path] of [['自治体JSON', municipalityPath], ['task', taskPath]]) {
    try {
      await access(path);
    } catch {
      errors.push(`${code}: ${label}が存在しません`);
    }
  }
  if (errors.some((message) => message.startsWith(`${code}:`) && message.includes('存在しません'))) continue;

  let municipality;
  let task;
  try {
    municipality = JSON.parse(await readFile(municipalityPath, 'utf8'));
    task = JSON.parse(await readFile(taskPath, 'utf8'));
  } catch (cause) {
    errors.push(`${code}: JSON解析失敗 ${cause.message}`);
    continue;
  }

  if (municipality.code !== code) errors.push(`${code}: municipality.code不一致 ${municipality.code}`);
  if (municipality.prefectureCode !== prefectureCode) errors.push(`${code}: prefectureCode不一致 ${municipality.prefectureCode}`);
  if (!municipality.name || typeof municipality.name !== 'string') errors.push(`${code}: 自治体名がありません`);
  if (!/^https:\/\//u.test(municipality.officialUrl ?? '')) errors.push(`${code}: officialUrlがHTTPSではありません`);
  if (!DATE_PATTERN.test(municipality.updatedAt ?? '')) errors.push(`${code}: updatedAt形式不正 ${municipality.updatedAt}`);
  if (!municipality.summary || typeof municipality.summary !== 'string') errors.push(`${code}: summaryがありません`);

  const serviceKeys = Object.keys(municipality.services ?? {});
  for (const key of expectedServices) {
    if (!serviceKeys.includes(key)) errors.push(`${code}: 制度 ${key} がありません`);
  }
  for (const key of serviceKeys) {
    if (!expectedServices.includes(key)) warnings.push(`${code}: 想定外制度キー ${key}`);
  }

  let verified = 0;
  let unavailable = 0;
  const primarySources = [];
  for (const key of expectedServices) {
    const service = municipality.services?.[key];
    if (!service) continue;
    if (!VALID_STATUSES.has(service.status)) {
      errors.push(`${code}/${key}: status不正 ${service.status}`);
      continue;
    }
    if (service.status === 'verified') verified += 1;
    if (service.status === 'unavailable') unavailable += 1;
    if (!service.summary || typeof service.summary !== 'string') errors.push(`${code}/${key}: summaryがありません`);
    if (!/^https:\/\//u.test(service.source?.url ?? '')) errors.push(`${code}/${key}: source.urlがHTTPSではありません`);
    else primarySources.push(service.source.url);
    if (!DATE_PATTERN.test(service.source?.checkedAt ?? '')) errors.push(`${code}/${key}: checkedAt形式不正 ${service.source?.checkedAt}`);

    if (service.status === 'verified' && ageRangeServices.has(key)) {
      const minMonths = service.eligibility?.minAgeMonths;
      const maxYears = service.eligibility?.maxAgeYears;
      if (!Number.isInteger(minMonths) || minMonths < 0 || minMonths > 216) {
        errors.push(`${code}/${key}: verifiedのminAgeMonths不正 ${minMonths}`);
      }
      if (!Number.isInteger(maxYears) || maxYears < 0 || maxYears > 120) {
        errors.push(`${code}/${key}: verifiedのmaxAgeYears不正 ${maxYears}`);
      }
    }

    if (/令和[1-7]年度|202[0-5]年度/u.test(service.summary) && service.source?.checkedAt >= '2026-04-01') {
      warnings.push(`${code}/${key}: 過年度表現を現行制度として扱っていないか要確認「${service.summary}」`);
    }
    if (service.status === 'verified' && /確認できない|不明|要確認/u.test(service.summary)) {
      warnings.push(`${code}/${key}: verified要約に未確認表現があります「${service.summary}」`);
    }
  }

  if (verified + unavailable !== expectedServices.length) {
    errors.push(`${code}: verified+unavailableが${expectedServices.length}ではありません (${verified}+${unavailable})`);
  }

  if (task.municipalityCode !== code) errors.push(`${code}: task municipalityCode不一致 ${task.municipalityCode}`);
  if (task.municipalityName !== municipality.name) errors.push(`${code}: task municipalityName不一致`);
  if (task.prefectureCode !== prefectureCode) errors.push(`${code}: task prefectureCode不一致`);
  if (task.assignedTeam !== '中日本調査班') errors.push(`${code}: task assignedTeam不一致 ${task.assignedTeam}`);
  if (!['merged', 'pr_open'].includes(task.status)) warnings.push(`${code}: task.status要確認 ${task.status}`);
  if (!DATE_PATTERN.test(task.lastCheckedAt ?? '')) errors.push(`${code}: task.lastCheckedAt形式不正 ${task.lastCheckedAt}`);
  if (!DATETIME_PATTERN.test(task.lastUpdatedAt ?? '')) errors.push(`${code}: task.lastUpdatedAt形式不正 ${task.lastUpdatedAt}`);
  if (task.verifiedCount !== verified) errors.push(`${code}: task verifiedCount不一致 ${task.verifiedCount}/${verified}`);
  if (task.unavailableCount !== unavailable) errors.push(`${code}: task unavailableCount不一致 ${task.unavailableCount}/${unavailable}`);
  if (task.researchingCount !== 0) errors.push(`${code}: task researchingCountが0ではありません ${task.researchingCount}`);
  if (task.needsMediumReviewCount !== 0) errors.push(`${code}: task needsMediumReviewCountが0ではありません ${task.needsMediumReviewCount}`);
  if (task.nextServiceIndex !== expectedServices.length || task.currentService !== null) {
    errors.push(`${code}: task完了位置が不正 next=${task.nextServiceIndex} current=${task.currentService}`);
  }
  if (JSON.stringify(task.completedServices) !== JSON.stringify(expectedServices)) {
    errors.push(`${code}: task.completedServicesが9制度順序と一致しません`);
  }
  if (JSON.stringify(task.officialSources) !== JSON.stringify([...new Set(primarySources)])) {
    errors.push(`${code}: task.officialSourcesが制度主出典の再計算値と一致しません`);
  }

  rows.push({
    code,
    name: municipality.name,
    verified,
    unavailable,
    updatedAt: municipality.updatedAt,
    taskStatus: task.status
  });
}

const result = {
  round: batch.round,
  codes: batch.codes,
  checkedMunicipalities: rows.length,
  rows,
  errorCount: errors.length,
  warningCount: warnings.length,
  errors,
  warnings
};

await writeFile(OUTPUT_PATH, JSON.stringify(result, null, 2) + '\n', 'utf8');
console.log(JSON.stringify(result, null, 2));

if (errors.length > 0) process.exit(1);
