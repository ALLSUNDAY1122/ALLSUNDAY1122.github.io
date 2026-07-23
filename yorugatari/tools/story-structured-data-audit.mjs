import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';

const ROOT = process.cwd();
const SITE = path.join(ROOT, 'yorugatari');
const BASE = 'https://allsunday1122.github.io/yorugatari';
const SHARE_IMAGE = `${BASE}/assets/yorugatari-share.png`;
const LIVE = process.argv.includes('--live');
const REPORT_PATH = path.join(ROOT, 'yorugatari-story-structured-data-report.json');
const MANIFEST_PATH = path.join(SITE, 'tools', 'story-structured-data-manifest-latest.json');
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
const CATEGORIES = {
  '心霊': { slug: 'shinrei', name: '心霊・幽霊の怖い話' },
  '人怖': { slug: 'hitokowa', name: '人が怖い話（人怖）' },
  '意味怖': { slug: 'imikowa', name: '意味がわかると怖い話（意味怖）' },
  'ネット怪談': { slug: 'net-kaidan', name: 'ネット・SNSの怖い話' },
  '都市伝説風': { slug: 'urban-legend', name: '都市伝説・奇妙なルールの怖い話' },
  '後味悪い': { slug: 'aftertaste', name: '後味の悪い怖い話' }
};

function loadStories() {
  const sandbox = { window: { STORIES: [], NOTION_STORIES: [] } };
  vm.createContext(sandbox);
  for (const relative of CATALOG_FILES) {
    vm.runInContext(fs.readFileSync(path.join(SITE, relative), 'utf8'), sandbox, { filename: relative });
  }
  const combined = [...sandbox.window.STORIES, ...sandbox.window.NOTION_STORIES];
  const stories = Array.from(new Map(combined.map((story) => [story.slug, story])).values());
  if (stories.length !== 100) throw new Error(`Expected 100 unique stories, found ${stories.length}`);
  return stories;
}

function parseJsonLd(html) {
  const values = [];
  for (const match of html.matchAll(/<script\b[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi)) {
    try {
      values.push(JSON.parse(match[1].trim()));
    } catch (error) {
      values.push({ parseError: error.message });
    }
  }
  return values;
}

function metaProperty(html, property) {
  const escaped = property.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return html.match(new RegExp(`<meta\\s+property=["']${escaped}["']\\s+content=["']([^"']+)["']`, 'i'))?.[1] || '';
}

function evaluate(html, story, expectedDates) {
  const category = CATEGORIES[story.category];
  const pageUrl = `${BASE}/stories/${story.slug}.html`;
  const categoryUrl = `${BASE}/categories/${category.slug}.html`;
  const blocks = parseJsonLd(html);
  const shortStories = blocks.filter((value) => value?.['@type'] === 'ShortStory');
  const breadcrumbs = blocks.filter((value) => value?.['@type'] === 'BreadcrumbList');
  const data = shortStories[0];
  const breadcrumb = breadcrumbs[0];
  const categoryCrumb = breadcrumb?.itemListElement?.find((item) => item?.position === 3);
  const checks = {
    oneShortStory: shortStories.length === 1,
    oneBreadcrumb: breadcrumbs.length === 1,
    headline: data?.headline === story.title,
    description: data?.description === story.summary,
    genre: Array.isArray(data?.genre) && data.genre.includes('ホラー') && data.genre.includes(story.category) && data.genre.includes(category.name),
    keywords: Array.isArray(data?.keywords) && (story.tags || []).every((tag) => data.keywords.includes(tag)),
    language: data?.inLanguage === 'ja',
    duration: data?.timeRequired === 'PT5M',
    published: data?.datePublished === expectedDates.datePublished,
    modified: data?.dateModified === expectedDates.dateModified,
    dateOrder: /^\d{4}-\d{2}-\d{2}$/.test(data?.datePublished || '') && /^\d{4}-\d{2}-\d{2}$/.test(data?.dateModified || '') && data.datePublished <= data.dateModified,
    image: data?.image?.['@type'] === 'ImageObject' && data.image.url === SHARE_IMAGE && data.image.contentUrl === SHARE_IMAGE && data.image.width === 2172 && data.image.height === 724,
    collection: data?.isPartOf?.['@type'] === 'CollectionPage' && data.isPartOf.url === categoryUrl && data.isPartOf.name === category.name,
    publisher: data?.publisher?.['@type'] === 'Organization' && data.publisher.name === '夜語り' && data.publisher.url === `${BASE}/`,
    mainPage: data?.mainEntityOfPage?.['@type'] === 'WebPage' && data.mainEntityOfPage['@id'] === pageUrl,
    breadcrumbCategory: categoryCrumb?.name === category.name && categoryCrumb?.item === categoryUrl,
    visibleCategory: html.includes(`href="../categories/${category.slug}.html">${category.name}</a>`),
    publishedMeta: metaProperty(html, 'article:published_time') === expectedDates.datePublished,
    modifiedMeta: metaProperty(html, 'article:modified_time') === expectedDates.dateModified,
    sectionMeta: metaProperty(html, 'article:section') === category.name
  };
  return {
    ok: Object.values(checks).every(Boolean),
    checks,
    dates: { published: data?.datePublished || null, modified: data?.dateModified || null },
    jsonLdBlocks: blocks.length,
    shortStoryBlocks: shortStories.length,
    breadcrumbBlocks: breadcrumbs.length
  };
}

async function fetchCurrent(url, story, expectedDates, attempts = 12) {
  let last = null;
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try {
      const separator = url.includes('?') ? '&' : '?';
      const response = await fetch(`${url}${separator}schema=${Date.now()}-${attempt}`, {
        redirect: 'follow',
        headers: { 'cache-control': 'no-cache, no-store, max-age=0', 'user-agent': 'Yorugatari-Story-Schema-Audit/1.0' },
        signal: AbortSignal.timeout(30000)
      });
      const html = await response.text();
      const result = evaluate(html, story, expectedDates);
      last = { attempt, status: response.status, ...result, error: null };
      if (response.status === 200 && result.ok) return last;
    } catch (error) {
      last = { attempt, status: null, ok: false, checks: {}, error: error.message };
    }
    if (attempt < attempts) await new Promise((resolve) => setTimeout(resolve, 5000));
  }
  return last;
}

