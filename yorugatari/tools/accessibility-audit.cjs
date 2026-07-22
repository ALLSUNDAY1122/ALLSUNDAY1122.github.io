const fs = require('node:fs');
const { chromium } = require('playwright');
const AxeBuilder = require('@axe-core/playwright').default;

const base = 'https://allsunday1122.github.io/yorugatari';
const results = [];
const failures = [];
const sleep = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

function record(name, ok, detail = null) {
  const result = { name, ok: Boolean(ok), detail };
  results.push(result);
  if (!result.ok) failures.push(result);
}

function compactViolation(violation) {
  return {
    id: violation.id,
    impact: violation.impact,
    help: violation.help,
    helpUrl: violation.helpUrl,
    nodes: violation.nodes.map((node) => ({
      target: node.target,
      html: node.html,
      failureSummary: node.failureSummary
    }))
  };
}

async function openWithRetry(page, path, selector, readiness, name, attempts = 10) {
  let detail = null;
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try {
      const separator = path.includes('?') ? '&' : '?';
      await page.goto(`${base}${path}${separator}audit=${Date.now()}-${attempt}`, {
        waitUntil: 'networkidle',
        timeout: 60000
      });
      await page.waitForSelector(selector, { timeout: 20000 });
      const state = readiness ? await readiness(page) : { ready: true };
      detail = { attempt, ...state };
      if (Object.values(state).every(Boolean)) {
        record(`${name}: published page loaded`, true, detail);
        return true;
      }
    } catch (error) {
      detail = { attempt, error: error.message };
    }
    if (attempt < attempts) await sleep(5000);
  }
  record(`${name}: published page loaded`, false, detail);
  return false;
}

async function materializeDeferredContent(page) {
  await page.evaluate(async () => {
    const deferred = Array.from(document.querySelectorAll('.card,.archive-section,.archive-item'));
    for (let index = 0; index < deferred.length; index += 4) {
      deferred[index].scrollIntoView({ block: 'center' });
      await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    }
    window.scrollTo(0, 0);
    await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
  });
}

async function auditAxe(page, name) {
  const scan = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'])
    .analyze();
  const violations = scan.violations.map(compactViolation);
  const blocking = violations.filter((item) => item.impact === 'critical' || item.impact === 'serious');
  record(`${name}: no critical or serious axe violations`, blocking.length === 0, violations);
}

async function auditDocumentStructure(page, name) {
  const structure = await page.evaluate(() => {
    const headings = Array.from(document.querySelectorAll('h1,h2,h3,h4,h5,h6')).map((heading) => ({
      level: Number(heading.tagName.slice(1)),
      text: heading.textContent.trim()
    }));
    const skipped = [];
    for (let index = 1; index < headings.length; index += 1) {
      if (headings[index].level > headings[index - 1].level + 1) skipped.push([headings[index - 1], headings[index]]);
    }
    return {
      lang: document.documentElement.lang,
      title: document.title,
      h1Count: document.querySelectorAll('h1').length,
      skipped,
      unnamedButtons: Array.from(document.querySelectorAll('button')).filter((button) => !((button.textContent || '').trim() || button.getAttribute('aria-label'))).length,
      unnamedLinks: Array.from(document.querySelectorAll('a[href]')).filter((link) => !((link.textContent || '').trim() || link.getAttribute('aria-label'))).length,
      mainCount: document.querySelectorAll('main').length
    };
  });
  record(`${name}: document language is Japanese`, structure.lang === 'ja', structure.lang);
  record(`${name}: has one non-empty page title`, Boolean(structure.title), structure.title);
  record(`${name}: has exactly one h1`, structure.h1Count === 1, structure.h1Count);
  record(`${name}: heading levels do not skip`, structure.skipped.length === 0, structure.skipped);
  record(`${name}: buttons have accessible names`, structure.unnamedButtons === 0, structure.unnamedButtons);
  record(`${name}: links have accessible names`, structure.unnamedLinks === 0, structure.unnamedLinks);
  record(`${name}: has exactly one main landmark`, structure.mainCount === 1, structure.mainCount);
}

async function auditSkipLink(page, name) {
  await page.evaluate(() => {
    window.scrollTo(0, 0);
    if (document.activeElement && document.activeElement.blur) document.activeElement.blur();
  });
  await page.keyboard.press('Tab');
  const focused = await page.evaluate(() => {
    const element = document.activeElement;
    if (!element) return null;
    const style = getComputedStyle(element);
    return {
      tag: element.tagName,
      className: element.className,
      href: element.getAttribute('href'),
      text: element.textContent.trim(),
      visible: style.display !== 'none' && style.visibility !== 'hidden' && element.getBoundingClientRect().height > 0
    };
  });
  const isSkip = focused && focused.tag === 'A' && String(focused.className).includes('skip-link') && focused.visible;
  record(`${name}: first Tab exposes a visible skip link`, isSkip, focused);
  if (isSkip) {
    await page.keyboard.press('Enter');
    const target = await page.evaluate(() => ({
      hash: location.hash,
      activeId: document.activeElement && document.activeElement.id,
      mainId: document.querySelector('main') && document.querySelector('main').id
    }));
    record(`${name}: skip link moves focus to main content`, target.activeId && target.activeId === target.mainId, target);
  }
}

