import { mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const PROJECT_DIR = resolve(SCRIPT_DIR, '..');
const GENERATED_FILE = join(PROJECT_DIR, 'data', 'generated', 'municipalities.json');
const DEFINITIONS_FILE = join(PROJECT_DIR, 'data', 'service-definitions.json');
const OUTPUT_DIR = join(PROJECT_DIR, 'municipality');
const MANIFEST_FILE = join(PROJECT_DIR, 'data', 'generated', 'municipality-pages.json');
const SITEMAP_FILE = join(PROJECT_DIR, 'sitemap.xml');
const SITE_ROOT = 'https://allsunday1122.github.io/jichitai-compare/';

const generated = JSON.parse(await readFile(GENERATED_FILE, 'utf8'));
const definitions = JSON.parse(await readFile(DEFINITIONS_FILE, 'utf8'));
const municipalities = [...(generated.municipalities ?? [])].sort((a, b) => a.code.localeCompare(b.code));
const serviceDefinitions = definitions.services ?? [];
const updatedAt = generated.meta?.updatedAt ?? new Date().toISOString().slice(0, 10);

if (municipalities.length === 0) throw new Error('自治体データがありません');
if (serviceDefinitions.length !== 9) throw new Error(`制度定義数が不正です: ${serviceDefinitions.length}`);

const byPrefecture = new Map();
for (const municipality of municipalities) {
  const list = byPrefecture.get(municipality.prefectureCode) ?? [];
  list.push(municipality);
  byPrefecture.set(municipality.prefectureCode, list);
}

await rm(OUTPUT_DIR, { recursive: true, force: true });
await mkdir(OUTPUT_DIR, { recursive: true });

for (let start = 0; start < municipalities.length; start += 100) {
  const batch = municipalities.slice(start, start + 100);
  await Promise.all(batch.map(async (municipality) => {
    const directory = join(OUTPUT_DIR, municipality.code);
    await mkdir(directory, { recursive: true });
    await writeFile(join(directory, 'index.html'), renderMunicipalityPage(municipality), 'utf8');
  }));
}

const pages = municipalities.map((municipality) => ({
  code: municipality.code,
  prefectureCode: municipality.prefectureCode,
  prefecture: municipality.prefecture,
  name: municipality.name,
  path: `municipality/${municipality.code}/index.html`,
  url: `${SITE_ROOT}municipality/${municipality.code}/`
}));

await writeFile(MANIFEST_FILE, `${JSON.stringify({
  schemaVersion: '1.0.0',
  updatedAt,
  municipalityCount: pages.length,
  pages
}, null, 2)}\n`, 'utf8');

await writeFile(SITEMAP_FILE, renderSitemap(pages), 'utf8');
console.log(`自治体別静的ページを生成しました: ${pages.length}ページ`);

function renderMunicipalityPage(municipality) {
  const canonical = `${SITE_ROOT}municipality/${municipality.code}/`;
  const title = `${municipality.name}の子育て支援・公共サービス9制度｜自治体くらべ`;
  const description = `${municipality.prefecture}${municipality.name}の子ども医療費、保育料、学校給食、産後ケア、住宅支援、粗大ごみ、防災など9制度を自治体公式情報から確認できます。`;
  const compareUrl = `../../?compare=${encodeURIComponent(municipality.code)}&pref=${encodeURIComponent(municipality.prefectureCode)}`;
  const services = serviceDefinitions
    .map((definition) => renderService(municipality.services?.[definition.id], definition))
    .join('\n');
  const related = (byPrefecture.get(municipality.prefectureCode) ?? [])
    .filter((item) => item.code !== municipality.code)
    .slice(0, 12)
    .map((item) => `<li><a href="../${escapeHtml(item.code)}/">${escapeHtml(item.name)}</a></li>`)
    .join('');
  const structuredData = JSON.stringify({
    '@context': 'https://schema.org',
    '@type': 'WebPage',
    name: title,
    url: canonical,
    description,
    inLanguage: 'ja',
    isPartOf: {
      '@type': 'WebSite',
      name: '自治体くらべ',
      url: SITE_ROOT
    },
    about: {
      '@type': 'AdministrativeArea',
      name: `${municipality.prefecture}${municipality.name}`,
      sameAs: municipality.officialUrl
    }
  }).replaceAll('<', '\\u003c');

  return `<!doctype html>
<html lang="ja">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="${escapeHtml(description)}">
  <meta name="theme-color" content="#0f766e">
  <meta name="robots" content="index,follow,max-image-preview:large">
  <title>${escapeHtml(title)}</title>
  <link rel="canonical" href="${escapeHtml(canonical)}">
  <meta property="og:type" content="article">
  <meta property="og:locale" content="ja_JP">
  <meta property="og:site_name" content="自治体くらべ">
  <meta property="og:title" content="${escapeHtml(title)}">
  <meta property="og:description" content="${escapeHtml(description)}">
  <meta property="og:url" content="${escapeHtml(canonical)}">
  <meta name="twitter:card" content="summary">
  <script type="application/ld+json">${structuredData}</script>
  <link rel="stylesheet" href="../../styles.css">
</head>
<body>
  <header class="site-header">
    <div class="shell header-inner">
      <a class="brand" href="../../" aria-label="自治体くらべ トップ">自治体くらべ <span>全国版</span></a>
      <nav aria-label="サイトナビゲーション">
        <a href="../../">比較トップ</a>
        <a href="../../about/">運営方針</a>
        <a href="../../privacy/">プライバシー</a>
      </nav>
    </div>
  </header>

  <main class="shell content-page">
    <article class="content-card">
      <nav aria-label="パンくずリスト"><a href="../../">全国</a> › ${escapeHtml(municipality.prefecture)} › ${escapeHtml(municipality.name)}</nav>
      <p class="eyebrow">${escapeHtml(municipality.prefecture)}・自治体制度情報</p>
      <h1>${escapeHtml(municipality.name)}</h1>
      <p>${escapeHtml(municipality.summary)}</p>
      <p><a href="${escapeHtml(compareUrl)}">${escapeHtml(municipality.name)}を比較画面で開く</a> ／ <a href="${escapeHtml(municipality.officialUrl)}" target="_blank" rel="noopener noreferrer">${escapeHtml(municipality.name)}公式サイト</a></p>

      <section>
        <h2>${escapeHtml(municipality.name)}の9制度</h2>
        <p>制度の正式な対象可否は、世帯状況や申請時期によって変わります。申請や転居の判断前に、必ず自治体の公式サイトまたは担当窓口で最新条件をご確認ください。</p>
        <div class="policy-list">
${services}
        </div>
      </section>

      <section>
        <h2>${escapeHtml(municipality.prefecture)}のほかの自治体</h2>
        ${related ? `<ul>${related}</ul>` : '<p>同じ都道府県の自治体ページはありません。</p>'}
      </section>

      <section>
        <h2>情報の見方</h2>
        <p>「確認済み」は自治体公式情報から主要条件を確認できた制度です。「公式情報で詳細未確認」は制度がないことを意味せず、現行年度の条件を公開情報だけでは確定できない状態です。</p>
        <p><a href="../../about/">情報掲載方針と訂正方法を確認する</a></p>
      </section>
    </article>
  </main>

  <footer>
    <div class="shell footer-inner">
      <div class="footer-copy">
        <p>自治体くらべ 全国版</p>
        <p>当サイトは自治体の公式サイトではありません。</p>
      </div>
      <nav class="footer-links" aria-label="フッターナビゲーション">
        <a href="../../">比較トップ</a>
        <a href="../../about/">運営方針</a>
        <a href="../../privacy/">プライバシー</a>
      </nav>
    </div>
  </footer>
</body>
</html>
`;
}

function renderService(service, definition) {
  if (!service) {
    return `          <div><dt>${escapeHtml(definition.label)}</dt><dd><span class="status review">データ未登録</span></dd></div>`;
  }
  const verified = service.status === 'verified';
  const statusLabel = verified ? '確認済み' : '公式情報で詳細未確認';
  const statusClass = verified ? 'status ok' : 'status review';
  const details = definition.detailFields
    .map((field) => {
      const value = formatValue(valueAtPath(service, field.path));
      return value === null ? null : `${field.label}：${value}${field.suffix ?? ''}`;
    })
    .filter(Boolean);
  const age = definition.eligibilityRule === 'ageRange' ? formatAge(service.eligibility) : null;
  if (age) details.unshift(`年齢目安：${age}`);
  const detailHtml = details.length ? `<p>${escapeHtml(details.join('／'))}</p>` : '';
  const source = service.source?.url
    ? `<p><a href="${escapeHtml(service.source.url)}" target="_blank" rel="noopener noreferrer">自治体公式情報（確認日 ${escapeHtml(service.source.checkedAt ?? '未記録')}）</a></p>`
    : '';
  const note = verified ? '' : '<p>制度がないとは限りません。現行条件は自治体へご確認ください。</p>';
  return `          <div>
            <dt>${escapeHtml(definition.label)}</dt>
            <dd><span class="${statusClass}">${statusLabel}</span><strong class="cell-main">${escapeHtml(service.summary)}</strong>${detailHtml}${note}${source}</dd>
          </div>`;
}

function formatAge(eligibility) {
  if (!eligibility || typeof eligibility !== 'object') return null;
  const min = Number.isInteger(eligibility.minAgeMonths) ? eligibility.minAgeMonths : null;
  const max = Number.isInteger(eligibility.maxAgeYears) ? eligibility.maxAgeYears : null;
  if (min === null && max === null) return null;
  if (min !== null && max !== null) return `生後${min}か月から${max}歳まで`;
  if (min !== null) return `生後${min}か月から`;
  return `${max}歳まで`;
}

function valueAtPath(object, path) {
  return String(path).split('.').reduce((value, key) => value?.[key], object);
}

function formatValue(value) {
  if (value === undefined || value === null || value === '') return null;
  if (Array.isArray(value)) return value.map(formatValue).filter(Boolean).join('、') || null;
  if (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') return String(value);
  return null;
}

function renderSitemap(pages) {
  const fixed = [
    { url: SITE_ROOT, priority: '1.0', changefreq: 'weekly' },
    { url: `${SITE_ROOT}about/`, priority: '0.5', changefreq: 'monthly' },
    { url: `${SITE_ROOT}privacy/`, priority: '0.5', changefreq: 'monthly' }
  ];
  const entries = [
    ...fixed,
    ...pages.map((page) => ({ url: page.url, priority: '0.7', changefreq: 'monthly' }))
  ];
  const body = entries.map((entry) => `  <url>\n    <loc>${escapeXml(entry.url)}</loc>\n    <lastmod>${updatedAt}</lastmod>\n    <changefreq>${entry.changefreq}</changefreq>\n    <priority>${entry.priority}</priority>\n  </url>`).join('\n');
  return `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${body}\n</urlset>\n`;
}

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

function escapeXml(value) {
  return escapeHtml(value);
}
