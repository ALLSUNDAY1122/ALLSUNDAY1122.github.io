import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';

const SITE_ROOT = path.resolve(process.cwd(), 'yorugatari');
const ASSETS_DIR = path.join(SITE_ROOT, 'assets');
const STORIES_DIR = path.join(SITE_ROOT, 'stories');
const STORY_SCRIPT_VERSION = '20260723-006';
const SHARE_IMAGE_ALT = '月明かりと提灯が照らす夜の町並み';
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

function loadCatalog() {
  const context = vm.createContext({ window: {} });
  for (const filename of CATALOG_FILES) {
    const source = fs.readFileSync(path.join(ASSETS_DIR, filename), 'utf8');
    vm.runInContext(source, context, { filename });
  }

  const stories = Array.isArray(context.window.STORIES) ? context.window.STORIES : [];
  const duplicateSlugs = stories
    .map((story) => story.slug)
    .filter((slug, index, all) => all.indexOf(slug) !== index);

  if (duplicateSlugs.length) {
    throw new Error(`Duplicate story slugs: ${[...new Set(duplicateSlugs)].join(', ')}`);
  }
  if (stories.length !== 100) {
    throw new Error(`Expected 100 unique stories, found ${stories.length}`);
  }
  return stories;
}

function breadcrumbData(story, pageUrl) {
  return {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: [
      {
        '@type': 'ListItem',
        position: 1,
        name: '夜語り',
        item: 'https://allsunday1122.github.io/yorugatari/'
      },
      {
        '@type': 'ListItem',
        position: 2,
        name: '全100話',
        item: 'https://allsunday1122.github.io/yorugatari/archive.html'
      },
      {
        '@type': 'ListItem',
        position: 3,
        name: story.category,
        item: `https://allsunday1122.github.io/yorugatari/archive.html#${encodeURIComponent(story.category)}`
      },
      {
        '@type': 'ListItem',
        position: 4,
        name: story.title,
        item: pageUrl
      }
    ]
  };
}

function ensureHeadMetadata(html, story, pageUrl) {
  if (!html.includes('rel="preconnect" href="https://page-views-api.ratneshc.com"')) {
    html = html.replace(
      /(<link rel="canonical"\s+href="[^"]+">)/,
      '<link rel="preconnect" href="https://page-views-api.ratneshc.com" crossorigin>\n  $1'
    );
  }

  const missingOg = [];
  if (!html.includes('property="og:image:width"')) {
    missingOg.push('<meta property="og:image:width" content="2048">');
  }
  if (!html.includes('property="og:image:height"')) {
    missingOg.push('<meta property="og:image:height" content="683">');
  }
  if (!html.includes('property="og:image:alt"')) {
    missingOg.push(`<meta property="og:image:alt" content="${SHARE_IMAGE_ALT}">`);
  }
  if (missingOg.length) {
    html = html.replace(
      /(<meta property="og:image"\s+content="[^"]+">)/,
      `$1\n  ${missingOg.join('\n  ')}`
    );
  }

  const data = JSON.stringify(breadcrumbData(story, pageUrl));
  let foundBreadcrumb = false;
  html = html.replace(
    /<script\b[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi,
    (full, body) => {
      try {
        const parsed = JSON.parse(body.trim());
        if (parsed && parsed['@type'] === 'BreadcrumbList') {
          foundBreadcrumb = true;
          return `<script type="application/ld+json">${data}</script>`;
        }
      } catch {
        // Preserve unrelated or legacy JSON-LD exactly as authored.
      }
      return full;
    }
  );
  if (!foundBreadcrumb) {
    html = html.replace('</head>', `  <script type="application/ld+json">${data}</script>\n</head>`);
  }

  return html;
}

function ensureVisibleBreadcrumb(html, story) {
  if (/class=["'][^"']*\bbreadcrumb\b/.test(html)) return html;

  const markup =
    '<nav class="breadcrumb" aria-label="パンくずリスト">' +
    '<a href="../index.html">夜語り</a>' +
    '<span aria-hidden="true">›</span>' +
    '<a href="../archive.html">全100話</a>' +
    '<span aria-hidden="true">›</span>' +
    `<a href="../archive.html#${encodeURIComponent(story.category)}">${story.category}</a>` +
    '</nav>';

  const heroStart = /(<section\b[^>]*class=["'][^"']*\bstory-hero\b[^"']*["'][^>]*>\s*<div\b[^>]*class=["'][^"']*\bwrap\b[^"']*["'][^>]*>)/i;
  if (!heroStart.test(html)) {
    throw new Error(`Could not locate story hero for ${story.slug}`);
  }
  return html.replace(heroStart, `$1${markup}`);
}

function ensureFooterArchiveLink(html) {
  const footerNav = /(<nav\b[^>]*class=["'][^"']*\bfooter-links\b[^"']*["'][^>]*>)([\s\S]*?)(<\/nav>)/i;
  return html.replace(footerNav, (full, open, inner, close) => {
    if (inner.includes('href="../archive.html"')) return full;
    return `${open}<a href="../archive.html">全100話一覧</a>${inner}${close}`;
  });
}

function ensureStoryId(html, storyId) {
  if (html.includes(storyId)) return html;

  const dlPattern = /(<div\b[^>]*class=["'][^"']*\bstory-info\b[^"']*["'][^>]*>[\s\S]*?<dl>)/i;
  if (dlPattern.test(html)) {
    return html.replace(dlPattern, `$1<dt>作品ID</dt><dd>${storyId}</dd>`);
  }

  const headingPattern = /(<(?:div|aside)\b[^>]*class=["'][^"']*\bstory-info\b[^"']*["'][^>]*>\s*<h2>作品情報<\/h2>)/i;
  if (headingPattern.test(html)) {
    return html.replace(headingPattern, `$1<p><strong>作品ID：</strong>${storyId}</p>`);
  }

  throw new Error(`Could not add ${storyId}: story-info block missing`);
}

function normalizeStoryPage(story, index) {
  const filename = `${story.slug}.html`;
  const filePath = path.join(STORIES_DIR, filename);
  if (!fs.existsSync(filePath)) {
    throw new Error(`Missing story file: ${filename}`);
  }

  const pageUrl = `https://allsunday1122.github.io/yorugatari/stories/${filename}`;
  const storyId = `YGT-${String(index + 1).padStart(3, '0')}`;
  let html = fs.readFileSync(filePath, 'utf8');

  html = ensureHeadMetadata(html, story, pageUrl);
  html = ensureVisibleBreadcrumb(html, story);
  html = ensureFooterArchiveLink(html);
  html = ensureStoryId(html, storyId);
  html = html.replace(
    /\.\.\/assets\/story\.js\?v=[^"'<>\s]+/g,
    `../assets/story.js?v=${STORY_SCRIPT_VERSION}`
  );

  const required = [
    `data-slug="${story.slug}"`,
    `<h1>${story.title}</h1>`,
    `href="${pageUrl}"`,
    '"timeRequired":"PT5M"',
    '"@type":"BreadcrumbList"',
    'class="breadcrumb"',
    'href="../archive.html">全100話一覧</a>',
    `../assets/story.js?v=${STORY_SCRIPT_VERSION}`,
    storyId
  ];
  for (const token of required) {
    if (!html.includes(token)) {
      throw new Error(`${filename} is missing required token: ${token}`);
    }
  }

  fs.writeFileSync(filePath, html, 'utf8');
}

const stories = loadCatalog();
stories.forEach(normalizeStoryPage);
console.log(`Normalized and validated ${stories.length} Yorugatari story pages.`);
