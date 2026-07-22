import fs from 'node:fs';
import path from 'node:path';
import { buildSitemap, expectedPages } from './generate-sitemap.mjs';

const ROOT = process.cwd();
const SITE = path.join(ROOT, 'yorugatari');
const BASE = 'https://allsunday1122.github.io/yorugatari';
const REPORT_PATH = path.join(ROOT, 'yorugatari-seo-report.json');
const EXPECTED_PAGES = expectedPages();
const EXPECTED_URLS = EXPECTED_PAGES.map((relative) => relative === 'index.html' ? `${BASE}/` : `${BASE}/${relative}`);
const errors = [];
const warnings = [];
const pages = [];

function error(scope, message, detail = null) {
  errors.push({ scope, message, detail });
}

function warning(scope, message, detail = null) {
  warnings.push({ scope, message, detail });
}

function attribute(tag, name) {
  const match = tag.match(new RegExp(`\\s${name}\\s*=\\s*(?:"([^"]*)"|'([^']*)'|([^\\s>]+))`, 'i'));
  return match ? (match[1] ?? match[2] ?? match[3] ?? '') : null;
}

function meta(html, key, value) {
  const tags = html.match(/<meta\b[^>]*>/gi) || [];
  const found = tags.find((tag) => attribute(tag, key)?.toLowerCase() === value.toLowerCase());
  return found ? attribute(found, 'content') : null;
}

function canonical(html) {
  const tags = html.match(/<link\b[^>]*>/gi) || [];
  const found = tags.find((tag) => (attribute(tag, 'rel') || '').toLowerCase().split(/\s+/).includes('canonical'));
  return found ? attribute(found, 'href') : null;
}

function title(html) {
  const match = html.match(/<title>([\s\S]*?)<\/title>/i);
  return match ? match[1].replace(/\s+/g, ' ').trim() : '';
}

