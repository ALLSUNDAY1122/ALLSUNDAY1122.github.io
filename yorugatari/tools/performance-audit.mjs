import fs from 'node:fs';

const base = 'https://allsunday1122.github.io/yorugatari';
const targets = [
  { name: 'top', url: `${base}/` },
  { name: 'archive', url: `${base}/archive.html` },
  { name: 'story-032', url: `${base}/stories/spare-key-returned.html` }
];

const profiles = [
  {
    name: 'mobile',
    flags: {
      formFactor: 'mobile',
      screenEmulation: {
        mobile: true,
        width: 390,
        height: 844,
        deviceScaleFactor: 2,
        disabled: false
      }
    }
  },
  {
    name: 'desktop',
    flags: {
      formFactor: 'desktop',
      screenEmulation: {
        mobile: false,
        width: 1440,
        height: 900,
        deviceScaleFactor: 1,
        disabled: false
      },
      throttling: {
        rttMs: 40,
        throughputKbps: 10240,
        cpuSlowdownMultiplier: 1,
        requestLatencyMs: 0,
        downloadThroughputKbps: 0,
        uploadThroughputKbps: 0
      }
    }
  }
];

const report = {
  auditedAt: new Date().toISOString(),
  baseUrl: base,
  success: false,
  releaseCheck: null,
  runs: [],
  errors: []
};

function errorDetail(error) {
  return {
    message: error instanceof Error ? error.message : String(error),
    stack: error instanceof Error ? error.stack : null
  };
}

function sleep(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function waitForPublishedRelease() {
  const attempts = 24;
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try {
      const stamp = Date.now();
      const [topResponse, archiveResponse] = await Promise.all([
        fetch(`${base}/?performance-release=${stamp}`, { headers: { 'cache-control': 'no-cache' } }),
        fetch(`${base}/archive.html?performance-release=${stamp}`, { headers: { 'cache-control': 'no-cache' } })
      ]);
      const [topHtml, archiveHtml] = await Promise.all([topResponse.text(), archiveResponse.text()]);
      const detail = {
        attempt,
        topStatus: topResponse.status,
        archiveStatus: archiveResponse.status,
        topOptimization: topHtml.includes('.card:nth-child(n+9)'),
        archiveOptimization: archiveHtml.includes('contain-intrinsic-size:auto 1600px')
      };
      if (topResponse.ok && archiveResponse.ok && detail.topOptimization && detail.archiveOptimization) {
        report.releaseCheck = detail;
        return;
      }
      report.releaseCheck = detail;
    } catch (error) {
      report.releaseCheck = { attempt, ...errorDetail(error) };
    }
    if (attempt < attempts) await sleep(10000);
  }
  throw new Error(`Published performance release was not detected: ${JSON.stringify(report.releaseCheck)}`);
}

function auditValue(audits, id) {
  const audit = audits[id];
  if (!audit) return null;
  return {
    score: audit.score,
    numericValue: Number.isFinite(audit.numericValue) ? audit.numericValue : null,
    numericUnit: audit.numericUnit || null,
    displayValue: audit.displayValue || null,
    title: audit.title || id
  };
}

function resourceSummary(audits) {
  const rows = audits['resource-summary']?.details?.items || [];
  return rows.map((row) => ({
    resourceType: row.resourceType,
    requestCount: row.requestCount,
    transferSize: row.transferSize
  }));
}

function largestRequests(audits) {
  const rows = audits['network-requests']?.details?.items || [];
  return rows
    .map((row) => ({
      url: row.url,
      resourceType: row.resourceType,
      transferSize: row.transferSize,
      resourceSize: row.resourceSize,
      statusCode: row.statusCode,
      mimeType: row.mimeType
    }))
    .filter((row) => Number.isFinite(row.transferSize))
    .sort((a, b) => b.transferSize - a.transferSize)
    .slice(0, 12);
}

