import { readdir, readFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const PROJECT_DIR = resolve(fileURLToPath(new URL('..', import.meta.url)));
const MUNICIPALITY_DIR = join(PROJECT_DIR, 'data', 'municipalities');
const TASK_DIR = join(PROJECT_DIR, 'operations', 'tasks');

const EXPECTED_BY_PREFECTURE = new Map([
  ['31', 19], ['32', 19], ['34', 23], ['35', 19], ['36', 24],
  ['38', 20], ['41', 20], ['42', 21], ['44', 18], ['45', 26], ['47', 41]
]);
const SERVICE_IDS = [
  'childMedical', 'sickChildCare', 'childcareFee', 'schoolMeals',
  'postpartumCare', 'temporaryChildcare', 'housingSupport',
  'bulkyWaste', 'disasterPrevention'
];

const errors = [];
const records = [];
let serviceCount = 0;
let verifiedCount = 0;
let unavailableCount = 0;

async function readJson(path) {
  return JSON.parse(await readFile(path, 'utf8'));
}

function unique(values) {
  return [...new Set(values)];
}

for (const [prefectureCode, expectedCount] of EXPECTED_BY_PREFECTURE) {
  const directory = join(MUNICIPALITY_DIR, prefectureCode);
  const filenames = (await readdir(directory))
    .filter((name) => /^\d{5}\.json$/.test(name))
    .sort();

  if (filenames.length !== expectedCount) {
    errors.push(`都道府県${prefectureCode}: 自治体JSON数 期待=${expectedCount} 実際=${filenames.length}`);
  }

  for (const filename of filenames) {
    const code = filename.slice(0, -5);
    const municipalityPath = join(directory, filename);
    const taskPath = join(TASK_DIR, filename);
    const municipality = await readJson(municipalityPath);
    let task;
    try {
      task = await readJson(taskPath);
    } catch (error) {
      errors.push(`${code}: task読込失敗 ${error.message}`);
      continue;
    }

    if (municipality.code !== code) errors.push(`${code}: 自治体コードとファイル名が不一致`);
    if (municipality.prefectureCode !== prefectureCode) errors.push(`${code}: 都道府県コードが不一致`);
    if (task.municipalityCode !== code) errors.push(`${code}: task municipalityCodeが不一致`);
    if (task.municipalityName !== municipality.name) errors.push(`${code}: task自治体名が不一致`);

    const services = municipality.services ?? {};
    const actualIds = Object.keys(services);
    if (actualIds.length !== 9 || SERVICE_IDS.some((id) => !(id in services))) {
      errors.push(`${code}: 必須9制度が未充足`);
    }

    const sourceUrls = [];
    let municipalityVerified = 0;
    let municipalityUnavailable = 0;
    for (const serviceId of SERVICE_IDS) {
      const service = services[serviceId];
      if (!service) continue;
      serviceCount += 1;
      if (service.status === 'verified') {
        verifiedCount += 1;
        municipalityVerified += 1;
      } else if (service.status === 'unavailable') {
        unavailableCount += 1;
        municipalityUnavailable += 1;
      } else {
        errors.push(`${code}/${serviceId}: 完了外status=${service.status}`);
      }
      const source = service.source ?? {};
      if (typeof source.url !== 'string' || !source.url.startsWith('https://')) {
        errors.push(`${code}/${serviceId}: 公式HTTPS出典なし`);
      } else {
        sourceUrls.push(source.url);
      }
      if (typeof source.checkedAt !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(source.checkedAt)) {
        errors.push(`${code}/${serviceId}: checkedAt不正`);
      }
    }

    if (task.status !== 'merged') errors.push(`${code}: task status=${task.status}`);
    if (task.currentService !== null || task.nextServiceIndex !== 9) errors.push(`${code}: task完了位置が不正`);
    if (!Array.isArray(task.completedServices) || task.completedServices.length !== 9 || SERVICE_IDS.some((id) => !task.completedServices.includes(id))) {
      errors.push(`${code}: completedServices不正`);
    }
    if (task.verifiedCount !== municipalityVerified) errors.push(`${code}: verifiedCount不一致`);
    if (task.unavailableCount !== municipalityUnavailable) errors.push(`${code}: unavailableCount不一致`);
    if ((task.researchingCount ?? 0) !== 0) errors.push(`${code}: researchingCount残存`);
    if ((task.needsMediumReviewCount ?? 0) !== 0) errors.push(`${code}: needsMediumReviewCount残存`);
    if (!Number.isInteger(task.pullRequestNumber)) errors.push(`${code}: pullRequestNumber未確定`);

    const expectedOfficialSources = unique(sourceUrls);
    if (JSON.stringify(task.officialSources ?? []) !== JSON.stringify(expectedOfficialSources)) {
      errors.push(`${code}: officialSources不一致`);
    }

    records.push({ code, prefectureCode, verified: municipalityVerified, unavailable: municipalityUnavailable });
  }
}

const expectedMunicipalities = [...EXPECTED_BY_PREFECTURE.values()].reduce((sum, value) => sum + value, 0);
const expectedServices = expectedMunicipalities * SERVICE_IDS.length;
if (records.length !== expectedMunicipalities) errors.push(`自治体総数 期待=${expectedMunicipalities} 実際=${records.length}`);
if (serviceCount !== expectedServices) errors.push(`制度総数 期待=${expectedServices} 実際=${serviceCount}`);
if (verifiedCount + unavailableCount !== expectedServices) {
  errors.push(`完了制度総数 期待=${expectedServices} 実際=${verifiedCount + unavailableCount}`);
}

if (errors.length > 0) {
  for (const message of errors) console.error(`::error::WEST_B_FINAL_AUDIT ${message}`);
  console.error(`WEST_B_FINAL_AUDIT_FAILED errors=${errors.length} municipalities=${records.length}/${expectedMunicipalities} services=${serviceCount}/${expectedServices}`);
  process.exitCode = 1;
} else {
  console.log(`WEST_B_FINAL_AUDIT_SUCCESS municipalities=${records.length}/${expectedMunicipalities} services=${serviceCount}/${expectedServices} verified=${verifiedCount} unavailable=${unavailableCount} tasksMerged=${records.length}`);
}
