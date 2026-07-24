const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright');

const ROOT = process.cwd();
const SITE = path.join(ROOT, 'yorugatari');
const STORIES = path.join(SITE, 'stories');
const BASE = 'https://allsunday1122.github.io/yorugatari';
const ANALYTICS_VERSION = '20260723-003';
const FIVE_MINUTE_ANALYTICS_VERSION = '20260724-004';
const BEDTIME_ANALYTICS_VERSION = '20260724-005';
const ENGAGEMENT_VERSION = '20260723-003';
const STORY_VERSION = '20260723-007';
const campaigns = JSON.parse(fs.readFileSync(path.join(SITE, 'tools', 'campaigns.json'), 'utf8'));
const results = [];
const failures = [];

function record(name, ok, detail = null) {
  const item = { name, ok: Boolean(ok), detail };
  results.push(item);
  if (!item.ok) failures.push(item);
}

function staticVersion(filename) {
  if (filename === '5min-horror.html') return FIVE_MINUTE_ANALYTICS_VERSION;
  if (filename === 'bedtime-horror.html') return BEDTIME_ANALYTICS_VERSION;
  return ANALYTICS_VERSION;
}

function localAudit() {
  const staticFiles = ['index.html', '5min-horror.html', 'bedtime-horror.html', 'archive.html', 'about.html', 'privacy.html', 'terms.html', 'contact.html'];
  const storyFiles = fs.readdirSync(STORIES).filter((name) => name.endsWith('.html')).sort();
  const errors = [];

  for (const filename of staticFiles) {
    const html = fs.readFileSync(path.join(SITE, filename), 'utf8');
    const expectedVersion = staticVersion(filename);
    if (!html.includes(`assets/analytics.js?v=${expectedVersion}`) || html.includes('assets/engagement.js')) errors.push({ file: filename, check: 'runtime' });
    if (!html.includes('property="og:image:width" content="2172"') || !html.includes('property="og:image:height" content="724"')) errors.push({ file: filename, check: 'dimensions' });
  }

  for (const filename of storyFiles) {
    const html = fs.readFileSync(path.join(STORIES, filename), 'utf8');
    if (!html.includes(`../assets/story.js?v=${STORY_VERSION}`)) errors.push({ file: `stories/${filename}`, check: 'story runtime' });
    if (!html.includes(`../assets/engagement.js?v=${ENGAGEMENT_VERSION}`) || html.includes('../assets/analytics.js')) errors.push({ file: `stories/${filename}`, check: 'engagement runtime' });
    if (!html.includes('class="hero-actions story-pagination"') || !html.includes('class="related"')) errors.push({ file: `stories/${filename}`, check: 'static circulation' });
    if (!html.includes('property="og:image:width" content="2172"') || !html.includes('property="og:image:height" content="724"')) errors.push({ file: `stories/${filename}`, check: 'dimensions' });
  }

  const fiveMinute = fs.readFileSync(path.join(SITE, '5min-horror.html'), 'utf8');
  if ((fiveMinute.match(/class="pick"/g) || []).length !== 12) errors.push({ file: '5min-horror.html', check: '12 editorial picks' });
  if ((fiveMinute.match(/class="guide-card"/g) || []).length !== 6) errors.push({ file: '5min-horror.html', check: 'six genre guides' });
  if (!fiveMinute.includes('"@type":"FAQPage"') || !fiveMinute.includes('"@type":"CollectionPage"')) errors.push({ file: '5min-horror.html', check: 'structured data' });

  const bedtime = fs.readFileSync(path.join(SITE, 'bedtime-horror.html'), 'utf8');
  if ((bedtime.match(/class="pick"/g) || []).length !== 8) errors.push({ file: 'bedtime-horror.html', check: 'eight editorial picks' });
  if ((bedtime.match(/class="mood-card"/g) || []).length !== 4) errors.push({ file: 'bedtime-horror.html', check: 'four mood guides' });
  if (!bedtime.includes('"@type":"FAQPage"') || !bedtime.includes('"@type":"CollectionPage"')) errors.push({ file: 'bedtime-horror.html', check: 'structured data' });

  const storyRuntime = fs.readFileSync(path.join(SITE, 'assets', 'story.js'), 'utf8');
  const analyticsRuntime = fs.readFileSync(path.join(SITE, 'assets', 'analytics.js'), 'utf8');
  const engagementRuntime = fs.readFileSync(path.join(SITE, 'assets', 'engagement.js'), 'utf8');
  const launchKit = fs.readFileSync(path.join(SITE, 'tools', 'external-launch-kit.md'), 'utf8');
  const campaignDefinitions = Array.isArray(campaigns.definitions) ? campaigns.definitions : [];
  const requiredCampaigns = new Set([
    'launch-20260723-x-top-100',
    'launch-20260723-x-last-elevator',
    'launch-20260723-threads-spare-key',
    'launch-20260723-line-hired-experience',
    'launch-20260724-x-five-minute',
    'launch-20260724-threads-five-minute',
    'launch-20260724-x-bedtime',
    'launch-20260724-threads-bedtime'
  ]);

  record('local: eight static pages and 100 stories are covered', staticFiles.length === 8 && storyFiles.length === 100, { static: staticFiles.length, stories: storyFiles.length });
  record('local: runtime modules, social metadata, and static circulation are complete', errors.length === 0, errors);
  record('local: story runtime no longer loads the 100-story catalog', !storyRuntime.includes('catalogSources') && !storyRuntime.includes('loadCatalogScript'));
  record('local: eight fixed launch links and onsite sharing are defined', campaignDefinitions.length === 8 && campaignDefinitions.every((item) => item.id && item.url && requiredCampaigns.has(item.id) && launchKit.includes(item.url)) && campaigns.onsiteShare?.id === 'onsite-share', campaignDefinitions);
  record('local: curated landing campaign codes exist only in the registered runtime map', analyticsRuntime.includes('launch-20260724-x-five-minute') && analyticsRuntime.includes('launch-20260724-threads-five-minute') && analyticsRuntime.includes('launch-20260724-x-bedtime') && analyticsRuntime.includes('launch-20260724-threads-bedtime'));
  record('local: unknown UTM values are not converted into campaign paths', analyticsRuntime.includes('knownCampaigns.get') && engagementRuntime.includes('knownCampaigns.get') && !analyticsRuntime.includes("'/yorugatari/__campaign/' + query") && !engagementRuntime.includes("'/yorugatari/__campaign/' + query"));

  const privacy = fs.readFileSync(path.join(SITE, 'privacy.html'), 'utf8');
  record('local: privacy policy explains coarse sources and fixed campaign codes', privacy.includes('粗い区分') && privacy.includes('固定キャンペーンコード') && privacy.includes('登録済みコードに一致しない値は破棄') && privacy.includes('参照元URL') && privacy.includes('検索語'));

  const notFound = fs.readFileSync(path.join(ROOT, '404.html'), 'utf8');
  record('local: custom 404 is noindex and recoverable', notFound.includes('noindex,follow') && notFound.includes('data-page-type="404"') && notFound.includes('/yorugatari/archive.html') && notFound.includes(`/yorugatari/assets/analytics.js?v=${ANALYTICS_VERSION}`));
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
      alt: get('meta[property="og:image:alt"]'),
      card: get('meta[name="twitter:card"]'),
      twitterImage: get('meta[name="twitter:image"]'),
      twitterAlt: get('meta[name="twitter:image:alt"]')
    };
  });
}

