import { access, readdir, readFile } from 'node:fs/promises';
import { basename, dirname, extname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const PROJECT_DIR = resolve(SCRIPT_DIR, '..');
const SOURCE_DIR = join(PROJECT_DIR, 'data', 'municipalities');
const TASK_DIR = join(PROJECT_DIR, 'operations', 'tasks');
const DEFINITIONS_FILE = join(PROJECT_DIR, 'data', 'service-definitions.json');
const GENERATED_FILE = join(PROJECT_DIR, 'data', 'generated', 'municipalities.json');
const LEGACY_FILE = join(PROJECT_DIR, 'data', 'municipalities.json');

const REQUIRE_GENERATED = process.argv.includes('--require-generated');
const ALLOWED_STATUSES = new Set([
  'todo',
  'researching',
  'verified',
  'unavailable',
  'needs_medium_review',
  'needs_revision',
  'needs_coordinator',
  'pr_open',
  'merged',
  'blocked'
]);
const SERVICE_WORK_STATUSES = new Set([
  'todo',
  'researching',
  'verified',
  'unavailable',
  'needs_medium_review',
  'needs_revision',
  'needs_coordinator',
  'blocked'
]);
const COMPLETED_STATUSES = new Set(['verified', 'unavailable']);
const ALLOWED_RULES = new Set(['ageRange', 'informational']);
const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;
const DATETIME_PATTERN = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:Z|[+-]\d{2}:\d{2})$/;
const TEAM_BY_PREFECTURE = new Map([
  ...range(1, 7).map((code) => [code, '北日本調査班']),
  ...range(8, 15).map((code) => [code, '東日本調査班']),
  [19, '東日本調査班'],
  [20, '東日本調査班'],
  ...range(16, 18).map((code) => [code, '中日本調査班']),
  ...range(21, 30).map((code) => [code, '中日本調査班']),
  ...range(31, 47).map((code) => [code, '西日本調査班'])
]);

let errors = 0;
let warnings = 0;

function range(start, end) {
  return Array.from({ length: end - start + 1 }, (_, index) => start + index);
}

function error(message) {
  console.error(`ERROR: ${message}`);
  errors += 1;
}

function warn(message) {
  console.warn(`WARN: ${message}`);
  warnings += 1;
}

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function isHttpsUrl(value) {
  return typeof value === 'string' && /^https:\/\/\S+$/u.test(value);
}

function isNonEmptyString(value) {
  return typeof value === 'string' && value.trim().length > 0;
}

async function exists(path) {
  try {
    await access(path);
    return true;
  } catch {
    return false;
  }
}

async function readJson(path, label) {
  try {
    return JSON.parse(await readFile(path, 'utf8'));
  } catch (cause) {
    error(`${label}: JSONを読み込めません: ${cause.message}`);
    return null;
  }
}

async function collectJsonFiles(directory) {
  if (!await exists(directory)) {
    error(`${relative(PROJECT_DIR, directory)}: ディレクトリがありません`);
    return [];
  }

  const entries = await readdir(directory, { withFileTypes: true });
  const files = [];
  for (const entry of entries.sort((a, b) => a.name.localeCompare(b.name, 'ja'))) {
    const fullPath = join(directory, entry.name);
    if (entry.isDirectory()) {
      files.push(...await collectJsonFiles(fullPath));
    } else if (entry.isFile() && extname(entry.name) === '.json') {
      files.push(fullPath);
    }
  }
  return files;
}

function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical);
  if (!isPlainObject(value)) return value;
  return Object.fromEntries(
    Object.entries(value)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([key, child]) => [key, canonical(child)])
  );
}

function sameJson(left, right) {
  return JSON.stringify(canonical(left)) === JSON.stringify(canonical(right));
}

function publicMunicipality(municipality) {
  const { schemaVersion: _schemaVersion, updatedAt: _updatedAt, ...publicData } = municipality;
  return publicData;
}

