import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';

const SITE_ROOT = path.resolve(process.cwd(), 'yorugatari');
const ASSETS_DIR = path.join(SITE_ROOT, 'assets');
const STORIES_DIR = path.join(SITE_ROOT, 'stories');
const CATALOG_FILES = [
  'stories.js',
  'stories-016-025.js',
  'stories-026-035.js',
  'stories-036-045.js',
  'stories-046-055.js',
  'stories-056-065.js',
  'stories-066-075.js',
  'stories-076-085.js',
  'stories-086-095.js',
  'stories-096-100.js'
];
const CATEGORY_PAGES = {
  '心霊': { name: '心霊・幽霊の怖い話', file: 'shinrei.html' },
  '人怖': { name: '人が怖い話（人怖）', file: 'hitokowa.html' },
  '意味怖': { name: '意味がわかると怖い話（意味怖）', file: 'imikowa.html' },
  'ネット怪談': { name: 'ネット・SNSの怖い話', file: 'net-kaidan.html' },
  '都市伝説風': { name: '都市伝説・奇妙なルールの怖い話', file: 'urban-legend.html' },
  '後味悪い': { name: '後味の悪い怖い話', file: 'aftertaste.html' }
};

function loadCatalog() {
  const context = vm.createContext({ window: {} });
  for (const filename of CATALOG_FILES) {
    vm.runInContext(fs.readFileSync(path.join(ASSETS_DIR, filename), 'utf8'), context, { filename });
  }
  const stories = Array.isArray(context.window.STORIES) ? context.window.STORIES : [];
  if (stories.length !== 100) throw new Error(`Expected 100 stories, found ${stories.length}`);
  return stories;
}

function repairJsonLd(html, story, category) {
  const categoryUrl = `https://allsunday1122.github.io/yorugatari/categories/${category.file}`;
  let found = false;
  const repaired = html.replace(
    /<script\b[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi,
    (full, body) => {
      try {
        const data = JSON.parse(body.trim());
        if (data && data['@type'] === 'BreadcrumbList' && Array.isArray(data.itemListElement)) {
          const third = data.itemListElement.find((item) => item && item.position === 3);
          if (!third) throw new Error(`Breadcrumb item 3 missing for ${story.slug}`);
          third.name = category.name;
          third.item = categoryUrl;
          found = true;
          return `<script type="application/ld+json">${JSON.stringify(data)}</script>`;
        }
      } catch (error) {
        if (String(error.message || error).includes('Breadcrumb item 3 missing')) throw error;
      }
      return full;
    }
  );
  if (!found) throw new Error(`Breadcrumb JSON-LD missing for ${story.slug}`);
  return repaired;
}

function repairVisibleBreadcrumb(html, story, category) {
  const legacyHref = `../archive.html#${encodeURIComponent(story.category)}`;
  const desired = `<a href="../categories/${category.file}">${category.name}</a>`;
  const quotedLegacy = `<a href="${legacyHref}">${story.category}</a>`;
  const singleQuotedLegacy = `<a href='${legacyHref}'>${story.category}</a>`;
  return html.replace(quotedLegacy, desired).replace(singleQuotedLegacy, desired);
}

const stories = loadCatalog();
let changed = 0;
for (const story of stories) {
  const category = CATEGORY_PAGES[story.category];
  if (!category) throw new Error(`Unknown category ${story.category} for ${story.slug}`);
  const filePath = path.join(STORIES_DIR, `${story.slug}.html`);
  let html = fs.readFileSync(filePath, 'utf8');
  const original = html;
  html = repairJsonLd(html, story, category);
  html = repairVisibleBreadcrumb(html, story, category);
  if (html !== original) {
    fs.writeFileSync(filePath, html, 'utf8');
    changed += 1;
  }
}

console.log(`Restored canonical category breadcrumbs in ${changed} of ${stories.length} story pages.`);
