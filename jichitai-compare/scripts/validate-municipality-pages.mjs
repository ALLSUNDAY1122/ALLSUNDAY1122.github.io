import { access, mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const PROJECT_DIR = resolve(SCRIPT_DIR, '..');
const GENERATED_FILE = join(PROJECT_DIR, 'data', 'generated', 'municipalities.json');
const MANIFEST_FILE = join(PROJECT_DIR, 'data', 'generated', 'municipality-pages.json');
const SITEMAP_FILE = join(PROJECT_DIR, 'sitemap.xml');
const FAILURE_REPORT_FILE = join(PROJECT_DIR, 'operations', 'audits', 'public-summary-validation-report.json');
const INTERNAL_WORKFLOW_PHRASES = [
  'PR提出前',
  'PR提出',
  '作業ブランチ',
  'CI run',
  'mainへ',
  'マージ後',
  '最終検証を実施',
  '次の自治体'
];
const WEST_INTERNAL_PHRASES = ['調査班', '初期登録対象', '移行監査', '地域正本'];
const WEST_PUBLIC_COPY_GUARDS = [
  {
    scope: 'west-a',
    label: '西日本A',
    municipalityCount: 226,
    prefectureCodes: new Set(['33', '37', '39', '40', '43', '46'])
  },
  {
    scope: 'west-b',
    label: '西日本B',
    municipalityCount: 250,
    prefectureCodes: new Set(['31', '32', '34', '35', '36', '38', '41', '42', '44', '45', '47'])
  }
];

const generated = JSON.parse(await readFile(GENERATED_FILE, 'utf8'));
const manifest = JSON.parse(await readFile(MANIFEST_FILE, 'utf8'));
const sitemap = await readFile(SITEMAP_FILE, 'utf8');
const municipalities = generated.municipalities ?? [];
const pages = manifest.pages ?? [];
const errors = [];
const internalWorkflowViolations = [];

if (manifest.schemaVersion !== '1.0.0') errors.push(`manifest schemaVersionが不正です: ${manifest.schemaVersion}`);
if (manifest.municipalityCount !== municipalities.length) {
  errors.push(`manifest件数が不一致です: ${manifest.municipalityCount}/${municipalities.length}`);
}
if (pages.length !== municipalities.length) errors.push(`pages件数が不一致です: ${pages.length}/${municipalities.length}`);

const municipalityByCode = new Map(municipalities.map((item) => [item.code, item]));
const seen = new Set();
for (const page of pages) {
  if (seen.has(page.code)) errors.push(`ページコードが重複しています: ${page.code}`);
  seen.add(page.code);
  if (!municipalityByCode.has(page.code)) errors.push(`元データのないページです: ${page.code}`);
}
for (const municipality of municipalities) {
  if (!seen.has(municipality.code)) errors.push(`ページがmanifestにありません: ${municipality.code}`);

  const publicSummaries = [
    { field: 'municipality.summary', value: municipality.summary },
    ...Object.entries(municipality.services ?? {}).map(([serviceKey, service]) => ({
      field: `services.${serviceKey}.summary`,
      value: service?.summary
    }))
  ].filter((item) => typeof item.value === 'string');

  for (const phrase of INTERNAL_WORKFLOW_PHRASES) {
    for (const summary of publicSummaries) {
      if (!summary.value.includes(phrase)) continue;
      errors.push(`${municipality.code}: 公開要約に内部作業文言「${phrase}」が含まれています`);
      internalWorkflowViolations.push({
        code: municipality.code,
        prefectureCode: municipality.prefectureCode ?? null,
        prefecture: municipality.prefecture ?? null,
        name: municipality.name ?? null,
        source: summary.field,
        phrase,
        text: summary.value
      });
    }
  }

  for (const guard of WEST_PUBLIC_COPY_GUARDS) {
    if (!guard.prefectureCodes.has(municipality.prefectureCode)) continue;
    for (const phrase of WEST_INTERNAL_PHRASES) {
      for (const summary of publicSummaries) {
        if (!summary.value.includes(phrase)) continue;
        errors.push(`${municipality.code}: ${guard.label}公開要約に内部運用語「${phrase}」が含まれています`);
        internalWorkflowViolations.push({
          code: municipality.code,
          prefectureCode: municipality.prefectureCode ?? null,
          prefecture: municipality.prefecture ?? null,
          name: municipality.name ?? null,
          source: summary.field,
          phrase,
          text: summary.value,
          scope: guard.scope
        });
      }
    }
  }
}

for (let start = 0; start < pages.length; start += 100) {
  const batch = pages.slice(start, start + 100);
  await Promise.all(batch.map(async (page) => {
    const municipality = municipalityByCode.get(page.code);
    const filePath = join(PROJECT_DIR, page.path);
    try {
      await access(filePath);
      const html = await readFile(filePath, 'utf8');
      const canonical = `https://allsunday1122.github.io/jichitai-compare/municipality/${page.code}/`;
      const municipalityName = escapeHtml(municipality?.name ?? '');
      const officialUrl = escapeHtml(municipality?.officialUrl ?? '');
      const publicSummary = String(municipality?.summary ?? '');
      const escapedPublicSummary = escapeHtml(publicSummary);
      const compareUrl = `../../?compare=${page.code}&amp;pref=${escapeHtml(municipality?.prefectureCode ?? '')}`;
      const officialLink = `<a href="${officialUrl}" target="_blank" rel="noopener noreferrer">${municipalityName}公式サイト</a>`;
      const compareLink = `<a href="${compareUrl}">${municipalityName}を比較画面で開く</a>`;

      if (!html.includes(`<link rel="canonical" href="${canonical}">`)) errors.push(`${page.code}: canonicalが不正です`);
      if (!html.includes(`<h1>${municipalityName}</h1>`)) errors.push(`${page.code}: h1が自治体名と一致しません`);
      if (!html.includes(`<p>${escapedPublicSummary}</p>`)) errors.push(`${page.code}: 公開要約が生成JSONと一致しません`);
      if (!html.includes('9制度')) errors.push(`${page.code}: 9制度の説明がありません`);
      if (html.includes('制度なし・対象外')) errors.push(`${page.code}: unavailableの旧誤表示が残っています`);
      if (!html.includes('自治体公式情報')) errors.push(`${page.code}: 公式情報への表示がありません`);
      if (!html.includes(officialLink)) errors.push(`${page.code}: 自治体公式サイトリンクが元データのofficialUrlと一致しません`);
      if (!html.includes(compareLink)) errors.push(`${page.code}: 比較画面への自治体指定リンクが不正です`);
      if (!sitemap.includes(`<loc>${canonical}</loc>`)) errors.push(`${page.code}: sitemapにURLがありません`);
      for (const phrase of INTERNAL_WORKFLOW_PHRASES) {
        if (!html.includes(phrase)) continue;
        errors.push(`${page.code}: 公開ページに内部作業文言「${phrase}」が含まれています`);
        internalWorkflowViolations.push({
          code: page.code,
          prefectureCode: municipality?.prefectureCode ?? null,
          prefecture: municipality?.prefecture ?? null,
          name: municipality?.name ?? null,
          source: page.path,
          phrase,
          text: null
        });
      }
      for (const guard of WEST_PUBLIC_COPY_GUARDS) {
        if (!guard.prefectureCodes.has(municipality?.prefectureCode)) continue;
        for (const phrase of WEST_INTERNAL_PHRASES) {
          if (!html.includes(phrase)) continue;
          errors.push(`${page.code}: ${guard.label}公開ページに内部運用語「${phrase}」が含まれています`);
          internalWorkflowViolations.push({
            code: page.code,
            prefectureCode: municipality?.prefectureCode ?? null,
            prefecture: municipality?.prefecture ?? null,
            name: municipality?.name ?? null,
            source: page.path,
            phrase,
            text: null,
            scope: guard.scope
          });
        }
      }
    } catch (cause) {
      errors.push(`${page.code}: ページを読み込めません: ${cause.message}`);
    }
  }));
}

const sitemapCount = (sitemap.match(/<url>/gu) ?? []).length;
const expectedSitemapCount = municipalities.length + 3;
if (sitemapCount !== expectedSitemapCount) errors.push(`sitemap件数が不一致です: ${sitemapCount}/${expectedSitemapCount}`);

if (errors.length > 0) {
  await mkdir(dirname(FAILURE_REPORT_FILE), { recursive: true });
  await writeFile(
    FAILURE_REPORT_FILE,
    JSON.stringify({
      schemaVersion: '1.0.0',
      generatedAt: new Date().toISOString(),
      municipalityCount: municipalities.length,
      pageCount: pages.length,
      errorCount: errors.length,
      internalWorkflowViolationCount: internalWorkflowViolations.length,
      internalWorkflowViolations,
      errors
    }, null, 2) + '\n',
    'utf8'
  );
  console.error(`自治体別ページ検証失敗: ${errors.length}件`);
  errors.slice(0, 100).forEach((error) => console.error(`- ${error}`));
  if (errors.length > 100) console.error(`...ほか${errors.length - 100}件`);
  console.error(`検証レポート: ${FAILURE_REPORT_FILE}`);
  process.exit(1);
}

const westGuardSummary = WEST_PUBLIC_COPY_GUARDS
  .map((guard) => `${guard.label}公開要約${guard.municipalityCount}自治体`)
  .join('・');
console.log(`自治体別ページ検証成功: ${municipalities.length}ページ・公開要約一致・公式サイト/比較導線・内部作業文言なし・${westGuardSummary}・sitemap ${sitemapCount} URL`);

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}
