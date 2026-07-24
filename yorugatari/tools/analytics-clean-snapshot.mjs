import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const site = path.join(root, 'yorugatari');
const tools = path.join(site, 'tools');
const rawPath = path.join(tools, 'analytics-snapshot-latest.json');
const baselinePath = path.join(tools, 'analytics-clean-baseline.json');
const latestPath = path.join(tools, 'analytics-clean-latest.json');
const historyPath = path.join(tools, 'analytics-clean-history.json');
const resetId = 'audit-filtered-20260724-001';
const runtimeRelease = '20260724-001';
const thresholds = {
  rankingStoryViews: 100,
  rankingActiveStories: 20,
  rankingDays: 7,
  acquisitionExternalLandings: 30,
  campaignTotalLandings: 30,
  campaignVariantLandings: 10
};

function readJson(filePath, fallback) {
  try { return JSON.parse(fs.readFileSync(filePath, 'utf8')); } catch { return fallback; }
}

function japanDate(instant = new Date()) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Tokyo', year: 'numeric', month: '2-digit', day: '2-digit'
  }).format(instant);
}

function requireAuditFilteredRelease() {
  const requirements = [
    ['index.html', `assets/analytics.js?v=20260723-003&r=${runtimeRelease}`],
    ['5min-horror.html', `assets/analytics.js?v=20260724-004&r=${runtimeRelease}`],
    ['5min-horror.html', `assets/landing-start-20260724-001.js?r=${runtimeRelease}`],
    ['bedtime-horror.html', `assets/analytics.js?v=20260724-005&r=${runtimeRelease}`],
    ['bedtime-horror.html', `assets/landing-start-20260724-001.js?r=${runtimeRelease}`],
    ['stories/spare-key-returned.html', `../assets/engagement.js?v=20260723-003&r=${runtimeRelease}`],
    ['privacy.html', '自動監査、Lighthouse、ヘッドレスブラウザ']
  ];
  const missing = [];
  for (const [relativePath, token] of requirements) {
    const text = fs.readFileSync(path.join(site, relativePath), 'utf8');
    if (!text.includes(token)) missing.push({ path: relativePath, token });
  }
  const runtimes = ['analytics.js', 'engagement.js', 'landing-start-20260724-001.js'];
  for (const filename of runtimes) {
    const text = fs.readFileSync(path.join(site, 'assets', filename), 'utf8');
    for (const token of ['isAutomatedRequest', 'HeadlessChrome', 'automatedQuery']) {
      if (!text.includes(token)) missing.push({ path: `assets/${filename}`, token });
    }
  }
  if (missing.length) throw new Error(`Audit-filtered runtime is not fully normalized: ${JSON.stringify(missing)}`);
}

function mapViews(rows, key) {
  return Object.fromEntries((rows || []).filter((row) => row && row[key] && Number.isFinite(row.views)).map((row) => [row[key], row.views]));
}

function cleanRows(rows, key, baselineMap) {
  return (rows || []).map((row) => {
    const cumulativeViews = Number.isFinite(row.views) ? row.views : null;
    const baselineViews = Number.isFinite(baselineMap?.[row[key]]) ? baselineMap[row[key]] : 0;
    const views = Number.isFinite(cumulativeViews) ? Math.max(0, cumulativeViews - baselineViews) : null;
    return { ...row, views, cumulativeViews, baselineViews };
  });
}

function ratio(numerator, denominator) {
  if (!Number.isFinite(numerator) || !Number.isFinite(denominator) || denominator <= 0) return null;
  return Math.round((numerator / denominator) * 1000) / 10;
}

function difference(current, previous) {
  return Number.isFinite(current) && Number.isFinite(previous) ? current - previous : null;
}

requireAuditFilteredRelease();
const raw = readJson(rawPath, null);
if (!raw || raw.success !== true) throw new Error('Successful raw analytics snapshot is required');

let baseline = readJson(baselinePath, null);
if (!baseline || baseline.resetId !== resetId) {
  baseline = {
    resetId,
    runtimeRelease,
    establishedAt: new Date().toISOString(),
    japanDate: japanDate(),
    reason: '自動監査アクセス除外ランタイム公開前の累計値を、運用判断の母数から除外するため',
    rawGeneratedAt: raw.generatedAt,
    totals: raw.totals,
    pages: mapViews(raw.pages, 'path'),
    sources: mapViews(raw.sources, 'channel'),
    campaigns: mapViews(raw.campaigns, 'id')
  };
  fs.writeFileSync(baselinePath, JSON.stringify(baseline, null, 2) + '\n');
}

