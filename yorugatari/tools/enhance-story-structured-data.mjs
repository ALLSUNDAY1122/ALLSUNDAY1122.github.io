import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { execFileSync } from 'node:child_process';

const ROOT = process.cwd();
const SITE = path.join(ROOT, 'yorugatari');
const STORIES_DIR = path.join(SITE, 'stories');
const BASE = 'https://allsunday1122.github.io/yorugatari';
const SHARE_IMAGE = `${BASE}/assets/yorugatari-share.png`;
const SHARE_IMAGE_ALT = '月明かりと提灯が照らす夜の町並み';
const REPORT_PATH = path.join(SITE, 'tools', 'story-structured-data-manifest-latest.json');
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

function gitDates(slug) {
  const relative = `yorugatari/stories/${slug}.html`;
  const output = execFileSync('git', ['log', '--follow', '--format=%cs', '--', relative], {
    cwd: ROOT,
    encoding: 'utf8'
  }).trim();
  const dates = output.split(/\r?\n/).filter((value) => /^\d{4}-\d{2}-\d{2}$/.test(value));
  if (!dates.length) throw new Error(`Could not determine Git dates for ${relative}`);
  return { datePublished: dates.at(-1), dateModified: dates[0] };
}

function jsonForHtml(value) {
  return JSON.stringify(value).replaceAll('<', '\\u003c');
}

function upsertPropertyMeta(html, property, content) {
  const escaped = property.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const pattern = new RegExp(`<meta\\s+property=["']${escaped}["'][^>]*>`, 'i');
  const tag = `<meta property="${property}" content="${content}">`;
  if (pattern.test(html)) return html.replace(pattern, tag);
  return html.replace('</head>', `  ${tag}\n</head>`);
}

