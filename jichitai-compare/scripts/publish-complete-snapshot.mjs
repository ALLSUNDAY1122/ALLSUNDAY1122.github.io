import { execFileSync } from 'node:child_process';
import { mkdirSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';

const project = process.cwd();
const releaseAt = process.env.RELEASE_AT ?? new Date().toISOString();
const checkedAt = releaseAt.slice(0, 10);
const manifestName = process.env.MANIFEST_NAME ?? 'release-latest-complete.json';
const regions = [
  ['north', '北日本調査班'],
  ['east', '東日本調査班'],
  ['central', '中日本調査班'],
  ['west', '西日本調査班']
];

function git(...args) {
  return execFileSync('git', args, {
    encoding: 'utf8',
    maxBuffer: 64 * 1024 * 1024
  });
}

function showJson(ref, file) {
  return JSON.parse(git('show', `${ref}:${file}`));
}

const progressPath = join(project, 'operations', 'progress.json');
const before = JSON.parse(readFileSync(progressPath, 'utf8'));
const taskDir = join(project, 'operations', 'tasks');
const existing = new Set(
  readdirSync(taskDir)
    .filter((name) => /^\d{5}\.json$/u.test(name))
    .map((name) => name.slice(0, 5))
);
const selected = [];
const excluded = [];
const seen = new Set();

for (const [region, team] of regions) {
  const ref = `origin/region/${region}`;
  const listing = git('ls-tree', '-r', '--name-only', ref, 'jichitai-compare/operations/tasks').trim();
  for (const taskPath of listing ? listing.split('\n') : []) {
    if (!/\/\d{5}\.json$/u.test(taskPath)) continue;
    let task;
    try {
      task = showJson(ref, taskPath);
    } catch (error) {
      excluded.push({ region, taskPath, reason: `task parse: ${error.message}` });
      continue;
    }
    const code = task?.municipalityCode;
    if (!/^\d{5}$/u.test(code ?? '') || existing.has(code) || seen.has(code)) continue;
    seen.add(code);
    const completed = Array.isArray(task.completedServices) ? task.completedServices : [];
    const blockers = Array.isArray(task.blockers) ? task.blockers : [];
    if (completed.length !== 9 || blockers.length) {
      excluded.push({ region, code, name: task.municipalityName, reason: 'task incomplete or blocked' });
      continue;
    }
    const municipalityPath = `jichitai-compare/data/municipalities/${task.prefectureCode}/${code}.json`;
    let municipality;
    try {
      municipality = showJson(ref, municipalityPath);
    } catch (error) {
      excluded.push({ region, code, name: task.municipalityName, reason: `municipality missing: ${error.message}` });
      continue;
    }
    const services = Object.entries(municipality?.services ?? {});
    if (services.length !== 9 || !services.every(([, service]) => ['verified', 'unavailable'].includes(service?.status))) {
      excluded.push({ region, code, name: municipality.name, reason: 'services not fully publishable' });
      continue;
    }
    const localMunicipalityPath = join(project, 'data', 'municipalities', task.prefectureCode, `${code}.json`);
    mkdirSync(dirname(localMunicipalityPath), { recursive: true });
    writeFileSync(localMunicipalityPath, `${JSON.stringify(municipality, null, 2)}\n`);
    const sourcePullRequestNumber = task.pullRequestNumber ?? null;
    const normalizedTask = {
      ...task,
      status: 'merged',
      currentService: null,
      nextServiceIndex: 9,
      pullRequestNumber: null,
      blockers: [],
      lastCheckedAt: checkedAt,
      lastUpdatedAt: releaseAt,
      lastUpdatedBy: `${task.lastUpdatedBy || team}・統括⑤全国統合`,
      notes: [
        ...(Array.isArray(task.notes) ? task.notes : []),
        '最新地方統合済み全件監査によりmainへ全国統合。'
      ]
    };
    const localTaskPath = join(project, 'operations', 'tasks', `${code}.json`);
    writeFileSync(localTaskPath, `${JSON.stringify(normalizedTask, null, 2)}\n`);
    selected.push({
      region,
      team,
      code,
      name: municipality.name,
      prefecture: municipality.prefecture,
      sourcePullRequestNumber
    });
  }
}

selected.sort((a, b) => a.code.localeCompare(b.code));
excluded.sort((a, b) => String(a.code ?? a.taskPath).localeCompare(String(b.code ?? b.taskPath)));
if (!selected.length) throw new Error('公開可能なmain未登録自治体がありません。');
const byRegion = Object.fromEntries(regions.map(([region]) => [region, selected.filter((item) => item.region === region).length]));
const manifest = {
  schemaVersion: '1.0.0',
  createdAt: releaseAt,
  previousPublishedMunicipalities: before.registeredMunicipalities,
  selectedMunicipalities: selected.length,
  byRegion,
  municipalities: selected,
  excludedCount: excluded.length,
  excluded
};
const manifestPath = join(project, 'operations', 'control', manifestName);
writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
console.log(JSON.stringify({ selected: selected.length, byRegion, excluded: excluded.length }, null, 2));
