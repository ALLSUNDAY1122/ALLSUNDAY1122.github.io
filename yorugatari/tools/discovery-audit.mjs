import fs from 'node:fs';
import path from 'node:path';

const ROOT = process.cwd();
const SITE = path.join(ROOT, 'yorugatari');
const BASE = 'https://allsunday1122.github.io/yorugatari';
const LIVE = process.argv.includes('--live');
const CATEGORIES = [
  ['心霊', 'shinrei'],
  ['人怖', 'hitokowa'],
  ['意味怖', 'imikowa'],
  ['ネット怪談', 'net-kaidan'],
  ['都市伝説風', 'urban-legend'],
  ['後味悪い', 'aftertaste']
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

function localAudit() {
  const manifestPath = path.join(SITE, 'tools', 'discovery-manifest-latest.json');
  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  record('local: discovery manifest reports six categories and 100 stories', manifest.success && manifest.categories.length === 6 && manifest.totalStories === 100 && manifest.feedItems === 30, manifest);

  const allStoryLinks = [];
  for (const [name, slug] of CATEGORIES) {
    const filePath = path.join(SITE, 'categories', `${slug}.html`);
    const html = fs.readFileSync(filePath, 'utf8');
    const links = storyLinks(html);
    allStoryLinks.push(...links);
    record(`local: ${name} category page is indexable and structured`,
      html.includes(`<title>${name}の怖い話`) &&
      html.includes(`<link rel="canonical" href="${BASE}/categories/${slug}.html">`) &&
      html.includes('rel="alternate" type="application/rss+xml"') &&
      html.includes('"@type":"CollectionPage"') &&
      html.includes('"@type":"BreadcrumbList"') &&
      links.length > 0,
      { slug, storyLinks: links.length });
  }
  record('local: category pages link to all 100 stories exactly once', allStoryLinks.length === 100 && new Set(allStoryLinks).size === 100, { links: allStoryLinks.length, unique: new Set(allStoryLinks).size });

  const feed = fs.readFileSync(path.join(SITE, 'feed.xml'), 'utf8');
  const feedLinks = Array.from(feed.matchAll(/<guid isPermaLink="true">([^<]+)<\/guid>/g), (match) => match[1]);
  record('local: RSS feed has 30 unique story items and a self link', itemCount(feed) === 30 && new Set(feedLinks).size === 30 && feed.includes(`<atom:link href="${BASE}/feed.xml" rel="self" type="application/rss+xml" />`), { items: itemCount(feed), unique: new Set(feedLinks).size });

  for (const page of ['index.html', 'archive.html']) {
    const html = fs.readFileSync(path.join(SITE, page), 'utf8');
    const categoryTargets = CATEGORIES.filter(([, slug]) => html.includes(`categories/${slug}.html`));
    record(`local: ${page} exposes RSS and all category pages`, html.includes('rel="alternate" type="application/rss+xml"') && categoryTargets.length === 6, { categories: categoryTargets.length });
  }
}

async function fetchText(url, attempts = 12) {
  let detail = null;
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try {
      const separator = url.includes('?') ? '&' : '?';
      const response = await fetch(`${url}${separator}discovery=${Date.now()}-${attempt}`, {
        redirect: 'follow',
        headers: { 'cache-control': 'no-cache, no-store, max-age=0', 'user-agent': 'Yorugatari-Discovery-Audit/1.0' },
        signal: AbortSignal.timeout(30000)
      });
      const text = await response.text();
      detail = { attempt, status: response.status, text };
      if (response.status === 200) return detail;
    } catch (error) {
      detail = { attempt, status: null, text: '', error: error.message };
    }
    if (attempt < attempts) await new Promise((resolve) => setTimeout(resolve, 5000));
  }
  return detail;
}

async function liveAudit() {
  const top = await fetchText(`${BASE}/`);
  const topCategories = CATEGORIES.filter(([, slug]) => top.text.includes(`categories/${slug}.html`));
  record('published: top exposes RSS and six category links', top.status === 200 && top.text.includes('rel="alternate" type="application/rss+xml"') && topCategories.length === 6, { status: top.status, attempt: top.attempt, categories: topCategories.length });

  const linkedStories = [];
  for (const [name, slug] of CATEGORIES) {
    const response = await fetchText(`${BASE}/categories/${slug}.html`);
    const canonical = `${BASE}/categories/${slug}.html`;
    const links = storyLinks(response.text);
    linkedStories.push(...links);
    const ok = response.status === 200 && response.text.includes(`<link rel="canonical" href="${canonical}">`) && response.text.includes(`<h1>${name}の怖い話</h1>`) && links.length > 0;
    record(`published: ${name} category page is available`, ok, { status: response.status, attempt: response.attempt, links: links.length, canonical });
  }
  record('published: six category pages cover 100 unique stories', linkedStories.length === 100 && new Set(linkedStories).size === 100, { links: linkedStories.length, unique: new Set(linkedStories).size });

  const feed = await fetchText(`${BASE}/feed.xml`);
  const feedLinks = Array.from(feed.text.matchAll(/<guid isPermaLink="true">([^<]+)<\/guid>/g), (match) => match[1]);
  record('published: RSS feed is valid and contains 30 unique stories', feed.status === 200 && feed.text.includes('<rss version="2.0"') && itemCount(feed.text) === 30 && new Set(feedLinks).size === 30, { status: feed.status, attempt: feed.attempt, items: itemCount(feed.text), unique: new Set(feedLinks).size });
}

if (LIVE) await liveAudit();
else localAudit();

const report = { auditedAt: new Date().toISOString(), mode: LIVE ? 'live' : 'local', success: failures.length === 0, results, failures };
fs.writeFileSync(path.join(ROOT, 'yorugatari-discovery-report.json'), `${JSON.stringify(report, null, 2)}\n`);
console.log(`YORUGATARI_DISCOVERY_REPORT=${JSON.stringify(report)}`);
if (failures.length) process.exit(1);
