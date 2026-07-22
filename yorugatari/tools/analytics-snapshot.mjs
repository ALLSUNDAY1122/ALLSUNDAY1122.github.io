import fs from 'node:fs';
import path from 'node:path';

const ROOT = process.cwd();
const SITE_ROOT = path.join(ROOT, 'yorugatari');
const TOOLS_ROOT = path.join(SITE_ROOT, 'tools');
const LATEST_PATH = path.join(TOOLS_ROOT, 'analytics-snapshot-latest.json');
const HISTORY_PATH = path.join(TOOLS_ROOT, 'analytics-history.json');
const INSIGHTS_PATH = path.join(TOOLS_ROOT, 'analytics-insights-latest.md');
const API = 'https://page-views-api.ratneshc.com/api/v1/views';
const SITE_ID = 'allsunday1122.github.io';
const SOURCE_CHANNELS = ['direct', 'search', 'social', 'referral', 'campaign'];
const SOURCE_LABELS = {
  direct: '直接',
  search: '検索',
  social: 'SNS',
  referral: 'その他の参照',
  campaign: 'キャンペーン'
};
const READINESS_THRESHOLDS = {
  rankingStoryViews: 100,
  rankingActiveStories: 20,
  rankingDays: 7,
  acquisitionSourceLandings: 30
};

function readJson(filePath, fallback) {
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch {
    return fallback;
  }
}

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
        headers: { 'user-agent': 'Yorugatari-Analytics-Snapshot/1.1' },
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

function japanDate(instant = new Date()) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Tokyo',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  }).format(instant);
}

function roundedRatio(numerator, denominator) {
  if (!Number.isFinite(numerator) || !Number.isFinite(denominator) || denominator <= 0) return null;
  return Math.round((numerator / denominator) * 1000) / 10;
}

function delta(current, previous) {
  return Number.isFinite(current) && Number.isFinite(previous) ? current - previous : null;
}

function formatNumber(value) {
  return Number.isFinite(value) ? new Intl.NumberFormat('ja-JP').format(value) : '—';
}

function formatDelta(value) {
  if (!Number.isFinite(value)) return '—';
  return value > 0 ? `+${formatNumber(value)}` : formatNumber(value);
}

function formatPercent(value) {
  return Number.isFinite(value) ? `${value.toFixed(1)}%` : '—';
}

function buildInsightsMarkdown(report) {
  const readiness = report.analysis.dataReadiness;
  const metrics = report.analysis.metrics;
  const runDelta = report.analysis.deltasFromPreviousRun;
  const sourceRows = report.sources
    .map((row) => `| ${SOURCE_LABELS[row.channel] || row.channel} | ${formatNumber(row.views)} |`)
    .join('\n');
  const topRows = report.topStories.slice(0, 10)
    .map((row, index) => `| ${index + 1} | ${row.title.replace(/｜夜語り$/, '')} | ${formatNumber(row.views)} |`)
    .join('\n');
  const actions = report.analysis.actions.map((item) => `- ${item}`).join('\n');
  const reasons = readiness.reasons.map((item) => `- ${item}`).join('\n');

  return `# 夜語り アクセス分析\n\n` +
    `生成日時：${report.generatedAt}  
集計日（日本時間）：${report.analysis.japanDate}\n\n` +
    `## 現在値\n\n` +
    `| 指標 | 累計 | 前回差分 |\n|---|---:|---:|\n` +
    `| 全ページ閲覧 | ${formatNumber(report.totals.pageViews)} | ${formatDelta(runDelta.pageViews)} |\n` +
    `| 作品閲覧 | ${formatNumber(report.totals.storyViews)} | ${formatDelta(runDelta.storyViews)} |\n` +
    `| 流入区分記録 | ${formatNumber(report.totals.sourceLandingViews)} | ${formatDelta(runDelta.sourceLandingViews)} |\n` +
    `| 404閲覧 | ${formatNumber(report.totals.notFoundViews)} | ${formatDelta(runDelta.notFoundViews)} |\n\n` +
    `作品閲覧比率：${formatPercent(metrics.storyViewShare)}  
閲覧のある作品：${formatNumber(metrics.activeStories)}／${formatNumber(report.coverage.stories)}話（${formatPercent(metrics.activeStoryRate)}）  
最多閲覧作品の作品閲覧内シェア：${formatPercent(metrics.topStoryShare)}\n\n` +
    `## 流入区分\n\n| 区分 | 累計 |\n|---|---:|\n${sourceRows}\n\n` +
    `## 上位作品（参考値）\n\n| 順位 | 作品 | 閲覧 |\n|---:|---|---:|\n${topRows || '| — | データなし | — |'}\n\n` +
    `## 判定\n\n` +
    `人気順の変更：${readiness.rankingReady ? '実施判断可能' : '保留'}  
流入施策の比較：${readiness.acquisitionReady ? '実施判断可能' : '母数収集中'}\n\n` +
    `${reasons || '- 判定上の不足はありません。'}\n\n` +
    `## 次に行うこと\n\n${actions}\n`;
}

