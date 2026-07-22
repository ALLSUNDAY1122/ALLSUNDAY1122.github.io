import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { execFileSync } from 'node:child_process';

const ROOT = process.cwd();
const SITE = path.join(ROOT, 'yorugatari');
const CATEGORY_DIR = path.join(SITE, 'categories');
const BASE = 'https://allsunday1122.github.io/yorugatari';
const ANALYTICS_VERSION = '20260723-003';
const CATALOG_FILES = [
  'assets/stories.js',
  'assets/stories-016-025.js',
  'assets/stories-026-035.js',
  'assets/stories-036-045.js',
  'assets/stories-046-055.js',
  'assets/stories-056-065.js',
  'assets/stories-066-075.js',
  'assets/stories-076-085.js',
  'assets/stories-086-095.js',
  'assets/stories-096-100.js'
];
const CATEGORIES = [
  { name: '心霊', slug: 'shinrei', description: '幽霊、死者、古い家、事故現場など、目に見えない存在が日常へ入り込むオリジナル怖い話。' },
  { name: '人怖', slug: 'hitokowa', description: '監視、侵入、支配、詐欺など、人間の意図と行動が生む現実的な恐怖を描いた怖い話。' },
  { name: '意味怖', slug: 'imikowa', description: '最後の一文や隠された事実によって、それまでの出来事の意味が反転する怖い話。' },
  { name: 'ネット怪談', slug: 'net-kaidan', description: 'スマートフォン、SNS、クラウド、録音、通信機器を通じて広がる現代の怪談。' },
  { name: '都市伝説風', slug: 'urban-legend', description: '学校、駅、道路、施設などに残る奇妙な規則や噂を題材にした都市伝説風の怖い話。' },
  { name: '後味悪い', slug: 'aftertaste', description: '事件が終わっても救い切れず、不穏な余韻や割り切れなさが残る怖い話。' }
];

function loadStories() {
  const sandbox = { window: { STORIES: [], NOTION_STORIES: [] } };
  vm.createContext(sandbox);
  for (const relative of CATALOG_FILES) {
    vm.runInContext(fs.readFileSync(path.join(SITE, relative), 'utf8'), sandbox, { filename: relative });
  }
  const combined = [...sandbox.window.STORIES, ...sandbox.window.NOTION_STORIES];
  const stories = Array.from(new Map(combined.map((story) => [story.slug, story])).values());
  if (stories.length !== 100) throw new Error(`Expected 100 unique stories, found ${stories.length}`);
  return stories.map((story, index) => ({ ...story, number: index + 1 }));
}

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function escapeXml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
}

function storyLastModified(story) {
  const relative = `yorugatari/stories/${story.slug}.html`;
  const value = execFileSync('git', ['log', '-1', '--format=%cs', '--', relative], { cwd: ROOT, encoding: 'utf8' }).trim();
  return /^\d{4}-\d{2}-\d{2}$/.test(value) ? value : new Date().toISOString().slice(0, 10);
}

function categoryLinks(prefix = '') {
  return CATEGORIES.map((category) => `<a class="chip" href="${prefix}categories/${category.slug}.html">${category.name}</a>`).join('');
}

function ensureFeedAndCategoryLinks() {
  const feedTag = '  <link rel="alternate" type="application/rss+xml" title="夜語り RSS" href="https://allsunday1122.github.io/yorugatari/feed.xml">\n';
  const indexPath = path.join(SITE, 'index.html');
  let index = fs.readFileSync(indexPath, 'utf8');
  if (!index.includes('rel="alternate" type="application/rss+xml"')) index = index.replace('</head>', `${feedTag}</head>`);
  if (!index.includes('aria-label="カテゴリ別の怖い話ページ"')) {
    index = index.replace(
      '<div class="grid" id="storyGrid"></div>',
      `<nav class="chips category-page-links" aria-label="カテゴリ別の怖い話ページ">${categoryLinks()}</nav><div class="grid" id="storyGrid"></div>`
    );
  }
  fs.writeFileSync(indexPath, index);

  const archivePath = path.join(SITE, 'archive.html');
  let archive = fs.readFileSync(archivePath, 'utf8');
  if (!archive.includes('rel="alternate" type="application/rss+xml"')) archive = archive.replace('</head>', `${feedTag}</head>`);
  if (!archive.includes('aria-label="カテゴリ別ページ"')) {
    archive = archive.replace(
      '<nav class="archive-jump" id="archiveJump" aria-label="カテゴリへ移動"></nav>',
      `<nav class="archive-jump" id="archiveJump" aria-label="カテゴリへ移動"></nav><nav class="archive-jump" aria-label="カテゴリ別ページ">${categoryLinks()}</nav>`
    );
  }
  fs.writeFileSync(archivePath, archive);
}

