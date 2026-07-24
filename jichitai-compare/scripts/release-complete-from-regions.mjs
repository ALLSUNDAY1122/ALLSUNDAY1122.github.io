import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

const projectRoot = process.cwd();
const repoRoot = path.resolve(projectRoot, '..');
const releaseAt = process.env.RELEASE_AT || new Date().toISOString();
const manifestName = process.env.RELEASE_MANIFEST || 'release-complete-from-regions.json';
const regions = {
  north: '北日本調査班',
  east: '東日本調査班',
  central: '中日本調査班',
  west: '西日本調査班',
};

const run = (command) => execFileSync('bash', ['-lc', command], {
  cwd: repoRoot,
  encoding: 'utf8',
  stdio: ['ignore', 'pipe', 'pipe'],
}).trim();
const readJson = (file) => JSON.parse(fs.readFileSync(path.join(projectRoot, file), 'utf8'));
const readRefJson = (ref, file) => JSON.parse(run(`git show ${ref}:jichitai-compare/${file}`));
const serviceIds = readJson('data/service-definitions.json').services.map(({ id }) => id);
const progress = readJson('operations/progress.json');
const added = [];
const skippedIncomplete = [];
const regionCodes = {};

for (const [region, team] of Object.entries(regions)) {
  const ref = `origin/region/${region}`;
  const files = run(`git ls-tree -r --name-only ${ref} -- jichitai-compare/data/municipalities`)
    .split(/\r?\n/)
    .filter((file) => /\/\d{5}\.json$/.test(file));
  regionCodes[region] = new Set(files.map((file) => path.basename(file, '.json')));

  for (const repoFile of files) {
    const relativeDataFile = repoFile.replace(/^jichitai-compare\//, '');
    const localDataFile = path.join(projectRoot, relativeDataFile);
    if (fs.existsSync(localDataFile)) continue;

    const code = path.basename(relativeDataFile, '.json');
    const relativeTaskFile = `operations/tasks/${code}.json`;
    let municipality;
    let task;
    try {
      municipality = readRefJson(ref, relativeDataFile);
      task = readRefJson(ref, relativeTaskFile);
    } catch {
      skippedIncomplete.push({ region, code, reason: 'municipality_or_task_missing' });
      continue;
    }

    const entries = serviceIds.map((id) => [id, municipality.services?.[id]]);
    if (entries.some(([, service]) => !['verified', 'unavailable'].includes(service?.status))) {
      skippedIncomplete.push({ region, code, name: municipality.name, reason: 'service_incomplete' });
      continue;
    }

    fs.mkdirSync(path.dirname(localDataFile), { recursive: true });
    fs.writeFileSync(localDataFile, `${JSON.stringify(municipality)}\n`);

    task.status = 'merged';
    task.currentService = null;
    task.nextServiceIndex = 9;
    task.completedServices = serviceIds;
    task.assignedTeam = team;
    task.verifiedCount = entries.filter(([, service]) => service.status === 'verified').length;
    task.unavailableCount = entries.filter(([, service]) => service.status === 'unavailable').length;
    task.researchingCount = 0;
    task.needsMediumReviewCount = 0;
    task.lastCheckedAt = municipality.updatedAt;
    task.lastUpdatedAt = releaseAt;
    task.lastUpdatedBy = '統括';
    task.officialSources = [...new Set(entries.map(([, service]) => service.source?.url).filter(Boolean))];
    task.notes = Array.isArray(task.notes) ? task.notes : [];
    task.blockers = [];

    const localTaskFile = path.join(projectRoot, relativeTaskFile);
    fs.mkdirSync(path.dirname(localTaskFile), { recursive: true });
    fs.writeFileSync(localTaskFile, `${JSON.stringify(task)}\n`);
    added.push({
      region,
      team,
      code,
      name: municipality.name,
      prefecture: municipality.prefecture,
      pullRequestNumber: task.pullRequestNumber ?? null,
    });
  }
}

const eastQueueFile = path.join(projectRoot, 'operations/control/east-b-niigata-remaining-20260724.json');
if (fs.existsSync(eastQueueFile)) {
  const queue = JSON.parse(fs.readFileSync(eastQueueFile, 'utf8'));
  const pending = queue.municipalities
    .filter(({ code }) => !regionCodes.east.has(code))
    .map((item, index) => ({ ...item, order: index + 1 }));
  queue.updatedAt = releaseAt;
  queue.currentRegionEastMunicipalities = queue.expectedEastMunicipalities - pending.length;
  queue.remainingCount = pending.length;
  queue.nextMunicipality = pending[0] ?? null;
  queue.municipalities = pending;
  queue.alreadyInRegion = [
    ...(queue.alreadyInRegion || []),
    ...added.filter(({ region }) => region === 'east').map(({ code, name }) => ({ code, name })),
  ].filter((item, index, all) => all.findIndex(({ code }) => code === item.code) === index)
    .sort((a, b) => a.code.localeCompare(b.code));
  fs.writeFileSync(eastQueueFile, `${JSON.stringify(queue, null, 2)}\n`);
}

added.sort((a, b) => a.code.localeCompare(b.code));
const byRegion = Object.fromEntries(Object.keys(regions).map((region) => [
  region,
  added.filter((item) => item.region === region).length,
]));
const skippedIncompleteCountByRegion = Object.fromEntries(Object.keys(regions).map((region) => [
  region,
  skippedIncomplete.filter((item) => item.region === region).length,
]));
const manifest = {
  schemaVersion: '1.0.0',
  createdAt: releaseAt,
  previousPublishedMunicipalities: progress.registeredMunicipalities,
  addedCount: added.length,
  byRegion,
  added,
  skippedIncompleteCountByRegion,
};
const manifestFile = path.join(projectRoot, 'operations/control', manifestName);
fs.mkdirSync(path.dirname(manifestFile), { recursive: true });
fs.writeFileSync(manifestFile, `${JSON.stringify(manifest, null, 2)}\n`);
console.log(JSON.stringify({ addedCount: added.length, byRegion, skippedIncompleteCountByRegion }));
