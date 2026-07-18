import { readFile } from 'node:fs/promises';

const municipalitiesRaw = await readFile(new URL('../data/municipalities.json', import.meta.url), 'utf8');
const definitionsRaw = await readFile(new URL('../data/service-definitions.json', import.meta.url), 'utf8');
const municipalitiesData = JSON.parse(municipalitiesRaw);
const definitionsData = JSON.parse(definitionsRaw);

const requiredMunicipalityFields = ['code', 'prefectureCode', 'prefecture', 'name', 'officialUrl', 'services'];
const requiredDefinitionFields = ['id', 'label', 'category', 'eligibilityRule', 'detailFields'];
const allowedStatuses = new Set(['verified', 'researching', 'unavailable']);
const allowedRules = new Set(['ageRange', 'informational']);
const datePattern = /^\d{4}-\d{2}-\d{2}$/;
const municipalityCodes = new Set();
const definitionIds = new Set();
let errors = 0;

function error(message) {
  console.error(message);
  errors += 1;
}

function isHttpsUrl(value) {
  return typeof value === 'string' && value.startsWith('https://');
}

if (!Array.isArray(definitionsData.services) || !definitionsData.services.length) {
  error('service-definitions.json: services が空です');
}

for (const definition of definitionsData.services ?? []) {
  for (const field of requiredDefinitionFields) {
    if (!(field in definition)) error(`制度定義 ${definition.id ?? '(IDなし)'}: ${field} がありません`);
  }
  if (definitionIds.has(definition.id)) error(`制度IDが重複しています: ${definition.id}`);
  definitionIds.add(definition.id);
  if (!allowedRules.has(definition.eligibilityRule)) {
    error(`${definition.id}: 未対応の判定ルールです: ${definition.eligibilityRule}`);
  }
  if (!Array.isArray(definition.detailFields)) error(`${definition.id}: detailFields は配列にしてください`);
}

if (!Array.isArray(municipalitiesData.municipalities) || !municipalitiesData.municipalities.length) {
  error('municipalities.json: municipalities が空です');
}

for (const municipality of municipalitiesData.municipalities ?? []) {
  const name = municipality.name ?? '(名称なし)';
  for (const field of requiredMunicipalityFields) {
    if (!(field in municipality)) error(`${name}: ${field} がありません`);
  }

  if (municipalityCodes.has(municipality.code)) error(`自治体コードが重複しています: ${municipality.code}`);
  municipalityCodes.add(municipality.code);

  if (!/^\d{5}$/.test(municipality.code ?? '')) error(`${name}: 自治体コードは5桁の数字にしてください`);
  if (!/^\d{2}$/.test(municipality.prefectureCode ?? '')) error(`${name}: 都道府県コードは2桁の数字にしてください`);
  if (!isHttpsUrl(municipality.officialUrl)) error(`${name}: officialUrl はhttps://で始めてください`);

  const serviceIds = Object.keys(municipality.services ?? {});
  for (const definitionId of definitionIds) {
    if (!(definitionId in (municipality.services ?? {}))) error(`${name}: services.${definitionId} がありません`);
  }
  for (const serviceId of serviceIds) {
    if (!definitionIds.has(serviceId)) error(`${name}: 未定義の制度IDがあります: ${serviceId}`);
  }

  for (const [serviceId, service] of Object.entries(municipality.services ?? {})) {
    if (!allowedStatuses.has(service.status)) {
      error(`${name} / ${serviceId}: status は verified, researching, unavailable のいずれかです`);
      continue;
    }
    if (typeof service.summary !== 'string' || !service.summary.trim()) {
      error(`${name} / ${serviceId}: summary がありません`);
    }

    if (service.status !== 'verified') continue;

    const definition = definitionsData.services.find((item) => item.id === serviceId);
    if (!isHttpsUrl(service.source?.url)) error(`${name} / ${serviceId}: 確認済み制度には公式source.urlが必要です`);
    if (!datePattern.test(service.source?.checkedAt ?? '')) error(`${name} / ${serviceId}: source.checkedAt はYYYY-MM-DD形式にしてください`);

    if (definition?.eligibilityRule === 'ageRange') {
      const min = service.eligibility?.minAgeMonths;
      const max = service.eligibility?.maxAgeYears;
      if (!Number.isInteger(min) || min < 0) error(`${name} / ${serviceId}: eligibility.minAgeMonths が不正です`);
      if (!Number.isInteger(max) || max < 0 || max > 120) error(`${name} / ${serviceId}: eligibility.maxAgeYears が不正です`);
    }
  }
}

if (municipalitiesData.meta?.version !== definitionsData.meta?.version) {
  error(`データ版が一致しません: municipalities=${municipalitiesData.meta?.version}, definitions=${definitionsData.meta?.version}`);
}

if (errors) process.exit(1);
console.log(`${municipalitiesData.municipalities.length}自治体・${definitionsData.services.length}制度のデータ検証に成功しました。`);
