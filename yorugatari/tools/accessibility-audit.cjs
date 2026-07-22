const fs = require('node:fs');
const { chromium } = require('playwright');
const AxeBuilder = require('@axe-core/playwright').default;

const base = 'https://allsunday1122.github.io/yorugatari';
const results = [];
const failures = [];
const sleep = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

function record(name, ok, detail = null) {
  const item = { name, ok: Boolean(ok), detail };
  results.push(item);
  if (!item.ok) failures.push(item);
}

async function open(page, pathname, ready, name, attempts = 10) {
  let detail = null;
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try {
      await page.goto(`${base}${pathname}${pathname.includes('?') ? '&' : '?'}audit=${Date.now()}-${attempt}`, { waitUntil: 'networkidle', timeout: 60000 });
      detail = await ready(page, attempt);
      if (detail.ready) {
        record(`${name}: published page loaded`, true, detail);
        return true;
      }
    } catch (error) {
      detail = { ready: false, attempt, error: error.message };
    }
    if (attempt < attempts) await sleep(4000);
  }
  record(`${name}: published page loaded`, false, detail);
  return false;
}

async function axe(page, name) {
  const scan = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']).analyze();
  const blocking = scan.violations.filter((item) => item.impact === 'critical' || item.impact === 'serious').map((item) => ({ id: item.id, impact: item.impact, help: item.help }));
  record(`${name}: no critical or serious axe violations`, blocking.length === 0, blocking);
}

async function structure(page, name) {
  const value = await page.evaluate(() => {
    const headings = Array.from(document.querySelectorAll('h1,h2,h3,h4,h5,h6')).map((heading) => Number(heading.tagName.slice(1)));
    const skipped = headings.some((level, index) => index > 0 && level > headings[index - 1] + 1);
    return {
      lang: document.documentElement.lang,
      title: document.title,
      h1: document.querySelectorAll('h1').length,
      main: document.querySelectorAll('main').length,
      skipped,
      unnamedButtons: Array.from(document.querySelectorAll('button')).filter((button) => !((button.textContent || '').trim() || button.getAttribute('aria-label'))).length,
      unnamedLinks: Array.from(document.querySelectorAll('a[href]')).filter((link) => !((link.textContent || '').trim() || link.getAttribute('aria-label'))).length
    };
  });
  record(`${name}: document language is Japanese`, value.lang === 'ja', value.lang);
  record(`${name}: has one non-empty page title`, Boolean(value.title), value.title);
  record(`${name}: has exactly one h1`, value.h1 === 1, value.h1);
  record(`${name}: heading levels do not skip`, !value.skipped, value.skipped);
  record(`${name}: buttons have accessible names`, value.unnamedButtons === 0, value.unnamedButtons);
  record(`${name}: links have accessible names`, value.unnamedLinks === 0, value.unnamedLinks);
  record(`${name}: has exactly one main landmark`, value.main === 1, value.main);
}

async function skipLink(page, name) {
  await page.evaluate(() => {
    window.scrollTo(0, 0);
    document.activeElement?.blur?.();
  });
  await page.keyboard.press('Tab');
  const focused = await page.evaluate(() => {
    const element = document.activeElement;
    if (!element) return null;
    const style = getComputedStyle(element);
    return { tag: element.tagName, className: element.className, href: element.getAttribute('href'), text: element.textContent.trim(), visible: style.display !== 'none' && style.visibility !== 'hidden' && element.getBoundingClientRect().height > 0 };
  });
  const valid = focused && focused.tag === 'A' && String(focused.className).includes('skip-link') && focused.visible;
  record(`${name}: first Tab exposes a visible skip link`, valid, focused);
  if (!valid) return;
  await page.keyboard.press('Enter');
  const target = await page.evaluate(() => ({ activeId: document.activeElement?.id, mainId: document.querySelector('main')?.id }));
  record(`${name}: skip link moves focus to main content`, Boolean(target.activeId && target.activeId === target.mainId), target);
}

async function focusIndicator(page, selector, name) {
  const target = page.locator(selector).first();
  await target.focus();
  const value = await target.evaluate((element) => {
    const style = getComputedStyle(element);
    return { outlineStyle: style.outlineStyle, outlineWidth: style.outlineWidth, outlineColor: style.outlineColor, boxShadow: style.boxShadow };
  });
  const visible = (value.outlineStyle !== 'none' && Number.parseFloat(value.outlineWidth || '0') >= 2) || value.boxShadow !== 'none';
  record(`${name}: keyboard focus indicator is visible`, visible, value);
}

