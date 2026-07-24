const fs = require('node:fs');
const { chromium } = require('playwright');
const { AxeBuilder } = require('@axe-core/playwright');

const base = 'https://allsunday1122.github.io/yorugatari';
const url = `${base}/horror-quiz.html`;
const version = '20260724-001';
const results = [];
const failures = [];
const browserErrors = [];
const sleep = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

function record(name, ok, detail = null) {
  const row = { name, ok: Boolean(ok), detail };
  results.push(row);
  if (!row.ok) failures.push(row);
}

async function waitForRelease(page) {
  let detail = null;
  for (let attempt = 1; attempt <= 24; attempt += 1) {
    try {
      const response = await page.goto(`${url}?quiz-audit=${Date.now()}-${attempt}`, { waitUntil: 'networkidle', timeout: 60000 });
      detail = await page.evaluate((expectedVersion) => ({
        httpStatus: null,
        title: document.title,
        canonical: document.querySelector('link[rel="canonical"]')?.href,
        h1: document.querySelectorAll('h1').length,
        fieldsets: document.querySelectorAll('fieldset').length,
        radios: document.querySelectorAll('input[type="radio"]').length,
        requiredRadios: document.querySelectorAll('input[type="radio"][required]').length,
        quizRuntime: Array.from(document.scripts).some((script) => script.src.includes(`assets/horror-quiz.js?v=${expectedVersion}`)),
        analytics: Array.from(document.scripts).some((script) => script.src.includes('assets/analytics.js?v=20260723-003')),
        engagement: Array.from(document.scripts).some((script) => script.src.includes('assets/engagement.js')),
        resultHidden: document.querySelector('#quizResult')?.hidden === true,
        faqItems: document.querySelectorAll('.quiz-faq article').length,
        jsonLdBlocks: document.querySelectorAll('script[type="application/ld+json"]').length,
        overflow: document.documentElement.scrollWidth <= document.documentElement.clientWidth + 1
      }), version);
      detail.httpStatus = response?.status();
      detail.attempt = attempt;
      if (detail.httpStatus === 200 && detail.quizRuntime && detail.analytics && !detail.engagement && detail.fieldsets === 3 && detail.radios === 11 && detail.requiredRadios === 11 && detail.resultHidden && detail.faqItems === 3 && detail.overflow) return detail;
    } catch (error) {
      detail = { attempt, error: error.message };
    }
    if (attempt < 24) await sleep(5000);
  }
  return detail;
}

