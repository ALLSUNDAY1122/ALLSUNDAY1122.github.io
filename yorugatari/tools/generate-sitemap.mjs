import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { execFileSync } from 'node:child_process';

const repoRoot = process.cwd();
const siteDir = path.join(repoRoot, 'yorugatari');
const baseUrl = 'https://allsunday1122.github.io/yorugatari';
const sitemapPath = path.join(siteDir, 'sitemap.xml');
const catalogFiles = [
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
const staticPages = [
  'index.html',
  '5min-horror.html',
  'bedtime-horror.html',
  'horror-quiz.html',
  'archive.html',
  'about.html',
  'privacy.html',
  'terms.html',
  'contact.html'
];
const categoryPages = [
  'categories/shinrei.html',
  'categories/hitokowa.html',
  'categories/imikowa.html',
  'categories/net-kaidan.html',
  'categories/urban-legend.html',
  'categories/aftertaste.html'
];

function loadStories() {
  const sandbox = { window: { STORIES: [], NOTION_STORIES: [] } };
  vm.createContext(sandbox);
  for (const relativePath of catalogFiles) {
    const absolutePath = path.join(siteDir, relativePath);
    if (!fs.existsSync(absolutePath)) throw new Error(`Missing catalog: ${relativePath}`);
    vm.runInContext(fs.readFileSync(absolutePath, 'utf8'), sandbox, { filename: relativePath });
  }

  const combined = [
    ...(Array.isArray(sandbox.window.STORIES) ? sandbox.window.STORIES : []),
    ...(Array.isArray(sandbox.window.NOTION_STORIES) ? sandbox.window.NOTION_STORIES : [])
  ];
  const stories = Array.from(new Map(combined.map((story) => [story.slug, story])).values());
  if (stories.length !== 100) {
    throw new Error(`Expected 100 unique stories, found ${stories.length}`);
  }
  return stories;
}

function japanDate() {
  return new Date(Date.now() + 9 * 60 * 60 * 1000).toISOString().slice(0, 10);
}

function gitLastModified(relativePath) {
  const repositoryPath = path.posix.join('yorugatari', relativePath.replaceAll('\\', '/'));
  const workingTreeStatus = execFileSync('git', ['status', '--porcelain', '--', repositoryPath], {
    cwd: repoRoot,
    encoding: 'utf8'
  }).trim();
  if (workingTreeStatus) return japanDate();

  const value = execFileSync('git', ['log', '-1', '--format=%cs', '--', repositoryPath], {
    cwd: repoRoot,
    encoding: 'utf8'
  }).trim();
  if (/^\d{4}-\d{2}-\d{2}$/.test(value)) return value;
  if (fs.existsSync(path.join(siteDir, relativePath))) return japanDate();
  throw new Error(`Could not determine last modification date for ${repositoryPath}`);
}

function escapeXml(value) {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
}

export function expectedPages() {
  const stories = loadStories();
  const pages = [
    ...staticPages,
    ...categoryPages,
    ...stories.map((story) => `stories/${story.slug}.html`)
  ];

  for (const relativePath of pages) {
    if (!fs.existsSync(path.join(siteDir, relativePath))) {
      throw new Error(`Sitemap target does not exist: ${relativePath}`);
    }
  }
  return pages;
}

export function buildSitemap() {
  const pages = expectedPages();
  const rows = pages.map((relativePath) => {
    const location = relativePath === 'index.html' ? `${baseUrl}/` : `${baseUrl}/${relativePath}`;
    return `  <url><loc>${escapeXml(location)}</loc><lastmod>${gitLastModified(relativePath)}</lastmod></url>`;
  });
  return [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
    ...rows,
    '</urlset>',
    ''
  ].join('\n');
}

const generated = buildSitemap();
const checkOnly = process.argv.includes('--check');
const current = fs.existsSync(sitemapPath) ? fs.readFileSync(sitemapPath, 'utf8') : '';

if (checkOnly) {
  if (current !== generated) {
    console.error('yorugatari/sitemap.xml is not synchronized with the current files and git history.');
    process.exit(1);
  }
} else if (current !== generated) {
  fs.writeFileSync(sitemapPath, generated);
}

console.log(JSON.stringify({
  sitemap: path.relative(repoRoot, sitemapPath).replaceAll('\\', '/'),
  urls: expectedPages().length,
  changed: current !== generated,
  mode: checkOnly ? 'check' : 'write'
}));
