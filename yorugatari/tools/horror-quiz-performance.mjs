import fs from 'node:fs';

const base = 'https://allsunday1122.github.io/yorugatari';
const pageUrl = `${base}/horror-quiz.html?lighthouse-audit=1`;
const version = '20260724-001';
const report = { auditedAt: new Date().toISOString(), success: false, version, releaseCheck: null, runs: [], failures: [], errors: [] };
const sleep = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

function detail(error) {
  return { message: error instanceof Error ? error.message : String(error), stack: error instanceof Error ? error.stack : null };
}

async function waitForRelease() {
  for (let attempt = 1; attempt <= 30; attempt += 1) {
    try {
      const stamp = Date.now();
      const [pageResponse, runtimeResponse] = await Promise.all([
        fetch(`${base}/horror-quiz.html?quiz-performance-release=${stamp}`, { cache: 'no-store', headers: { 'cache-control': 'no-cache' } }),
        fetch(`${base}/assets/horror-quiz.js?v=${version}&quiz-performance-release=${stamp}`, { cache: 'no-store', headers: { 'cache-control': 'no-cache' } })
      ]);
      const [html, runtime] = await Promise.all([pageResponse.text(), runtimeResponse.text()]);
      const release = {
        attempt,
        pageStatus: pageResponse.status,
        runtimeStatus: runtimeResponse.status,
        pageReady: html.includes('assets/horror-quiz.js?v=20260724-001') && (html.match(/<fieldset\b/g) || []).length === 3 && html.includes('id="quizResult"') && html.includes('horror-quiz.html'),
        runtimeReady: runtime.includes('const RESULTS = {') && runtime.includes('quiet:') && runtime.includes('human:') && runtime.includes('digital:') && runtime.includes('rules:') && runtime.includes("utm_content', 'horror_quiz'")
      };
      report.releaseCheck = release;
      if (pageResponse.ok && runtimeResponse.ok && release.pageReady && release.runtimeReady) return;
    } catch (error) {
      report.releaseCheck = { attempt, ...detail(error) };
    }
    if (attempt < 30) await sleep(10000);
  }
  throw new Error(`Published quiz release was not detected: ${JSON.stringify(report.releaseCheck)}`);
}

function profile(profileName) {
  if (profileName === 'desktop') {
    return {
      formFactor: 'desktop',
      screenEmulation: { mobile: false, width: 1440, height: 900, deviceScaleFactor: 1, disabled: false },
      throttling: { rttMs: 40, throughputKbps: 10240, cpuSlowdownMultiplier: 1, requestLatencyMs: 0, downloadThroughputKbps: 0, uploadThroughputKbps: 0 }
    };
  }
  return { formFactor: 'mobile', screenEmulation: { mobile: true, width: 390, height: 844, deviceScaleFactor: 2, disabled: false } };
}

function auditValue(audits, id) {
  const item = audits[id];
  return item ? { score: item.score, numericValue: Number.isFinite(item.numericValue) ? item.numericValue : null, displayValue: item.displayValue || null } : null;
}

function summarize(lhr, profileName) {
  const audits = lhr.audits;
  return {
    profile: profileName,
    fetchTime: lhr.fetchTime,
    scores: {
      performance: lhr.categories.performance?.score ?? null,
      bestPractices: lhr.categories['best-practices']?.score ?? null,
      seo: lhr.categories.seo?.score ?? null
    },
    metrics: {
      firstContentfulPaint: auditValue(audits, 'first-contentful-paint'),
      largestContentfulPaint: auditValue(audits, 'largest-contentful-paint'),
      totalBlockingTime: auditValue(audits, 'total-blocking-time'),
      cumulativeLayoutShift: auditValue(audits, 'cumulative-layout-shift'),
      totalByteWeight: auditValue(audits, 'total-byte-weight')
    }
  };
}

function validate(run) {
  const mobile = run.profile === 'mobile';
  const checks = {
    performance: Number.isFinite(run.scores.performance) && run.scores.performance >= (mobile ? 0.9 : 0.95),
    bestPractices: Number.isFinite(run.scores.bestPractices) && run.scores.bestPractices >= 0.9,
    seo: run.scores.seo === 1,
    totalBlockingTime: Number.isFinite(run.metrics.totalBlockingTime?.numericValue) && run.metrics.totalBlockingTime.numericValue <= (mobile ? 300 : 150),
    cumulativeLayoutShift: Number.isFinite(run.metrics.cumulativeLayoutShift?.numericValue) && run.metrics.cumulativeLayoutShift.numericValue <= 0.1,
    totalByteWeight: Number.isFinite(run.metrics.totalByteWeight?.numericValue) && run.metrics.totalByteWeight.numericValue <= 50000
  };
  if (!Object.values(checks).every(Boolean)) report.failures.push({ profile: run.profile, checks, run });
}

let chrome;
try {
  await waitForRelease();
  const [{ default: lighthouse }, chromeLauncher] = await Promise.all([import('lighthouse'), import('chrome-launcher')]);
  chrome = await chromeLauncher.launch({ chromeFlags: ['--headless=new', '--no-sandbox', '--disable-dev-shm-usage', '--disable-gpu'] });
  for (const profileName of ['mobile', 'desktop']) {
    const result = await lighthouse(pageUrl, {
      port: chrome.port,
      output: 'json',
      logLevel: 'error',
      onlyCategories: ['performance', 'best-practices', 'seo'],
      throttlingMethod: 'simulate',
      disableStorageReset: false,
      ...profile(profileName)
    });
    const run = summarize(result.lhr, profileName);
    report.runs.push(run);
    validate(run);
  }
} catch (error) {
  report.errors.push(detail(error));
} finally {
  if (chrome) {
    try { await chrome.kill(); } catch (error) { report.errors.push(detail(error)); }
  }
  report.success = report.runs.length === 2 && report.failures.length === 0 && report.errors.length === 0;
  fs.writeFileSync('yorugatari-horror-quiz-performance-report.json', `${JSON.stringify(report, null, 2)}\n`);
  console.log(`YORUGATARI_HORROR_QUIZ_PERFORMANCE=${JSON.stringify({ success: report.success, releaseCheck: report.releaseCheck, runs: report.runs, failures: report.failures, errors: report.errors })}`);
}

if (!report.success) process.exit(1);