function jsonLd(html, scope) {
  const values = [];
  const pattern = /<script\b[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;
  let match;
  while ((match = pattern.exec(html))) {
    try {
      values.push(JSON.parse(match[1].trim()));
    } catch (cause) {
      error(scope, 'Invalid JSON-LD', cause.message);
    }
  }
  return values;
}

function hasType(values, wanted) {
  return values.some((value) => {
    const raw = value?.['@type'];
    return (Array.isArray(raw) ? raw : [raw]).includes(wanted);
  });
}

function relativeForUrl(url) {
  const parsed = new URL(url);
  if (parsed.hostname !== 'allsunday1122.github.io' || !parsed.pathname.startsWith('/yorugatari/')) return null;
  const remainder = decodeURIComponent(parsed.pathname.slice('/yorugatari/'.length));
  return remainder || 'index.html';
}

function fragmentExists(relative, fragment) {
  if (!fragment) return true;
  const decoded = decodeURIComponent(fragment);
  if (relative === 'archive.html' && new Set(['心霊', '人怖', '意味怖', 'ネット怪談', '都市伝説風', '後味悪い']).has(decoded)) return true;
  const target = path.join(SITE, relative);
  if (!fs.existsSync(target)) return false;
  const html = fs.readFileSync(target, 'utf8');
  const escaped = decoded.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return new RegExp(`(?:id|name)=["']${escaped}["']`, 'i').test(html);
}

function validateLinks(relative, html, pageCanonical) {
  for (const tag of html.match(/<a\b[^>]*>/gi) || []) {
    const href = attribute(tag, 'href');
    if (!href || /^(?:mailto:|tel:|javascript:|data:)/i.test(href)) continue;
    let resolved;
    try {
      resolved = new URL(href, pageCanonical);
    } catch (cause) {
      error(relative, 'Invalid link URL', { href, cause: cause.message });
      continue;
    }
    const target = relativeForUrl(resolved);
    if (!target) continue;
    const clean = target.endsWith('/') ? `${target}index.html` : target;
    if (!fs.existsSync(path.join(SITE, clean))) {
      error(relative, 'Broken internal link', { href, target: clean });
      continue;
    }
    if (!fragmentExists(clean, resolved.hash.slice(1))) error(relative, 'Broken internal fragment', { href, target: clean, fragment: resolved.hash });
  }
}

function validatePage(relative) {
  const html = fs.readFileSync(path.join(SITE, relative), 'utf8');
  const expectedCanonical = relative === 'index.html' ? `${BASE}/` : `${BASE}/${relative}`;
  const pageTitle = title(html);
  const description = meta(html, 'name', 'description');
  const robots = meta(html, 'name', 'robots');
  const pageCanonical = canonical(html);
  const ogUrl = meta(html, 'property', 'og:url');
  const h1 = (html.match(/<h1\b/gi) || []).length;
  const schemas = jsonLd(html, relative);

  if (!/<html\b[^>]*lang=["']ja["']/i.test(html)) error(relative, 'Missing html lang="ja"');
  if (!pageTitle) error(relative, 'Missing page title');
  if (!description) error(relative, 'Missing meta description');
  if (pageCanonical !== expectedCanonical) error(relative, 'Canonical URL mismatch', { expected: expectedCanonical, actual: pageCanonical });
  if (/noindex/i.test(robots || '')) error(relative, 'Page is marked noindex', robots);
  if (h1 !== 1) error(relative, 'Page must contain exactly one h1', h1);
  if (ogUrl && ogUrl !== expectedCanonical) error(relative, 'og:url mismatch', { expected: expectedCanonical, actual: ogUrl });
  if (pageTitle.length > 65) warning(relative, 'Long title may be truncated', pageTitle.length);
  if (description && description.length > 170) warning(relative, 'Long description may be truncated', description.length);

  if (relative === 'index.html' && !hasType(schemas, 'WebSite')) error(relative, 'Missing WebSite structured data');
  if (relative === 'archive.html' && !hasType(schemas, 'CollectionPage')) error(relative, 'Missing CollectionPage structured data');
  if (relative.startsWith('categories/')) {
    if (!hasType(schemas, 'CollectionPage')) error(relative, 'Missing category CollectionPage structured data');
    if (!hasType(schemas, 'BreadcrumbList')) error(relative, 'Missing category BreadcrumbList structured data');
  }
  if (relative.startsWith('stories/')) {
    if (!hasType(schemas, 'ShortStory')) error(relative, 'Missing ShortStory structured data');
    if (!hasType(schemas, 'BreadcrumbList')) error(relative, 'Missing BreadcrumbList structured data');
    if (!meta(html, 'property', 'og:image:alt')) error(relative, 'Missing Open Graph image alt text');
  }

  validateLinks(relative, html, expectedCanonical);
  pages.push({ relativePath: relative, canonical: expectedCanonical, title: pageTitle, descriptionLength: description?.length || 0, h1Count: h1, jsonLdBlocks: schemas.length });
}

function validateLocal() {
  const robotsPath = path.join(ROOT, 'robots.txt');
  if (!fs.existsSync(robotsPath)) {
    error('robots.txt', 'Root robots.txt is missing');
  } else {
    const robots = fs.readFileSync(robotsPath, 'utf8');
    if (!/^User-agent:\s*\*/im.test(robots)) error('robots.txt', 'Missing wildcard user-agent');
    if (!/^Allow:\s*\/$/im.test(robots)) error('robots.txt', 'Site is not explicitly allowed');
    if (!/^Sitemap:\s*https:\/\/allsunday1122\.github\.io\/yorugatari\/sitemap\.xml$/im.test(robots)) error('robots.txt', 'Sitemap directive is missing or incorrect');
  }

  const sitemapPath = path.join(SITE, 'sitemap.xml');
  const current = fs.readFileSync(sitemapPath, 'utf8');
  const generated = buildSitemap();
  if (current !== generated) error('sitemap.xml', 'Sitemap is not synchronized with current files and git history');
  const locations = Array.from(current.matchAll(/<loc>([^<]+)<\/loc>/g), (match) => match[1]);
  const lastmods = Array.from(current.matchAll(/<lastmod>([^<]+)<\/lastmod>/g), (match) => match[1]);
  const unique = new Set(locations);
  if (locations.length !== EXPECTED_URLS.length) error('sitemap.xml', `Expected ${EXPECTED_URLS.length} URLs`, locations.length);
  if (unique.size !== locations.length) error('sitemap.xml', 'Duplicate sitemap URLs detected');
  const expected = new Set(EXPECTED_URLS);
  const missing = EXPECTED_URLS.filter((url) => !unique.has(url));
  const unexpected = locations.filter((url) => !expected.has(url));
  if (missing.length) error('sitemap.xml', 'Expected URLs missing', missing);
  if (unexpected.length) error('sitemap.xml', 'Unexpected URLs present', unexpected);
  for (const value of lastmods) if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) error('sitemap.xml', 'Invalid lastmod format', value);

  for (const relative of EXPECTED_PAGES) validatePage(relative);
  const titles = new Map();
  for (const page of pages) titles.set(page.title, [...(titles.get(page.title) || []), page.relativePath]);
  for (const [value, linked] of titles) if (value && linked.length > 1) error('titles', 'Duplicate page title', { title: value, pages: linked });
}

async function waitForSitemap(expected) {
  let detail = null;
  for (let attempt = 1; attempt <= 24; attempt += 1) {
    try {
      const response = await fetch(`${BASE}/sitemap.xml?seo=${Date.now()}-${attempt}`, { headers: { 'cache-control': 'no-cache', 'user-agent': 'Yorugatari-SEO-Audit/1.1' }, signal: AbortSignal.timeout(30000) });
      const text = await response.text();
      detail = { attempt, status: response.status, bytes: Buffer.byteLength(text), matches: text === expected };
      if (response.status === 200 && text === expected) return detail;
    } catch (cause) {
      detail = { attempt, error: cause.message };
    }
    if (attempt < 24) await new Promise((resolve) => setTimeout(resolve, 10000));
  }
  throw new Error(`Published sitemap did not match repository version: ${JSON.stringify(detail)}`);
}

async function liveRequest(url, index) {
  let detail = null;
  for (let attempt = 1; attempt <= 3; attempt += 1) {
    try {
      const response = await fetch(`${url}${url.includes('?') ? '&' : '?'}seo=${Date.now()}-${index}-${attempt}`, { redirect: 'follow', headers: { 'cache-control': 'no-cache', 'user-agent': 'Yorugatari-SEO-Audit/1.1' }, signal: AbortSignal.timeout(30000) });
      const html = await response.text();
      detail = { status: response.status, canonical: canonical(html), title: title(html), description: Boolean(meta(html, 'name', 'description')), noindex: /noindex/i.test(meta(html, 'name', 'robots') || '') };
      if (response.status < 500) return detail;
    } catch (cause) {
      detail = { status: null, error: cause.message };
    }
    if (attempt < 3) await new Promise((resolve) => setTimeout(resolve, attempt * 1500));
  }
  return detail;
}

async function validateLive() {
  const expectedSitemap = fs.readFileSync(path.join(SITE, 'sitemap.xml'), 'utf8');
  const releaseCheck = await waitForSitemap(expectedSitemap);
  const liveErrors = [];
  const livePages = new Array(EXPECTED_URLS.length);
  const robotsResponse = await fetch(`https://allsunday1122.github.io/robots.txt?seo=${Date.now()}`, { headers: { 'cache-control': 'no-cache', 'user-agent': 'Yorugatari-SEO-Audit/1.1' } });
  const robotsText = await robotsResponse.text();
  if (robotsResponse.status !== 200 || !robotsText.includes(`Sitemap: ${BASE}/sitemap.xml`)) liveErrors.push({ scope: 'robots.txt', message: 'Published robots.txt is unavailable or incorrect', status: robotsResponse.status });

  let cursor = 0;
  await Promise.all(Array.from({ length: 10 }, async () => {
    while (cursor < EXPECTED_URLS.length) {
      const index = cursor++;
      const url = EXPECTED_URLS[index];
      const detail = await liveRequest(url, index);
      const ok = detail.status === 200 && detail.canonical === url && detail.title && detail.description && !detail.noindex;
      livePages[index] = { url, ...detail, ok: Boolean(ok) };
      if (!ok) liveErrors.push({ scope: url, message: 'Published page failed SEO checks', detail: livePages[index] });
    }
  }));
  return { success: liveErrors.length === 0, releaseCheck, robotsStatus: robotsResponse.status, pages: livePages, errors: liveErrors };
}

validateLocal();
const runLive = process.argv.includes('--live');
let live = null;
if (runLive && errors.length === 0) live = await validateLive();
const report = {
  auditedAt: new Date().toISOString(),
  mode: runLive ? 'local+live' : 'local',
  success: errors.length === 0 && (!live || live.success),
  expectedUrls: EXPECTED_URLS.length,
  local: { success: errors.length === 0, pages, errors, warnings },
  live
};
fs.writeFileSync(REPORT_PATH, `${JSON.stringify(report, null, 2)}\n`);
console.log(`YORUGATARI_SEO_REPORT=${JSON.stringify(report)}`);
if (!report.success) process.exit(1);