const pages = cleanRows(raw.pages, 'path', baseline.pages);
const sources = cleanRows(raw.sources, 'channel', baseline.sources);
const campaigns = cleanRows(raw.campaigns, 'id', baseline.campaigns);
const validPages = pages.filter((row) => Number.isFinite(row.views));
const stories = validPages.filter((row) => row.type === 'story');
const totals = {
  pageViews: validPages.reduce((sum, row) => sum + row.views, 0),
  storyViews: stories.reduce((sum, row) => sum + row.views, 0),
  sourceLandingViews: sources.filter((row) => Number.isFinite(row.views)).reduce((sum, row) => sum + row.views, 0),
  campaignLandingViews: campaigns.filter((row) => Number.isFinite(row.views)).reduce((sum, row) => sum + row.views, 0),
  notFoundViews: validPages.find((row) => row.type === '404')?.views || 0
};
const topStories = stories.slice().sort((left, right) => right.views - left.views || left.path.localeCompare(right.path, 'ja')).slice(0, 20);
const activeStories = stories.filter((row) => row.views > 0).length;
const externalSourceViews = sources.filter((row) => row.channel !== 'direct' && Number.isFinite(row.views)).reduce((sum, row) => sum + row.views, 0);
const currentDate = japanDate();
const previous = readJson(latestPath, null);
const history = readJson(historyPath, []);
const observedDays = new Set((Array.isArray(history) ? history : []).map((row) => row?.date).filter(Boolean).concat(currentDate)).size;
const previousTotals = previous?.totals || {};
const deltas = {
  previousGeneratedAt: previous?.generatedAt || null,
  pageViews: difference(totals.pageViews, previousTotals.pageViews),
  storyViews: difference(totals.storyViews, previousTotals.storyViews),
  sourceLandingViews: difference(totals.sourceLandingViews, previousTotals.sourceLandingViews),
  campaignLandingViews: difference(totals.campaignLandingViews, previousTotals.campaignLandingViews),
  notFoundViews: difference(totals.notFoundViews, previousTotals.notFoundViews)
};
const rankingReady = totals.storyViews >= thresholds.rankingStoryViews && activeStories >= thresholds.rankingActiveStories && observedDays >= thresholds.rankingDays;
const acquisitionReady = externalSourceViews >= thresholds.acquisitionExternalLandings;
const campaignReady = totals.campaignLandingViews >= thresholds.campaignTotalLandings && campaigns.some((row) => Number.isFinite(row.views) && row.views >= thresholds.campaignVariantLandings);
const reasons = [];
if (totals.storyViews < thresholds.rankingStoryViews) reasons.push(`除外後の作品閲覧が${thresholds.rankingStoryViews}件未満です。`);
if (activeStories < thresholds.rankingActiveStories) reasons.push(`除外後に閲覧のある作品が${thresholds.rankingActiveStories}話未満です。`);
if (observedDays < thresholds.rankingDays) reasons.push(`除外後の日次データが${thresholds.rankingDays}日分未満です。`);
if (!acquisitionReady) reasons.push(`検索・SNS・外部参照の流入が${thresholds.acquisitionExternalLandings}件未満です。`);
if (!campaignReady) reasons.push(`固定キャンペーン流入が合計${thresholds.campaignTotalLandings}件、かつ1リンク${thresholds.campaignVariantLandings}件の比較基準に達していません。`);
const actions = [];
if (!rankingReady) actions.push('作品の並び順や人気表示は変更せず、除外後データを収集する。');
if (externalSourceViews === 0) actions.push('外部投稿は未実施のため、投稿後の検索・SNS・参照流入を確認する。');
if (!campaignReady) actions.push('固定キャンペーンは投稿証跡があるものだけを比較し、母数到達まで優劣を決めない。');
if (totals.notFoundViews > 0) actions.push('除外後の404発生元を確認する。');

const report = {
  generatedAt: new Date().toISOString(),
  japanDate: currentDate,
  success: true,
  baseline: { resetId: baseline.resetId, runtimeRelease: baseline.runtimeRelease, establishedAt: baseline.establishedAt, rawGeneratedAt: baseline.rawGeneratedAt },
  definitions: {
    views: '自動監査アクセス除外ランタイム公開後の増分',
    cumulativeViews: 'Page Views API上の累計参考値',
    privacy: raw.definitions?.privacy || null
  },
  coverage: { ...raw.coverage, observedDays },
  rawReference: { generatedAt: raw.generatedAt, totals: raw.totals },
  totals,
  analysis: {
    deltasFromPreviousRun: deltas,
    metrics: {
      storyViewShare: ratio(totals.storyViews, totals.pageViews),
      activeStories,
      activeStoryRate: ratio(activeStories, stories.length),
      topStoryShare: ratio(topStories[0]?.views || 0, totals.storyViews),
      externalSourceViews,
      directSourceShare: ratio(sources.find((row) => row.channel === 'direct')?.views || 0, totals.sourceLandingViews),
      campaignShareOfSources: ratio(totals.campaignLandingViews, totals.sourceLandingViews),
      notFoundRate: ratio(totals.notFoundViews, totals.pageViews)
    },
    dataReadiness: { status: rankingReady && acquisitionReady && campaignReady ? 'ready' : 'collecting', rankingReady, acquisitionReady, campaignReady, thresholds, reasons },
    actions
  },
  sources,
  campaigns,
  topStories,
  pages,
  errors: []
};

const historyEntry = {
  date: currentDate,
  generatedAt: report.generatedAt,
  totals,
  metrics: report.analysis.metrics,
  sources: sources.map(({ channel, views }) => ({ channel, views })),
  campaigns: campaigns.map(({ id, label, views }) => ({ id, label, views })),
  topStories: topStories.slice(0, 5).map(({ path: storyPath, title, views }) => ({ path: storyPath, title, views }))
};
const nextHistory = (Array.isArray(history) ? history : []).filter((row) => row?.date !== currentDate).concat(historyEntry).sort((left, right) => left.date.localeCompare(right.date)).slice(-180);
fs.writeFileSync(latestPath, JSON.stringify(report, null, 2) + '\n');
fs.writeFileSync(historyPath, JSON.stringify(nextHistory, null, 2) + '\n');
console.log(`YORUGATARI_CLEAN_ANALYTICS=${JSON.stringify({ success: report.success, baseline: report.baseline, totals: report.totals, readiness: report.analysis.dataReadiness })}`);