function validateDefinitions(definitionsData) {
  const ids = [];
  if (!isPlainObject(definitionsData) || !Array.isArray(definitionsData.services) || definitionsData.services.length === 0) {
    error('data/service-definitions.json: servicesが空または不正です');
    return ids;
  }

  const seen = new Set();
  for (const definition of definitionsData.services) {
    const id = definition?.id ?? '(IDなし)';
    for (const field of ['id', 'label', 'category', 'eligibilityRule', 'detailFields']) {
      if (!(field in (definition ?? {}))) error(`制度定義 ${id}: ${field}がありません`);
    }
    if (!isNonEmptyString(definition?.id)) error(`制度定義 ${id}: idが空です`);
    if (seen.has(definition?.id)) error(`制度IDが重複しています: ${definition.id}`);
    seen.add(definition?.id);
    ids.push(definition?.id);
    if (!ALLOWED_RULES.has(definition?.eligibilityRule)) {
      error(`制度定義 ${id}: 未対応のeligibilityRuleです: ${definition?.eligibilityRule}`);
    }
    if (!Array.isArray(definition?.detailFields)) error(`制度定義 ${id}: detailFieldsは配列にしてください`);
  }

  if (ids.length !== 9) error(`制度定義数は9件必要です: 実際=${ids.length}`);
  return ids;
}

function validateService(service, serviceId, municipalityName, definition) {
  const label = `${municipalityName} / ${serviceId}`;
  if (!isPlainObject(service)) {
    error(`${label}: 制度データはオブジェクトにしてください`);
    return;
  }
  if (!ALLOWED_STATUSES.has(service.status)) error(`${label}: 未許可statusです: ${service.status}`);
  if (!SERVICE_WORK_STATUSES.has(service.status)) warn(`${label}: 制度単位では通常使用しないstatusです: ${service.status}`);
  if (!isNonEmptyString(service.summary)) error(`${label}: summaryがありません`);

  if (service.status === 'verified' || service.status === 'unavailable') {
    if (!isHttpsUrl(service.source?.url)) error(`${label}: ${service.status}には公式HTTPS source.urlが必要です`);
    if (!DATE_PATTERN.test(service.source?.checkedAt ?? '')) error(`${label}: source.checkedAtはYYYY-MM-DD形式にしてください`);
  }

  if (service.status === 'verified' && definition?.eligibilityRule === 'ageRange') {
    const min = service.eligibility?.minAgeMonths;
    const max = service.eligibility?.maxAgeYears;
    if (!Number.isInteger(min) || min < 0) error(`${label}: eligibility.minAgeMonthsが不正です`);
    if (!Number.isInteger(max) || max < 0 || max > 120) error(`${label}: eligibility.maxAgeYearsが不正です`);
  }

  if (service.additionalSources !== undefined) {
    if (!Array.isArray(service.additionalSources)) {
      error(`${label}: additionalSourcesは配列にしてください`);
    } else {
      service.additionalSources.forEach((source, index) => {
        if (!isHttpsUrl(source?.url)) error(`${label}: additionalSources[${index}].urlはHTTPSにしてください`);
        if (!DATE_PATTERN.test(source?.checkedAt ?? '')) error(`${label}: additionalSources[${index}].checkedAtが不正です`);
      });
    }
  }

  if (service.notes !== undefined && !Array.isArray(service.notes)) error(`${label}: notesは配列にしてください`);
}