function metadataComplete(value) {
  return Boolean(value.type && value.url && value.title && value.description && value.image && value.width === '2172' && value.height === '724' && value.alt && value.card === 'summary_large_image' && value.twitterImage && value.twitterAlt);
}

async function open(page, url, inspect, attempts = 10) {
  let detail = null;
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try {
      const response = await page.goto(`${url}${url.includes('?') ? '&' : '?'}audit=${Date.now()}-${attempt}`, { waitUntil: 'networkidle', timeout: 60000 });
      detail = await inspect(page, response, attempt);
      if (detail.ready) return detail;
    } catch (error) {
      detail = { ready: false, attempt, error: error.message };
    }
    if (attempt < attempts) await new Promise((resolve) => setTimeout(resolve, 4000));
  }
  return detail || { ready: false };
}

async function imageAudit() {
  const response = await fetch(`${BASE}/assets/yorugatari-share.png?audit=${Date.now()}`);
  const buffer = Buffer.from(await response.arrayBuffer());
  const png = buffer.length >= 24 && buffer.toString('ascii', 1, 4) === 'PNG';
  const detail = { status: response.status, bytes: buffer.length, width: png ? buffer.readUInt32BE(16) : 0, height: png ? buffer.readUInt32BE(20) : 0 };
  record('published: social image is exactly 2172 by 724 pixels', response.ok && detail.width === 2172 && detail.height === 724, detail);
}