const previousReport = readJson(LATEST_PATH, null);
const existingHistory = readJson(HISTORY_PATH, []);
const history = Array.isArray(existingHistory) ? existingHistory : [];

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
const notFoundViews = validPages.find((row) => row.type === '404')?.views || 0;
const topStories = stories
  .slice()
  .sort((left, right) => right.views - left.views || left.path.localeCompare(right.path, 'ja'))
  .slice(0, 20);
const activeStories = stories.filter((row) => row.views > 0).length;
const externalSourceViews = sourceRows
  .filter((row) => row.channel !== 'direct' && Number.isFinite(row.views))
  .reduce((sum, row) => sum + row.views, 0);
const currentDate = japanDate();
const priorDates = history.filter((row) => row && row.date && row.date < currentDate).sort((left, right) => left.date.localeCompare(right.date));
const previousDay = priorDates.at(-1) || null;
const observedDays = new Set(history.map((row) => row?.date).filter(Boolean).concat(currentDate)).size;

const previousTotals = previousReport?.totals || {};
const deltasFromPreviousRun = {
  previousGeneratedAt: previousReport?.generatedAt || null,
  pageViews: delta(totalPageViews, previousTotals.pageViews),
  storyViews: delta(totalStoryViews, previousTotals.storyViews),
  sourceLandingViews: delta(sourceTotal, previousTotals.sourceLandingViews),
  notFoundViews: delta(notFoundViews, previousTotals.notFoundViews)
};
const deltasFromPreviousDay = {
  previousDate: previousDay?.date || null,
  pageViews: delta(totalPageViews, previousDay?.totals?.pageViews),
  storyViews: delta(totalStoryViews, previousDay?.totals?.storyViews),
  sourceLandingViews: delta(sourceTotal, previousDay?.totals?.sourceLandingViews),
  notFoundViews: delta(notFoundViews, previousDay?.totals?.notFoundViews)
};

const rankingReady = totalStoryViews >= READINESS_THRESHOLDS.rankingStoryViews &&
  activeStories >= READINESS_THRESHOLDS.rankingActiveStories &&
  observedDays >= READINESS_THRESHOLDS.rankingDays;
const acquisitionReady = sourceTotal >= READINESS_THRESHOLDS.acquisitionSourceLandings;
const readinessReasons = [];
if (totalStoryViews < READINESS_THRESHOLDS.rankingStoryViews) readinessReasons.push(`作品閲覧が${READINESS_THRESHOLDS.rankingStoryViews}件未満のため、人気順位は偶然の影響が大きいです。`);
if (activeStories < READINESS_THRESHOLDS.rankingActiveStories) readinessReasons.push(`閲覧のある作品が${READINESS_THRESHOLDS.rankingActiveStories}話未満です。`);
if (observedDays < READINESS_THRESHOLDS.rankingDays) readinessReasons.push(`日次データが${READINESS_THRESHOLDS.rankingDays}日分未満です。`);
if (!acquisitionReady) readinessReasons.push(`流入区分の記録が${READINESS_THRESHOLDS.acquisitionSourceLandings}件未満です。`);