function validateMunicipality(municipality, filePath, definitions, seenCodes) {
  const relativePath = relative(PROJECT_DIR, filePath).replaceAll('\\', '/');
  if (!isPlainObject(municipality)) {
    error(`${relativePath}: JSONのルートはオブジェクトにしてください`);
    return null;
  }

  for (const field of [
    'schemaVersion',
    'code',
    'prefectureCode',
    'prefecture',
    'name',
    'officialUrl',
    'status',
    'summary',
    'updatedAt',
    'services'
  ]) {
    if (!(field in municipality)) error(`${relativePath}: ${field}がありません`);
  }

  if (municipality.schemaVersion !== '1.0.0') error(`${relativePath}: schemaVersionは1.0.0にしてください`);
  if (!/^\d{5}$/.test(municipality.code ?? '')) error(`${relativePath}: codeは5桁の数字文字列にしてください`);
  if (!/^\d{2}$/.test(municipality.prefectureCode ?? '')) error(`${relativePath}: prefectureCodeは2桁の数字文字列にしてください`);
  if (basename(filePath, '.json') !== municipality.code) error(`${relativePath}: ファイル名と自治体コードが一致しません`);
  if (basename(dirname(filePath)) !== municipality.prefectureCode) error(`${relativePath}: 親ディレクトリと都道府県コードが一致しません`);
  if (seenCodes.has(municipality.code)) error(`${relativePath}: 自治体コードが重複しています: ${municipality.code}`);
  seenCodes.add(municipality.code);
  if (!isNonEmptyString(municipality.prefecture)) error(`${relativePath}: prefectureが空です`);
  if (!isNonEmptyString(municipality.name)) error(`${relativePath}: nameが空です`);
  if (!isHttpsUrl(municipality.officialUrl)) error(`${relativePath}: officialUrlはHTTPSにしてください`);
  if (!ALLOWED_STATUSES.has(municipality.status)) error(`${relativePath}: 未許可statusです: ${municipality.status}`);
  if (!isNonEmptyString(municipality.summary)) error(`${relativePath}: summaryが空です`);
  if (!DATE_PATTERN.test(municipality.updatedAt ?? '')) error(`${relativePath}: updatedAtはYYYY-MM-DD形式にしてください`);
  if (!isPlainObject(municipality.services)) error(`${relativePath}: servicesはオブジェクトにしてください`);

  const expectedIds = definitions.map((definition) => definition.id);
  const actualIds = Object.keys(municipality.services ?? {});
  for (const id of expectedIds) {
    if (!(id in (municipality.services ?? {}))) error(`${relativePath}: services.${id}がありません`);
  }
  for (const id of actualIds) {
    if (!expectedIds.includes(id)) error(`${relativePath}: 未定義の制度IDがあります: ${id}`);
  }

  const definitionMap = new Map(definitions.map((definition) => [definition.id, definition]));
  for (const [serviceId, service] of Object.entries(municipality.services ?? {})) {
    validateService(service, serviceId, municipality.name ?? relativePath, definitionMap.get(serviceId));
  }

  return municipality;
}

function calculateTaskState(municipality, orderedServiceIds) {
  const entries = orderedServiceIds.map((id) => [id, municipality.services[id]]);
  const completedServices = entries
    .filter(([, service]) => COMPLETED_STATUSES.has(service?.status))
    .map(([id]) => id);
  const count = (status) => entries.filter(([, service]) => service?.status === status).length;
  const nextServiceIndex = entries.findIndex(([, service]) => !COMPLETED_STATUSES.has(service?.status));
  const normalizedNextIndex = nextServiceIndex === -1 ? orderedServiceIds.length : nextServiceIndex;
  const officialSources = entries
    .filter(([, service]) => COMPLETED_STATUSES.has(service?.status) && isHttpsUrl(service?.source?.url))
    .map(([, service]) => service.source.url);

  return {
    completedServices,
    verifiedCount: count('verified'),
    researchingCount: count('researching'),
    unavailableCount: count('unavailable'),
    needsMediumReviewCount: count('needs_medium_review'),
    nextServiceIndex: normalizedNextIndex,
    currentService: orderedServiceIds[normalizedNextIndex] ?? null,
    officialSources: [...new Set(officialSources)]
  };
}

