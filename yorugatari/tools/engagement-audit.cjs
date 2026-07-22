const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright');

const ROOT = process.cwd();
const SITE_ROOT = path.join(ROOT, 'yorugatari');
const STORY_ROOT = path.join(SITE_ROOT, 'stories');
const BASE = 'https://allsunday1122.github.io/yorugatari';
const VERSION = '20260723-001';
const results = [];
const failures = [];

function record(name, ok, detail = null) {
  const result = { name, ok: Boolean(ok), detail };
  results.push(result);
  if (!result.ok) failures.push(result);
}

function count(text, pattern) {
  return (text.match(pattern) || []).length;
}

function localAudit() {
  const staticFiles = ['index.html', 'archive.html', 'about.html', 'privacy.html', 'terms.html', 'contact.html'];
  const storyFiles = fs.readdirSync(STORY_ROOT).filter((name) => name.endsWith('.html')).sort();
  const files = staticFiles.map((name) => path.join(SITE_ROOT, name))
    .concat(storyFiles.map((name) => path.join(STORY_ROOT, name)));
  const errors = [];

  for (const filePath of files) {
    const html = fs.readFileSync(filePath, 'utf8');
    const relative = path.relative(SITE_ROOT, filePath).replace(/\\/g, '/');
    const story = relative.startsWith('stories/');
    const expected = story
      ? `../assets/engagement.js?v=${VERSION}`
      : `assets/analytics.js?v=${VERSION}`;
    const checks = [
      ['runtime', html.includes(expected) && !html.includes(story ? 'analytics.js' : 'engagement.js')],
      ['og:type', count(html, /<meta\s+property=["']og:type["']/gi) === 1],
      ['og:url', count(html, /<meta\s+property=["']og:url["']/gi) === 1],
      ['og:title', count(html, /<meta\s+property=["']og:title["']/gi) === 1],
      ['og:description', count(html, /<meta\s+property=["']og:description["']/gi) === 1],
      ['og:image', count(html, /<meta\s+property=["']og:image["']/gi) === 1],
      ['og:image dimensions', html.includes('property="og:image:width" content="2172"') && html.includes('property="og:image:height" content="724"')],
      ['og:image:alt', count(html, /<meta\s+property=["']og:image:alt["']/gi) === 1],
      ['twitter card', count(html, /<meta\s+name=["']twitter:card["']/gi) === 1 && count(html, /<meta\s+name=["']twitter:image["']/gi) === 1 && count(html, /<meta\s+name=["']twitter:image:alt["']/gi) === 1]
    ];
    checks.forEach(([name, ok]) => { if (!ok) errors.push({ file: relative, check: name }); });
  }

  record('local: six static pages and 100 stories are covered', files.length === 106, { static: staticFiles.length, stories: storyFiles.length });
  record('local: analytics, engagement, and social metadata are complete', errors.length === 0, errors);

  const privacy = fs.readFileSync(path.join(SITE_ROOT, 'privacy.html'), 'utf8');
  record('local: privacy policy explains page-view processing', privacy.includes('サイト識別子とページのパス') && privacy.includes('参照元URL') && privacy.includes('2026年7月23日'));

  const notFound = fs.readFileSync(path.join(ROOT, '404.html'), 'utf8');
  record('local: 404 is noindex and recoverable',
    notFound.includes('name="robots" content="noindex,follow"') &&
    notFound.includes('data-page-type="404"') &&
    notFound.includes('href="/yorugatari/archive.html"') &&
    notFound.includes(`/yorugatari/assets/analytics.js?v=${VERSION}`) &&
    !notFound.includes('engagement.js'));
}

async function retry(page, url, inspect, attempts = 12) {
  let detail = null;
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try {
      const separator = url.includes('?') ? '&' : '?';
      const response = await page.goto(`${url}${separator}audit=${Date.now()}-${attempt}`, { waitUntil: 'networkidle', timeout: 60000 });
      detail = await inspect(page, response, attempt);
      if (detail.ready) return detail;
    } catch (error) {
      detail = { ready: false, attempt, error: error.message };
    }
    if (attempt < attempts) await new Promise((resolve) => setTimeout(resolve, 5000));
  }
  return detail || { ready: false };
}

async function metadata(page) {
  return page.evaluate(() => {
    const get = (selector) => document.querySelector(selector)?.getAttribute('content') || '';
    return {
      type: get('meta[property="og:type"]'),
      url: get('meta[property="og:url"]'),
      title: get('meta[property="og:title"]'),
      description: get('meta[property="og:description"]'),
      image: get('meta[property="og:image"]'),
      width: get('meta[property="og:image:width"]'),
      height: get('meta[property="og:image:height"]'),
      imageAlt: get('meta[property="og:image:alt"]'),
      card: get('meta[name="twitter:card"]'),
      twitterImage: get('meta[name="twitter:image"]'),
      twitterAlt: get('meta[name="twitter:image:alt"]')
    };
  });
}

function completeMeta(meta) {
  return Boolean(meta.type && meta.url && meta.title && meta.description && meta.image &&
    meta.width === '2172' && meta.height === '724' && meta.imageAlt &&
    meta.card === 'summary_large_image' && meta.twitterImage && meta.twitterAlt);
}

async function imageAudit() {
  const response = await fetch(`${BASE}/assets/yorugatari-share.png?audit=${Date.now()}`, { headers: { 'cache-control': 'no-cache' } });
  const buffer = Buffer.from(await response.arrayBuffer());
  const png = buffer.length >= 24 && buffer.toString('ascii', 1, 4) === 'PNG';
  const detail = {
    status: response.status,
    contentType: response.headers.get('content-type'),
    bytes: buffer.length,
    width: png ? buffer.readUInt32BE(16) : 0,
    height: png ? buffer.readUInt32BE(20) : 0
  };
  record('published: social image is a valid PNG with declared dimensions', response.ok && detail.width === 2172 && detail.height === 724, detail);
}

async function browserAudit() {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
    isMobile: true,
    hasTouch: true,
    serviceWorkers: 'block',
    userAgent: 'Yorugatari-Engagement-Audit/1.4'
  });
  await context.addInitScript(() => {
    Object.defineProperty(navigator, 'share', {
      configurable: true,
      value: async (payload) => { window.__YORUGATARI_SHARE_PAYLOAD__ = payload; }
    });
  });
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', (error) => errors.push(`pageerror: ${error.message}`));
  page.on('console', (message) => { if (message.type() === 'error') errors.push(`console: ${message.text()}`); });

  const top = await retry(page, `${BASE}/`, async (target, response, attempt) => {
    const state = await target.evaluate((version) => ({
      analyticsScript: Array.from(document.scripts).some((script) => script.src.includes(`analytics.js?v=${version}`)),
      engagementScript: Array.from(document.scripts).some((script) => script.src.includes('engagement.js')),
      analytics: Boolean(window.YORUGATARI_ANALYTICS),
      path: window.YORUGATARI_ANALYTICS?.path,
      panel: Boolean(document.querySelector('#readerPanel'))
    }), VERSION);
    const meta = await metadata(target);
    return { ready: response?.status() === 200 && state.analyticsScript && !state.engagementScript && state.analytics && state.panel && completeMeta(meta), status: response?.status(), attempt, state, meta };
  });
  record('published: top uses lightweight analytics and complete social metadata', top.ready && top.state?.path === '/yorugatari', top);

  const story = await retry(page, `${BASE}/stories/spare-key-returned.html`, async (target, response, attempt) => {
    const state = await target.evaluate((version) => ({
      engagementScript: Array.from(document.scripts).some((script) => script.src.includes(`engagement.js?v=${version}`)),
      analyticsScript: Array.from(document.scripts).some((script) => script.src.includes('analytics.js')),
      engagement: Boolean(window.YORUGATARI_ENGAGEMENT),
      share: Boolean(document.querySelector('#shareButton'))
    }), VERSION);
    const meta = await metadata(target);
    return { ready: response?.status() === 200 && state.engagementScript && !state.analyticsScript && state.engagement && state.share && completeMeta(meta), status: response?.status(), attempt, state, meta };
  });
  record('published: story uses engagement module and complete social metadata', story.ready, story);

  try { await page.waitForFunction(() => Number.isFinite(window.YORUGATARI_ENGAGEMENT?.views), null, { timeout: 20000 }); } catch (error) {}
  const views = await page.evaluate(() => ({
    value: window.YORUGATARI_ENGAGEMENT?.views,
    text: document.querySelector('.view-count strong')?.textContent.trim(),
    error: window.YORUGATARI_ENGAGEMENT?.error
  }));
  record('published: Page Views API count is displayed', Number.isFinite(views.value) && /^\d/.test(views.text || ''), views);

  await page.locator('#shareButton').click();
  const share = await page.evaluate(() => ({ payload: window.__YORUGATARI_SHARE_PAYLOAD__, status: document.querySelector('.share-status')?.textContent.trim() }));
  record('published: native share receives canonical story data', Boolean(share.payload && share.payload.url === `${BASE}/stories/spare-key-returned.html` && String(share.payload.title).includes('合鍵は返却済み') && share.status === '共有画面を開きました。'), share);

  try { await page.waitForFunction(() => document.querySelectorAll('.related a').length >= 2, null, { timeout: 12000 }); } catch (error) {}
  const circulation = await page.evaluate(() => ({
    pagination: Array.from(document.querySelectorAll('.story-pagination a')).map((link) => link.textContent.trim()),
    related: Array.from(document.querySelectorAll('.related a')).map((link) => link.textContent.trim()),
    archiveLinks: document.querySelectorAll('a[href*="archive.html"]').length
  }));
  record('published: previous, archive, next, and related paths exist', circulation.pagination.length === 3 && circulation.related.length >= 2 && circulation.archiveLinks >= 1, circulation);

  const policy = await retry(page, `${BASE}/about.html`, async (target, response, attempt) => {
    const meta = await metadata(target);
    const scripts = await target.evaluate(() => ({
      analytics: Array.from(document.scripts).some((script) => script.src.includes('analytics.js')),
      engagement: Array.from(document.scripts).some((script) => script.src.includes('engagement.js'))
    }));
    return { ready: response?.status() === 200 && completeMeta(meta) && scripts.analytics && !scripts.engagement, status: response?.status(), attempt, meta, scripts };
  }, 6);
  record('published: policy uses lightweight analytics and social metadata', policy.ready, policy);
  record('published: normal pages have no JavaScript errors', errors.length === 0, errors.slice());
  errors.length = 0;

  const missing = await retry(page, `${BASE}/stories/missing-${Date.now()}.html`, async (target, response, attempt) => {
    const detail = await target.evaluate(() => ({
      noindex: document.querySelector('meta[name="robots"]')?.content,
      pageType: document.body.dataset.pageType,
      archive: Boolean(document.querySelector('a[href="/yorugatari/archive.html"]')),
      top: Boolean(document.querySelector('a[href="/yorugatari/"]')),
      trackingPath: window.YORUGATARI_ANALYTICS?.trackingPath,
      analytics: Array.from(document.scripts).some((script) => script.src.includes('analytics.js')),
      engagement: Array.from(document.scripts).some((script) => script.src.includes('engagement.js'))
    }));
    return { ready: response?.status() === 404 && detail.pageType === '404' && detail.archive && detail.analytics && !detail.engagement, status: response?.status(), attempt, ...detail };
  }, 6);
  record('published: custom 404 is noindex, tracked, and recoverable', missing.ready && missing.noindex === 'noindex,follow' && missing.top && missing.trackingPath === '/yorugatari/404', missing);
  const relevant404Errors = errors.filter((message) => !message.includes('server responded with a status of 404'));
  record('published: custom 404 has no JavaScript exceptions', relevant404Errors.length === 0, relevant404Errors);

  await context.close();
  await browser.close();
  await imageAudit();
}

(async () => {
  localAudit();
  try {
    await browserAudit();
  } catch (error) {
    record('audit completed without exception', false, { message: error.message, stack: error.stack });
  }
  const report = { auditedAt: new Date().toISOString(), success: failures.length === 0, results, failures };
  fs.writeFileSync('yorugatari-engagement-report.json', `${JSON.stringify(report, null, 2)}\n`);
  console.log(`YORUGATARI_ENGAGEMENT_REPORT=${JSON.stringify(report)}`);
  if (failures.length) process.exit(1);
})();
