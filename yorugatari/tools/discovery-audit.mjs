import fs from 'node:fs';
import path from 'node:path';

const ROOT = process.cwd();
const SITE = path.join(ROOT, 'yorugatari');
const BASE = 'https://allsunday1122.github.io/yorugatari';
const LIVE = process.argv.includes('--live');
const CATEGORIES = [
  { name: '心霊', slug: 'shinrei', linkLabel: '心霊・幽霊', heading: '心霊・幽霊の怖い話', titlePhrase: '心霊・幽霊の怖い話', descriptionPhrase: '心霊・幽霊の怖い話' },
  { name: '人怖', slug: 'hitokowa', linkLabel: '人が怖い話', heading: '人が怖い話（人怖）', titlePhrase: '人が怖い話｜人怖・実話風ホラー', descriptionPhrase: '人が怖い話' },
  { name: '意味怖', slug: 'imikowa', linkLabel: '意味がわかると怖い話', heading: '意味がわかると怖い話（意味怖）', titlePhrase: '意味がわかると怖い話｜意味怖', descriptionPhrase: '意味がわかると怖い話' },
  { name: 'ネット怪談', slug: 'net-kaidan', linkLabel: 'ネット・SNS怪談', heading: 'ネット・SNSの怖い話', titlePhrase: 'ネット・SNSの怖い話｜現代怪談', descriptionPhrase: 'ネット・SNSの怖い話' },
  { name: '都市伝説風', slug: 'urban-legend', linkLabel: '都市伝説・奇妙なルール', heading: '都市伝説・奇妙なルールの怖い話', titlePhrase: '都市伝説・奇妙なルールの怖い話', descriptionPhrase: '都市伝説風の怖い話' },
  { name: '後味悪い', slug: 'aftertaste', linkLabel: '後味の悪い話', heading: '後味の悪い怖い話', titlePhrase: '後味の悪い怖い話｜救いのない怪談', descriptionPhrase: '後味の悪い怖い話' }
];
const results = [];
const failures = [];

function record(name, ok, detail = null) {
  const row = { name, ok: Boolean(ok), detail };
  results.push(row);
  if (!row.ok) failures.push(row);
}

function storyLinks(html) {
  return Array.from(html.matchAll(/href=["']\.\.\/stories\/([^"'#?]+\.html)["']/g), (match) => match[1]);
}

function itemCount(xml) {
  return (xml.match(/<item>/g) || []).length;
}