async function auditFocusIndicator(page, selector, name) {
  const target = page.locator(selector).first();
  await target.focus();
  const focus = await target.evaluate((element) => {
    const style = getComputedStyle(element);
    return {
      outlineStyle: style.outlineStyle,
      outlineWidth: style.outlineWidth,
      outlineColor: style.outlineColor,
      boxShadow: style.boxShadow
    };
  });
  const width = Number.parseFloat(focus.outlineWidth || '0');
  const visible = (focus.outlineStyle !== 'none' && width >= 2) || focus.boxShadow !== 'none';
  record(`${name}: keyboard focus indicator is visible`, visible, focus);
}

async function auditTop(page) {
  const loaded = await openWithRetry(
    page,
    '/',
    '.card',
    async (targetPage) => targetPage.evaluate(() => ({
      skipLink: Boolean(document.querySelector('a.skip-link[href="#main-content"]')),
      mainTarget: Boolean(document.querySelector('main#main-content[tabindex="-1"]')),
      progressbar: Boolean(document.querySelector('.reader-meter[role="progressbar"][aria-valuemin="0"][aria-valuemax="100"][aria-valuenow]')),
      appVersion: Array.from(document.scripts).some((script) => script.src.includes('assets/app.js?v=20260723-005'))
    })),
    'top',
    12
  );
  if (!loaded) return;

  await materializeDeferredContent(page);
  await auditAxe(page, 'top');
  await auditDocumentStructure(page, 'top');
  await auditSkipLink(page, 'top');
  await auditFocusIndicator(page, '#searchInput', 'top search field');

  const search = page.locator('#searchInput');
  await search.focus();
  await search.fill('エレベーター');
  const liveText = await page.locator('#count').innerText();
  record('top: search result count is announced through live region', await page.locator('#count').getAttribute('aria-live') === 'polite' && liveText.includes('表示1話'), liveText);

  const category = page.getByRole('button', { name: '心霊', exact: true });
  await category.focus();
  await page.keyboard.press('Enter');
  record('top: category filter works with keyboard and exposes pressed state', await category.getAttribute('aria-pressed') === 'true');
}

async function auditArchive(page) {
  const loaded = await openWithRetry(page, '/archive.html', '.archive-item', null, 'archive', 6);
  if (!loaded) return;
  await materializeDeferredContent(page);
  await auditAxe(page, 'archive');
  await auditDocumentStructure(page, 'archive');
  await auditSkipLink(page, 'archive');
  await auditFocusIndicator(page, '.archive-jump a', 'archive jump link');
}

async function auditStory(page) {
  const loaded = await openWithRetry(page, '/stories/spare-key-returned.html', '.story-pagination', null, 'story', 6);
  if (!loaded) return;
  await materializeDeferredContent(page);
  await auditAxe(page, 'story');
  await auditDocumentStructure(page, 'story');
  await auditSkipLink(page, 'story');
  await auditFocusIndicator(page, '#explainBtn', 'story explanation button');

  const button = page.locator('#explainBtn');
  await button.focus();
  await page.keyboard.press('Enter');
  record('story: explanation opens by keyboard and updates aria-expanded', await button.getAttribute('aria-expanded') === 'true' && await page.locator('#explanation').isVisible());

  const paginationNames = await page.locator('.story-pagination a').evaluateAll((links) => links.map((link) => link.textContent.trim()));
  record('story: previous, archive, and next links have descriptive names', paginationNames.length === 3 && paginationNames.every(Boolean), paginationNames);
}

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
    isMobile: true,
    hasTouch: true,
    userAgent: 'Yorugatari-Accessibility-Audit/1.2'
  });
  const page = await context.newPage();
  const browserErrors = [];
  page.on('pageerror', (error) => browserErrors.push(`pageerror: ${error.message}`));
  page.on('console', (message) => {
    if (message.type() === 'error') browserErrors.push(`console: ${message.text()}`);
  });

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

  const report = {
    auditedAt: new Date().toISOString(),
    success: failures.length === 0,
    results,
    failures
  };
  fs.writeFileSync('yorugatari-accessibility-report.json', `${JSON.stringify(report, null, 2)}\n`);
  console.log(`YORUGATARI_ACCESSIBILITY_REPORT=${JSON.stringify(report)}`);
  if (failures.length) process.exit(1);
})();
