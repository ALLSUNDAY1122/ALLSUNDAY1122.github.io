import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';

const ROOT = process.cwd();
const SITE = path.join(ROOT, 'yorugatari');
const STORIES_DIR = path.join(SITE, 'stories');
const REPORT_PATH = path.join(SITE, 'tools', 'story-search-metadata-latest.json');
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
const SEARCH_PHRASES = {
  '心霊': '心霊・幽霊の怖い話',
  '人怖': '人が怖い話',
  '意味怖': '意味がわかると怖い話',
  'ネット怪談': 'ネット・SNSの怖い話',
  '都市伝説風': '都市伝説・奇妙なルールの怖い話',
  '後味悪い': '後味の悪い怖い話'
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

function escapeRegExp(value) {
  return String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function escapeAttribute(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('"', '&quot;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
}

function searchPhrase(story) {
  const phrase = SEARCH_PHRASES[story.category];
  if (!phrase) throw new Error(`Unknown category for ${story.slug}: ${story.category}`);
  return phrase;
}

function seoTitle(story) {
  return `${story.title}｜${searchPhrase(story)}｜夜語り`;
}

function seoDescription(story) {
  const prefix = `${searchPhrase(story)}「${story.title}」。`;
  const suffix = ' 約5分で読める一話完結の創作怪談。';
  const maximum = 155;
  let summary = String(story.summary || '').trim();
  let description = `${prefix}${summary}${suffix}`;
  if (description.length > maximum) {
    const allowed = Math.max(20, maximum - prefix.length - suffix.length - 1);
    summary = `${summary.slice(0, allowed).replace(/[、。\s]+$/u, '')}…`;
    description = `${prefix}${summary}${suffix}`;
  }
  return description;
}

function upsertTitle(html, value) {
  const tag = `<title>${value}</title>`;
  if (/<title>[\s\S]*?<\/title>/i.test(html)) return html.replace(/<title>[\s\S]*?<\/title>/i, tag);
  return html.replace('</head>', `  ${tag}\n</head>`);
}

function upsertMeta(html, attribute, key, value) {
  const escapedKey = escapeRegExp(key);
  const pattern = new RegExp(`<meta\\s+${attribute}=["']${escapedKey}["'][^>]*>`, 'i');
  const tag = `<meta ${attribute}="${key}" content="${escapeAttribute(value)}">`;
  if (pattern.test(html)) return html.replace(pattern, tag);
  return html.replace('</head>', `  ${tag}\n</head>`);
}

const stories = loadStories();
const rows = [];
const titles = new Set();
const descriptions = new Set();

for (const story of stories) {
  const filePath = path.join(STORIES_DIR, `${story.slug}.html`);
  if (!fs.existsSync(filePath)) throw new Error(`Missing story page: ${story.slug}.html`);
  let html = fs.readFileSync(filePath, 'utf8');
  const title = seoTitle(story);
  const description = seoDescription(story);

  if (title.length > 65) throw new Error(`${story.slug} SEO title is too long: ${title.length}`);
  if (description.length < 55 || description.length > 160) {
    throw new Error(`${story.slug} SEO description length is invalid: ${description.length}`);
  }
  if (titles.has(title)) throw new Error(`Duplicate SEO title: ${title}`);
  if (descriptions.has(description)) throw new Error(`Duplicate SEO description: ${description}`);
  titles.add(title);
  descriptions.add(description);

  html = upsertTitle(html, escapeAttribute(title));
  html = upsertMeta(html, 'name', 'description', description);
  html = upsertMeta(html, 'property', 'og:title', title);
  html = upsertMeta(html, 'property', 'og:description', description);
  html = upsertMeta(html, 'name', 'twitter:title', title);
  html = upsertMeta(html, 'name', 'twitter:description', description);

  if (!html.includes(`<h1>${story.title}</h1>`)) throw new Error(`${story.slug} visible h1 changed or is missing`);
  fs.writeFileSync(filePath, html, 'utf8');
  rows.push({
    slug: story.slug,
    title: story.title,
    category: story.category,
    seoTitle: title,
    titleLength: title.length,
    descriptionLength: description.length
  });
}

const report = {
  generatedAt: new Date().toISOString(),
  success: true,
  stories: rows.length,
  uniqueTitles: titles.size,
  uniqueDescriptions: descriptions.size,
  titleLength: {
    min: Math.min(...rows.map((row) => row.titleLength)),
    max: Math.max(...rows.map((row) => row.titleLength))
  },
  descriptionLength: {
    min: Math.min(...rows.map((row) => row.descriptionLength)),
    max: Math.max(...rows.map((row) => row.descriptionLength))
  },
  categories: Object.fromEntries(Object.entries(SEARCH_PHRASES).map(([category, phrase]) => [category, { phrase, stories: rows.filter((row) => row.category === category).length }])),
  pages: rows
};

fs.writeFileSync(REPORT_PATH, `${JSON.stringify(report, null, 2)}\n`, 'utf8');
console.log(`YORUGATARI_STORY_SEARCH_METADATA=${JSON.stringify(report)}`);
