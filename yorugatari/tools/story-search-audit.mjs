import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';

const ROOT = process.cwd();
const SITE = path.join(ROOT, 'yorugatari');
const STORIES_DIR = path.join(SITE, 'stories');
const BASE = 'https://allsunday1122.github.io/yorugatari/stories';
const LIVE = process.argv.includes('--live');
const REPORT_PATH = path.join(ROOT, 'yorugatari-story-search-report.json');
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

function decodeHtml(value) {
  return String(value)
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&');
}

function extractTitle(html) {
  return decodeHtml(html.match(/<title>([\s\S]*?)<\/title>/i)?.[1]?.trim() || '');
}

function extractMeta(html, attribute, key) {
  const tags = html.match(/<meta\b[^>]*>/gi) || [];
  const target = tags.find((tag) => {
    const match = tag.match(new RegExp(`${attribute}=["']([^"']+)["']`, 'i'));
    return match?.[1]?.toLowerCase() === key.toLowerCase();
  });
  return decodeHtml(target?.match(/content=["']([^"']*)["']/i)?.[1] || '');
}

function expectedTitle(story) {
  return `${story.title}｜${SEARCH_PHRASES[story.category]}｜夜語り`;
}

function expectedDescription(story) {
  const prefix = `${SEARCH_PHRASES[story.category]}「${story.title}」。`;
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

function inspect(html, story, status = 200) {
  const title = extractTitle(html);
  const description = extractMeta(html, 'name', 'description');
  const ogTitle = extractMeta(html, 'property', 'og:title');
  const ogDescription = extractMeta(html, 'property', 'og:description');
  const twitterTitle = extractMeta(html, 'name', 'twitter:title');
  const twitterDescription = extractMeta(html, 'name', 'twitter:description');
  const expectedTitleValue = expectedTitle(story);
  const expectedDescriptionValue = expectedDescription(story);
  const checks = {
    status: status === 200,
    title: title === expectedTitleValue,
    description: description === expectedDescriptionValue,
    ogTitle: ogTitle === expectedTitleValue,
    ogDescription: ogDescription === expectedDescriptionValue,
    twitterTitle: twitterTitle === expectedTitleValue,
    twitterDescription: twitterDescription === expectedDescriptionValue,
    visibleTitle: html.includes(`<h1>${story.title}</h1>`),
    titleLength: title.length >= 15 && title.length <= 65,
    descriptionLength: description.length >= 55 && description.length <= 160
  };
  return {
    slug: story.slug,
    category: story.category,
    title,
    descriptionLength: description.length,
    ok: Object.values(checks).every(Boolean),
    checks
  };
}

async function fetchCurrentStory(story) {
  const expected = expectedTitle(story);
  let last = null;
  for (let attempt = 1; attempt <= 6; attempt += 1) {
    try {
      const response = await fetch(`${BASE}/${story.slug}.html?story-search=${Date.now()}-${attempt}`, {
        redirect: 'follow',
        headers: { 'cache-control': 'no-cache, no-store, max-age=0', 'user-agent': 'Yorugatari-Story-Search-Audit/1.0' },
        signal: AbortSignal.timeout(30000)
      });
      const html = await response.text();
      last = { status: response.status, html, attempt };
      if (response.status === 200 && extractTitle(html) === expected) return last;
    } catch (error) {
      last = { status: null, html: '', attempt, error: error.message };
    }
    if (attempt < 6) await new Promise((resolve) => setTimeout(resolve, 5000));
  }
  return last;
}

const stories = loadStories();
const pages = new Array(stories.length);

if (LIVE) {
  let cursor = 0;
  const workers = Array.from({ length: 10 }, async () => {
    while (cursor < stories.length) {
      const index = cursor++;
      const story = stories[index];
      const response = await fetchCurrentStory(story);
      pages[index] = { ...inspect(response?.html || '', story, response?.status), attempt: response?.attempt || null, error: response?.error || null };
    }
  });
  await Promise.all(workers);
} else {
  stories.forEach((story, index) => {
    const filePath = path.join(STORIES_DIR, `${story.slug}.html`);
    const html = fs.readFileSync(filePath, 'utf8');
    pages[index] = inspect(html, story);
  });
}

const duplicateTitles = pages.map((page) => page.title).filter((title, index, all) => title && all.indexOf(title) !== index);
const localDescriptions = LIVE ? [] : stories.map((story) => expectedDescription(story));
const duplicateDescriptions = localDescriptions.filter((description, index, all) => all.indexOf(description) !== index);
const failures = pages.filter((page) => !page.ok);
const report = {
  auditedAt: new Date().toISOString(),
  mode: LIVE ? 'live' : 'local',
  success: failures.length === 0 && duplicateTitles.length === 0 && duplicateDescriptions.length === 0,
  stories: pages.length,
  passed: pages.length - failures.length,
  failed: failures.length,
  uniqueTitles: pages.length - duplicateTitles.length,
  uniqueDescriptions: LIVE ? null : localDescriptions.length - duplicateDescriptions.length,
  titleLength: {
    min: Math.min(...pages.map((page) => page.title.length)),
    max: Math.max(...pages.map((page) => page.title.length))
  },
  descriptionLength: {
    min: Math.min(...pages.map((page) => page.descriptionLength)),
    max: Math.max(...pages.map((page) => page.descriptionLength))
  },
  failures,
  pages
};

fs.writeFileSync(REPORT_PATH, `${JSON.stringify(report, null, 2)}\n`, 'utf8');
console.log(`YORUGATARI_STORY_SEARCH_AUDIT=${JSON.stringify(report)}`);
if (!report.success) process.exit(1);