function extractMetaDescription(html) {
  return html.match(/<meta\s+name=["']description["']\s+content=["']([^"']+)["']/i)?.[1] || '';
}

function categoryReady(html, category) {
  const description = extractMetaDescription(html);
  return html.includes(`<title>${category.titlePhrase}`) &&
    html.includes(`<h1>${category.heading}</h1>`) &&
    description.includes(category.descriptionPhrase) &&
    description.includes('無料');
}

function localAudit() {
  const manifestPath = path.join(SITE, 'tools', 'discovery-manifest-latest.json');
  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  record('local: discovery manifest reports six categories and 100 stories', manifest.success && manifest.categories.length === 6 && manifest.totalStories === 100 && manifest.feedItems === 30, manifest);

  const allStoryLinks = [];
  const descriptions = [];
  for (const category of CATEGORIES) {
    const filePath = path.join(SITE, 'categories', `${category.slug}.html`);
    const html = fs.readFileSync(filePath, 'utf8');
    const links = storyLinks(html);
    const description = extractMetaDescription(html);
    descriptions.push(description);
    allStoryLinks.push(...links);
    record(`local: ${category.name} category page uses search-friendly language and structure`,
      categoryReady(html, category) &&
      description.includes('約5分') &&
      html.includes(`<link rel="canonical" href="${BASE}/categories/${category.slug}.html">`) &&
      html.includes('rel="alternate" type="application/rss+xml"') &&
      html.includes('"@type":"CollectionPage"') &&
      html.includes('"@type":"BreadcrumbList"') &&
      links.length > 0,
      { slug: category.slug, heading: category.heading, description, storyLinks: links.length });
  }
  record('local: category descriptions are unique', new Set(descriptions).size === CATEGORIES.length, { descriptions: descriptions.length, unique: new Set(descriptions).size });
  record('local: category pages link to all 100 stories exactly once', allStoryLinks.length === 100 && new Set(allStoryLinks).size === 100, { links: allStoryLinks.length, unique: new Set(allStoryLinks).size });

  const feed = fs.readFileSync(path.join(SITE, 'feed.xml'), 'utf8');
  const feedLinks = Array.from(feed.matchAll(/<guid isPermaLink="true">([^<]+)<\/guid>/g), (match) => match[1]);
  record('local: RSS feed has 30 unique story items and a self link', itemCount(feed) === 30 && new Set(feedLinks).size === 30 && feed.includes(`<atom:link href="${BASE}/feed.xml" rel="self" type="application/rss+xml" />`), { items: itemCount(feed), unique: new Set(feedLinks).size });

  for (const page of ['index.html', 'archive.html']) {
    const html = fs.readFileSync(path.join(SITE, page), 'utf8');
    const categoryTargets = CATEGORIES.filter((category) => html.includes(`categories/${category.slug}.html`));
    const searchLabels = CATEGORIES.filter((category) => html.includes(`>${category.linkLabel}</a>`));
    record(`local: ${page} exposes RSS and all search-friendly category pages`, html.includes('rel="alternate" type="application/rss+xml"') && html.includes('href="feed.xml">RSS</a>') && categoryTargets.length === 6 && searchLabels.length === 6, { categories: categoryTargets.length, labels: searchLabels.length });
  }
}

async function fetchText(url, ready = () => true, attempts = 18) {
  let detail = null;
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try {
      const separator = url.includes('?') ? '&' : '?';
      const response = await fetch(`${url}${separator}discovery=${Date.now()}-${attempt}`, {
        redirect: 'follow',
        headers: { 'cache-control': 'no-cache, no-store, max-age=0', 'pragma': 'no-cache', 'user-agent': 'Yorugatari-Discovery-Audit/1.3' },
        signal: AbortSignal.timeout(30000)
      });
      const text = await response.text();
      const current = response.status === 200 && ready(text);
      detail = { attempt, status: response.status, text, current };
      if (current) return detail;
    } catch (error) {
      detail = { attempt, status: null, text: '', current: false, error: error.message };
    }
    if (attempt < attempts) await new Promise((resolve) => setTimeout(resolve, 5000));
  }
  return detail;
}

async function liveAudit() {
  const topReady = (html) => CATEGORIES.every((category) => html.includes(`categories/${category.slug}.html`) && html.includes(`>${category.linkLabel}</a>`)) && html.includes('href="feed.xml">RSS</a>');
  const top = await fetchText(`${BASE}/`, topReady);
  const topCategories = CATEGORIES.filter((category) => top.text.includes(`categories/${category.slug}.html`));
  const topLabels = CATEGORIES.filter((category) => top.text.includes(`>${category.linkLabel}</a>`));
  record('published: top exposes RSS and six search-friendly category links', top.status === 200 && top.current && top.text.includes('rel="alternate" type="application/rss+xml"') && topCategories.length === 6 && topLabels.length === 6, { status: top.status, attempt: top.attempt, current: top.current, categories: topCategories.length, labels: topLabels.length });

  const linkedStories = [];
  for (const category of CATEGORIES) {
    const response = await fetchText(`${BASE}/categories/${category.slug}.html`, (html) => categoryReady(html, category));
    const canonical = `${BASE}/categories/${category.slug}.html`;
    const links = storyLinks(response.text);
    const description = extractMetaDescription(response.text);
    linkedStories.push(...links);
    const ok = response.status === 200 && response.current && response.text.includes(`<link rel="canonical" href="${canonical}">`) && categoryReady(response.text, category) && links.length > 0;
    record(`published: ${category.name} category page uses search-friendly language`, ok, { status: response.status, attempt: response.attempt, current: response.current, links: links.length, canonical, heading: category.heading, description });
  }
  record('published: six category pages cover 100 unique stories', linkedStories.length === 100 && new Set(linkedStories).size === 100, { links: linkedStories.length, unique: new Set(linkedStories).size });

  const feed = await fetchText(`${BASE}/feed.xml`, (xml) => xml.includes('<rss version="2.0"') && itemCount(xml) === 30);
  const feedLinks = Array.from(feed.text.matchAll(/<guid isPermaLink="true">([^<]+)<\/guid>/g), (match) => match[1]);
  record('published: RSS feed is valid and contains 30 unique stories', feed.status === 200 && feed.current && itemCount(feed.text) === 30 && new Set(feedLinks).size === 30, { status: feed.status, attempt: feed.attempt, current: feed.current, items: itemCount(feed.text), unique: new Set(feedLinks).size });
}

if (LIVE) await liveAudit();
else localAudit();

const report = { auditedAt: new Date().toISOString(), mode: LIVE ? 'live' : 'local', success: failures.length === 0, results, failures };
fs.writeFileSync(path.join(ROOT, 'yorugatari-discovery-report.json'), `${JSON.stringify(report, null, 2)}\n`);
console.log(`YORUGATARI_DISCOVERY_REPORT=${JSON.stringify(report)}`);
if (failures.length) process.exit(1);
