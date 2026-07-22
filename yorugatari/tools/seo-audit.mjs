import fs from 'node:fs';
import path from 'node:path';
import { buildSitemap, expectedPages } from './generate-sitemap.mjs';

const repoRoot = process.cwd();
const siteDir = path.join(repoRoot, 'yorugatari');
const baseUrl = 'https://allsunday1122.github.io/yorugatari';
const reportPath = path.join(repoRoot, 'yorugatari-seo-report.json');
const expectedRelativePages = expectedPages();
const expectedUrls = expectedRelativePages.map((relativePath) => (
  relativePath === 'index.html' ? `${baseUrl}/` : `${baseUrl}/${relativePath}`
));
const errors = [];
const warnings = [];
const pageResults = [];

function recordError(scope, message, detail = null) {
  errors.push({ scope, message, detail });
}

function recordWarning(scope, message, detail = null) {
  warnings.push({ scope, message, detail });
}

function getAttribute(tag, name) {
  const match = tag.match(new RegExp(`\\s${name}\\s*=\\s*(?:"([^"]*)"|'([^']*)'|([^\\s>]+))`, 'i'));
  return match ? (match[1] ?? match[2] ?? match[3] ?? '') : null;
}

function findMeta(html, attribute, value) {
  const tags = html.match(/<meta\b[^>]*>/gi) || [];
  const tag = tags.find((candidate) => getAttribute(candidate, attribute)?.toLowerCase() === value.toLowerCase());
  return tag ? getAttribute(tag, 'content') : null;
}

function findCanonical(html) {
  const tags = html.match(/<link\b[^>]*>/gi) || [];
  const tag = tags.find((candidate) => {
    const rel = getAttribute(candidate, 'rel') || '';
    return rel.toLowerCase().split(/\s+/).includes('canonical');
  });
  return tag ? getAttribute(tag, 'href') : null;
}

function extractTitle(html) {
  const match = html.match(/<title>([\s\S]*?)<\/title>/i);
  return match ? match[1].replace(/\s+/g, ' ').trim() : '';
}

