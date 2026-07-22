const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright');

const root = process.cwd();
const siteRoot = path.join(root, 'yorugatari');
const storyRoot = path.join(siteRoot, 'stories');
const base = 'https://allsunday1122.github.io/yorugatari';
const analyticsVersion = '20260723-001';
const engagementVersion = '20260723-001';
const results = [];
const failures = [];

function record(name, ok, detail = null) {
  const result = { name, ok: Boolean(ok), detail };
  results.push(result);
  if (!result.ok) failures.push(result);
}

function countMatches(text, pattern) {
  return (text.match(pattern) || []).length;
}

function localAudit() {
  const staticFiles = ['index.html', 'archive.html', 'about.html', 'privacy.html', 'terms.html', 'contact.html'];
  const storyFiles = fs.readdirSync(storyRoot).filter((name) => name.endsWith('.html')).sort();
  const files = staticFiles.map((name) => path.join(siteRoot, name)).concat(storyFiles.map((name) => path.join(storyRoot, name)));
  const errors = [];

  for (const filePath of files) {
    const html = fs.readFileSync(filePath, 'utf8');
    const relative = path.relative(siteRoot, filePath).replace(/\\/g, '/');
    const isStory = relative.startsWith('stories/');
    const expectedScript = isStory
      ? `../assets/engagement.js?v=${engagementVersion}`
      : `assets/analytics.js?v=${analyticsVersion}`;
    const unwantedScript = isStory ? 'analytics.js' : 'engagement.js';
    const required = [
      ['correct runtime script', html.includes(expectedScript) && !html.includes(unwantedScript)],
      ['og:type', countMatches(html, /<meta\s+property=["']og:type["']/gi) === 1],
      ['og:url', countMatches(html, /<meta\s+property=["']og:url["']/gi) === 1],
      ['og:title', countMatches(html, /<meta\s+property=["']og:title["']/gi) === 1],
      ['og:description', countMatches(html, /<meta\s+property=["']og:description["']/gi) === 1],
      ['og:image', countMatches(html, /<meta\s+property=["']og:image["']/gi) === 1],
      ['og:image width', html.includes('property="og:image:width" content="2172"')],
      ['og:image height', html.includes('property="og:image:height" content="724"')],
      ['og:image:alt', countMatches(html, /<meta\s+property=["']og:image:alt["']/gi) === 1],
      ['twitter:card', countMatches(html, /<meta\s+name=["']twitter:card["']/gi) === 1],
      ['twitter:image', countMatches(html, /<meta\s+name=["']twitter:image["']/gi) === 1],
      ['twitter:image:alt', countMatches(html, /<meta\s+name=["']twitter:image:alt["']/gi) === 1]
    ];
    for (const [name, ok] of required) {
      if (!ok) errors.push({ file: relative, missing: name });
    }
  }

  record('local: six static pages and 100 stories are covered', files.length === 106, { static: staticFiles.length, stories: storyFiles.length });
  record('local: split analytics, engagement, and social metadata are complete', errors.length === 0, errors);

  const privacy = fs.readFileSync(path.join(siteRoot, 'privacy.html'), 'utf8');
  record(
    'local: privacy policy explains page-view processing',
    privacy.includes('サイト識別子とページのパス') && privacy.includes('参照元URL') && privacy.includes('2026年7月23日')
  );

  const notFound = fs.readFileSync(path.join(root, '404.html'), 'utf8');
  record(
    'local: 404 page is noindex and has recovery links',
    notFound.includes('name="robots" content="noindex,follow"') &&
      notFound.includes('data-page-type="404"') &&
      notFound.includes('href="/yorugatari/archive.html"') &&
      notFound.includes(`/yorugatari/assets/analytics.js?v=${analyticsVersion}`) &&
      !notFound.includes('engagement.js')
  );
}

async function openWithRetry(page, url, readiness, attempts = 12) {
  let detail = null;
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try {
      const separator = url.includes('?') ? '&' : '?';
      const response = await page.goto(`${url}${separator}engagementAudit=${Date.now()}-${attempt}`, {
        waitUntil: 'networkidle',
        timeout: 60000
      });
      detail = await readiness(page, response, attempt);
      if (detail.ready) return detail;
    } catch (error) {
      detail = { ready: false, attempt, error: error.message };
    }
    if (attempt < attempts) await new Promise((resolve) => setTimeout(resolve, 5000));
  }
  return detail || { ready: false };
}

async function socialMetadata(page) {
  return page.evaluate(() => {
    const get = (selector) => document.querySelector(selector)?.getAttribute('content') || '';
    return {
      type: get('meta[property="og:type"]'),
      url: get('meta[property="og:url"]'),
      title: get('meta[property="og:title"]'),
      description: get('meta[property="og:description"]'),
      image: get('meta[property="og:image"]'),
      imageWidth: get('meta[property="og:image:width"]'),
      imageHeight: get('meta[property="og:image:height"]'),
      imageAlt: get('meta[property="og:image:alt"]'),
      twitterCard: get('meta[name="twitter:card"]'),
      twitterImage: get('meta[name="twitter:image"]'),
      twitterImageAlt: get('meta[name="twitter:image:alt"]')
    };
  });
}

function completeSocial(meta) {
  return Boolean(
    meta.type && meta.url && meta.title && meta.description && meta.image &&
    meta.imageWidth === '2172' && meta.imageHeight === '724' && meta.imageAlt &&
    meta.twitterCard === 'summary_large_image' && meta.twitterImage && meta.twitterImageAlt
  );
}

async function auditShareImage() {
  const url = 'https://allsunday1122.github.io/yorugatari/assets/yorugatari-share.png?audit=' + Date.now();
  let detail = null;
  for (let attempt = 1; attempt <= 4; attempt += 1) {
    try {
      const response = await fetch(url, { headers: { 'cache-control': 'no-cache', pragma: 'no-cache' } });
      const buffer = Buffer.from(await response.arrayBuffer());
      const png = buffer.length >= 24 && buffer.toString('ascii', 1, 4) === 'PNG';
      const width = png ? buffer.readUInt32BE(16) : 0;
      const height = png ? buffer.readUInt32BE(20) : 0;
      detail = { status: response.status, contentType: response.headers.get('content-type'), bytes: buffer.length, width, height, attempt };
      if (response.ok && png && width === 2172 && height === 724) break;
    } catch (error) {
      detail = { attempt, error: error.message };
    }
    await new Promise((resolve) => setTimeout(resolve, 2000));
  }
  record('published: social preview image is a valid PNG with declared dimensions', Boolean(detail && detail.status === 200 && detail.width === 2172 && detail.height === 724), detail);
}

async function browserAudit() {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
    isMobile: true,
    hasTouch: true,
    userAgent: 'Yorugatari-Engagement-Audit/1.3',
    extraHTTPHeaders: {
      'cache-control': 'no-cache, no-store, max-age=0',
      pragma: 'no-cache'
    }
  });
  await context.addInitScript(() => {
    Object.defineProperty(navigator, 'share', {
      configurable: true,
      value: async (payload) => { window.__YORUGATARI_SHARE_PAYLOAD__ = payload; }
    });
  });
  const page = await context.newPage();
  const browserErrors = [];
  page.on('pageerror', (error) => browserErrors.push(`pageerror: ${error.message}`));
  page.on('console', (message) => {
    if (message.type() === 'error') browserErrors.push(`console: ${message.text()}`);
  });

  const top = await openWithRetry(page, `${base}/`, async (targetPage, response, attempt) => {
    const state = await targetPage.evaluate((version) => ({
      script: Array.from(document.scripts).some((script) => script.src.includes(`analytics.js?v=${version}`)),
      noStoryModule: !Array.from(document.scripts).some((script) => script.src.includes('engagement.js')),
      analytics: Boolean(window.YORUGATARI_ANALYTICS),
      path: window.YORUGATARI_ANALYTICS?.path,
      panel: Boolean(document.querySelector('#readerPanel')),
      imageWidth: document.querySelector('meta[property="og:image:width"]')?.content,
      imageHeight: document.querySelector('meta[property="og:image:height"]')?.content
    }), analyticsVersion);
    return {
      ready: response?.status() === 200 && state.script && state.noStoryModule && state.analytics && state.panel && state.imageWidth === '2172' && state.imageHeight === '724',
      status: response?.status(),
      attempt,
      ...state
    };
  });
  record('published: top loads only the lightweight analytics module', top.ready && top.path === '/yorugatari', top);
  const topSocial = await socialMetadata(page);
  record('published: top has complete social preview metadata', completeSocial(topSocial), topSocial);

  const story = await openWithRetry(page, `${base}/stories/spare-key-returned.html`, async (targetPage, response, attempt) => {
    const state = await targetPage.evaluate((version) => ({
      script: Array.from(document.scripts).some((script) => script.src.includes(`engagement.js?v=${version}`)),
      noStaticModule: !Array.from(document.scripts).some((script) => script.src.includes('analytics.js')),
      engagement: Boolean(window.YORUGATARI_ENGAGEMENT),
      share: Boolean(document.querySelector('#shareButton')),
      viewText: document.querySelector('.view-count strong')?.textContent.trim() || '',
      imageWidth: document.querySelector('meta[property="og:image:width"]')?.content,
      imageHeight: document.querySelector('meta[property="og:image:height"]')?.content
    }), engagementVersion);
    return {
      ready: response?.status() === 200 && state.script && state.noStaticModule && state.engagement && state.share && state.imageWidth === '2172' && state.imageHeight === '724',
      status: response?.status(),
      attempt,
      ...state
    };
  });
  record('published: story loads view count and share controls', story.ready, story);

  try {
    await page.waitForFunction(() => Number.isFinite(window.YORUGATARI_ENGAGEMENT?.views), null, { timeout: 20000 });
  } catch (error) {}
  const viewState = await page.evaluate(() => ({
    views: window.YORUGATARI_ENGAGEMENT?.views,
    text: document.querySelector('.view-count strong')?.textContent.trim(),
    error: window.YORUGATARI_ENGAGEMENT?.error
  }));
  record('published: Page Views API count is displayed', Number.isFinite(viewState.views) && /^\d/.test(viewState.text || ''), viewState);

  await page.locator('#shareButton').click();
  const shareState = await page.evaluate(() => ({
    payload: window.__YORUGATARI_SHARE_PAYLOAD__,
    status: document.querySelector('.share-status')?.textContent.trim()
  }));
  record(
    'published: native sharing receives canonical story data',
    Boolean(
      shareState.payload &&
      shareState.payload.url === `${base}/stories/spare-key-returned.html` &&
      String(shareState.payload.title).includes('合鍵は返却済み') &&
      shareState.status === '共有画面を開きました。'
    ),
    shareState
  );

  try {
    await page.waitForFunction(() => document.querySelectorAll('.related a').length >= 2, null, { timeout: 12000 });
  } catch (error) {}
  const circulation = await page.evaluate(() => ({
    pagination: Array.from(document.querySelectorAll('.story-pagination a')).map((link) => link.textContent.trim()),
    related: Array.from(document.querySelectorAll('.related a')).map((link) => link.textContent.trim()),
    archiveLinks: document.querySelectorAll('a[href*="archive.html"]').length
  }));
  record(
    'published: story has previous, archive, next, and related-story paths',
    circulation.pagination.length === 3 && circulation.related.length >= 2 && circulation.archiveLinks >= 1,
    circulation
  );
  const storySocial = await socialMetadata(page);
  record('published: story has complete social preview metadata', completeSocial(storySocial) && storySocial.type === 'article', storySocial);

  const policy = await openWithRetry(page, `${base}/about.html`, async (targetPage, response, attempt) => {
    const meta = await socialMetadata(targetPage);
    const moduleState = await targetPage.evaluate((version) => ({
      analytics: Array.from(document.scripts).some((script) => script.src.includes(`analytics.js?v=${version}`)),
      noStoryModule: !Array.from(document.scripts).some((script) => script.src.includes('engagement.js'))
    }), analyticsVersion);
    return { ready: response?.status() === 200 && completeSocial(meta) && moduleState.analytics && moduleState.noStoryModule, status: response?.status(), attempt, meta, moduleState };
  }, 6);
  record('published: policy page has complete social metadata and lightweight analytics', policy.ready, policy);
  record('published: normal pages have no browser JavaScript errors', browserErrors.length === 0, browserErrors.slice());
  browserErrors.length = 0;

  const missingUrl = `${base}/stories/this-page-does-not-exist-${Date.now()}.html`;
  const missing = await openWithRetry(page, missingUrl, async (targetPage, response, attempt) => {
    const detail = await targetPage.evaluate(() => ({
      title: document.title,
      noindex: document.querySelector('meta[name="robots"]')?.content,
      pageType: document.body.dataset.pageType,
      archive: Boolean(document.querySelector('a[href="/yorugatari/archive.html"]')),
      top: Boolean(document.querySelector('a[href="/yorugatari/"]')),
      trackingPath: window.YORUGATARI_ANALYTICS?.trackingPath,
      analytics: Array.from(document.scripts).some((script) => script.src.includes('/analytics.js?v=')),
      noStoryModule: !Array.from(document.scripts).some((script) => script.src.includes('engagement.js'))
    }));
    return { ready: response?.status() === 404 && detail.pageType === '404' && detail.archive && detail.analytics && detail.noStoryModule, status: response?.status(), attempt, ...detail };
  }, 6);
  record(
    'published: custom 404 returns HTTP 404, noindex, analytics, and recovery paths',
    missing.ready && missing.noindex === 'noindex,follow' && missing.top && missing.trackingPath === '/yorugatari/404',
    missing
  );
  const errorPageErrors = browserErrors.filter((message) => !message.includes('server responded with a status of 404'));
  record('published: custom 404 has no JavaScript exceptions', errorPageErrors.length === 0, errorPageErrors);

  await context.close();
  await browser.close();
  await auditShareImage();
}

(async () => {
  localAudit();
  try {
    await browserAudit();
  } catch (error) {
    record('engagement audit completed without exception', false, { message: error.message, stack: error.stack });
  }
  const report = {
    auditedAt: new Date().toISOString(),
    success: failures.length === 0,
    results,
    failures
  };
  fs.writeFileSync('yorugatari-engagement-report.json', `${JSON.stringify(report, null, 2)}\n`);
  console.log(`YORUGATARI_ENGAGEMENT_REPORT=${JSON.stringify(report)}`);
  if (failures.length) process.exit(1);
})();
