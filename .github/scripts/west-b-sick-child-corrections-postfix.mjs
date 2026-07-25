import fs from 'node:fs';
import path from 'node:path';

const root = path.join(process.cwd(), 'jichitai-compare');
const targets = [
  ['35', '35321', 0, 12],
  ['35', '35502', 0, 12],
  ['36', '36342', 0, 12],
  ['42', '42214', 0, 12],
  ['45', '45341', 0, 12],
  ['45', '45382', 0, 12]
];

for (const [pref, code, minAgeMonths, maxAgeYears] of targets) {
  const municipalityPath = path.join(root, 'data', 'municipalities', pref, `${code}.json`);
  const municipality = JSON.parse(fs.readFileSync(municipalityPath, 'utf8'));
  municipality.services.sickChildCare.eligibility = { minAgeMonths, maxAgeYears };
  fs.writeFileSync(municipalityPath, JSON.stringify(municipality, null, 2) + '\n');

  const taskPath = path.join(root, 'operations', 'tasks', `${code}.json`);
  const task = JSON.parse(fs.readFileSync(taskPath, 'utf8'));
  const serviceIds = ['childMedical','sickChildCare','childcareFee','schoolMeals','postpartumCare','temporaryChildcare','housingSupport','bulkyWaste','disasterPrevention'];
  const entries = serviceIds.map((id) => [id, municipality.services[id]]);
  task.completedServices = entries.filter(([, service]) => ['verified','unavailable'].includes(service.status)).map(([id]) => id);
  task.verifiedCount = entries.filter(([, service]) => service.status === 'verified').length;
  task.researchingCount = entries.filter(([, service]) => service.status === 'researching').length;
  task.unavailableCount = entries.filter(([, service]) => service.status === 'unavailable').length;
  task.needsMediumReviewCount = entries.filter(([, service]) => service.status === 'needs_medium_review').length;
  task.nextServiceIndex = serviceIds.length;
  task.currentService = null;
  task.officialSources = [...new Set(entries.filter(([, service]) => ['verified','unavailable'].includes(service.status) && /^https:\/\//u.test(service.source?.url ?? '')).map(([, service]) => service.source.url))];
  fs.writeFileSync(taskPath, JSON.stringify(task, null, 2) + '\n');
}