function extractJsonLd(html, scope) {
  const blocks = [];
  const pattern = /<script\b[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;
  let match;
  while ((match = pattern.exec(html))) {
    try {
      blocks.push(JSON.parse(match[1].trim()));
    } catch (error) {
      recordError(scope, 'Invalid JSON-LD', error.message);
    }
  }
  return blocks;
}

function schemaTypes(value) {
  const raw = value?.['@type'];
  return new Set(Array.isArray(raw) ? raw : raw ? [raw] : []);
}

function pathForUrl(url) {
  const parsed = new URL(url);
  const prefix = '/yorugatari/';
  if (parsed.hostname !== 'allsunday1122.github.io' || !parsed.pathname.startsWith(prefix)) return null;
  const remainder = decodeURIComponent(parsed.pathname.slice(prefix.length));
  return remainder === '' ? 'index.html' : remainder;
}

function fragmentExists(targetRelativePath, fragment) {
  if (!fragment) return true;
  const decoded = decodeURIComponent(fragment);
  if (targetRelativePath === 'archive.html' && new Set(['心霊', '人怖', '意味怖', 'ネット怪談', '都市伝説風', '後味悪い']).has(decoded)) {
    return true;
  }
  const targetPath = path.join(siteDir, targetRelativePath);
  if (!fs.existsSync(targetPath)) return false;
  const html = fs.readFileSync(targetPath, 'utf8');
  const escaped = decoded.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return new RegExp(`(?:id|name)=["']${escaped}["']`, 'i').test(html);
}

function validateInternalLinks(relativePath, html, canonical) {
  const tags = html.match(/<a\b[^>]*>/gi) || [];
  for (const tag of tags) {
    const href = getAttribute(tag, 'href');
    if (!href || /^(?:mailto:|tel:|javascript:|data:)/i.test(href)) continue;
    let resolved;
    try {
      resolved = new URL(href, canonical);
    } catch (error) {
      recordError(relativePath, 'Invalid link URL', { href, error: error.message });
      continue;
    }
    const targetRelativePath = pathForUrl(resolved);
    if (!targetRelativePath) continue;
    const cleanTarget = targetRelativePath.endsWith('/') ? `${targetRelativePath}index.html` : targetRelativePath;
    const absoluteTarget = path.join(siteDir, cleanTarget);
    if (!fs.existsSync(absoluteTarget)) {
      recordError(relativePath, 'Broken internal link', { href, target: cleanTarget });
      continue;
    }
    if (!fragmentExists(cleanTarget, resolved.hash.slice(1))) {
      recordError(relativePath, 'Broken internal fragment', { href, target: cleanTarget, fragment: resolved.hash });
    }
  }
}

function validateLocalPage(relativePath) {
  const absolutePath = path.join(siteDir, relativePath);
  const html = fs.readFileSync(absolutePath, 'utf8');
  const canonicalExpected = relativePath === 'index.html' ? `${baseUrl}/` : `${baseUrl}/${relativePath}`;
  const title = extractTitle(html);
  const description = findMeta(html, 'name', 'description');
  const robots = findMeta(html, 'name', 'robots');
  const canonical = findCanonical(html);
  const ogUrl = findMeta(html, 'property', 'og:url');
  const h1Count = (html.match(/<h1\b/gi) || []).length;
  const jsonLd = extractJsonLd(html, relativePath);

  if (!/<html\b[^>]*lang=["']ja["']/i.test(html)) recordError(relativePath, 'Missing html lang="ja"');
  if (!title) recordError(relativePath, 'Missing page title');
  if (!description) recordError(relativePath, 'Missing meta description');
  if (canonical !== canonicalExpected) recordError(relativePath, 'Canonical URL mismatch', { expected: canonicalExpected, actual: canonical });
  if (robots && /noindex/i.test(robots)) recordError(relativePath, 'Page is marked noindex', robots);
  if (h1Count !== 1) recordError(relativePath, 'Page must contain exactly one h1', h1Count);
  if (ogUrl && ogUrl !== canonicalExpected) recordError(relativePath, 'og:url mismatch', { expected: canonicalExpected, actual: ogUrl });
  if (title.length > 65) recordWarning(relativePath, 'Long title may be truncated', title.length);
  if (description && description.length > 170) recordWarning(relativePath, 'Long description may be truncated', description.length);

  if (relativePath === 'index.html' && !jsonLd.some((item) => schemaTypes(item).has('WebSite'))) {
    recordError(relativePath, 'Missing WebSite structured data');
  }
  if (relativePath === 'archive.html' && !jsonLd.some((item) => schemaTypes(item).has('CollectionPage'))) {
    recordError(relativePath, 'Missing CollectionPage structured data');
  }
  if (relativePath.startsWith('stories/')) {
    if (!jsonLd.some((item) => schemaTypes(item).has('ShortStory'))) recordError(relativePath, 'Missing ShortStory structured data');
    if (!jsonLd.some((item) => schemaTypes(item).has('BreadcrumbList'))) recordError(relativePath, 'Missing BreadcrumbList structured data');
    if (!findMeta(html, 'property', 'og:image:alt')) recordError(relativePath, 'Missing Open Graph image alt text');
  }

  validateInternalLinks(relativePath, html, canonicalExpected);
  pageResults.push({ relativePath, canonical: canonicalExpected, title, descriptionLength: description?.length || 0, h1Count, jsonLdBlocks: jsonLd.length });
}

function validateLocalConfiguration() {
  const robotsPath = path.join(repoRoot, 'robots.txt');
  if (!fs.existsSync(robotsPath)) {
    recordError('robots.txt', 'Root robots.txt is missing');
  } else {
    const robots = fs.readFileSync(robotsPath, 'utf8');
    if (!/^User-agent:\s*\*/im.test(robots)) recordError('robots.txt', 'Missing wildcard user-agent');
    if (!/^Allow:\s*\/$/im.test(robots)) recordError('robots.txt', 'Site is not explicitly allowed');
    if (!/^Sitemap:\s*https:\/\/allsunday1122\.github\.io\/yorugatari\/sitemap\.xml$/im.test(robots)) {
      recordError('robots.txt', 'Sitemap directive is missing or incorrect');
    }
  }

  const sitemapPath = path.join(siteDir, 'sitemap.xml');
  const currentSitemap = fs.readFileSync(sitemapPath, 'utf8');
  const generatedSitemap = buildSitemap();
  if (currentSitemap !== generatedSitemap) recordError('sitemap.xml', 'Sitemap is not synchronized with current files and git history');

  const locations = Array.from(currentSitemap.matchAll(/<loc>([^<]+)<\/loc>/g), (match) => match[1]);
  const lastmods = Array.from(currentSitemap.matchAll(/<lastmod>([^<]+)<\/lastmod>/g), (match) => match[1]);
  const uniqueLocations = new Set(locations);
  if (locations.length !== 106) recordError('sitemap.xml', 'Expected 106 URLs', locations.length);
  if (uniqueLocations.size !== locations.length) recordError('sitemap.xml', 'Duplicate sitemap URLs detected');
  const expectedSet = new Set(expectedUrls);
  const missing = expectedUrls.filter((url) => !uniqueLocations.has(url));
  const unexpected = locations.filter((url) => !expectedSet.has(url));
  if (missing.length) recordError('sitemap.xml', 'Expected URLs missing', missing);
  if (unexpected.length) recordError('sitemap.xml', 'Unexpected URLs present', unexpected);
  for (const value of lastmods) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) recordError('sitemap.xml', 'Invalid lastmod format', value);
  }

  for (const relativePath of expectedRelativePages) validateLocalPage(relativePath);

  const titles = new Map();
  for (const page of pageResults) {
    const list = titles.get(page.title) || [];
    list.push(page.relativePath);
    titles.set(page.title, list);
  }
  for (const [title, pages] of titles) {
    if (title && pages.length > 1) recordError('titles', 'Duplicate page title', { title, pages });
  }
}

async function waitForPublishedSitemap(expectedText) {
  let lastDetail = null;
  for (let attempt = 1; attempt <= 24; attempt += 1) {
    try {
      const response = await fetch(`${baseUrl}/sitemap.xml?seo=${Date.now()}-${attempt}`, {
        headers: { 'cache-control': 'no-cache', 'user-agent': 'Yorugatari-SEO-Audit/1.0' }
      });
      const text = await response.text();
      lastDetail = { attempt, status: response.status, bytes: Buffer.byteLength(text), matches: text === expectedText };
      if (response.status === 200 && text === expectedText) return lastDetail;
    } catch (error) {
      lastDetail = { attempt, error: error.message };
    }
    await new Promise((resolve) => setTimeout(resolve, 10000));
  }
  throw new Error(`Published sitemap did not match repository version: ${JSON.stringify(lastDetail)}`);
}

async function validateLive() {
  const expectedSitemap = fs.readFileSync(path.join(siteDir, 'sitemap.xml'), 'utf8');
  const releaseCheck = await waitForPublishedSitemap(expectedSitemap);
  const liveErrors = [];
  const livePages = [];

  const robotsResponse = await fetch(`https://allsunday1122.github.io/robots.txt?seo=${Date.now()}`, {
    headers: { 'cache-control': 'no-cache', 'user-agent': 'Yorugatari-SEO-Audit/1.0' }
  });
  const robotsText = await robotsResponse.text();
  if (robotsResponse.status !== 200 || !robotsText.includes(`Sitemap: ${baseUrl}/sitemap.xml`)) {
    liveErrors.push({ scope: 'robots.txt', message: 'Published robots.txt is unavailable or incorrect', status: robotsResponse.status });
  }

  let cursor = 0;
  const workers = Array.from({ length: 10 }, async () => {
    while (cursor < expectedUrls.length) {
      const index = cursor++;
      const url = expectedUrls[index];
      try {
        const separator = url.includes('?') ? '&' : '?';
        const response = await fetch(`${url}${separator}seo=${Date.now()}-${index}`, {
          redirect: 'follow',
          headers: { 'cache-control': 'no-cache', 'user-agent': 'Yorugatari-SEO-Audit/1.0' }
        });
        const html = await response.text();
        const canonical = findCanonical(html);
        const title = extractTitle(html);
        const description = findMeta(html, 'name', 'description');
        const robots = findMeta(html, 'name', 'robots');
        const ok = response.status === 200 && canonical === url && Boolean(title) && Boolean(description) && !/noindex/i.test(robots || '');
        livePages[index] = { url, status: response.status, canonical, title, description: Boolean(description), noindex: /noindex/i.test(robots || ''), ok };
        if (!ok) liveErrors.push({ scope: url, message: 'Published page failed SEO checks', detail: livePages[index] });
      } catch (error) {
        livePages[index] = { url, ok: false, error: error.message };
        liveErrors.push({ scope: url, message: 'Published page request failed', detail: error.message });
      }
    }
  });
  await Promise.all(workers);
  return { success: liveErrors.length === 0, releaseCheck, robotsStatus: robotsResponse.status, pages: livePages, errors: liveErrors };
}

validateLocalConfiguration();
const runLive = process.argv.includes('--live');
let live = null;
if (runLive && errors.length === 0) live = await validateLive();

const report = {
  auditedAt: new Date().toISOString(),
  mode: runLive ? 'local+live' : 'local',
  success: errors.length === 0 && (!live || live.success),
  expectedUrls: expectedUrls.length,
  local: { success: errors.length === 0, pages: pageResults, errors, warnings },
  live
};
fs.writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);
console.log(`YORUGATARI_SEO_REPORT=${JSON.stringify(report)}`);
if (!report.success) process.exit(1);
