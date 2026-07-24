import { access, readFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const PROJECT_DIR = resolve(SCRIPT_DIR, '..');
const GENERATED_FILE = join(PROJECT_DIR, 'data', 'generated', 'municipalities.json');
const MANIFEST_FILE = join(PROJECT_DIR, 'data', 'generated', 'municipality-pages.json');
const SITEMAP_FILE = join(PROJECT_DIR, 'sitemap.xml');

const generated = JSON.parse(await readFile(GENERATED_FILE, 'utf8'));
const manifest = JSON.parse(await readFile(MANIFEST_FILE, 'utf8'));
const sitemap = await readFile(SITEMAP_FILE, 'utf8');
const municipalities = generated.municipalities ?? [];
const pages = manifest.pages ?? [];
const errors = [];

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
      if (!html.includes(`<link rel="canonical" href="${canonical}">`)) errors.push(`${page.code}: canonicalが不正です`);
      if (!html.includes(`<h1>${escapeHtml(municipality?.name ?? '')}</h1>`)) errors.push(`${page.code}: h1が自治体名と一致しません`);
      if (!html.includes('9制度')) errors.push(`${page.code}: 9制度の説明がありません`);
      if (html.includes('制度なし・対象外')) errors.push(`${page.code}: unavailableの旧誤表示が残っています`);
      if (!html.includes('自治体公式情報')) errors.push(`${page.code}: 公式情報への表示がありません`);
      if (!sitemap.includes(`<loc>${canonical}</loc>`)) errors.push(`${page.code}: sitemapにURLがありません`);
    } catch (cause) {
      errors.push(`${page.code}: ページを読み込めません: ${cause.message}`);
    }
  }));
}

const sitemapCount = (sitemap.match(/<url>/gu) ?? []).length;
const expectedSitemapCount = municipalities.length + 3;
if (sitemapCount !== expectedSitemapCount) errors.push(`sitemap件数が不一致です: ${sitemapCount}/${expectedSitemapCount}`);

if (errors.length > 0) {
  console.error(`自治体別ページ検証失敗: ${errors.length}件`);
  errors.slice(0, 100).forEach((error) => console.error(`- ${error}`));
  if (errors.length > 100) console.error(`...ほか${errors.length - 100}件`);
  process.exit(1);
}

console.log(`自治体別ページ検証成功: ${municipalities.length}ページ・sitemap ${sitemapCount} URL`);

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}