const cases = [
  { type: 'quiet', scene: 'quiet', ending: 'linger', intensity: 'low' },
  { type: 'human', scene: 'human', ending: 'real', intensity: 'high' },
  { type: 'digital', scene: 'digital', ending: 'twist', intensity: 'medium' },
  { type: 'rules', scene: 'rules', ending: 'ritual', intensity: 'high' }
];

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true, userAgent: 'Yorugatari-Horror-Quiz-Audit/1.0' });
  await context.addInitScript(() => {
    window.__QUIZ_SHARE__ = null;
    window.__QUIZ_COPY__ = null;
    Object.defineProperty(navigator, 'share', { configurable: true, value: async (payload) => { window.__QUIZ_SHARE__ = payload; } });
    Object.defineProperty(navigator, 'clipboard', { configurable: true, value: { writeText: async (value) => { window.__QUIZ_COPY__ = value; } } });
  });
  const page = await context.newPage();
  page.on('pageerror', (error) => browserErrors.push(`pageerror: ${error.message}`));
  page.on('console', (message) => { if (message.type() === 'error') browserErrors.push(`console: ${message.text()}`); });

  try {
    const ready = await waitForRelease(page);
    record('published quiz release is ready', Boolean(ready?.quizRuntime && ready?.overflow), ready);
    if (!ready?.quizRuntime) throw new Error('Published quiz runtime was not detected');

    record('quiz metadata and structure are complete', ready.title === 'あなたに合う怖い話診断｜3問でおすすめ短編3選｜夜語り' && ready.canonical === url && ready.h1 === 1 && ready.jsonLdBlocks === 3, ready);

    const allStoryUrls = new Set();
    for (const currentCase of cases) {
      await page.locator(`input[name="scene"][value="${currentCase.scene}"]`).check();
      await page.locator(`input[name="ending"][value="${currentCase.ending}"]`).check();
      await page.locator(`input[name="intensity"][value="${currentCase.intensity}"]`).check();
      await page.locator('#horrorQuiz button[type="submit"]').click();
      const state = await page.evaluate(() => ({
        hidden: document.querySelector('#quizResult')?.hidden,
        type: document.querySelector('#quizResult')?.dataset.type,
        title: document.querySelector('#quizResultTitle')?.textContent.trim(),
        links: Array.from(document.querySelectorAll('#quizResultStories a')).map((anchor) => anchor.href),
        status: document.querySelector('#quizStatus')?.textContent.trim(),
        focused: document.activeElement?.id
      }));
      state.links.forEach((storyUrl) => allStoryUrls.add(storyUrl));
      record(`${currentCase.type}: expected result and three stories`, state.hidden === false && state.type === currentCase.type && state.links.length === 3 && new Set(state.links).size === 3 && state.status.includes('おすすめ3作品') && state.focused === 'quizResultTitle', state);
      await page.locator('#quizRestart').click();
      const reset = await page.evaluate(() => ({ hidden: document.querySelector('#quizResult')?.hidden, checked: document.querySelectorAll('input:checked').length }));
      record(`${currentCase.type}: restart clears answers`, reset.hidden === true && reset.checked === 0, reset);
    }

    record('quiz recommends twelve unique stories across four types', allStoryUrls.size === 12, Array.from(allStoryUrls));
    const linkChecks = [];
    for (const storyUrl of allStoryUrls) {
      const response = await context.request.get(`${storyUrl}?quiz-link-audit=${Date.now()}`, { timeout: 30000 });
      linkChecks.push({ url: storyUrl, status: response.status() });
    }
    record('all recommended story links return HTTP 200', linkChecks.every((row) => row.status === 200), linkChecks);

    await page.locator('input[name="scene"][value="quiet"]').check();
    await page.locator('input[name="ending"][value="linger"]').check();
    await page.locator('input[name="intensity"][value="low"]').check();
    await page.locator('#horrorQuiz button[type="submit"]').click();
    await page.locator('#quizShare').click();
    await page.locator('#quizCopy').click();
    const sharing = await page.evaluate(() => ({ share: window.__QUIZ_SHARE__, copy: window.__QUIZ_COPY__, status: document.querySelector('#quizStatus')?.textContent.trim() }));
    const sharedUrl = new URL(sharing.share?.url || 'https://invalid.invalid/');
    record('quiz sharing uses registered privacy-safe tracking',
      sharedUrl.origin + sharedUrl.pathname === url &&
      sharedUrl.searchParams.get('utm_source') === 'web_share' &&
      sharedUrl.searchParams.get('utm_medium') === 'social' &&
      sharedUrl.searchParams.get('utm_campaign') === 'onsite_share' &&
      sharedUrl.searchParams.get('utm_content') === 'horror_quiz' &&
      !sharedUrl.search.includes('quiet') &&
      typeof sharing.copy === 'string' && sharing.copy.includes(sharedUrl.href), sharing);

    const axe = await new AxeBuilder({ page }).analyze();
    const serious = axe.violations.filter((violation) => violation.impact === 'critical' || violation.impact === 'serious');
    record('quiz has no critical or serious axe violations', serious.length === 0, serious.map((violation) => ({ id: violation.id, impact: violation.impact, nodes: violation.nodes.length })));
    const finalLayout = await page.evaluate(() => ({ overflow: document.documentElement.scrollWidth <= document.documentElement.clientWidth + 1, resultLinks: document.querySelectorAll('#quizResultStories a').length }));
    record('quiz remains usable without mobile horizontal overflow', finalLayout.overflow && finalLayout.resultLinks === 3, finalLayout);
    record('quiz has no browser JavaScript errors', browserErrors.length === 0, browserErrors);
  } catch (error) {
    record('horror quiz audit completed without exception', false, { message: error.message, stack: error.stack });
  } finally {
    await context.close();
    await browser.close();
  }

  const report = { auditedAt: new Date().toISOString(), success: failures.length === 0, version, results, failures };
  fs.writeFileSync('yorugatari-horror-quiz-report.json', `${JSON.stringify(report, null, 2)}\n`);
  console.log(`YORUGATARI_HORROR_QUIZ_REPORT=${JSON.stringify(report)}`);
  if (failures.length) process.exit(1);
})();
