import fs from 'node:fs';

const base = 'https://allsunday1122.github.io/yorugatari';
const cases = [
  { target: 'top', profile: 'mobile', url: `${base}/`, repeats: 3 },
  { target: 'top', profile: 'desktop', url: `${base}/`, repeats: 1 },
  { target: 'archive', profile: 'mobile', url: `${base}/archive.html`, repeats: 1 },
  { target: 'archive', profile: 'desktop', url: `${base}/archive.html`, repeats: 1 },
  { target: 'story-032', profile: 'mobile', url: `${base}/stories/spare-key-returned.html`, repeats: 1 },
  { target: 'story-032', profile: 'desktop', url: `${base}/stories/spare-key-returned.html`, repeats: 1 }
];

const report = {
  auditedAt: new Date().toISOString(),
  baseUrl: base,
  success: false,
  releaseCheck: null,
  runs: [],
  representativeRuns: [],
  failures: [],
  errors: []
};

const sleep = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

function errorDetail(error) {
  return { message: error instanceof Error ? error.message : String(error), stack: error instanceof Error ? error.stack : null };
}

async function waitForRelease() {
  for (let attempt = 1; attempt <= 24; attempt += 1) {
    try {
      const stamp = Date.now();
      const [topResponse, archiveResponse, storyResponse] = await Promise.all([
        fetch(`${base}/?performance-release=${stamp}`, { headers: { 'cache-control': 'no-cache' } }),
        fetch(`${base}/archive.html?performance-release=${stamp}`, { headers: { 'cache-control': 'no-cache' } }),
        fetch(`${base}/stories/spare-key-returned.html?performance-release=${stamp}`, { headers: { 'cache-control': 'no-cache' } })
      ]);
      const [topHtml, archiveHtml, storyHtml] = await Promise.all([topResponse.text(), archiveResponse.text(), storyResponse.text()]);
      const detail = {
        attempt,
        topStatus: topResponse.status,
        archiveStatus: archiveResponse.status,
        storyStatus: storyResponse.status,
        progressiveApp: topHtml.includes('assets/app.js?v=20260723-007'),
        analytics: topHtml.includes('assets/analytics.js?v=20260723-002'),
        archiveReady: archiveHtml.includes('assets/archive.js?v=20260723-004'),
        storyReady: storyHtml.includes('../assets/engagement.js?v=20260723-002')
      };
      report.releaseCheck = detail;
      if (topResponse.ok && archiveResponse.ok && storyResponse.ok && detail.progressiveApp && detail.analytics && detail.archiveReady && detail.storyReady) return;
    } catch (error) {
      report.releaseCheck = { attempt, ...errorDetail(error) };
    }
    if (attempt < 24) await sleep(10000);
  }
  throw new Error(`Published release was not detected: ${JSON.stringify(report.releaseCheck)}`);
}

function profileFlags(profile) {
  if (profile === 'desktop') {
    return {
      formFactor: 'desktop',
      screenEmulation: { mobile: false, width: 1440, height: 900, deviceScaleFactor: 1, disabled: false },
      throttling: { rttMs: 40, throughputKbps: 10240, cpuSlowdownMultiplier: 1, requestLatencyMs: 0, downloadThroughputKbps: 0, uploadThroughputKbps: 0 }
    };
  }
  return {
    formFactor: 'mobile',
    screenEmulation: { mobile: true, width: 390, height: 844, deviceScaleFactor: 2, disabled: false }
  };
}

function auditValue(audits, id) {
  const value = audits[id];
  if (!value) return null;
  return {
    score: value.score,
    numericValue: Number.isFinite(value.numericValue) ? value.numericValue : null,
    displayValue: value.displayValue || null
  };
}