function opportunities(audits) {
  const ids = [
    'render-blocking-resources',
    'unused-javascript',
    'unused-css-rules',
    'modern-image-formats',
    'uses-responsive-images',
    'offscreen-images',
    'uses-long-cache-ttl',
    'unminified-javascript',
    'unminified-css',
    'bootup-time',
    'mainthread-work-breakdown',
    'third-party-summary'
  ];
  return ids
    .map((id) => {
      const value = auditValue(audits, id);
      return value ? { id, ...value } : null;
    })
    .filter(Boolean);
}

function summarize(result, target, profile) {
  if (!result?.lhr) throw new Error('Lighthouse returned no report');
  const lhr = result.lhr;
  const audits = lhr.audits;
  return {
    target: target.name,
    profile: profile.name,
    requestedUrl: target.url,
    finalUrl: lhr.finalDisplayedUrl || lhr.finalUrl,
    fetchTime: lhr.fetchTime,
    lighthouseVersion: lhr.lighthouseVersion,
    userAgent: lhr.userAgent,
    scores: {
      performance: lhr.categories.performance?.score ?? null,
      bestPractices: lhr.categories['best-practices']?.score ?? null,
      seo: lhr.categories.seo?.score ?? null
    },
    metrics: {
      firstContentfulPaint: auditValue(audits, 'first-contentful-paint'),
      largestContentfulPaint: auditValue(audits, 'largest-contentful-paint'),
      speedIndex: auditValue(audits, 'speed-index'),
      totalBlockingTime: auditValue(audits, 'total-blocking-time'),
      cumulativeLayoutShift: auditValue(audits, 'cumulative-layout-shift'),
      interactive: auditValue(audits, 'interactive'),
      serverResponseTime: auditValue(audits, 'server-response-time'),
      totalByteWeight: auditValue(audits, 'total-byte-weight'),
      domSize: auditValue(audits, 'dom-size')
    },
    resources: resourceSummary(audits),
    largestRequests: largestRequests(audits),
    opportunities: opportunities(audits)
  };
}

let chrome;
try {
  await waitForPublishedRelease();

  const [{ default: lighthouse }, chromeLauncher] = await Promise.all([
    import('lighthouse'),
    import('chrome-launcher')
  ]);

  if (typeof lighthouse !== 'function') throw new Error('Lighthouse default export is unavailable');
  if (typeof chromeLauncher.launch !== 'function') throw new Error('chrome-launcher launch export is unavailable');

  chrome = await chromeLauncher.launch({
    chromeFlags: [
      '--headless=new',
      '--no-sandbox',
      '--disable-dev-shm-usage',
      '--disable-gpu'
    ]
  });

  for (const target of targets) {
    for (const profile of profiles) {
      try {
        const result = await lighthouse(target.url, {
          port: chrome.port,
          output: 'json',
          logLevel: 'error',
          onlyCategories: ['performance', 'best-practices', 'seo'],
          throttlingMethod: 'simulate',
          disableStorageReset: false,
          ...profile.flags
        });
        report.runs.push(summarize(result, target, profile));
      } catch (error) {
        report.errors.push({ target: target.name, profile: profile.name, ...errorDetail(error) });
      }
    }
  }
} catch (error) {
  report.errors.push({ target: 'launcher', profile: null, ...errorDetail(error) });
} finally {
  if (chrome) {
    try {
      await chrome.kill();
    } catch (error) {
      report.errors.push({ target: 'launcher-cleanup', profile: null, ...errorDetail(error) });
    }
  }

  report.success = report.runs.length === targets.length * profiles.length && report.errors.length === 0;
  fs.writeFileSync('yorugatari-performance-report.json', `${JSON.stringify(report, null, 2)}\n`);
  console.log(`Yorugatari Lighthouse runs: ${report.runs.length}/${targets.length * profiles.length}; errors: ${report.errors.length}`);
  if (report.errors.length) console.error(JSON.stringify(report.errors, null, 2));
}

if (!report.success) process.exit(1);
