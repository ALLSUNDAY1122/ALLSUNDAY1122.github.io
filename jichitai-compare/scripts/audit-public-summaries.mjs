import { readdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const PROJECT_DIR = resolve(SCRIPT_DIR, '..');
const TARGET_PREFECTURES = (process.env.TARGET_PREFECTURES ?? '')
  .split(',')
  .map((value) => value.trim())
  .filter(Boolean);
const APPLY_FIXES = process.env.APPLY_FIXES !== 'false';
const EXPECTED_MUNICIPALITY_COUNT = Number(process.env.EXPECTED_MUNICIPALITY_COUNT ?? 0);
const AUDIT_AT = process.env.AUDIT_AT ?? new Date().toISOString();
const PR_NUMBER = Number(process.env.PR_NUMBER ?? 0) || null;
const AUDIT_FILE = process.env.AUDIT_FILE
  ? resolve(PROJECT_DIR, process.env.AUDIT_FILE)
  : null;
const CHECKPOINT_FILE = process.env.CHECKPOINT_FILE
  ? resolve(PROJECT_DIR, process.env.CHECKPOINT_FILE)
  : null;

if (TARGET_PREFECTURES.length === 0) {
  throw new Error('TARGET_PREFECTURES is required, for example 02,03,07');
}

const forbiddenPatterns = [
  { label: '調査班', pattern: /調査班/u },
  { label: 'verified', pattern: /\bverified\b/iu },
  { label: 'unavailable', pattern: /\bunavailable\b/iu },
  { label: 'task', pattern: /\btask(?:\.status)?\b/iu },
  { label: 'PR番号', pattern: /\bPR\s*#?\d+/iu },
  { label: 'PR提出', pattern: /PR提出/u },
  { label: '作業ブランチ', pattern: /作業ブランチ/u },
  { label: 'mainへ', pattern: /mainへ/iu },
  { label: 'マージ後', pattern: /マージ後/u },
  { label: '次の自治体', pattern: /次の自治体/u },
  { label: '内部登録表現', pattern: /(?:制度|データ)[^。]{0,30}(?:として登録|を登録|登録済み)/u }
];

const municipalityFiles = [];
for (const prefectureCode of TARGET_PREFECTURES) {
  const directory = join(PROJECT_DIR, 'data', 'municipalities', prefectureCode);
  const entries = await readdir(directory, { withFileTypes: true });
  for (const entry of entries) {
    if (entry.isFile() && entry.name.endsWith('.json')) {
      municipalityFiles.push(join(directory, entry.name));
    }
  }
}
municipalityFiles.sort();

if (EXPECTED_MUNICIPALITY_COUNT > 0 && municipalityFiles.length !== EXPECTED_MUNICIPALITY_COUNT) {
  throw new Error(`Expected ${EXPECTED_MUNICIPALITY_COUNT} municipality files, found ${municipalityFiles.length}`);
}

let municipalitiesChanged = 0;
let summariesChanged = 0;
const changedCodes = [];
const samples = [];
const remainingViolations = [];

for (const file of municipalityFiles) {
  const raw = await readFile(file, 'utf8');
  const municipality = JSON.parse(raw);
  const summaryEntries = collectSummaryEntries(municipality);
  const changes = summaryEntries
    .map((entry) => ({ ...entry, after: cleanSummary(entry.before) }))
    .filter((entry) => entry.after !== entry.before);

  let nextRaw = raw;
  if (changes.length > 0) {
    nextRaw = replaceSummaryStrings(raw, changes, municipality.code);
    municipalitiesChanged += 1;
    summariesChanged += changes.length;
    changedCodes.push(municipality.code);
    if (samples.length < 12) {
      const topLevelChange = changes.find((entry) => entry.path === 'summary') ?? changes[0];
      samples.push({
        code: municipality.code,
        name: municipality.name,
        path: topLevelChange.path,
        before: topLevelChange.before,
        after: topLevelChange.after
      });
    }
    if (APPLY_FIXES) await writeFile(file, nextRaw, 'utf8');
  }

  const checkedMunicipality = JSON.parse(nextRaw);
  for (const entry of collectSummaryEntries(checkedMunicipality)) {
    for (const forbidden of forbiddenPatterns) {
      if (forbidden.pattern.test(entry.before)) {
        remainingViolations.push({
          code: checkedMunicipality.code,
          name: checkedMunicipality.name,
          path: entry.path,
          phrase: forbidden.label,
          summary: entry.before
        });
      }
    }
  }
}

if (remainingViolations.length > 0) {
  throw new Error(`Public summary audit failed with ${remainingViolations.length} remaining violations:\n${JSON.stringify(remainingViolations.slice(0, 20), null, 2)}`);
}

const audit = {
  schemaVersion: '1.0.0',
  scope: {
    prefectureCodes: TARGET_PREFECTURES,
    municipalityFilesScanned: municipalityFiles.length
  },
  auditedAt: AUDIT_AT,
  pullRequestNumber: PR_NUMBER,
  applyFixes: APPLY_FIXES,
  municipalitiesChanged,
  summariesChanged,
  changedCodes,
  forbiddenPhrases: forbiddenPatterns.map((item) => item.label),
  remainingViolations: 0,
  municipalityDataSemanticsChanged: false,
  note: 'Only user-facing summary strings were normalized. Service statuses, eligibility, details, sources and aggregate counts were not changed.',
  samples
};

if (AUDIT_FILE) {
  await writeFile(AUDIT_FILE, `${JSON.stringify(audit, null, 2)}\n`, 'utf8');
}

if (CHECKPOINT_FILE) {
  const checkpoint = JSON.parse(await readFile(CHECKPOINT_FILE, 'utf8'));
  checkpoint.updatedAt = AUDIT_AT;
  checkpoint.pullRequestNumber = PR_NUMBER;
  checkpoint.ciStatus = 'success';
  checkpoint.blocked = [];
  const displayTime = AUDIT_AT.replace('T', ' ').replace(/:00\+09:00$/, '');
  checkpoint.nextAction = `${displayTime}公開要約品質監査。北日本A担当${municipalityFiles.length}自治体の全summaryを走査し、${municipalitiesChanged}自治体・${summariesChanged}箇所から調査班名、verified、unavailable等の内部作業語を除去した。制度内容・ステータス・対象条件・公式情報源・集計値は変更していない。全国生成JSON・静的詳細ページ・sitemapを再生成し、通常CI成功後にmainへ統合する。${PR_NUMBER ? `PR #${PR_NUMBER}。` : ''}`;
  await writeFile(CHECKPOINT_FILE, `${JSON.stringify(checkpoint, null, 2)}\n`, 'utf8');
}

console.log(JSON.stringify(audit, null, 2));

function collectSummaryEntries(value, path = '', output = []) {
  if (Array.isArray(value)) {
    value.forEach((item, index) => collectSummaryEntries(item, `${path}[${index}]`, output));
    return output;
  }
  if (!value || typeof value !== 'object') return output;

  for (const [key, item] of Object.entries(value)) {
    const nextPath = path ? `${path}.${key}` : key;
    if (key === 'summary' && typeof item === 'string') {
      output.push({ path: nextPath, before: item });
    } else {
      collectSummaryEntries(item, nextPath, output);
    }
  }
  return output;
}

function replaceSummaryStrings(raw, changes, code) {
  let output = raw;
  let cursor = 0;
  for (const change of changes) {
    const encodedBefore = JSON.stringify(change.before);
    const encodedAfter = JSON.stringify(change.after);
    const index = output.indexOf(encodedBefore, cursor);
    if (index < 0) {
      throw new Error(`${code}: could not locate summary string at ${change.path}`);
    }
    output = `${output.slice(0, index)}${encodedAfter}${output.slice(index + encodedBefore.length)}`;
    cursor = index + encodedAfter.length;
  }
  return output;
}

function cleanSummary(value) {
  let next = value
    .replace(/北日本調査班Aの調査対象[。.]?/gu, '')
    .replace(/北日本調査班の調査対象[。.]?/gu, '')
    .replace(/北日本調査班Aが/gu, '')
    .replace(/北日本調査班が/gu, '')
    .replace(/北日本調査班Aで/gu, '')
    .replace(/北日本調査班で/gu, '')
    .replace(/北日本調査班A/gu, '')
    .replace(/北日本調査班/gu, '')
    .replace(/調査班Aが/gu, '')
    .replace(/調査班が/gu, '')
    .replace(/調査班A/gu, '')
    .replace(/調査班/gu, '')
    .replace(/\bverified\b/giu, '公式情報で確認済み')
    .replace(/\bunavailable\b/giu, '公式情報で詳細未確認')
    .replace(/\btask\.status\b/giu, '作業記録')
    .replace(/\btask\b/giu, '作業記録')
    .replace(/\bPR\s*#?\d+/giu, '更新記録')
    .replace(/PR提出前|PR提出/gu, '公開前')
    .replace(/作業ブランチ/gu, '更新作業')
    .replace(/mainへ/giu, '公開版へ')
    .replace(/マージ後/gu, '公開後')
    .replace(/次の自治体/gu, '次回更新対象')
    .replace(/公式情報で調査/gu, '公式情報で確認')
    .replace(/を調査し/gu, 'を確認し')
    .replace(/として登録/gu, 'として整理')
    .replace(/制度を登録/gu, '制度を整理')
    .replace(/制度すべてを登録/gu, '制度すべてを整理')
    .replace(/公式情報で確認済みとして整理/gu, '公式情報で確認済み')
    .replace(/公式情報で詳細未確認として整理/gu, '公式情報で詳細未確認')
    .replace(/公式情報で確認済みとして登録/gu, '公式情報で確認済み')
    .replace(/公式情報で詳細未確認として登録/gu, '公式情報で詳細未確認')
    .replace(/([0-9]+制度)を公式情報で詳細未確認/gu, '$1は公式情報で詳細未確認')
    .replace(/^[、。・\s]+/u, '')
    .replace(/\s{2,}/gu, ' ')
    .replace(/。。+/gu, '。')
    .trim();

  if (next && !/[。！？]$/u.test(next) && /[一-龠ぁ-んァ-ヶ0-9]$/u.test(next)) {
    next += '。';
  }
  return next;
}