async function mapConcurrent(items, concurrency, worker) {
  const results = new Array(items.length);
  let cursor = 0;
  async function run() {
    while (true) {
      const index = cursor;
      cursor += 1;
      if (index >= items.length) return;
      results[index] = await worker(items[index], index);
    }
  }
  await Promise.all(Array.from({ length: concurrency }, () => run()));
  return results;
}

const stories = loadStories();
const manifest = JSON.parse(fs.readFileSync(MANIFEST_PATH, 'utf8'));
const expectedBySlug = new Map(manifest.pages.map((row) => [row.slug, row]));
let pages;

if (LIVE) {
  pages = await mapConcurrent(stories, 8, async (story) => {
    const expected = expectedBySlug.get(story.slug);
    if (!expected) return { slug: story.slug, category: story.category, ok: false, error: 'Missing manifest row' };
    const result = await fetchCurrent(`${BASE}/stories/${story.slug}.html`, story, expected);
    return { slug: story.slug, category: story.category, ...result };
  });
} else {
  pages = stories.map((story) => {
    const expected = expectedBySlug.get(story.slug);
    if (!expected) return { slug: story.slug, category: story.category, ok: false, error: 'Missing manifest row' };
    const html = fs.readFileSync(path.join(SITE, 'stories', `${story.slug}.html`), 'utf8');
    return { slug: story.slug, category: story.category, status: 200, attempt: 0, error: null, ...evaluate(html, story, expected) };
  });
}

const failures = pages.filter((page) => !page.ok);
const publishedDates = pages.map((page) => page.dates?.published).filter(Boolean).sort();
const modifiedDates = pages.map((page) => page.dates?.modified).filter(Boolean).sort();
const report = {
  auditedAt: new Date().toISOString(),
  mode: LIVE ? 'live' : 'local',
  success: failures.length === 0,
  stories: pages.length,
  passed: pages.length - failures.length,
  failed: failures.length,
  datePublished: { earliest: publishedDates[0] || null, latest: publishedDates.at(-1) || null },
  dateModified: { earliest: modifiedDates[0] || null, latest: modifiedDates.at(-1) || null },
  categories: Object.fromEntries(Object.keys(CATEGORIES).map((category) => [category, {
    stories: pages.filter((page) => page.category === category).length,
    passed: pages.filter((page) => page.category === category && page.ok).length
  }])),
  failures,
  pages
};
fs.writeFileSync(REPORT_PATH, `${JSON.stringify(report, null, 2)}\n`, 'utf8');
console.log(`YORUGATARI_STORY_STRUCTURED_DATA_REPORT=${JSON.stringify(report)}`);
if (failures.length) process.exit(1);
