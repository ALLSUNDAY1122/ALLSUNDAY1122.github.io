import { readdir, readFile, rename, writeFile } from 'node:fs/promises';
import { basename, dirname, extname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const PROJECT_DIR = resolve(SCRIPT_DIR, '..');
const MUNICIPALITY_DIR = join(PROJECT_DIR, 'data', 'municipalities');
const TASK_DIR = join(PROJECT_DIR, 'operations', 'tasks');
const OUTPUT_FILE = join(PROJECT_DIR, 'operations', 'progress.json');

const TEAM_NAMES = [
  '北日本調査班',
  '東日本調査班',
  '中日本調査班',
  '西日本調査班'
];

const MUNICIPALITY_STATUS_FIELDS = {
  todo: 'todoMunicipalities',
  researching: 'researchingMunicipalities',
  verified: 'verifiedMunicipalities',
  unavailable: 'unavailableMunicipalities',
  needs_medium_review: 'needsMediumReviewMunicipalities',
  needs_revision: 'needsRevisionMunicipalities',
  needs_coordinator: 'needsCoordinatorMunicipalities',
  pr_open: 'prOpenMunicipalities',
  merged: 'mergedMunicipalities',
  blocked: 'blockedMunicipalities'
};

const SERVICE_STATUS_FIELDS = {
  todo: 'todoServices',
  researching: 'researchingServices',
  verified: 'verifiedServices',
  unavailable: 'unavailableServices',
  needs_medium_review: 'needsMediumReviewServices',
  needs_revision: 'needsRevisionServices',
  needs_coordinator: 'needsCoordinatorServices',
  pr_open: 'prOpenServices',
  merged: 'mergedServices',
  blocked: 'blockedServices'
};

const ASSIGNMENT_STATES = [
  'unassigned',
  'assigned',
  'pr_open',
  'blocked'
];

const TOTAL_MUNICIPALITIES_SOURCE = {
  value: 1741,
  asOf: '2026-01-01',
  checkedAt: '2026-07-19',
  authority: '政府統計の総合窓口 e-Stat',
  url: 'https://www.e-stat.go.jp/municipalities/number-of-municipalities?day=1&month=1&year=2026',
  calculation: '市町村計1724（北方4島の6村を含み、特別区を含まない）- 6村 + 23特別区 = 1741',
  scope: '現に自治体行政が行われている市町村および東京都23特別区'
};

function fail(message) {
  throw new Error(message);
}

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

async function readJson(path) {
  try {
    return JSON.parse(await readFile(path, 'utf8'));
  } catch (error) {
    fail(`${relative(PROJECT_DIR, path)}: JSONを読み込めません: ${error.message}`);
  }
}

async function collectJsonFiles(directory, recursive = false) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = [];

  for (const entry of entries.sort((a, b) => a.name.localeCompare(b.name, 'ja'))) {
    const fullPath = join(directory, entry.name);
    if (recursive && entry.isDirectory()) {
      files.push(...await collectJsonFiles(fullPath, true));
    } else if (entry.isFile() && extname(entry.name) === '.json') {
      files.push(fullPath);
    }
  }

  return files;
}

function emptyStatusCounts(mapping) {
  return Object.fromEntries(Object.values(mapping).map((field) => [field, 0]));
}

function emptyAssignmentSummary() {
  return Object.fromEntries(ASSIGNMENT_STATES.map((state) => [state, 0]));
}

function emptyTeamProgress() {
  return {
    registeredMunicipalities: 0,
    assignedMunicipalities: 0,
    prOpenMunicipalities: 0,
    blockedMunicipalities: 0,
    verifiedServices: 0,
    researchingServices: 0,
    unavailableServices: 0,
    needsReviewServices: 0,
    blockedServices: 0,
    municipalityCodes: []
  };
}

function incrementMappedCount(target, mapping, status, label) {
  const field = mapping[status];
  if (!field) fail(`${label}: 未許可statusです: ${status}`);
  target[field] += 1;
}

function serviceCounts(municipality) {
  const counts = emptyStatusCounts(SERVICE_STATUS_FIELDS);
  for (const [serviceId, service] of Object.entries(municipality.services ?? {})) {
    incrementMappedCount(counts, SERVICE_STATUS_FIELDS, service?.status, `${municipality.code}/${serviceId}`);
  }
  return counts;
}

function completedServiceCount(counts) {
  return counts.verifiedServices + counts.unavailableServices;
}

function assignmentState(task) {
  const blockers = Array.isArray(task.blockers) ? task.blockers : [];
  if (task.status === 'blocked' || task.status === 'needs_coordinator' || blockers.length > 0) return 'blocked';
  if (task.status === 'pr_open') return 'pr_open';
  if (task.status === 'merged') return 'assigned';
  if (typeof task.currentBranch === 'string' && task.currentBranch.trim()) return 'assigned';
  return 'unassigned';
}

