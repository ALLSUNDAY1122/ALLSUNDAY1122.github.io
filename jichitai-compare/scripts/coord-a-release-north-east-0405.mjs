import { execFileSync } from 'node:child_process';
import { mkdirSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const project = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const repo = resolve(project, '..');
const releaseAt = process.env.RELEASE_AT ?? new Date().toISOString();
const checkedAt = releaseAt.slice(0, 10);
const regions = [
  ['north', '北日本調査班'],
  ['east', '東日本調査班']
];

function git(...args) {
  return execFileSync('git', args, {
    cwd: repo,
    encoding: 'utf8',
    maxBuffer: 64 * 1024 * 1024
  });
}

function showJson(ref, path) {
  return JSON.parse(git('show', `${ref}:${path}`));
}

const progressPath = join(project, 'operations', 'progress.json');
const before = JSON.parse(readFileSync(progressPath, 'utf8'));
const mainTaskDir = join(project, 'operations', 'tasks');
const existingCodes = new Set(
  readdirSync(mainTaskDir)
    .filter((name) => /^\d{5}\.json$/u.test(name))
    .map((name) => name.slice(0, 5))
);

const selected = [];
const excluded = [];
const seen = new Set();

for (const [region, team] of regions) {
  const ref = `origin/region/${region}`;
  const listing = git(
    'ls-tree', '-r', '--name-only', ref,
    'jichitai-compare/operations/tasks'
  ).trim();

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
    if (!/^\d{5}$/u.test(code ?? '') || existingCodes.has(code) || seen.has(code)) continue;
    seen.add(code);

    const completed = Array.isArray(task.completedServices) ? task.completedServices : [];
    const blockers = Array.isArray(task.blockers) ? task.blockers : [];
    if (completed.length !== 9 || blockers.length > 0) {
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
    const publishable = services.length === 9 && services.every(([, service]) =>
      ['verified', 'unavailable'].includes(service?.status)
    );
    if (!publishable) {
      excluded.push({ region, code, name: municipality?.name, reason: 'services not fully publishable' });
      continue;
    }

    const municipalityOut = join(project, 'data', 'municipalities', task.prefectureCode, `${code}.json`);
    mkdirSync(dirname(municipalityOut), { recursive: true });
    writeFileSync(municipalityOut, `${JSON.stringify(municipality, null, 2)}\n`);

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
      lastUpdatedBy: `${task.lastUpdatedBy || team}・統括A全国統合`,
      notes: [
        ...(Array.isArray(task.notes) ? task.notes : []),
        '統括Aの北日本・東日本全件監査によりmainへ全国統合。'
      ]
    };
    const taskOut = join(project, 'operations', 'tasks', `${code}.json`);
    writeFileSync(taskOut, `${JSON.stringify(normalizedTask, null, 2)}\n`);

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

const byRegion = Object.fromEntries(
  regions.map(([region]) => [region, selected.filter((item) => item.region === region).length])
);
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
writeFileSync(
  join(project, 'operations', 'control', 'coord-a-release-north-east-20260724-0405.json'),
  `${JSON.stringify(manifest, null, 2)}\n`
);

console.log(JSON.stringify({ selected: selected.length, byRegion, excluded: excluded.length }, null, 2));
if (selected.length === 0) process.exitCode = 2;
