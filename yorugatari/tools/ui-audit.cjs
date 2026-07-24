const fs = require('node:fs');
const { chromium } = require('playwright');

const base = 'https://allsunday1122.github.io/yorugatari';
const fiveMinuteAnalyticsVersion = '20260724-004';
const bedtimeAnalyticsVersion = '20260724-005';
const results = [];
const failures = [];

function record(name, ok, detail = null) {
  results.push({ name, ok: Boolean(ok), detail });
  if (!ok) failures.push({ name, detail });
}

async function noHorizontalOverflow(page, name) {
  const values = await page.evaluate(() => ({ scrollWidth: document.documentElement.scrollWidth, clientWidth: document.documentElement.clientWidth }));
  record(name, values.scrollWidth <= values.clientWidth + 1, values);
}

async function waitForTopCards(page) {
  await page.waitForFunction(() => document.querySelector('#storyGrid')?.getAttribute('aria-busy') === 'false' && document.querySelectorAll('.card').length === 100, null, { timeout: 30000 });
}

async function run() {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true, userAgent: 'Yorugatari-UI-Audit/1.5' });
  const page = await context.newPage();
  const browserErrors = [];
  page.on('pageerror', (error) => browserErrors.push(`pageerror: ${error.message}`));
  page.on('console', (message) => { if (message.type() === 'error') browserErrors.push(`console: ${message.text()}`); });

  await page.addInitScript(() => {
    localStorage.setItem('yorugatari-completed-stories', JSON.stringify(['last-elevator']));
    localStorage.setItem('yorugatari-favorites', JSON.stringify(['neighbor-wifi']));
  });

  await page.goto(`${base}/?ui=${Date.now()}`, { waitUntil: 'networkidle' });
  await waitForTopCards(page);
  const topState = await page.evaluate(() => ({
    cards: document.querySelectorAll('.card').length,
    unique: new Set(Array.from(document.querySelectorAll('.card')).map((card) => card.getAttribute('href'))).size,
    busy: document.querySelector('#storyGrid')?.getAttribute('aria-busy'),
    version: Array.from(document.scripts).some((script) => script.src.includes('assets/app.js?v=20260723-008')),
    fiveMinuteLinks: document.querySelectorAll('a[href="5min-horror.html"]').length,
    bedtimeLinks: document.querySelectorAll('a[href="bedtime-horror.html"]').length
  }));
  record('top progressively renders 100 unique cards', topState.cards === 100 && topState.unique === 100 && topState.busy === 'false' && topState.version, topState);
  record('top exposes both curated horror landings', topState.fiveMinuteLinks >= 2 && topState.bedtimeLinks >= 2, topState);
  await noHorizontalOverflow(page, 'top mobile has no horizontal overflow');
  record('reader panel shows saved completion', (await page.locator('.reader-panel').innerText()).includes('1 / 100話 読了'));

  await page.locator('#searchInput').fill('最後のエレベーター');
  const searchCards = page.locator('.card');
  record('search narrows to matching story', await searchCards.count() === 1 && (await searchCards.first().innerText()).includes('最後のエレベーター'), await searchCards.count());

  await page.locator('#searchInput').fill('');
  await page.getByRole('button', { name: '心霊', exact: true }).click();
  const categoryCards = page.locator('.card');
  const categoryCount = await categoryCards.count();
  const categories = await categoryCards.locator('.badge').allTextContents();
  record('category filter shows only selected category', categoryCount > 0 && categories.every((value) => value === '心霊'), { categoryCount, categories: [...new Set(categories)] });

  await page.getByRole('button', { name: 'すべて', exact: true }).first().click();
  await page.getByRole('button', { name: '読了済み', exact: true }).click();
  const completedCards = page.locator('.card');
  record('completed filter uses local storage', await completedCards.count() === 1 && (await completedCards.first().getAttribute('href')).includes('last-elevator'), await completedCards.count());

  await page.getByRole('button', { name: 'お気に入り', exact: true }).click();
  const favoriteCards = page.locator('.card');
  record('favorite filter uses local storage', await favoriteCards.count() === 1 && (await favoriteCards.first().getAttribute('href')).includes('neighbor-wifi'), await favoriteCards.count());

  const randomContext = await browser.newContext({ viewport: { width: 390, height: 844 } });
  await randomContext.addInitScript(() => { Math.random = () => 0; });
  const randomPage = await randomContext.newPage();
  await randomPage.goto(`${base}/?random=${Date.now()}`, { waitUntil: 'networkidle' });
  await Promise.all([randomPage.waitForURL(/stories\/last-elevator\.html/), randomPage.locator('#randomBtn').click()]);
  record('random button navigates to a story', /stories\/last-elevator\.html/.test(randomPage.url()), randomPage.url());
  await randomContext.close();

  await page.goto(`${base}/archive.html?ui=${Date.now()}`, { waitUntil: 'networkidle' });
  await page.waitForSelector('.archive-item');
  const archiveCount = await page.locator('.archive-item').count();
  const archiveLandings = {
    fiveMinute: await page.locator('a[href="5min-horror.html"]').count(),
    bedtime: await page.locator('a[href="bedtime-horror.html"]').count()
  };
  record('archive renders 100 unique items', archiveCount === 100, archiveCount);
  record('archive exposes both curated horror landings', archiveLandings.fiveMinute >= 1 && archiveLandings.bedtime >= 1, archiveLandings);
  await noHorizontalOverflow(page, 'archive mobile has no horizontal overflow');
  await page.getByRole('button', { name: 'お気に入り', exact: true }).click();
  record('archive favorite filter works', await page.locator('.archive-item').count() === 1 && (await page.locator('.archive-item').first().getAttribute('href')).includes('neighbor-wifi'), await page.locator('.archive-item').count());

  await page.goto(`${base}/5min-horror.html?ui=${Date.now()}`, { waitUntil: 'networkidle' });
  await page.waitForSelector('.pick');
  const fiveMinute = await page.evaluate((version) => {
    const picks = Array.from(document.querySelectorAll('.pick'));
    return {
      picks: picks.length,
      uniquePicks: new Set(picks.map((item) => item.getAttribute('href'))).size,
      guides: document.querySelectorAll('.guide-card').length,
      faq: document.querySelectorAll('.faq article').length,
      h1: document.querySelectorAll('h1').length,
      breadcrumb: document.querySelectorAll('.breadcrumb').length,
      canonical: document.querySelector('link[rel="canonical"]')?.href,
      analytics: Array.from(document.scripts).some((script) => script.src.includes(`assets/analytics.js?v=${version}`)),
      engagement: Array.from(document.scripts).some((script) => script.src.includes('assets/engagement.js')),
      bedtimeLinks: document.querySelectorAll('a[href="bedtime-horror.html"]').length
    };
  }, fiveMinuteAnalyticsVersion);
  record('five-minute landing renders 12 unique editorial picks', fiveMinute.picks === 12 && fiveMinute.uniquePicks === 12, fiveMinute);
  record('five-minute landing renders six genre guides and three FAQ items', fiveMinute.guides === 6 && fiveMinute.faq === 3, fiveMinute);
  record('five-minute landing has canonical metadata and lightweight analytics', fiveMinute.h1 === 1 && fiveMinute.breadcrumb === 1 && fiveMinute.canonical === `${base}/5min-horror.html` && fiveMinute.analytics && !fiveMinute.engagement, fiveMinute);
  record('five-minute landing links to bedtime selection', fiveMinute.bedtimeLinks >= 1, fiveMinute.bedtimeLinks);
  await noHorizontalOverflow(page, 'five-minute landing mobile has no horizontal overflow');

  await page.goto(`${base}/bedtime-horror.html?ui=${Date.now()}`, { waitUntil: 'networkidle' });
  await page.waitForSelector('.pick');
  const bedtime = await page.evaluate((version) => {
    const picks = Array.from(document.querySelectorAll('.pick'));
    return {
      picks: picks.length,
      uniquePicks: new Set(picks.map((item) => item.getAttribute('href'))).size,
      moods: document.querySelectorAll('.mood-card').length,
      faq: document.querySelectorAll('.faq article').length,
      h1: document.querySelectorAll('h1').length,
      breadcrumb: document.querySelectorAll('.breadcrumb').length,
      canonical: document.querySelector('link[rel="canonical"]')?.href,
      analytics: Array.from(document.scripts).some((script) => script.src.includes(`assets/analytics.js?v=${version}`)),
      engagement: Array.from(document.scripts).some((script) => script.src.includes('assets/engagement.js')),
      fiveMinuteLinks: document.querySelectorAll('a[href="5min-horror.html"]').length
    };
  }, bedtimeAnalyticsVersion);
  record('bedtime landing renders eight unique editorial picks', bedtime.picks === 8 && bedtime.uniquePicks === 8, bedtime);
  record('bedtime landing renders four mood guides and three FAQ items', bedtime.moods === 4 && bedtime.faq === 3, bedtime);
  record('bedtime landing has canonical metadata and lightweight analytics', bedtime.h1 === 1 && bedtime.breadcrumb === 1 && bedtime.canonical === `${base}/bedtime-horror.html` && bedtime.analytics && !bedtime.engagement, bedtime);
  record('bedtime landing links to five-minute selection', bedtime.fiveMinuteLinks >= 1, bedtime.fiveMinuteLinks);
  await noHorizontalOverflow(page, 'bedtime landing mobile has no horizontal overflow');

  await page.goto(`${base}/stories/spare-key-returned.html?ui=${Date.now()}`, { waitUntil: 'networkidle' });
  await page.waitForSelector('.story-pagination');
  await noHorizontalOverflow(page, 'story mobile has no horizontal overflow');
  record('story pagination has previous archive and next links', await page.locator('.story-pagination a').count() === 3, await page.locator('.story-pagination a').allTextContents());
  record('story static breadcrumb visible', await page.locator('.breadcrumb').count() === 1, await page.locator('.breadcrumb').allTextContents());

  const explainButton = page.locator('#explainBtn');
  record('explanation control is available', await explainButton.isVisible());
  await explainButton.click();
  record('explanation opens and updates state', await page.locator('#explanation').isVisible() && await explainButton.getAttribute('aria-expanded') === 'true');

  const favoriteButton = page.locator('#favoriteBtn');
  await favoriteButton.click();
  const favoriteState = await page.evaluate(() => JSON.parse(localStorage.getItem('yorugatari-favorites') || '[]'));
  record('story favorite button persists state', favoriteState.includes('spare-key-returned') && await favoriteButton.getAttribute('aria-pressed') === 'true', favoriteState);

  const completedButton = page.locator('.completed-toggle');
  await completedButton.click();
  const completedState = await page.evaluate(() => JSON.parse(localStorage.getItem('yorugatari-completed-stories') || '[]'));
  record('story completed button persists state', completedState.includes('spare-key-returned') && await completedButton.getAttribute('aria-pressed') === 'true', completedState);

  const readingContext = await browser.newContext({ viewport: { width: 390, height: 844 } });
  await readingContext.addInitScript(() => {
    localStorage.setItem('yorugatari-completed-stories', '[]');
    localStorage.removeItem('yorugatari-last-reading');
  });
  const readingPage = await readingContext.newPage();
  await readingPage.goto(`${base}/stories/spare-key-returned.html?reading=${Date.now()}`, { waitUntil: 'networkidle' });
  await readingPage.evaluate(() => {
    document.documentElement.style.scrollBehavior = 'auto';
    const max = document.documentElement.scrollHeight - document.documentElement.clientHeight;
    window.scrollTo(0, Math.floor(max * 0.55));
  });
  await readingPage.waitForTimeout(1200);
  await readingPage.evaluate(() => window.dispatchEvent(new Event('scroll')));
  await readingPage.waitForTimeout(300);
  const readingState = await readingPage.evaluate(() => JSON.parse(localStorage.getItem('yorugatari-last-reading') || 'null'));
  record('reading position is saved', Boolean(readingState && readingState.slug === 'spare-key-returned' && readingState.progress > 0), readingState);
  await readingContext.close();

  await page.setViewportSize({ width: 1440, height: 900 });
  await page.reload({ waitUntil: 'networkidle' });
  const desktopLayout = await page.evaluate(() => {
    const shell = document.querySelector('.story-shell');
    const style = getComputedStyle(shell);
    return { display: style.display, columns: style.gridTemplateColumns, scrollWidth: document.documentElement.scrollWidth, clientWidth: document.documentElement.clientWidth };
  });
  record('story desktop keeps two-column layout without overflow', desktopLayout.display === 'grid' && desktopLayout.columns.split(' ').length >= 2 && desktopLayout.scrollWidth <= desktopLayout.clientWidth + 1, desktopLayout);

  record('no browser JavaScript errors', browserErrors.length === 0, browserErrors);
  await context.close();
  await browser.close();
}

(async () => {
  try { await run(); } catch (error) { failures.push({ name: 'audit execution', detail: error.stack || String(error) }); }
  const report = { auditedAt: new Date().toISOString(), success: failures.length === 0, results, failures };
  fs.writeFileSync('yorugatari-ui-report.json', `${JSON.stringify(report, null, 2)}\n`);
  console.log(`YORUGATARI_UI_REPORT=${JSON.stringify(report)}`);
  if (failures.length) process.exit(1);
})();