async function main() {
  const municipalityFiles = await collectJsonFiles(MUNICIPALITY_DIR, true);
  const taskFiles = await collectJsonFiles(TASK_DIR, false);
  if (!municipalityFiles.length) fail('自治体別JSONがありません。');
  if (!taskFiles.length) fail('自治体別進捗JSONがありません。');

  const municipalities = new Map();
  for (const filePath of municipalityFiles) {
    const municipality = await readJson(filePath);
    if (!isPlainObject(municipality) || !/^\d{5}$/u.test(municipality.code ?? '')) {
      fail(`${relative(PROJECT_DIR, filePath)}: 自治体コードが不正です。`);
    }
    if (municipalities.has(municipality.code)) fail(`自治体コードが重複しています: ${municipality.code}`);
    municipalities.set(municipality.code, municipality);
  }

  const tasks = new Map();
  for (const filePath of taskFiles) {
    const task = await readJson(filePath);
    const code = task?.municipalityCode;
    if (!/^\d{5}$/u.test(code ?? '')) fail(`${relative(PROJECT_DIR, filePath)}: municipalityCodeが不正です。`);
    if (basename(filePath, '.json') !== code) fail(`${relative(PROJECT_DIR, filePath)}: ファイル名とmunicipalityCodeが一致しません。`);
    if (tasks.has(code)) fail(`進捗ファイルが重複しています: ${code}`);
    if (!municipalities.has(code)) fail(`進捗ファイルに対応する自治体がありません: ${code}`);
    if (!TEAM_NAMES.includes(task.assignedTeam)) fail(`${code}: assignedTeamが不正です: ${task.assignedTeam}`);
    tasks.set(code, task);
  }

  for (const code of municipalities.keys()) {
    if (!tasks.has(code)) fail(`自治体に対応する進捗ファイルがありません: ${code}`);
  }

  const municipalityCounts = emptyStatusCounts(MUNICIPALITY_STATUS_FIELDS);
  const aggregateServiceCounts = emptyStatusCounts(SERVICE_STATUS_FIELDS);
  const assignmentSummary = emptyAssignmentSummary();
  const teams = Object.fromEntries(TEAM_NAMES.map((name) => [name, emptyTeamProgress()]));
  const stalledMunicipalities = [];
  const municipalityProgress = [];
  const updatedAtCandidates = [];

  for (const code of [...municipalities.keys()].sort()) {
    const municipality = municipalities.get(code);
    const task = tasks.get(code);
    const counts = serviceCounts(municipality);
    const assignment = assignmentState(task);
    const blockers = Array.isArray(task.blockers) ? task.blockers : [];

    incrementMappedCount(municipalityCounts, MUNICIPALITY_STATUS_FIELDS, task.status, code);
    assignmentSummary[assignment] += 1;
    for (const field of Object.values(SERVICE_STATUS_FIELDS)) {
      aggregateServiceCounts[field] += counts[field];
    }

    const team = teams[task.assignedTeam];
    team.registeredMunicipalities += 1;
    if (assignment !== 'unassigned') team.assignedMunicipalities += 1;
    if (assignment === 'pr_open') team.prOpenMunicipalities += 1;
    if (assignment === 'blocked') team.blockedMunicipalities += 1;
    team.verifiedServices += counts.verifiedServices;
    team.researchingServices += counts.researchingServices;
    team.unavailableServices += counts.unavailableServices;
    team.needsReviewServices += counts.needsMediumReviewServices + counts.needsRevisionServices + counts.needsCoordinatorServices;
    team.blockedServices += counts.blockedServices;
    team.municipalityCodes.push(code);

    if (typeof task.lastUpdatedAt === 'string') updatedAtCandidates.push(task.lastUpdatedAt);

    if (assignment === 'blocked') {
      stalledMunicipalities.push({
        code,
        name: municipality.name,
        assignedTeam: task.assignedTeam,
        status: task.status,
        currentBranch: task.currentBranch ?? null,
        pullRequestNumber: task.pullRequestNumber ?? null,
        blockers
      });
    }

    municipalityProgress.push({
      code,
      name: municipality.name,
      prefectureCode: municipality.prefectureCode,
      prefecture: municipality.prefecture,
      assignedTeam: task.assignedTeam,
      status: task.status,
      assignmentState: assignment,
      currentBranch: task.currentBranch ?? null,
      pullRequestNumber: task.pullRequestNumber ?? null,
      completedServiceCount: completedServiceCount(counts),
      verifiedCount: counts.verifiedServices,
      unavailableCount: counts.unavailableServices,
      researchingCount: counts.researchingServices,
      currentService: task.currentService,
      lastCheckedAt: task.lastCheckedAt,
      lastUpdatedAt: task.lastUpdatedAt,
      lastUpdatedBy: task.lastUpdatedBy,
      blockers
    });
  }

  const totalServices = [...municipalities.values()]
    .reduce((sum, municipality) => sum + Object.keys(municipality.services ?? {}).length, 0);
  const completedServices = aggregateServiceCounts.verifiedServices + aggregateServiceCounts.unavailableServices;
  const updatedAt = updatedAtCandidates.sort().at(-1);
  if (!updatedAt) fail('進捗更新日時を算定できません。');

  const progress = {
    schemaVersion: '1.0.0',
    updatedAt,
    totalMunicipalities: TOTAL_MUNICIPALITIES_SOURCE.value,
    totalMunicipalitiesSource: TOTAL_MUNICIPALITIES_SOURCE,
    registeredMunicipalities: municipalities.size,
    remainingMunicipalities: TOTAL_MUNICIPALITIES_SOURCE.value - municipalities.size,
    ...municipalityCounts,
    assignmentSummary,
    totalServices,
    completedServices,
    completionRatePercent: Number(((completedServices / totalServices) * 100).toFixed(2)),
    ...aggregateServiceCounts,
    teams,
    stalledMunicipalities,
    municipalities: municipalityProgress
  };

  const output = `${JSON.stringify(progress, null, 2)}\n`;
  const temporaryFile = `${OUTPUT_FILE}.tmp`;
  await writeFile(temporaryFile, output, 'utf8');
  await rename(temporaryFile, OUTPUT_FILE);

  console.log(`${municipalities.size}自治体・${totalServices}制度の全国進捗を生成しました: ${relative(PROJECT_DIR, OUTPUT_FILE)}`);
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
