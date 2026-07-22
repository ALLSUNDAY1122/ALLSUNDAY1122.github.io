import fs from 'node:fs';
import path from 'node:path';

const ROOT = process.cwd();
const SITE_ROOT = path.join(ROOT, 'yorugatari');
const API = 'https://page-views-api.ratneshc.com/api/v1/views';
const SITE_ID = 'allsunday1122.github.io';
const SOURCE_CHANNELS = ['direct', 'search', 'social', 'referral', 'campaign'];

function normalizePath(url) {
  const pathname = new URL(url).pathname.replace(/\/{2,}/g, '/');
  return pathname !== '/' ? pathname.replace(/\/$/, '') : pathname;
}

function pageTitle(trackingPath) {
  if (trackingPath === '/yorugatari/404') return '404 ページが見つかりません';
  const relative = trackingPath === '/yorugatari'
    ? 'index.html'
    : trackingPath.replace(/^\/yorugatari\//, '');
  const filePath = path.join(SITE_ROOT, relative);
  if (!fs.existsSync(filePath)) return trackingPath;
  const html = fs.readFileSync(filePath, 'utf8');
  const match = html.match(/<title>([\s\S]*?)<\/title>/i);
  return match ? match[1].replace(/<[^>]+>/g, '').trim() : trackingPath;
}

async function getViews(trackingPath) {
  const url = API + '?site=' + encodeURIComponent(SITE_ID) + '&path=' + encodeURIComponent(trackingPath);
  let lastError = null;
  for (let attempt = 1; attempt <= 4; attempt += 1) {
    try {
      const response = await fetch(url, {
        headers: { 'user-agent': 'Yorugatari-Analytics-Snapshot/1.0' },
        signal: AbortSignal.timeout(20000)
      });
      if (!response.ok) throw new Error('HTTP ' + response.status);
      const data = await response.json();
      const views = Number(data && data.views);
      if (!Number.isFinite(views) || views < 0) throw new Error('Invalid views response');
      return { trackingPath, views, attempt };
    } catch (error) {
      lastError = error;
      if (attempt < 4) await new Promise((resolve) => setTimeout(resolve, attempt * 750));
    }
  }
  throw new Error(`${trackingPath}: ${lastError?.message || 'request failed'}`);
}

async function mapLimit(items, limit, worker) {
  const output = new Array(items.length);
  let nextIndex = 0;
  async function run() {
    while (true) {
      const index = nextIndex;
      nextIndex += 1;
      if (index >= items.length) return;
      output[index] = await worker(items[index], index);
    }
  }
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, run));
  return output;
}

const sitemap = fs.readFileSync(path.join(SITE_ROOT, 'sitemap.xml'), 'utf8');
const publicUrls = Array.from(sitemap.matchAll(/<loc>([^<]+)<\/loc>/g), (match) => match[1]);
const pagePaths = Array.from(new Set(publicUrls.map(normalizePath).concat('/yorugatari/404')));
const sourcePaths = SOURCE_CHANNELS.map((channel) => `/yorugatari/__source/${channel}`);
const errors = [];

const pageRows = await mapLimit(pagePaths, 6, async (trackingPath) => {
  try {
    const result = await getViews(trackingPath);
    return {
      path: trackingPath,
      title: pageTitle(trackingPath),
      type: trackingPath.includes('/stories/') ? 'story' : (trackingPath.endsWith('/404') ? '404' : 'page'),
      views: result.views
    };
  } catch (error) {
    errors.push({ path: trackingPath, message: error.message });
    return { path: trackingPath, title: pageTitle(trackingPath), type: 'unknown', views: null };
  }
});

const sourceRows = await mapLimit(sourcePaths, 5, async (trackingPath) => {
  const channel = trackingPath.split('/').pop();
  try {
    const result = await getViews(trackingPath);
    return { channel, views: result.views };
  } catch (error) {
    errors.push({ path: trackingPath, message: error.message });
    return { channel, views: null };
  }
});

const validPages = pageRows.filter((row) => Number.isFinite(row.views));
const stories = validPages.filter((row) => row.type === 'story');
const totalPageViews = validPages.reduce((sum, row) => sum + row.views, 0);
const totalStoryViews = stories.reduce((sum, row) => sum + row.views, 0);
const sourceTotal = sourceRows.filter((row) => Number.isFinite(row.views)).reduce((sum, row) => sum + row.views, 0);
const topStories = stories
  .slice()
  .sort((left, right) => right.views - left.views || left.path.localeCompare(right.path, 'ja'))
  .slice(0, 20);

const report = {
  generatedAt: new Date().toISOString(),
  success: errors.length === 0,
  definitions: {
    pageViews: 'Page Views APIが30分単位で重複を除いた累計値',
    sourceViews: '外部からの初回訪問時に1セッション1回だけ送信する粗い流入区分',
    privacy: '参照元URL、検索語、UTMの具体値は保存しない'
  },
  coverage: {
    sitemapUrls: publicUrls.length,
    trackedPages: pagePaths.length,
    stories: stories.length,
    sourceChannels: SOURCE_CHANNELS.length
  },
  totals: {
    pageViews: totalPageViews,
    storyViews: totalStoryViews,
    sourceLandingViews: sourceTotal,
    notFoundViews: validPages.find((row) => row.type === '404')?.views || 0
  },
  sources: sourceRows,
  topStories,
  pages: pageRows,
  errors
};

fs.writeFileSync(path.join(SITE_ROOT, 'tools', 'analytics-snapshot-latest.json'), JSON.stringify(report, null, 2) + '\n');
console.log(`YORUGATARI_ANALYTICS_SNAPSHOT=${JSON.stringify({ success: report.success, coverage: report.coverage, totals: report.totals, sources: report.sources, errors: report.errors })}`);
if (!report.success) process.exit(1);