function upsertJsonLd(html, type, data) {
  const serialized = jsonForHtml(data);
  let found = false;
  html = html.replace(
    /<script\b[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi,
    (full, body) => {
      try {
        const parsed = JSON.parse(body.trim());
        if (parsed && parsed['@type'] === type) {
          found = true;
          return `<script type="application/ld+json">${serialized}</script>`;
        }
      } catch {
        // Preserve unrelated legacy JSON-LD.
      }
      return full;
    }
  );
  if (!found) html = html.replace('</head>', `  <script type="application/ld+json">${serialized}</script>\n</head>`);
  return html;
}

function updateVisibleBreadcrumb(html, category) {
  const categoryHref = `../categories/${category.slug}.html`;
  const breadcrumb = /(<nav\b[^>]*class=["'][^"']*\bbreadcrumb\b[^"']*["'][^>]*>[\s\S]*?<a\b[^>]*href=["']\.\.\/archive\.html["'][^>]*>全100話<\/a>[\s\S]*?<span\b[^>]*>›<\/span>)<a\b[^>]*href=["'][^"']+["'][^>]*>[^<]+<\/a>(<\/nav>)/i;
  if (!breadcrumb.test(html)) throw new Error('Could not locate visible category breadcrumb');
  return html.replace(breadcrumb, `$1<a href="${categoryHref}">${category.name}</a>$2`);
}

function structuredStory(story, category, pageUrl, dates) {
  const categoryUrl = `${BASE}/categories/${category.slug}.html`;
  return {
    '@context': 'https://schema.org',
    '@type': 'ShortStory',
    '@id': `${pageUrl}#story`,
    headline: story.title,
    description: story.summary,
    genre: ['ホラー', category.name, story.category],
    keywords: Array.isArray(story.tags) ? story.tags : [],
    inLanguage: 'ja',
    timeRequired: 'PT5M',
    datePublished: dates.datePublished,
    dateModified: dates.dateModified,
    image: {
      '@type': 'ImageObject',
      '@id': `${SHARE_IMAGE}#image`,
      url: SHARE_IMAGE,
      contentUrl: SHARE_IMAGE,
      width: 2172,
      height: 724,
      caption: SHARE_IMAGE_ALT
    },
    isPartOf: {
      '@type': 'CollectionPage',
      '@id': `${categoryUrl}#collection`,
      name: category.name,
      url: categoryUrl
    },
    publisher: {
      '@type': 'Organization',
      name: '夜語り',
      url: `${BASE}/`
    },
    mainEntityOfPage: {
      '@type': 'WebPage',
      '@id': pageUrl
    }
  };
}

function breadcrumbData(story, category, pageUrl) {
  const categoryUrl = `${BASE}/categories/${category.slug}.html`;
  return {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: [
      { '@type': 'ListItem', position: 1, name: '夜語り', item: `${BASE}/` },
      { '@type': 'ListItem', position: 2, name: '全100話', item: `${BASE}/archive.html` },
      { '@type': 'ListItem', position: 3, name: category.name, item: categoryUrl },
      { '@type': 'ListItem', position: 4, name: story.title, item: pageUrl }
    ]
  };
}

const stories = loadStories();
const rows = [];
for (const story of stories) {
  const category = CATEGORIES[story.category];
  if (!category) throw new Error(`Unknown category for ${story.slug}: ${story.category}`);
  const filePath = path.join(STORIES_DIR, `${story.slug}.html`);
  if (!fs.existsSync(filePath)) throw new Error(`Missing story page: ${story.slug}.html`);
  const pageUrl = `${BASE}/stories/${story.slug}.html`;
  const dates = gitDates(story.slug);
  let html = fs.readFileSync(filePath, 'utf8');
  html = upsertJsonLd(html, 'ShortStory', structuredStory(story, category, pageUrl, dates));
  html = upsertJsonLd(html, 'BreadcrumbList', breadcrumbData(story, category, pageUrl));
  html = updateVisibleBreadcrumb(html, category);
  html = upsertPropertyMeta(html, 'article:published_time', dates.datePublished);
  html = upsertPropertyMeta(html, 'article:modified_time', dates.dateModified);
  html = upsertPropertyMeta(html, 'article:section', category.name);

  const required = [
    '"@type":"ShortStory"',
    `"datePublished":"${dates.datePublished}"`,
    `"dateModified":"${dates.dateModified}"`,
    `"url":"${SHARE_IMAGE}"`,
    `"url":"${BASE}/categories/${category.slug}.html"`,
    `href="../categories/${category.slug}.html"`,
    `property="article:published_time" content="${dates.datePublished}"`,
    `property="article:modified_time" content="${dates.dateModified}"`
  ];
  for (const token of required) {
    if (!html.includes(token)) throw new Error(`${story.slug}.html is missing structured-data token: ${token}`);
  }
  fs.writeFileSync(filePath, html, 'utf8');
  rows.push({ slug: story.slug, category: story.category, categoryPage: category.slug, ...dates });
}

const report = {
  generatedAt: new Date().toISOString(),
  success: true,
  stories: rows.length,
  withPublishedDate: rows.filter((row) => row.datePublished).length,
  withModifiedDate: rows.filter((row) => row.dateModified).length,
  categories: Object.fromEntries(Object.entries(CATEGORIES).map(([key, value]) => [key, {
    name: value.name,
    slug: value.slug,
    stories: rows.filter((row) => row.category === key).length
  }])),
  datePublished: {
    earliest: rows.map((row) => row.datePublished).sort()[0],
    latest: rows.map((row) => row.datePublished).sort().at(-1)
  },
  dateModified: {
    earliest: rows.map((row) => row.dateModified).sort()[0],
    latest: rows.map((row) => row.dateModified).sort().at(-1)
  },
  pages: rows
};
fs.writeFileSync(REPORT_PATH, `${JSON.stringify(report, null, 2)}\n`, 'utf8');
console.log(`YORUGATARI_STORY_STRUCTURED_DATA=${JSON.stringify(report)}`);
