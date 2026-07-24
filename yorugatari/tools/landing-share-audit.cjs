const fs = require('node:fs');
const { chromium } = require('playwright');

const base = 'https://allsunday1122.github.io/yorugatari';
const shareVersion = '20260724-002';
const startVersion = '20260724-001';
const startRuntime = 'landing-start-20260724-001.js';
const cases = [
  { name: 'five-minute', path: '/5min-horror.html', canonical: `${base}/5min-horror.html`, content: 'five_minute_12', picks: 12, startPath: '/yorugatari/__landing-start/five-minute' },
  { name: 'bedtime', path: '/bedtime-horror.html', canonical: `${base}/bedtime-horror.html`, content: 'bedtime_8', picks: 8, startPath: '/yorugatari/__landing-start/bedtime' }
];
const results = [];
const failures = [];
const sleep = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

function record(name, ok, detail = null) {
  const item = { name, ok: Boolean(ok), detail };
  results.push(item);
  if (!item.ok) failures.push(item);
}

async function openReady(page, currentCase) {
  let detail = null;
  for (let attempt = 1; attempt <= 24; attempt += 1) {
    try {
      const response = await page.goto(`${base}${currentCase.path}?share-audit=${Date.now()}-${attempt}`, { waitUntil: 'networkidle', timeout: 60000 });
      detail = await page.evaluate(({ expectedShareVersion, expectedStartRuntime, expectedPicks }) => ({
        status: document.readyState,
        shareScript: Array.from(document.scripts).some((script) => script.src.includes(`assets/landing-share.js?v=${expectedShareVersion}`)),
        startScript: Array.from(document.scripts).some((script) => script.src.includes(`assets/${expectedStartRuntime}`)),
        shareButton: Boolean(document.querySelector('#landingShareButton')),
        copyButton: Boolean(document.querySelector('#landingCopyButton')),
        statusRegion: document.querySelector('#landingShareStatus')?.getAttribute('aria-live'),
        shareState: Boolean(window.YORUGATARI_LANDING_SHARE),
        startState: Boolean(window.YORUGATARI_LANDING_START),
        heroStoryLink: Boolean(document.querySelector('.story-hero .hero-actions a[href^="stories/"]')),
        picks: document.querySelectorAll('.pick').length,
        overflow: document.documentElement.scrollWidth <= document.documentElement.clientWidth + 1
      }), { expectedShareVersion: shareVersion, expectedStartRuntime: startRuntime, expectedPicks: currentCase.picks });
      detail.httpStatus = response?.status();
      detail.attempt = attempt;
      if (response?.status() === 200 && detail.shareScript && detail.startScript && detail.shareButton && detail.copyButton && detail.statusRegion === 'polite' && detail.shareState && detail.startState && detail.heroStoryLink && detail.picks === currentCase.picks && detail.overflow) return detail;
    } catch (error) {
      detail = { attempt, error: error.message };
    }
    if (attempt < 24) await sleep(5000);
  }
  return detail;
}

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true, userAgent: 'Yorugatari-Landing-Share-Audit/1.5' });
  const trackedPaths = [];
  await context.route('https://page-views-api.ratneshc.com/**', async (route) => {
    try {
      const value = new URL(route.request().url()).searchParams.get('path');
      if (value) trackedPaths.push(value);
    } catch (error) {}
    await route.fulfill({ status: 200, contentType: 'application/json', body: '{"views":1}' });
  });
  await context.addInitScript(() => {
    window.__YORUGATARI_ALLOW_TRACKING_TEST__ = true;
    window.__LANDING_SHARE_PAYLOAD__ = null;
    window.__LANDING_COPIED_URL__ = null;
    Object.defineProperty(navigator, 'share', {
      configurable: true,
      value: async (payload) => { window.__LANDING_SHARE_PAYLOAD__ = payload; }
    });
    Object.defineProperty(navigator, 'clipboard', {
      configurable: true,
      value: { writeText: async (value) => { window.__LANDING_COPIED_URL__ = value; } }
    });
  });
  const page = await context.newPage();
  const browserErrors = [];
  const networkDiagnostics = [];
  page.on('pageerror', (error) => browserErrors.push(`pageerror: ${error.message}`));
  page.on('console', (message) => {
    if (message.type() !== 'error') return;
    const text = message.text();
    if (/^Failed to load resource:\s+net::/i.test(text)) networkDiagnostics.push(`console: ${text}`);
    else browserErrors.push(`console: ${text}`);
  });

  try {
    for (const currentCase of cases) {
      const ready = await openReady(page, currentCase);
      record(`${currentCase.name}: published sharing and start controls are ready`, Boolean(ready?.shareScript && ready?.startScript && ready?.shareState && ready?.startState && ready?.heroStoryLink && ready?.overflow), ready);
      if (!ready?.shareScript || !ready?.startScript) continue;

      const shareState = await page.evaluate(() => window.YORUGATARI_LANDING_SHARE);
      const url = new URL(shareState.url);
      record(`${currentCase.name}: canonical tracked share URL is privacy-safe`,
        url.origin + url.pathname === currentCase.canonical &&
        url.searchParams.get('utm_source') === 'web_share' &&
        url.searchParams.get('utm_medium') === 'social' &&
        url.searchParams.get('utm_campaign') === 'onsite_share' &&
        url.searchParams.get('utm_content') === currentCase.content,
        shareState);

      await page.locator('#landingShareButton').click();
      const shared = await page.evaluate(() => ({ payload: window.__LANDING_SHARE_PAYLOAD__, status: document.querySelector('#landingShareStatus')?.textContent.trim(), action: window.YORUGATARI_LANDING_SHARE?.lastAction }));
      record(`${currentCase.name}: native share receives the tracked URL`, Boolean(shared.payload && shared.payload.url === shareState.url && shared.status === '共有画面を開きました。' && shared.action === 'share'), shared);

      await page.locator('#landingCopyButton').click();
      const copied = await page.evaluate(() => ({ url: window.__LANDING_COPIED_URL__, status: document.querySelector('#landingShareStatus')?.textContent.trim(), action: window.YORUGATARI_LANDING_SHARE?.lastAction }));
      record(`${currentCase.name}: copy button copies the same tracked URL`, copied.url === shareState.url && copied.status === '共有用リンクをコピーしました。' && copied.action === 'copy', copied);

      const beforeCount = trackedPaths.filter((value) => value === currentCase.startPath).length;
      const heroLink = page.locator('.story-hero .hero-actions a[href^="stories/"]').first();
      await heroLink.evaluate((link) => link.addEventListener('click', (event) => event.preventDefault()));
      await heroLink.click();
      await page.waitForTimeout(250);

      const pickLink = page.locator('.pick').nth(1);
      await pickLink.evaluate((link) => link.addEventListener('click', (event) => event.preventDefault()));
      await pickLink.click();
      await page.waitForTimeout(250);

      const afterCount = trackedPaths.filter((value) => value === currentCase.startPath).length;
      const startState = await page.evaluate(() => window.YORUGATARI_LANDING_START);
      const startPaths = trackedPaths.filter((value) => value.startsWith('/yorugatari/__landing-start/'));
      const leakedStoryPath = startPaths.some((value) => value.includes('/stories/'));
      record(`${currentCase.name}: hero and card starts are counted once per session without a story identifier`,
        afterCount - beforeCount === 1 &&
        startPaths.filter((value) => value === currentCase.startPath).length >= 1 &&
        !leakedStoryPath &&
        startState?.version === startVersion &&
        startState?.path === currentCase.startPath &&
        startState?.attempted &&
        startState?.tracked &&
        !startState?.inFlight &&
        !startState?.error,
        { beforeCount, afterCount, startPaths, leakedStoryPath, startState });
    }
    record('landing sharing: no page JavaScript exceptions', browserErrors.length === 0, browserErrors);
    record('landing sharing: network diagnostics are non-blocking', true, networkDiagnostics);
  } catch (error) {
    record('landing sharing audit completed without exception', false, { message: error.message, stack: error.stack });
  } finally {
    await context.close();
    await browser.close();
  }

  const report = { auditedAt: new Date().toISOString(), success: failures.length === 0, shareVersion, startVersion, startRuntime, results, failures };
  fs.writeFileSync('yorugatari-landing-share-report.json', `${JSON.stringify(report, null, 2)}\n`);
  console.log(`YORUGATARI_LANDING_SHARE_REPORT=${JSON.stringify(report)}`);
  if (failures.length) process.exit(1);
})();
