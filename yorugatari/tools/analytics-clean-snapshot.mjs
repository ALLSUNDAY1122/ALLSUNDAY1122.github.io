import fs from 'node:fs';
import path from 'node:path';

const site = path.join(process.cwd(), 'yorugatari');
const tools = path.join(site, 'tools');
const files = {
  raw: path.join(tools, 'analytics-snapshot-latest.json'),
  baseline: path.join(tools, 'analytics-clean-baseline.json'),
  latest: path.join(tools, 'analytics-clean-latest.json'),
  history: path.join(tools, 'analytics-clean-history.json')
};
const resetId = 'audit-filtered-20260724-001';
const release = '20260724-001';
const thresholds = {
  rankingStoryViews: 100,
  rankingActiveStories: 20,
  rankingDays: 7,
  acquisitionExternalLandings: 30,
  campaignTotalLandings: 30,
  campaignVariantLandings: 10
};
const read = (file, fallback) => { try { return JSON.parse(fs.readFileSync(file, 'utf8')); } catch { return fallback; } };
const jstDate = () => new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Tokyo', year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date());
const ratio = (a, b) => Number.isFinite(a) && Number.isFinite(b) && b > 0 ? Math.round(a / b * 1000) / 10 : null;
const diff = (a, b) => Number.isFinite(a) && Number.isFinite(b) ? a - b : null;
const viewMap = (rows, key) => Object.fromEntries((rows || []).filter((row) => row?.[key] && Number.isFinite(row.views)).map((row) => [row[key], row.views]));

function verifyRelease() {
  const pageTokens = [
    ['index.html', `assets/analytics.js?v=20260723-003&r=${release}`],
    ['5min-horror.html', `assets/analytics.js?v=20260724-004&r=${release}`],
    ['5min-horror.html', 'assets/landing-start-20260724-001.js'],
    ['bedtime-horror.html', `assets/analytics.js?v=20260724-005&r=${release}`],
    ['bedtime-horror.html', 'assets/landing-start-20260724-001.js'],
    ['stories/spare-key-returned.html', `../assets/engagement.js?v=20260723-003&r=${release}`],
    ['privacy.html', '自動監査、Lighthouse、ヘッドレスブラウザ']
  ];
  const missing = [];
  for (const [relative, token] of pageTokens) {
    if (!fs.readFileSync(path.join(site, relative), 'utf8').includes(token)) missing.push({ path: relative, token });
  }
  for (const runtime of ['analytics.js', 'engagement.js', 'landing-start-20260724-001.js']) {
    const body = fs.readFileSync(path.join(site, 'assets', runtime), 'utf8');
    for (const token of ['isAutomatedRequest', 'HeadlessChrome', 'automatedQuery']) {
      if (!body.includes(token)) missing.push({ path: `assets/${runtime}`, token });
    }
  }
  if (missing.length) throw new Error(`Audit-filtered runtime is incomplete: ${JSON.stringify(missing)}`);
}

function cleanRows(rows, key, baseline) {
  return (rows || []).map((row) => {
    const cumulativeViews = Number.isFinite(row.views) ? row.views : null;
    const baselineViews = Number.isFinite(baseline?.[row[key]]) ? baseline[row[key]] : 0;
    return { ...row, views: Number.isFinite(cumulativeViews) ? Math.max(0, cumulativeViews - baselineViews) : null, cumulativeViews, baselineViews };
  });
}

verifyRelease();
const raw = read(files.raw, null);
if (!raw?.success) throw new Error('Successful raw analytics snapshot is required');
let baseline = read(files.baseline, null);
if (baseline?.resetId !== resetId) {
  baseline = {
    resetId,
    runtimeRelease: release,
    establishedAt: new Date().toISOString(),
    japanDate: jstDate(),
    reason: '自動監査アクセス除外版の公開前累計を運用判断から除外するため',
    rawGeneratedAt: raw.generatedAt,
    totals: raw.totals,
    pages: viewMap(raw.pages, 'path'),
    sources: viewMap(raw.sources, 'channel'),
    campaigns: viewMap(raw.campaigns, 'id')
  };
  fs.writeFileSync(files.baseline, JSON.stringify(baseline, null, 2) + '\n');
}