function categoryPage(category, stories) {
  const canonical = `${BASE}/categories/${category.slug}.html`;
  const title = `${category.name}の怖い話${stories.length}選｜夜語り`;
  const description = `${category.description}約5分で読める一話完結作品を${stories.length}話掲載しています。`;
  const listItems = stories.map((story, index) => ({
    '@type': 'ListItem',
    position: index + 1,
    url: `${BASE}/stories/${story.slug}.html`,
    name: story.title
  }));
  const collection = {
    '@context': 'https://schema.org',
    '@type': 'CollectionPage',
    name: `${category.name}の怖い話`,
    description,
    url: canonical,
    inLanguage: 'ja',
    numberOfItems: stories.length,
    mainEntity: { '@type': 'ItemList', itemListElement: listItems }
  };
  const breadcrumb = {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: [
      { '@type': 'ListItem', position: 1, name: '夜語り', item: `${BASE}/` },
      { '@type': 'ListItem', position: 2, name: '全100話', item: `${BASE}/archive.html` },
      { '@type': 'ListItem', position: 3, name: category.name, item: canonical }
    ]
  };
  const items = stories.map((story) => `<a class="archive-item" href="../stories/${story.slug}.html"><span class="archive-no">${String(story.number).padStart(3, '0')}</span><span class="archive-copy"><strong>${escapeHtml(story.title)}</strong><small>${escapeHtml(story.summary)}</small><span class="meta"><span class="badge">${escapeHtml(story.category)}</span><span>約${story.minutes}分</span><span>怖さ ${'★'.repeat(story.fear)}${'☆'.repeat(Math.max(0, 5 - story.fear))}</span></span></span></a>`).join('');
  const nav = CATEGORIES.map((item) => `<a class="chip${item.slug === category.slug ? ' active' : ''}" href="${item.slug}.html"${item.slug === category.slug ? ' aria-current="page"' : ''}>${item.name}</a>`).join('');

  return `<!doctype html>
<html lang="ja">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>${escapeHtml(title)}</title>
  <meta name="description" content="${escapeHtml(description)}">
  <meta name="robots" content="index,follow,max-snippet:-1">
  <meta name="theme-color" content="#090b10">
  <link rel="canonical" href="${canonical}">
  <link rel="alternate" type="application/rss+xml" title="夜語り RSS" href="${BASE}/feed.xml">
  <link rel="stylesheet" href="../assets/styles.css?v=20260719-112">
  <meta property="og:locale" content="ja_JP">
  <meta property="og:type" content="website">
  <meta property="og:url" content="${canonical}">
  <meta property="og:site_name" content="夜語り">
  <meta property="og:title" content="${escapeHtml(title)}">
  <meta property="og:description" content="${escapeHtml(description)}">
  <meta property="og:image" content="${BASE}/assets/yorugatari-share.png">
  <meta property="og:image:width" content="2172">
  <meta property="og:image:height" content="724">
  <meta property="og:image:alt" content="月明かりと提灯が照らす夜の町並み">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:image" content="${BASE}/assets/yorugatari-share.png">
  <meta name="twitter:image:alt" content="月明かりと提灯が照らす夜の町並み">
  <style>.category-summary{max-width:760px;color:var(--muted);font-size:1.02rem}.category-nav{margin-top:1.5rem}.category-list{display:grid;gap:.75rem;padding:0 0 70px}.archive-item{display:grid;grid-template-columns:3.5rem 1fr;gap:1rem;align-items:start;padding:1rem 1.1rem;border:1px solid var(--line);border-radius:14px;background:rgba(255,255,255,.02)}.archive-item:hover{transform:translateY(-1px);border-color:rgba(255,255,255,.28)}.archive-no{font-variant-numeric:tabular-nums;color:var(--muted);font-size:.9rem;padding-top:.15rem}.archive-copy{display:grid;gap:.4rem}.archive-copy strong{font-family:serif;font-size:1.1rem}.archive-copy small{color:var(--muted);line-height:1.65}.archive-copy .meta{margin-top:.2rem}@media(max-width:640px){.archive-item{grid-template-columns:2.7rem 1fr;padding:.9rem}.archive-copy small{font-size:.84rem}}</style>
  <script type="application/ld+json">${JSON.stringify(collection)}</script>
  <script type="application/ld+json">${JSON.stringify(breadcrumb)}</script>
</head>
<body>
  <a class="skip-link" href="#category-content">作品一覧へ移動</a>
  <header class="site-header"><div class="wrap header-inner"><a class="logo" href="../index.html"><span class="logo-mark">夜</span>語り</a><nav class="nav" aria-label="主要メニュー"><a href="../index.html#stories">怖い話</a><a href="../archive.html">全100話</a><a href="../about.html">このサイトについて</a></nav></div></header>
  <main id="category-content" tabindex="-1">
    <section class="story-hero"><div class="wrap"><nav class="breadcrumb" aria-label="パンくずリスト"><a href="../index.html">夜語り</a><span aria-hidden="true">›</span><a href="../archive.html">全100話</a><span aria-hidden="true">›</span><span>${category.name}</span></nav><div class="eyebrow">Horror category</div><h1>${category.name}の怖い話</h1><p class="category-summary">${escapeHtml(category.description)}</p><p class="section-note">全${stories.length}話・すべて約5分・一話完結</p><nav class="chips category-nav" aria-label="ほかのカテゴリ">${nav}</nav></div></section>
    <section class="wrap category-list" aria-label="${category.name}の作品一覧">${items}</section>
  </main>
  <footer class="site-footer"><div class="wrap footer-inner"><span>© 2026 夜語り</span><nav class="footer-links" aria-label="運営情報"><a href="../index.html">トップ</a><a href="../archive.html">全100話</a><a href="../feed.xml">RSS</a><a href="../about.html">運営・編集方針</a><a href="../privacy.html">プライバシー</a></nav></div></footer>
  <script src="../assets/analytics.js?v=${ANALYTICS_VERSION}"></script>
</body>
</html>
`;
}