function validateTask(task, filePath, municipality, orderedServiceIds) {
  const relativePath = relative(PROJECT_DIR, filePath).replaceAll('\\', '/');
  if (!isPlainObject(task)) {
    error(`${relativePath}: JSONのルートはオブジェクトにしてください`);
    return;
  }

  for (const field of [
    'schemaVersion',
    'municipalityCode',
    'municipalityName',
    'prefectureCode',
    'prefectureName',
    'assignedTeam',
    'status',
    'currentService',
    'nextServiceIndex',
    'completedServices',
    'verifiedCount',
    'researchingCount',
    'unavailableCount',
    'needsMediumReviewCount',
    'currentBranch',
    'pullRequestNumber',
    'lastCheckedAt',
    'lastUpdatedAt',
    'lastUpdatedBy',
    'officialSources',
    'notes',
    'blockers'
  ]) {
    if (!(field in task)) error(`${relativePath}: ${field}がありません`);
  }

  if (task.schemaVersion !== '1.0.0') error(`${relativePath}: schemaVersionは1.0.0にしてください`);
  if (basename(filePath, '.json') !== task.municipalityCode) error(`${relativePath}: ファイル名とmunicipalityCodeが一致しません`);
  if (!municipality) {
    error(`${relativePath}: 対応する自治体ファイルがありません`);
    return;
  }

  if (task.municipalityCode !== municipality.code) error(`${relativePath}: municipalityCodeが自治体データと一致しません`);
  if (task.municipalityName !== municipality.name) error(`${relativePath}: municipalityNameが自治体データと一致しません`);
  if (task.prefectureCode !== municipality.prefectureCode) error(`${relativePath}: prefectureCodeが自治体データと一致しません`);
  if (task.prefectureName !== municipality.prefecture) error(`${relativePath}: prefectureNameが自治体データと一致しません`);
  if (!ALLOWED_STATUSES.has(task.status)) error(`${relativePath}: 未許可statusです: ${task.status}`);

  const expectedTeam = TEAM_BY_PREFECTURE.get(Number(task.prefectureCode));
  if (!expectedTeam) error(`${relativePath}: 都道府県コードの担当班を判定できません: ${task.prefectureCode}`);
  if (task.assignedTeam !== expectedTeam) error(`${relativePath}: assignedTeamが不正です: 期待=${expectedTeam}, 実際=${task.assignedTeam}`);

  if (!DATE_PATTERN.test(task.lastCheckedAt ?? '')) error(`${relativePath}: lastCheckedAtはYYYY-MM-DD形式にしてください`);
  if (!DATETIME_PATTERN.test(task.lastUpdatedAt ?? '')) error(`${relativePath}: lastUpdatedAtはタイムゾーン付きISO形式にしてください`);
  if (!isNonEmptyString(task.lastUpdatedBy)) error(`${relativePath}: lastUpdatedByが空です`);
  for (const field of ['completedServices', 'officialSources', 'notes', 'blockers']) {
    if (!Array.isArray(task[field])) error(`${relativePath}: ${field}は配列にしてください`);
  }
  for (const [index, url] of (task.officialSources ?? []).entries()) {
    if (!isHttpsUrl(url)) error(`${relativePath}: officialSources[${index}]はHTTPS URLにしてください`);
  }

  const expected = calculateTaskState(municipality, orderedServiceIds);
  for (const field of [
    'completedServices',
    'verifiedCount',
    'researchingCount',
    'unavailableCount',
    'needsMediumReviewCount',
    'nextServiceIndex',
    'currentService',
    'officialSources'
  ]) {
    if (!sameJson(task[field], expected[field])) {
      error(`${relativePath}: ${field}が自治体データの再計算値と一致しません: 期待=${JSON.stringify(expected[field])}, 実際=${JSON.stringify(task[field])}`);
    }
  }
}