function summarize(result, currentCase, runNumber) {
  const lhr = result?.lhr;
  if (!lhr) throw new Error('Lighthouse returned no report');
  const audits = lhr.audits;
  const resourceRows = audits['resource-summary']?.details?.items || [];
  return {
    target: currentCase.target,
    profile: currentCase.profile,
    run: runNumber,
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
      interactive: auditValue(audits, 'interactive'),
      totalByteWeight: auditValue(audits, 'total-byte-weight')
    },
    resources: resourceRows.map((row) => ({ resourceType: row.resourceType, requestCount: row.requestCount, transferSize: row.transferSize }))
  };
}

function medianRun(rows) {
  const sorted = rows.slice().sort((left, right) => (left.scores.performance ?? -1) - (right.scores.performance ?? -1));
  return sorted[Math.floor(sorted.length / 2)];
}

function validate(run) {
  const mobile = run.profile === 'mobile';
  const performanceMinimum = mobile ? 0.9 : 0.95;
  const tbtMaximum = mobile ? 300 : 150;
  const performance = run.scores.performance;
  const bestPractices = run.scores.bestPractices;
  const seo = run.scores.seo;
  const tbt = run.metrics.totalBlockingTime?.numericValue;
  const cls = run.metrics.cumulativeLayoutShift?.numericValue;
  const checks = {
    performance: Number.isFinite(performance) && performance >= performanceMinimum,
    bestPractices: Number.isFinite(bestPractices) && bestPractices >= 0.9,
    seo: seo === 1,
    totalBlockingTime: Number.isFinite(tbt) && tbt <= tbtMaximum,
    cumulativeLayoutShift: Number.isFinite(cls) && cls <= 0.1
  };
  if (!Object.values(checks).every(Boolean)) {
    report.failures.push({ target: run.target, profile: run.profile, checks, scores: run.scores, metrics: run.metrics });
  }
}

let chrome;
try {
  await waitForRelease();
  const [{ default: lighthouse }, chromeLauncher] = await Promise.all([import('lighthouse'), import('chrome-launcher')]);
  chrome = await chromeLauncher.launch({ chromeFlags: ['--headless=new', '--no-sandbox', '--disable-dev-shm-usage', '--disable-gpu'] });

  for (const currentCase of cases) {
    const group = [];
    for (let runNumber = 1; runNumber <= currentCase.repeats; runNumber += 1) {
      try {
        const result = await lighthouse(currentCase.url, {
          port: chrome.port,
          output: 'json',
          logLevel: 'error',
          onlyCategories: ['performance', 'best-practices', 'seo'],
          throttlingMethod: 'simulate',
          disableStorageReset: false,
          ...profileFlags(currentCase.profile)
        });
        const row = summarize(result, currentCase, runNumber);
        group.push(row);
        report.runs.push(row);
      } catch (error) {
        report.errors.push({ target: currentCase.target, profile: currentCase.profile, run: runNumber, ...errorDetail(error) });
      }
    }
    if (group.length) {
      const representative = medianRun(group);
      report.representativeRuns.push(representative);
      validate(representative);
    }
  }
} catch (error) {
  report.errors.push({ target: 'launcher', profile: null, ...errorDetail(error) });
} finally {
  if (chrome) {
    try { await chrome.kill(); } catch (error) { report.errors.push({ target: 'launcher-cleanup', profile: null, ...errorDetail(error) }); }
  }
  report.success = report.representativeRuns.length === cases.length && report.failures.length === 0 && report.errors.length === 0;
  fs.writeFileSync('yorugatari-performance-report.json', `${JSON.stringify(report, null, 2)}\n`);
  console.log(`YORUGATARI_PERFORMANCE_REPORT=${JSON.stringify({ success: report.success, releaseCheck: report.releaseCheck, representativeRuns: report.representativeRuns.map((run) => ({ target: run.target, profile: run.profile, scores: run.scores, tbt: run.metrics.totalBlockingTime?.numericValue, cls: run.metrics.cumulativeLayoutShift?.numericValue })), failures: report.failures, errors: report.errors })}`);
}

if (!report.success) process.exit(1);