function buildFeed(stories) {
  const dated = stories.map((story) => ({ ...story, modified: storyLastModified(story) }))
    .sort((left, right) => right.modified.localeCompare(left.modified) || left.number - right.number)
    .slice(0, 30);
  const latest = dated[0]?.modified || new Date().toISOString().slice(0, 10);
  const pubDate = (date) => new Date(`${date}T00:00:00+09:00`).toUTCString();
  const items = dated.map((story) => `    <item>
      <title>${escapeXml(story.title)}</title>
      <link>${BASE}/stories/${story.slug}.html</link>
      <guid isPermaLink="true">${BASE}/stories/${story.slug}.html</guid>
      <description>${escapeXml(story.summary)}</description>
      <category>${escapeXml(story.category)}</category>
      <pubDate>${pubDate(story.modified)}</pubDate>
    </item>`).join('\n');
  return `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
  <channel>
    <title>夜語り｜オリジナル怖い話</title>
    <link>${BASE}/</link>
    <description>約5分で読める一話完結のオリジナル怖い話100作品。</description>
    <language>ja</language>
    <lastBuildDate>${pubDate(latest)}</lastBuildDate>
    <atom:link href="${BASE}/feed.xml" rel="self" type="application/rss+xml" />
${items}
  </channel>
</rss>
`;
}

const stories = loadStories();
fs.mkdirSync(CATEGORY_DIR, { recursive: true });
ensureFeedAndCategoryLinks();
const categoryReport = [];
for (const category of CATEGORIES) {
  const matching = stories.filter((story) => story.category === category.name);
  if (!matching.length) throw new Error(`No stories found for category ${category.name}`);
  fs.writeFileSync(path.join(CATEGORY_DIR, `${category.slug}.html`), categoryPage(category, matching));
  categoryReport.push({ name: category.name, slug: category.slug, stories: matching.length });
}
fs.writeFileSync(path.join(SITE, 'feed.xml'), buildFeed(stories));
const totalAssigned = categoryReport.reduce((sum, row) => sum + row.stories, 0);
if (totalAssigned !== stories.length) throw new Error(`Category assignment mismatch: ${totalAssigned}/${stories.length}`);
const report = {
  generatedAt: new Date().toISOString(),
  success: true,
  categories: categoryReport,
  totalStories: stories.length,
  feedItems: 30,
  files: [...categoryReport.map((row) => `categories/${row.slug}.html`), 'feed.xml']
};
fs.writeFileSync(path.join(SITE, 'tools', 'discovery-manifest-latest.json'), `${JSON.stringify(report, null, 2)}\n`);
console.log(`YORUGATARI_DISCOVERY_GENERATION=${JSON.stringify(report)}`);
