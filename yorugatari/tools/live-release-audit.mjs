import fs from 'node:fs';

const base = 'https://allsunday1122.github.io/yorugatari';
const attempts = 24;
const delayMilliseconds = 5000;
const targets = [
  { name: 'top', url: `${base}/`, required: ['オリジナル怖い話100作品', 'class="skip-link"', 'id="readerPanel"', 'assets/stories-096-100.js?v=20260723-004', 'assets/app.js?v=20260723-008', 'assets/analytics.js?v=20260723-003'], forbidden: ['assets/engagement.js'] },
  { name: 'five-minute', url: `${base}/5min-horror.html`, required: ['5分で読める怖い話', 'class="pick"', 'class="guide-card"', 'assets/landing-share.js?v=20260724-002', 'assets/landing-start-20260724-001.js', '特集単位の合計だけを匿名で集計します', 'assets/analytics.js?v=20260724-004'], forbidden: ['assets/engagement.js'] },
  { name: 'bedtime', url: `${base}/bedtime-horror.html`, required: ['寝る前に読む怖い話', '"numberOfItems":8', 'class="pick"', 'class="mood-card"', '"@type":"FAQPage"', 'assets/landing-share.js?v=20260724-002', 'assets/landing-start-20260724-001.js', '特集単位の合計だけを匿名で集計します', 'assets/analytics.js?v=20260724-005'], forbidden: ['assets/engagement.js'] },
  { name: 'archive', url: `${base}/archive.html`, required: ['全100話アーカイブ', '"numberOfItems":100', 'assets/archive.js?v=20260723-004', 'assets/analytics.js?v=20260723-003'], forbidden: ['assets/engagement.js'] },
  { name: 'privacy', url: `${base}/privacy.html`, required: ['固定キャンペーンコード', '登録済みコードに一致しない値は破棄', '開いた作品名や作品URLはこの集計へ含めません', 'assets/analytics.js?v=20260723-003'], forbidden: ['assets/engagement.js'] },
  { name: 'story-001', url: `${base}/stories/last-elevator.html`, required: ['YGT-001', '"timeRequired":"PT5M"', 'class="breadcrumb"', 'class="hero-actions story-pagination"', 'class="related"', '../assets/story.js?v=20260723-007', '../assets/engagement.js?v=20260723-003'], forbidden: ['../assets/analytics.js'] },
  { name: 'story-032', url: `${base}/stories/spare-key-returned.html`, required: ['YGT-032', '"timeRequired":"PT5M"', 'class="breadcrumb"', 'class="hero-actions story-pagination"', 'class="related"', '../assets/story.js?v=20260723-007', '../assets/engagement.js?v=20260723-003'], forbidden: ['../assets/analytics.js'] },
  { name: 'story-100', url: `${base}/stories/hired-with-your-experience.html`, required: ['YGT-100', '"timeRequired":"PT5M"', 'class="breadcrumb"', 'class="hero-actions story-pagination"', 'class="related"', '../assets/story.js?v=20260723-007', '../assets/engagement.js?v=20260723-003'], forbidden: ['../assets/analytics.js'] },
  { name: 'story-js', url: `${base}/assets/story.js?v=20260723-007`, required: ['function normalizeBasicPage()', 'function ensureNavigationFallback()', "ensurePropertyMeta('og:image:width', '2172');"], forbidden: ['catalogSources', 'loadCatalogScript', 'buildStoryPagination'] },
  { name: 'analytics-js', url: `${base}/assets/analytics.js?v=20260724-005`, required: ['knownCampaigns', 'function campaignId()', 'campaignTracked', "'/yorugatari/__campaign/' + campaign", 'launch-20260724-x-five-minute', 'launch-20260724-threads-five-minute', 'launch-20260724-x-bedtime', 'launch-20260724-threads-bedtime'], forbidden: ["'/yorugatari/__campaign/' + query"] },
  { name: 'landing-share-js', url: `${base}/assets/landing-share.js?v=20260724-002`, required: ['window.YORUGATARI_LANDING_SHARE', 'navigator.share', 'navigator.clipboard', 'utm_source', 'onsite_share'], forbidden: ['utm_term', 'utm_id'] },
  { name: 'landing-start-js', url: `${base}/assets/landing-start-20260724-001.js`, required: ["const VERSION = '20260724-001'", '/yorugatari/__landing-start/five-minute', '/yorugatari/__landing-start/bedtime', 'window.YORUGATARI_LANDING_START', 'sessionStorage.setItem(storageKey'], forbidden: ['utm_', 'stories/last-elevator', 'stories/good-night'] },
  { name: 'engagement-js', url: `${base}/assets/engagement.js?v=20260723-003`, required: ['relatedReady: document.querySelectorAll', 'function taggedShareUrl()', 'function trackCampaign()', 'campaignTracked'], forbidden: ['installRelatedStories', 'buildRelatedStories', "'/yorugatari/__campaign/' + query"] }
];

const sleep = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

async function inspect(target, attempt) {
  try {
    const separator = target.url.includes('?') ? '&' : '?';
    const response = await fetch(`${target.url}${separator}verify=${Date.now()}-${attempt}`, {
      redirect: 'follow',
      headers: {
        'cache-control': 'no-cache, no-store, max-age=0',
        pragma: 'no-cache',
        'user-agent': 'Yorugatari-Live-Check/2.4'
      }
    });
    const text = await response.text();
    const missingTokens = target.required.filter((token) => !text.includes(token));
    const forbiddenTokens = target.forbidden.filter((token) => text.includes(token));
    return {
      name: target.name,
      status: response.status,
      finalUrl: response.url,
      bytes: Buffer.byteLength(text),
      missingTokens,
      forbiddenTokens,
      ok: response.status === 200 && missingTokens.length === 0 && forbiddenTokens.length === 0
    };
  } catch (error) {
    return {
      name: target.name,
      status: null,
      bytes: 0,
      missingTokens: target.required,
      forbiddenTokens: [],
      error: error instanceof Error ? error.message : String(error),
      ok: false
    };
  }
}

let report = null;
for (let attempt = 1; attempt <= attempts; attempt += 1) {
  const results = await Promise.all(targets.map((target) => inspect(target, attempt)));
  report = {
    verifiedAt: new Date().toISOString(),
    attempt,
    baseUrl: base,
    success: results.every((result) => result.ok),
    results
  };
  console.log(`YORUGATARI_LIVE_ATTEMPT=${JSON.stringify(report)}`);
  if (report.success) break;
  if (attempt < attempts) await sleep(delayMilliseconds);
}

fs.writeFileSync('yorugatari-live-report.json', `${JSON.stringify(report, null, 2)}\n`);
if (!report?.success) process.exit(1);
