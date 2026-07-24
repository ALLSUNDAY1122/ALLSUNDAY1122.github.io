import { readFile, access } from 'node:fs/promises';
import { resolve, dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const PROJECT_DIR = resolve(SCRIPT_DIR, '..');
const AUDIT_PATH = join(PROJECT_DIR, 'operations', 'audits', 'north-a-accuracy-audit-20260724.json');
const EXPECTED_SERVICES = [
  'childMedical', 'sickChildCare', 'childcareFee', 'schoolMeals',
  'postpartumCare', 'temporaryChildcare', 'housingSupport',
  'bulkyWaste', 'disasterPrevention'
];
const VALID_STATUSES = new Set(['verified', 'unavailable']);

const audit = JSON.parse(await readFile(AUDIT_PATH, 'utf8'));
const batch = audit.batches.find((item) => item.status === 'in_progress');
if (!batch) throw new Error('in_progress の監査バッチがありません');

const errors = [];
const warnings = [];
const rows = [];

for (const code of batch.codes) {
  const pref = code.slice(0, 2);
  const path = join(PROJECT_DIR, 'data', 'municipalities', pref, `${code}.json`);
  try {
    await access(path);
  } catch {
    errors.push(`${code}: 自治体JSONが存在しません`);
    continue;
  }

  let item;
  try {
    item = JSON.parse(await readFile(path, 'utf8'));
  } catch (cause) {
    errors.push(`${code}: JSON解析失敗 ${cause.message}`);
    continue;
  }

  if (item.code !== code) errors.push(`${code}: code不一致 ${item.code}`);
  if (item.prefectureCode !== pref) errors.push(`${code}: prefectureCode不一致 ${item.prefectureCode}`);
  if (!item.name || typeof item.name !== 'string') errors.push(`${code}: 自治体名がありません`);
  if (!/^https:\/\//.test(item.officialUrl ?? '')) errors.push(`${code}: officialUrlがHTTPSではありません`);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(item.updatedAt ?? '')) errors.push(`${code}: updatedAt形式不正 ${item.updatedAt}`);
  if (!item.summary || typeof item.summary !== 'string') errors.push(`${code}: summaryがありません`);

  const keys = Object.keys(item.services ?? {});
  for (const key of EXPECTED_SERVICES) {
    if (!keys.includes(key)) errors.push(`${code}: 制度 ${key} がありません`);
  }
  for (const key of keys) {
    if (!EXPECTED_SERVICES.includes(key)) warnings.push(`${code}: 想定外制度キー ${key}`);
  }

  let verified = 0;
  let unavailable = 0;
  for (const key of EXPECTED_SERVICES) {
    const service = item.services?.[key];
    if (!service) continue;
    if (!VALID_STATUSES.has(service.status)) {
      errors.push(`${code}/${key}: status不正 ${service.status}`);
      continue;
    }
    if (service.status === 'verified') verified += 1;
    if (service.status === 'unavailable') unavailable += 1;
    if (!service.summary || typeof service.summary !== 'string') errors.push(`${code}/${key}: summaryがありません`);
    if (!/^https:\/\//.test(service.source?.url ?? '')) errors.push(`${code}/${key}: source.urlがHTTPSではありません`);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(service.source?.checkedAt ?? '')) errors.push(`${code}/${key}: checkedAt形式不正 ${service.source?.checkedAt}`);
    const minMonths = service.eligibility?.minAgeMonths;
    const maxYears = service.eligibility?.maxAgeYears;
    if (minMonths != null && (!Number.isFinite(minMonths) || minMonths < 0 || minMonths > 216)) warnings.push(`${code}/${key}: minAgeMonths要確認 ${minMonths}`);
    if (maxYears != null && (!Number.isFinite(maxYears) || maxYears < 0 || maxYears > 120)) warnings.push(`${code}/${key}: maxAgeYears要確認 ${maxYears}`);
  }

  if (verified + unavailable !== 9) errors.push(`${code}: verified+unavailableが9ではありません (${verified}+${unavailable})`);
  const fullNine = /全9制度|9制度すべて/.test(item.summary ?? '');
  const countMatch = (item.summary ?? '').match(/(\d+)制度を確認済み/);
  if (fullNine && verified !== 9) errors.push(`${code}: summaryは全9制度確認済みだがverified=${verified}`);
  if (countMatch && Number(countMatch[1]) !== verified) errors.push(`${code}: summaryの確認済み数${countMatch[1]}とverified=${verified}が不一致`);

  rows.push({ code, name: item.name, verified, unavailable, updatedAt: item.updatedAt });
}

console.log(JSON.stringify({
  round: batch.round,
  codes: batch.codes,
  checkedMunicipalities: rows.length,
  rows,
  errors,
  warnings
}, null, 2));

if (errors.length > 0) process.exit(1);