async function validateGenerated(sourceMunicipalities) {
  const generatedExists = await exists(GENERATED_FILE);
  if (!generatedExists) {
    if (REQUIRE_GENERATED) error('data/generated/municipalities.jsonがありません');
    else warn('data/generated/municipalities.jsonは未生成です。npm run generate後に再検証してください');
    return;
  }

  const generated = await readJson(GENERATED_FILE, 'data/generated/municipalities.json');
  if (!generated) return;
  const expectedMunicipalities = sourceMunicipalities
    .map(publicMunicipality)
    .sort((a, b) => a.code.localeCompare(b.code));
  const expectedUpdatedAt = sourceMunicipalities.map((item) => item.updatedAt).sort().at(-1);

  if (!Array.isArray(generated.municipalities)) error('generated: municipalitiesは配列にしてください');
  if (generated.meta?.version !== '1.0.0') error(`generated: meta.versionは1.0.0にしてください: ${generated.meta?.version}`);
  if (generated.meta?.updatedAt !== expectedUpdatedAt) error(`generated: meta.updatedAtが不正です: 期待=${expectedUpdatedAt}, 実際=${generated.meta?.updatedAt}`);
  if (generated.meta?.municipalityCount !== sourceMunicipalities.length) {
    error(`generated: municipalityCountが不正です: 期待=${sourceMunicipalities.length}, 実際=${generated.meta?.municipalityCount}`);
  }
  if (!sameJson(generated.municipalities, expectedMunicipalities)) {
    error('generated: 自治体配列が自治体別元データと一致しません');
  }
}

async function validateLegacy(sourceMunicipalities) {
  if (!await exists(LEGACY_FILE)) return;
  const legacy = await readJson(LEGACY_FILE, 'data/municipalities.json');
  if (!legacy || !Array.isArray(legacy.municipalities)) {
    error('legacy: municipalitiesは配列にしてください');
    return;
  }
  const expected = sourceMunicipalities
    .map(publicMunicipality)
    .sort((a, b) => a.code.localeCompare(b.code));
  const actual = [...legacy.municipalities].sort((a, b) => a.code.localeCompare(b.code));
  if (!sameJson(actual, expected)) {
    error('legacy: 既存一括JSONと自治体別元データの内容が一致しません');
  }
}

async function main() {
  const definitionsData = await readJson(DEFINITIONS_FILE, 'data/service-definitions.json');
  const serviceIds = validateDefinitions(definitionsData);
  const definitions = definitionsData?.services ?? [];

  const municipalityFiles = await collectJsonFiles(SOURCE_DIR);
  const municipalitiesByCode = new Map();
  const seenCodes = new Set();
  for (const filePath of municipalityFiles) {
    const municipality = await readJson(filePath, relative(PROJECT_DIR, filePath));
    if (!municipality) continue;
    const validated = validateMunicipality(municipality, filePath, definitions, seenCodes);
    if (validated?.code) municipalitiesByCode.set(validated.code, validated);
  }
  if (municipalitiesByCode.size === 0) error('自治体別JSONが1件もありません');

  const taskFiles = await collectJsonFiles(TASK_DIR);
  const taskCodes = new Set();
  for (const filePath of taskFiles) {
    const task = await readJson(filePath, relative(PROJECT_DIR, filePath));
    if (!task) continue;
    if (task.municipalityCode) taskCodes.add(task.municipalityCode);
    validateTask(task, filePath, municipalitiesByCode.get(task.municipalityCode), serviceIds);
  }

  for (const code of municipalitiesByCode.keys()) {
    if (!taskCodes.has(code)) error(`operations/tasks/${code}.jsonがありません`);
  }
  for (const code of taskCodes) {
    if (!municipalitiesByCode.has(code)) error(`operations/tasks/${code}.jsonに対応する自治体ファイルがありません`);
  }

  const sourceMunicipalities = [...municipalitiesByCode.values()].sort((a, b) => a.code.localeCompare(b.code));
  await validateLegacy(sourceMunicipalities);
  await validateGenerated(sourceMunicipalities);

  if (errors) {
    console.error(`検証失敗: ${errors}件のエラー、${warnings}件の警告`);
    process.exitCode = 1;
    return;
  }
  console.log(`検証成功: ${sourceMunicipalities.length}自治体・${serviceIds.length}制度・${taskFiles.length}進捗ファイル（警告${warnings}件）`);
}

main().catch((cause) => {
  console.error(cause);
  process.exitCode = 1;
});