async function browserAudit() {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true, serviceWorkers: 'block', userAgent: 'Yorugatari-Engagement-Audit/2.3' });
  await context.addInitScript(() => {
    Object.defineProperty(navigator, 'share', { configurable: true, value: async (payload) => { window.__YORUGATARI_SHARE_PAYLOAD__ = payload; } });
  });
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', (error) => errors.push(`pageerror: ${error.message}`));
  page.on('console', (message) => { if (message.type() === 'error') errors.push(`console: ${message.text()}`); });

  const topCampaign = campaigns.definitions.find((item) => item.id === 'launch-20260723-x-top-100');
  const top = await open(page, topCampaign.url, async (target, response, attempt) => {
    const state = await target.evaluate((version) => ({
      analyticsScript: Array.from(document.scripts).some((script) => script.src.includes(`analytics.js?v=${version}`)),
      engagementScript: Array.from(document.scripts).some((script) => script.src.includes('engagement.js')),
      analytics: Boolean(window.YORUGATARI_ANALYTICS),
      source: window.YORUGATARI_ANALYTICS?.source,
      campaign: window.YORUGATARI_ANALYTICS?.campaign,
      panel: Boolean(document.querySelector('#readerPanel'))
    }), ANALYTICS_VERSION);
    const meta = await metadata(target);
    return { ready: response?.status() === 200 && state.analyticsScript && !state.engagementScript && state.analytics && state.source === 'social' && state.campaign === topCampaign.id && state.panel && metadataComplete(meta), status: response?.status(), attempt, state, meta };
  });
  record('published: top launch URL resolves and maps to its fixed social campaign', top.ready, top);

  const fiveMinuteCampaign = campaigns.definitions.find((item) => item.id === 'launch-20260724-x-five-minute');
  const fiveMinute = await open(page, fiveMinuteCampaign.url, async (target, response, attempt) => {
    const state = await target.evaluate((version) => ({
      analyticsScript: Array.from(document.scripts).some((script) => script.src.includes(`analytics.js?v=${version}`)),
      engagementScript: Array.from(document.scripts).some((script) => script.src.includes('engagement.js')),
      analytics: Boolean(window.YORUGATARI_ANALYTICS),
      source: window.YORUGATARI_ANALYTICS?.source,
      campaign: window.YORUGATARI_ANALYTICS?.campaign,
      picks: document.querySelectorAll('.pick').length,
      guides: document.querySelectorAll('.guide-card').length,
      faq: document.querySelectorAll('.faq article').length,
      breadcrumb: document.querySelectorAll('.breadcrumb').length,
      overflow: document.documentElement.scrollWidth <= document.documentElement.clientWidth + 1
    }), FIVE_MINUTE_ANALYTICS_VERSION);
    const meta = await metadata(target);
    return { ready: response?.status() === 200 && state.analyticsScript && !state.engagementScript && state.analytics && state.source === 'social' && state.campaign === fiveMinuteCampaign.id && state.picks === 12 && state.guides === 6 && state.faq === 3 && state.breadcrumb === 1 && state.overflow && metadataComplete(meta), status: response?.status(), attempt, state, meta };
  });
  record('published: five-minute launch URL maps to its fixed social campaign', fiveMinute.ready, fiveMinute);

  const bedtimeCampaign = campaigns.definitions.find((item) => item.id === 'launch-20260724-x-bedtime');
  const bedtime = await open(page, bedtimeCampaign.url, async (target, response, attempt) => {
    const state = await target.evaluate((version) => ({
      analyticsScript: Array.from(document.scripts).some((script) => script.src.includes(`analytics.js?v=${version}`)),
      engagementScript: Array.from(document.scripts).some((script) => script.src.includes('engagement.js')),
      analytics: Boolean(window.YORUGATARI_ANALYTICS),
      source: window.YORUGATARI_ANALYTICS?.source,
      campaign: window.YORUGATARI_ANALYTICS?.campaign,
      picks: document.querySelectorAll('.pick').length,
      moods: document.querySelectorAll('.mood-card').length,
      faq: document.querySelectorAll('.faq article').length,
      breadcrumb: document.querySelectorAll('.breadcrumb').length,
      overflow: document.documentElement.scrollWidth <= document.documentElement.clientWidth + 1
    }), BEDTIME_ANALYTICS_VERSION);
    const meta = await metadata(target);
    return { ready: response?.status() === 200 && state.analyticsScript && !state.engagementScript && state.analytics && state.source === 'social' && state.campaign === bedtimeCampaign.id && state.picks === 8 && state.moods === 4 && state.faq === 3 && state.breadcrumb === 1 && state.overflow && metadataComplete(meta), status: response?.status(), attempt, state, meta };
  });
  record('published: bedtime launch URL maps to its fixed social campaign', bedtime.ready, bedtime);

  const storyCampaign = campaigns.definitions.find((item) => item.id === 'launch-20260723-threads-spare-key');
  const story = await open(page, storyCampaign.url, async (target, response, attempt) => {
    const state = await target.evaluate(({ engagementVersion, storyVersion }) => ({
      engagementScript: Array.from(document.scripts).some((script) => script.src.includes(`engagement.js?v=${engagementVersion}`)),
      storyScript: Array.from(document.scripts).some((script) => script.src.includes(`story.js?v=${storyVersion}`)),
      catalogScripts: Array.from(document.scripts).filter((script) => /\/stories(?:-\d{3}-\d{3})?\.js/.test(script.src)).length,
      engagement: Boolean(window.YORUGATARI_ENGAGEMENT),
      source: window.YORUGATARI_ENGAGEMENT?.source,
      campaign: window.YORUGATARI_ENGAGEMENT?.campaign,
      shareUrl: window.YORUGATARI_ENGAGEMENT?.shareUrl,
      relatedReady: window.YORUGATARI_ENGAGEMENT?.relatedReady,
      share: Boolean(document.querySelector('#shareButton')),
      pagination: document.querySelectorAll('.story-pagination a').length,
      related: document.querySelectorAll('.related a').length
    }), { engagementVersion: ENGAGEMENT_VERSION, storyVersion: STORY_VERSION });
    const meta = await metadata(target);
    return { ready: response?.status() === 200 && state.engagementScript && state.storyScript && state.catalogScripts === 0 && state.engagement && state.source === 'social' && state.campaign === storyCampaign.id && state.relatedReady && state.share && state.pagination === 3 && state.related === 2 && metadataComplete(meta), status: response?.status(), attempt, state, meta };
  });
  record('published: story launch URL maps to its fixed campaign without catalog scripts', story.ready, story);

  try { await page.waitForFunction(() => Number.isFinite(window.YORUGATARI_ENGAGEMENT?.views), null, { timeout: 20000 }); } catch (error) {}
  const views = await page.evaluate(() => ({ value: window.YORUGATARI_ENGAGEMENT?.views, text: document.querySelector('.view-count strong')?.textContent.trim(), error: window.YORUGATARI_ENGAGEMENT?.error, sourceError: window.YORUGATARI_ENGAGEMENT?.sourceError, campaignError: window.YORUGATARI_ENGAGEMENT?.campaignError }));
  record('published: Page Views API count is displayed', Number.isFinite(views.value) && /^\d/.test(views.text || ''), views);

  await page.locator('#shareButton').click();
  const share = await page.evaluate(() => ({ payload: window.__YORUGATARI_SHARE_PAYLOAD__, status: document.querySelector('.share-status')?.textContent.trim() }));
  const expectedShare = new URL(`${BASE}/stories/spare-key-returned.html`);
  expectedShare.searchParams.set('utm_source', 'web_share');
  expectedShare.searchParams.set('utm_medium', 'social');
  expectedShare.searchParams.set('utm_campaign', 'onsite_share');
  record('published: native share receives a canonical-based tracked URL', Boolean(share.payload && share.payload.url === expectedShare.href && String(share.payload.title).includes('合鍵は返却済み') && share.status === '共有画面を開きました。'), share);

  const circulation = await page.evaluate(() => ({ pagination: Array.from(document.querySelectorAll('.story-pagination a')).map((link) => link.textContent.trim()), related: Array.from(document.querySelectorAll('.related a')).map((link) => link.textContent.trim()), archiveLinks: document.querySelectorAll('a[href*="archive.html"]').length }));
  record('published: previous, archive, next, and two related paths exist', circulation.pagination.length === 3 && circulation.related.length === 2 && circulation.archiveLinks >= 1, circulation);

  const unknown = await open(page, `${BASE}/?utm_source=x&utm_medium=social&utm_campaign=unknown&utm_content=unknown`, async (target, response, attempt) => {
    const state = await target.evaluate(() => ({ source: window.YORUGATARI_ANALYTICS?.source, campaign: window.YORUGATARI_ANALYTICS?.campaign }));
    return { ready: response?.status() === 200 && state.source === 'social' && state.campaign === null, status: response?.status(), attempt, state };
  }, 6);
  record('published: unregistered UTM values are discarded', unknown.ready, unknown);

  const policy = await open(page, `${BASE}/privacy.html`, async (target, response, attempt) => {
    const meta = await metadata(target);
    const detail = await target.evaluate((version) => ({
      analytics: Array.from(document.scripts).some((script) => script.src.includes(`analytics.js?v=${version}`)),
      engagement: Array.from(document.scripts).some((script) => script.src.includes('engagement.js')),
      fixedCodes: document.body.textContent.includes('固定キャンペーンコード'),
      unknownDiscarded: document.body.textContent.includes('登録済みコードに一致しない値は破棄')
    }), ANALYTICS_VERSION);
    return { ready: response?.status() === 200 && metadataComplete(meta) && detail.analytics && !detail.engagement && detail.fixedCodes && detail.unknownDiscarded, status: response?.status(), attempt, meta, detail };
  }, 6);
  record('published: privacy policy and lightweight analytics match campaign behavior', policy.ready, policy);
  record('published: normal pages have no JavaScript errors', errors.length === 0, errors.slice());
  errors.length = 0;

  const missing = await open(page, `${BASE}/stories/missing-${Date.now()}.html`, async (target, response, attempt) => {
    const detail = await target.evaluate((version) => ({ noindex: document.querySelector('meta[name="robots"]')?.content, pageType: document.body.dataset.pageType, archive: Boolean(document.querySelector('a[href="/yorugatari/archive.html"]')), top: Boolean(document.querySelector('a[href="/yorugatari/"]')), trackingPath: window.YORUGATARI_ANALYTICS?.trackingPath, analytics: Array.from(document.scripts).some((script) => script.src.includes(`analytics.js?v=${version}`)), engagement: Array.from(document.scripts).some((script) => script.src.includes('engagement.js')) }), ANALYTICS_VERSION);
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
  try { await browserAudit(); } catch (error) { record('audit completed without exception', false, { message: error.message, stack: error.stack }); }
  const report = { auditedAt: new Date().toISOString(), success: failures.length === 0, results, failures };
  fs.writeFileSync('yorugatari-engagement-report.json', `${JSON.stringify(report, null, 2)}\n`);
  console.log(`YORUGATARI_ENGAGEMENT_REPORT=${JSON.stringify(report)}`);
  if (failures.length) process.exit(1);
})();
