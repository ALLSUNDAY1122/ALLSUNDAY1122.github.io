import { readdir, readFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const PROJECT_DIR = resolve(fileURLToPath(new URL('..', import.meta.url)));
const MUNICIPALITY_DIR = join(PROJECT_DIR, 'data', 'municipalities');
const TASK_DIR = join(PROJECT_DIR, 'operations', 'tasks');

const EXPECTED_BY_PREFECTURE = new Map([
  ['31', 19],
  ['32', 19],
  ['34', 23],
  ['35', 19],
  ['36', 24],
  ['38', 20],
  ['41', 20],
  ['42', 21],
  ['44', 18],
  ['45', 26],
  ['47', 41]
]);
const SERVICE_IDS = [
  'childMedical',
  'sickChildCare',
  'childcareFee',
  'schoolMeals',
  'postpartumCare',
  'temporaryChildcare',
  'housingSupport',
  'bulkyWaste',
  'disasterPrevention'
];
const MODE = process.env.AUDIT_MODE ?? 'structure';
const REQUESTED_PREFECTURES = new Set(
  (process.env.AUDIT_PREFECTURES ?? [...EXPECTED_BY_PREFECTURE.keys()].join(','))
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean)
);

const errors = [];
const records = [];

async function readJson(path) {
  return JSON.parse(await readFile(path, 'utf8'));
}

for (const [prefectureCode, expectedCount] of EXPECTED_BY_PREFECTURE) {
  if (!REQUESTED_PREFECTURES.has(prefectureCode)) continue;

  const directory = join(MUNICIPALITY_DIR, prefectureCode);
  const filenames = (await readdir(directory))
    .filter((name) => /^\d{5}\.json$/.test(name))
    .sort();

  if (filenames.length !== expectedCount) {
    errors.push(`都道府県${prefectureCode}: 自治体JSON数 期待=${expectedCount} 実際=${filenames.length}`);
  }

  for (const filename of filenames) {
    const code = filename.slice(0, -5);
    const municipality = await readJson(join(directory, filename));
    const task = await readJson(join(TASK_DIR, filename));
    const actualServices = Object.keys(municipality.services ?? {});

    if (municipality.code !== code) errors.push(`${code}: 自治体コードとファイル名が不一致`);
    if (municipality.prefectureCode !== prefectureCode) errors.push(`${code}: 都道府県コードが不一致`);
    if (actualServices.length !== 9 || SERVICE_IDS.some((id) => !(id in (municipality.services ?? {})))) {
      errors.push(`${code}: 必須9制度が未充足`);
    }
    if (task.municipalityCode !== code) errors.push(`${code}: task municipalityCodeが不一致`);

    if (MODE === 'completion') {
      if (task.status !== 'merged') errors.push(`${code}: task status=${task.status}`);
      if (task.currentService !== null || task.nextServiceIndex !== 9) errors.push(`${code}: task完了位置が不正`);
      if (!Array.isArray(task.completedServices) || task.completedServices.length !== 9) {
        errors.push(`${code}: completedServicesが9件ではない`);
      }
      if ((task.verifiedCount ?? 0) + (task.unavailableCount ?? 0) !== 9) {
        errors.push(`${code}: verified+unavailableが9件ではない`);
      }
      if ((task.researchingCount ?? 0) !== 0 || (task.needsMediumReviewCount ?? 0) !== 0) {
        errors.push(`${code}: 未完了制度カウントが残存`);
      }
      if (!Number.isInteger(task.pullRequestNumber)) errors.push(`${code}: pullRequestNumber未確定`);
    }

    records.push({ code, prefectureCode, status: task.status });
  }
}

const expectedTotal = [...EXPECTED_BY_PREFECTURE]
  .filter(([prefectureCode]) => REQUESTED_PREFECTURES.has(prefectureCode))
  .reduce((sum, [, count]) => sum + count, 0);
if (records.length !== expectedTotal) {
  errors.push(`監査対象自治体総数 期待=${expectedTotal} 実際=${records.length}`);
}

if (errors.length > 0) {
  for (const message of errors) console.error(`::error::WEST_B_AUDIT ${message}`);
  console.error(`WEST_B_AUDIT_FAILED mode=${MODE} prefectures=${[...REQUESTED_PREFECTURES].join(',')} errors=${errors.length} municipalities=${records.length}/${expectedTotal}`);
  process.exitCode = 1;
} else {
  const mergedTasks = records.filter((record) => record.status === 'merged').length;
  console.log(`WEST_B_AUDIT_SUCCESS mode=${MODE} prefectures=${[...REQUESTED_PREFECTURES].join(',')} municipalities=${records.length}/${expectedTotal} services=${records.length * SERVICE_IDS.length} mergedTasks=${mergedTasks}`);
}
