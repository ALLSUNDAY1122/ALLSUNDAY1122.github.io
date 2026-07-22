import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';

const SITE_ROOT = path.resolve(process.cwd(), 'yorugatari');
const ASSETS_DIR = path.join(SITE_ROOT, 'assets');
const STORIES_DIR = path.join(SITE_ROOT, 'stories');
const STORY_SCRIPT_VERSION = '20260723-007';
const ENGAGEMENT_VERSION = '20260723-003';
const SHARE_IMAGE_ALT = '月明かりと提灯が照らす夜の町並み';
const SHARE_WIDTH = '2172';
const SHARE_HEIGHT = '724';
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
      { '@type': 'ListItem', position: 1, name: '夜語り', item: 'https://allsunday1122.github.io/yorugatari/' },
      { '@type': 'ListItem', position: 2, name: '全100話', item: 'https://allsunday1122.github.io/yorugatari/archive.html' },
      { '@type': 'ListItem', position: 3, name: story.category, item: `https://allsunday1122.github.io/yorugatari/archive.html#${encodeURIComponent(story.category)}` },
      { '@type': 'ListItem', position: 4, name: story.title, item: pageUrl }
    ]
  };
}

function escapeRegExp(value) {
  return String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function upsertPropertyMeta(html, property, content) {
  const pattern = new RegExp(`<meta\\s+property=["']${escapeRegExp(property)}["']\\s+content=["'][^"']*["']\\s*\\/?>`, 'i');
  const tag = `<meta property="${property}" content="${content}">`;
  if (pattern.test(html)) return html.replace(pattern, tag);
  if (property.startsWith('og:image:')) {
    return html.replace(/(<meta property="og:image"\s+content="[^"]+">)/i, `$1\n  ${tag}`);
  }
  return html.replace('</head>', `  ${tag}\n</head>`);
}

function ensureHeadMetadata(html, story, pageUrl) {
  if (!html.includes('rel="preconnect" href="https://page-views-api.ratneshc.com"')) {
    html = html.replace(
      /(<link rel="canonical"\s+href="[^"]+">)/,
      '<link rel="preconnect" href="https://page-views-api.ratneshc.com" crossorigin>\n  $1'
    );
  }

  html = upsertPropertyMeta(html, 'og:image:width', SHARE_WIDTH);
  html = upsertPropertyMeta(html, 'og:image:height', SHARE_HEIGHT);
  html = upsertPropertyMeta(html, 'og:image:alt', SHARE_IMAGE_ALT);

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
  if (!heroStart.test(html)) throw new Error(`Could not locate story hero for ${story.slug}`);
  return html.replace(heroStart, `$1${markup}`);
}

function ensureHeaderNavigation(html) {
  return html.replace(
    /<a\b[^>]*href=["']\.\.\/index\.html#ranking["'][^>]*>[\s\S]*?<\/a>/gi,
    '<a href="../index.html#readerPanel">読書記録</a>'
  );
}

function ensureFooterArchiveLink(html) {
  const desiredNav =
    '<nav class="footer-links" aria-label="運営情報">' +
    '<a href="../archive.html">全100話一覧</a>' +
    '<a href="../about.html">運営・編集方針</a>' +
    '<a href="../privacy.html">プライバシー</a>' +
    '<a href="../terms.html">利用規約</a>' +
    '<a href="../contact.html">お問い合わせ</a>' +
    '</nav>';
  const footerNav = /(<nav\b[^>]*class=["'][^"']*\bfooter-links\b[^"']*["'][^>]*>)([\s\S]*?)(<\/nav>)/i;

  if (footerNav.test(html)) {
    return html.replace(footerNav, (full, open, inner, close) => {
      const archiveLink = /<a\b[^>]*href=["']\.\.\/archive\.html["'][^>]*>[\s\S]*?<\/a>/i;
      if (archiveLink.test(inner)) {
        return `${open}${inner.replace(archiveLink, '<a href="../archive.html">全100話一覧</a>')}${close}`;
      }
      return `${open}<a href="../archive.html">全100話一覧</a>${inner}${close}`;
    });
  }

  const footerInner = /(<footer\b[^>]*class=["'][^"']*\bsite-footer\b[^"']*["'][^>]*>\s*<div\b[^>]*class=["'][^"']*\bfooter-inner\b[^"']*["'][^>]*>)([\s\S]*?)(<\/div>\s*<\/footer>)/i;
  if (!footerInner.test(html)) throw new Error('Could not locate footer container');
  return html.replace(footerInner, `$1$2${desiredNav}$3`);
}

function ensureStoryId(html, storyId) {
  if (html.includes(storyId)) return html;

  const dlPattern = /(<div\b[^>]*class=["'][^"']*\bstory-info\b[^"']*["'][^>]*>[\s\S]*?<dl>)/i;
  if (dlPattern.test(html)) return html.replace(dlPattern, `$1<dt>作品ID</dt><dd>${storyId}</dd>`);

  const headingPattern = /(<(?:div|aside)\b[^>]*class=["'][^"']*\bstory-info\b[^"']*["'][^>]*>\s*<h2>作品情報<\/h2>)/i;
  if (headingPattern.test(html)) return html.replace(headingPattern, `$1<p><strong>作品ID：</strong>${storyId}</p>`);

  throw new Error(`Could not add ${storyId}: story-info block missing`);
}

function storyPageHref(story) {
  const href = story && story.href ? story.href : `${story.slug}.html`;
  return href.replace(/^\.\.\//, '').replace(/^stories\//, '');
}

function ensureStoryPagination(html, stories, index) {
  html = html.replace(/<nav\b[^>]*class=["'][^"']*\bstory-pagination\b[^"']*["'][^>]*>[\s\S]*?<\/nav>/gi, '');

  const links = [];
  if (index > 0) {
    const previous = stories[index - 1];
    links.push(`<a class="btn" href="${storyPageHref(previous)}">← 前の話「${previous.title}」</a>`);
  }
  links.push('<a class="btn" href="../archive.html">全100話一覧</a>');
  if (index < stories.length - 1) {
    const next = stories[index + 1];
    links.push(`<a class="btn btn-primary" href="${storyPageHref(next)}">次の話「${next.title}」→</a>`);
  }

  const markup = `<nav class="hero-actions story-pagination" aria-label="前後の怖い話">${links.join('')}</nav>`;
  if (!html.includes('</main>')) throw new Error(`Could not locate main closing tag for ${stories[index].slug}`);
  return html.replace('</main>', `${markup}</main>`);
}

function selectRelatedStories(stories, index) {
  const current = stories[index];
  const sameCategory = stories
    .map((story, storyIndex) => ({ story, storyIndex }))
    .filter((entry) => entry.story.slug !== current.slug && entry.story.category === current.category)
    .sort((left, right) => Math.abs(left.storyIndex - index) - Math.abs(right.storyIndex - index))
    .map((entry) => entry.story);
  const fallback = stories.filter((story) => story.slug !== current.slug);
  return Array.from(new Map(sameCategory.concat(fallback).map((story) => [story.slug, story])).values()).slice(0, 2);
}

function ensureRelatedStories(html, stories, index) {
  html = html.replace(/<div\b[^>]*class=["'][^"']*\brelated\b[^"']*["'][^>]*>[\s\S]*?<\/div>/gi, '');
  const related = selectRelatedStories(stories, index);
  if (related.length !== 2) throw new Error(`Could not select two related stories for ${stories[index].slug}`);

  const markup = '<div class="related"><h2>関連する怖い話</h2>' + related
    .map((story) => `<a href="${storyPageHref(story)}">${story.title}</a>`)
    .join('') + '</div>';

  const storyInfo = /(<(div|aside)\b[^>]*class=["'][^"']*\bstory-info\b[^"']*["'][^>]*>)([\s\S]*?)(<\/\2>)/i;
  if (!storyInfo.test(html)) throw new Error(`Could not locate story-info for ${stories[index].slug}`);
  return html.replace(storyInfo, (full, open, tag, inner, close) => `${open}${inner}${markup}${close}`);
}

function normalizeStoryPage(story, index, stories) {
  const filename = `${story.slug}.html`;
  const filePath = path.join(STORIES_DIR, filename);
  if (!fs.existsSync(filePath)) throw new Error(`Missing story file: ${filename}`);

  const pageUrl = `https://allsunday1122.github.io/yorugatari/stories/${filename}`;
  const storyId = `YGT-${String(index + 1).padStart(3, '0')}`;
  let html = fs.readFileSync(filePath, 'utf8');

  html = ensureHeadMetadata(html, story, pageUrl);
  html = ensureVisibleBreadcrumb(html, story);
  html = ensureHeaderNavigation(html);
  html = ensureFooterArchiveLink(html);
  html = ensureStoryId(html, storyId);
  html = ensureRelatedStories(html, stories, index);
  html = ensureStoryPagination(html, stories, index);
  html = html.replace(/\.\.\/assets\/story\.js\?v=[^"'<>\s]+/g, `../assets/story.js?v=${STORY_SCRIPT_VERSION}`);
  html = html.replace(/\.\.\/assets\/engagement\.js\?v=[^"'<>\s]+/g, `../assets/engagement.js?v=${ENGAGEMENT_VERSION}`);

  const required = [
    `data-slug="${story.slug}"`,
    `<h1>${story.title}</h1>`,
    `href="${pageUrl}"`,
    '"timeRequired":"PT5M"',
    '"@type":"BreadcrumbList"',
    'class="breadcrumb"',
    'class="hero-actions story-pagination"',
    'class="related"',
    'href="../archive.html">全100話一覧</a>',
    `../assets/story.js?v=${STORY_SCRIPT_VERSION}`,
    `../assets/engagement.js?v=${ENGAGEMENT_VERSION}`,
    'property="og:image:width" content="2172"',
    'property="og:image:height" content="724"',
    storyId
  ];
  for (const token of required) {
    if (!html.includes(token)) throw new Error(`${filename} is missing required token: ${token}`);
  }
  if (html.includes('../index.html#ranking')) throw new Error(`${filename} still contains the retired #ranking link`);

  fs.writeFileSync(filePath, html, 'utf8');
}

const stories = loadCatalog();
stories.forEach((story, index) => normalizeStoryPage(story, index, stories));
console.log(`Normalized and validated ${stories.length} Yorugatari story pages with static navigation and related links.`);