async function auditTop(page) {
  const loaded = await open(page, '/', async (target, attempt) => {
    try { await target.waitForFunction(() => document.querySelector('#storyGrid')?.getAttribute('aria-busy') === 'false' && document.querySelectorAll('.card').length === 100, null, { timeout: 20000 }); } catch (error) {}
    return target.evaluate((currentAttempt) => ({
      ready: document.querySelectorAll('.card').length === 100 && document.querySelector('#storyGrid')?.getAttribute('aria-busy') === 'false' && Array.from(document.scripts).some((script) => script.src.includes('assets/app.js?v=20260723-007')),
      attempt: currentAttempt,
      cards: document.querySelectorAll('.card').length,
      gridBusy: document.querySelector('#storyGrid')?.getAttribute('aria-busy'),
      readerPanelReady: document.querySelector('#readerPanel')?.getAttribute('aria-busy') === 'false'
    }), attempt);
  }, 'top', 12);
  if (!loaded) return;

  await skipLink(page, 'top');
  await focusIndicator(page, '#searchInput', 'top search field');
  await axe(page, 'top');
  await structure(page, 'top');

  await page.locator('#searchInput').fill('エレベーター');
  const liveText = await page.locator('#count').innerText();
  record('top: search result count is announced through live region', await page.locator('#count').getAttribute('aria-live') === 'polite' && liveText.includes('表示1話'), liveText);

  const category = page.getByRole('button', { name: '心霊', exact: true });
  await category.focus();
  await page.keyboard.press('Enter');
  record('top: category filter works with keyboard and exposes pressed state', await category.getAttribute('aria-pressed') === 'true');
}

async function auditArchive(page) {
  const loaded = await open(page, '/archive.html', async (target, attempt) => ({ ready: await target.locator('.archive-item').count() === 100, attempt, items: await target.locator('.archive-item').count() }), 'archive', 8);
  if (!loaded) return;
  await skipLink(page, 'archive');
  await focusIndicator(page, '.archive-jump a', 'archive jump link');
  await axe(page, 'archive');
  await structure(page, 'archive');
}

async function auditStory(page) {
  const loaded = await open(page, '/stories/spare-key-returned.html', async (target, attempt) => ({ ready: await target.locator('.story-pagination a').count() === 3, attempt }), 'story', 8);
  if (!loaded) return;
  await skipLink(page, 'story');
  await focusIndicator(page, '#explainBtn', 'story explanation button');
  await axe(page, 'story');
  await structure(page, 'story');

  const button = page.locator('#explainBtn');
  await button.focus();
  await page.keyboard.press('Enter');
  record('story: explanation opens by keyboard and updates aria-expanded', await button.getAttribute('aria-expanded') === 'true' && await page.locator('#explanation').isVisible());
  const pagination = await page.locator('.story-pagination a').allTextContents();
  record('story: previous, archive, and next links have descriptive names', pagination.length === 3 && pagination.every((name) => name.trim()), pagination);
}

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true, userAgent: 'Yorugatari-Accessibility-Audit/1.5' });
  const page = await context.newPage();
  const browserErrors = [];
  page.on('pageerror', (error) => browserErrors.push(`pageerror: ${error.message}`));
  page.on('console', (message) => { if (message.type() === 'error') browserErrors.push(`console: ${message.text()}`); });

  try {
    await auditTop(page);
    await auditArchive(page);
    await auditStory(page);
    record('accessibility audit: no browser JavaScript errors', browserErrors.length === 0, browserErrors);
  } catch (error) {
    record('accessibility audit completed without test exception', false, { message: error.message, stack: error.stack });
  } finally {
    await context.close();
    await browser.close();
  }

  const report = { auditedAt: new Date().toISOString(), success: failures.length === 0, results, failures };
  fs.writeFileSync('yorugatari-accessibility-report.json', `${JSON.stringify(report, null, 2)}\n`);
  console.log(`YORUGATARI_ACCESSIBILITY_REPORT=${JSON.stringify(report)}`);
  if (failures.length) process.exit(1);
})();