const actions = [];
if (!rankingReady) actions.push('作品の並び順や「人気」表示は変更せず、データ収集を継続する。');
if (externalSourceViews === 0) actions.push('検索・SNS・外部参照の流入がまだ0件のため、まず外部から1件でも到達する導線を作る。');
else if (!acquisitionReady) actions.push('流入別の優劣はまだ決めず、検索・SNS・参照元の母数を増やす。');
if (notFoundViews === 0) actions.push('404は0件のため、リンク修正より新規流入獲得を優先する。');
else actions.push('404閲覧が発生しているため、参照元リンクと旧URLを確認する。');
if (rankingReady) actions.push('上位作品をトップの推薦枠へ反映するA/B比較を検討する。');

const report = {
  generatedAt: new Date().toISOString(),
  success: errors.length === 0,
  definitions: {
    pageViews: 'Page Views APIが30分単位で重複を除いた累計値',
    sourceViews: '外部からの初回訪問時に1セッション1回だけ送信する粗い流入区分',
    privacy: '参照元URL、検索語、UTMの具体値は保存しない',
    readiness: '作品順位は100作品閲覧・20作品以上の閲覧・7日分の観測が揃うまで変更しない'
  },
  coverage: {
    sitemapUrls: publicUrls.length,
    trackedPages: pagePaths.length,
    stories: stories.length,
    sourceChannels: SOURCE_CHANNELS.length,
    observedDays
  },
  totals: {
    pageViews: totalPageViews,
    storyViews: totalStoryViews,
    sourceLandingViews: sourceTotal,
    notFoundViews
  },
  analysis: {
    japanDate: currentDate,
    deltasFromPreviousRun,
    deltasFromPreviousDay,
    metrics: {
      storyViewShare: roundedRatio(totalStoryViews, totalPageViews),
      activeStories,
      activeStoryRate: roundedRatio(activeStories, stories.length),
      topStoryShare: roundedRatio(topStories[0]?.views || 0, totalStoryViews),
      externalSourceViews,
      directSourceShare: roundedRatio(sourceRows.find((row) => row.channel === 'direct')?.views || 0, sourceTotal),
      notFoundRate: roundedRatio(notFoundViews, totalPageViews)
    },
    dataReadiness: {
      status: rankingReady && acquisitionReady ? 'ready' : 'collecting',
      rankingReady,
      acquisitionReady,
      thresholds: READINESS_THRESHOLDS,
      reasons: readinessReasons
    },
    actions
  },
  sources: sourceRows,
  topStories,
  pages: pageRows,
  errors
};

const historyEntry = {
  date: currentDate,
  generatedAt: report.generatedAt,
  totals: report.totals,
  sources: sourceRows,
  metrics: report.analysis.metrics,
  topStories: topStories.slice(0, 5).map(({ path: storyPath, title, views }) => ({ path: storyPath, title, views }))
};
const nextHistory = history
  .filter((row) => row && row.date && row.date !== currentDate)
  .concat(historyEntry)
  .sort((left, right) => left.date.localeCompare(right.date))
  .slice(-180);

fs.writeFileSync(LATEST_PATH, JSON.stringify(report, null, 2) + '\n');
fs.writeFileSync(HISTORY_PATH, JSON.stringify(nextHistory, null, 2) + '\n');
fs.writeFileSync(INSIGHTS_PATH, buildInsightsMarkdown(report));
console.log(`YORUGATARI_ANALYTICS_SNAPSHOT=${JSON.stringify({ success: report.success, coverage: report.coverage, totals: report.totals, analysis: report.analysis, sources: report.sources, errors: report.errors })}`);
if (!report.success) process.exit(1);