const pages = cleanRows(raw.pages, 'path', baseline.pages);
const sources = cleanRows(raw.sources, 'channel', baseline.sources);
const campaigns = cleanRows(raw.campaigns, 'id', baseline.campaigns);
const stories = pages.filter((row) => row.type === 'story' && Number.isFinite(row.views));
const totals = {
  pageViews: pages.filter((row) => Number.isFinite(row.views)).reduce((sum, row) => sum + row.views, 0),
  storyViews: stories.reduce((sum, row) => sum + row.views, 0),
  sourceLandingViews: sources.filter((row) => Number.isFinite(row.views)).reduce((sum, row) => sum + row.views, 0),
  campaignLandingViews: campaigns.filter((row) => Number.isFinite(row.views)).reduce((sum, row) => sum + row.views, 0),
  notFoundViews: pages.find((row) => row.type === '404')?.views || 0
};
const topStories = stories.slice().sort((a, b) => b.views - a.views || a.path.localeCompare(b.path, 'ja')).slice(0, 20);
const activeStories = stories.filter((row) => row.views > 0).length;
const externalSourceViews = sources.filter((row) => row.channel !== 'direct' && Number.isFinite(row.views)).reduce((sum, row) => sum + row.views, 0);
const date = jstDate();
const previous = read(files.latest, null);
const history = read(files.history, []);
const observedDays = new Set((Array.isArray(history) ? history : []).map((row) => row?.date).filter(Boolean).concat(date)).size;
const rankingReady = totals.storyViews >= thresholds.rankingStoryViews && activeStories >= thresholds.rankingActiveStories && observedDays >= thresholds.rankingDays;
const acquisitionReady = externalSourceViews >= thresholds.acquisitionExternalLandings;
const campaignReady = totals.campaignLandingViews >= thresholds.campaignTotalLandings && campaigns.some((row) => row.views >= thresholds.campaignVariantLandings);
const reasons = [];
if (totals.storyViews < thresholds.rankingStoryViews) reasons.push(`除外後の作品閲覧が${thresholds.rankingStoryViews}件未満です。`);
if (activeStories < thresholds.rankingActiveStories) reasons.push(`除外後に閲覧のある作品が${thresholds.rankingActiveStories}話未満です。`);
if (observedDays < thresholds.rankingDays) reasons.push(`除外後の日次データが${thresholds.rankingDays}日分未満です。`);
if (!acquisitionReady) reasons.push(`検索・SNS・外部参照の流入が${thresholds.acquisitionExternalLandings}件未満です。`);
if (!campaignReady) reasons.push(`固定キャンペーン流入が合計${thresholds.campaignTotalLandings}件、かつ1リンク${thresholds.campaignVariantLandings}件の基準未満です。`);
const report = {
  generatedAt: new Date().toISOString(), japanDate: date, success: true,
  baseline: { resetId, runtimeRelease: release, establishedAt: baseline.establishedAt, rawGeneratedAt: baseline.rawGeneratedAt },
  definitions: { views: '自動監査アクセス除外版公開後の増分', cumulativeViews: 'Page Views API上の累計参考値', privacy: raw.definitions?.privacy || null },
  coverage: { ...raw.coverage, observedDays }, rawReference: { generatedAt: raw.generatedAt, totals: raw.totals }, totals,
  analysis: {
    deltasFromPreviousRun: {
      previousGeneratedAt: previous?.generatedAt || null,
      pageViews: diff(totals.pageViews, previous?.totals?.pageViews), storyViews: diff(totals.storyViews, previous?.totals?.storyViews),
      sourceLandingViews: diff(totals.sourceLandingViews, previous?.totals?.sourceLandingViews), campaignLandingViews: diff(totals.campaignLandingViews, previous?.totals?.campaignLandingViews),
      notFoundViews: diff(totals.notFoundViews, previous?.totals?.notFoundViews)
    },
    metrics: {
      storyViewShare: ratio(totals.storyViews, totals.pageViews), activeStories, activeStoryRate: ratio(activeStories, stories.length),
      topStoryShare: ratio(topStories[0]?.views || 0, totals.storyViews), externalSourceViews,
      directSourceShare: ratio(sources.find((row) => row.channel === 'direct')?.views || 0, totals.sourceLandingViews),
      campaignShareOfSources: ratio(totals.campaignLandingViews, totals.sourceLandingViews), notFoundRate: ratio(totals.notFoundViews, totals.pageViews)
    },
    dataReadiness: { status: rankingReady && acquisitionReady && campaignReady ? 'ready' : 'collecting', rankingReady, acquisitionReady, campaignReady, thresholds, reasons },
    actions: ['除外前の累計を人気順や施策比較に使用しない。', '外部投稿が記録されるまでキャンペーン0件を不振と判定しない。', '基準到達まで作品の並び順と人気表示を変更しない。']
  },
  sources, campaigns, topStories, pages, errors: []
};
const entry = { date, generatedAt: report.generatedAt, totals, metrics: report.analysis.metrics };
const nextHistory = (Array.isArray(history) ? history : []).filter((row) => row?.date !== date).concat(entry).sort((a, b) => a.date.localeCompare(b.date)).slice(-180);
fs.writeFileSync(files.latest, JSON.stringify(report, null, 2) + '\n');
fs.writeFileSync(files.history, JSON.stringify(nextHistory, null, 2) + '\n');
console.log(`YORUGATARI_CLEAN_ANALYTICS=${JSON.stringify({ success: true, baseline: report.baseline, totals, readiness: report.analysis.dataReadiness })}`);
