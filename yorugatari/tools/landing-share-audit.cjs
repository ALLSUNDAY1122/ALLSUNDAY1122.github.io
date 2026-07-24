const fs = require('node:fs');
const { chromium } = require('playwright');

const base = 'https://allsunday1122.github.io/yorugatari';
const version = '20260724-002';
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
      detail = await page.evaluate(({ expectedVersion, expectedPicks }) => ({
        status: document.readyState,
        script: Array.from(document.scripts).some((script) => script.src.includes(`assets/landing-share.js?v=${expectedVersion}`)),
        shareButton: Boolean(document.querySelector('#landingShareButton')),
        copyButton: Boolean(document.querySelector('#landingCopyButton')),
        statusRegion: document.querySelector('#landingShareStatus')?.getAttribute('aria-live'),
        state: Boolean(window.YORUGATARI_LANDING_SHARE),
        picks: document.querySelectorAll('.pick').length,
        overflow: document.documentElement.scrollWidth <= document.documentElement.clientWidth + 1
      }), { expectedVersion: version, expectedPicks: currentCase.picks });
      detail.httpStatus = response?.status();
      detail.attempt = attempt;
      if (response?.status() === 200 && detail.script && detail.shareButton && detail.copyButton && detail.statusRegion === 'polite' && detail.state && detail.picks === currentCase.picks && detail.overflow) return detail;
    } catch (error) {
      detail = { attempt, error: error.message };
    }
    if (attempt < 24) await sleep(5000);
  }
  return detail;
}

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true, userAgent: 'Yorugatari-Landing-Share-Audit/1.1' });
  const trackedPaths = [];
  await context.route('https://page-views-api.ratneshc.com/**', async (route) => {
    try {
      const value = new URL(route.request().url()).searchParams.get('path');
      if (value) trackedPaths.push(value);
    } catch (error) {}
    await route.fulfill({ status: 200, contentType: 'application/json', body: '{"views":1}' });
  });
  await context.addInitScript(() => {
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
  page.on('pageerror', (error) => browserErrors.push(`pageerror: ${error.message}`));
  page.on('console', (message) => { if (message.type() === 'error') browserErrors.push(`console: ${message.text()}`); });

  try {
    for (const currentCase of cases) {
      const ready = await openReady(page, currentCase);
      record(`${currentCase.name}: published sharing controls are ready`, Boolean(ready?.script && ready?.state && ready?.overflow), ready);
      if (!ready?.script) continue;

      const state = await page.evaluate(() => window.YORUGATARI_LANDING_SHARE);
      const url = new URL(state.url);
      record(`${currentCase.name}: canonical tracked share URL is privacy-safe`,
        url.origin + url.pathname === currentCase.canonical &&
        url.searchParams.get('utm_source') === 'web_share' &&
        url.searchParams.get('utm_medium') === 'social' &&
        url.searchParams.get('utm_campaign') === 'onsite_share' &&
        url.searchParams.get('utm_content') === currentCase.content,
        state);

      await page.locator('#landingShareButton').click();
      const shared = await page.evaluate(() => ({ payload: window.__LANDING_SHARE_PAYLOAD__, status: document.querySelector('#landingShareStatus')?.textContent.trim(), action: window.YORUGATARI_LANDING_SHARE?.lastAction }));
      record(`${currentCase.name}: native share receives the tracked URL`, Boolean(shared.payload && shared.payload.url === state.url && shared.status === '共有画面を開きました。' && shared.action === 'share'), shared);

      await page.locator('#landingCopyButton').click();
      const copied = await page.evaluate(() => ({ url: window.__LANDING_COPIED_URL__, status: document.querySelector('#landingShareStatus')?.textContent.trim(), action: window.YORUGATARI_LANDING_SHARE?.lastAction }));
      record(`${currentCase.name}: copy button copies the same tracked URL`, copied.url === state.url && copied.status === '共有用リンクをコピーしました。' && copied.action === 'copy', copied);

      const beforeCount = trackedPaths.filter((value) => value === currentCase.startPath).length;
      await page.locator('.pick').first().evaluate((link) => link.addEventListener('click', (event) => event.preventDefault()));
      await page.locator('.pick').first().click();
      await page.waitForTimeout(250);
      await page.locator('.pick').nth(1).evaluate((link) => link.addEventListener('click', (event) => event.preventDefault()));
      await page.locator('.pick').nth(1).click();
      await page.waitForTimeout(250);
      const afterCount = trackedPaths.filter((value) => value === currentCase.startPath).length;
      const startState = await page.evaluate(() => ({ path: window.YORUGATARI_LANDING_SHARE?.storyStartPath, attempted: window.YORUGATARI_LANDING_SHARE?.storyStartAttempted, tracked: window.YORUGATARI_LANDING_SHARE?.storyStartTracked, error: window.YORUGATARI_LANDING_SHARE?.storyStartError }));
      record(`${currentCase.name}: story start is sent once per session without a story identifier`, afterCount - beforeCount === 1 && startState.path === currentCase.startPath && startState.attempted && startState.tracked && !startState.error, { beforeCount, afterCount, startState });
    }
    record('landing sharing: no browser JavaScript errors', browserErrors.length === 0, browserErrors);
  } catch (error) {
    record('landing sharing audit completed without exception', false, { message: error.message, stack: error.stack });
  } finally {
    await context.close();
    await browser.close();
  }

  const report = { auditedAt: new Date().toISOString(), success: failures.length === 0, version, results, failures };
  fs.writeFileSync('yorugatari-landing-share-report.json', `${JSON.stringify(report, null, 2)}\n`);
  console.log(`YORUGATARI_LANDING_SHARE_REPORT=${JSON.stringify(report)}`);
  if (failures.length) process.exit(1);
})();
