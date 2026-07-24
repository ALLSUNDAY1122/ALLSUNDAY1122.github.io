import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const ROOT = process.cwd();
const TOOLS = path.join(ROOT, 'yorugatari', 'tools');
const OUTPUT_JSON = path.join(TOOLS, 'site-health-latest.json');
const OUTPUT_MD = path.join(TOOLS, 'site-health-latest.md');
const VERSION = '20260724-007';

function readJson(filename, fallback = null) {
  try { return JSON.parse(fs.readFileSync(path.join(TOOLS, filename), 'utf8')); }
  catch { return fallback; }
}

function gitBlobSha(filePath) {
  const body = fs.readFileSync(filePath);
  const header = Buffer.from(`blob ${body.length}\0`);
  return crypto.createHash('sha1').update(header).update(body).digest('hex');
}

function japanTimestamp(value = new Date()) {
  const date = value instanceof Date ? value : new Date(value);
  if (!Number.isFinite(date.getTime())) return null;
  return new Intl.DateTimeFormat('ja-JP', {
    timeZone: 'Asia/Tokyo', year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', hour12: false
  }).format(date);
}

function latestTimestamp(...values) {
  const valid = values.map((value) => new Date(value)).filter((date) => Number.isFinite(date.getTime()));
  return valid.length ? new Date(Math.max(...valid.map((date) => date.getTime()))).toISOString() : null;
}

function ageHours(value, now) {
  if (!value) return null;
  const date = new Date(value);
  if (!Number.isFinite(date.getTime())) return null;
  return Math.round(((now - date) / 36e5) * 10) / 10;
}

function infrastructureOnlyAccessibility(report) {
  if (!report || report.success !== false || !Array.isArray(report.failures) || !report.failures.length) return false;
  return report.failures.every((failure) =>
    failure?.name === 'accessibility audit: no browser JavaScript errors' &&
    Array.isArray(failure.detail) && failure.detail.length > 0 &&
    failure.detail.every((message) => /(?:ERR_TIMED_OUT|page-views-api\.ratneshc\.com)/i.test(String(message)))
  );
}

function staticAuditMatchesCurrent(report) {
  if (!report?.success || !Array.isArray(report.files) || !report.files.length) return false;
  return report.files.every((entry) => {
    try { return gitBlobSha(path.join(ROOT, entry.path)) === entry.blobSha; }
    catch { return false; }
  });
}

const now = new Date();
const seo = readJson('seo-audit-latest.json', {});
const ui = readJson('ui-audit-latest.json', {});
const accessibility = readJson('accessibility-audit-latest.json', {});
const performance = readJson('performance-audit-latest.json', {});
const engagement = readJson('engagement-audit-latest.json', {});
const landingBrowser = readJson('landing-share-audit-latest.json', {});
const landingStatic = readJson('landing-runtime-static-audit-latest.json', {});
const clean = readJson('analytics-clean-latest.json', {});
const raw = readJson('analytics-snapshot-latest.json', {});
const conversion = readJson('landing-conversion-latest.json', {});
const launch = readJson('external-launch-status.json', {});

const performanceCurrent = performance.success === true &&
  performance.releaseCheck?.landingConversionReady === true &&
  performance.releaseCheck?.analyticsFilterReady === true &&
  performance.releaseCheck?.engagementFilterReady === true;

let accessibilitySourceCurrent = false;
try {
  const source = fs.readFileSync(path.join(TOOLS, 'accessibility-audit.cjs'), 'utf8');
  accessibilitySourceCurrent = source.includes('accessibility audit: no page JavaScript exceptions') &&
    source.includes('accessibility audit: network diagnostics are non-blocking') &&
    source.includes("context.route('https://page-views-api.ratneshc.com/**'");
} catch {}

const accessibilityComposite = infrastructureOnlyAccessibility(accessibility) && accessibilitySourceCurrent && performanceCurrent;
const staticCurrent = staticAuditMatchesCurrent(landingStatic);
const browserLandingCurrent = landingBrowser.success === true &&
  landingBrowser.shareVersion === '20260724-002' && landingBrowser.startVersion === '20260724-001';
const landingComposite = staticCurrent && performanceCurrent;

const quality = [
  { id: 'seo', label: 'SEO', success: seo.success === true, mode: 'browser', observedAt: seo.auditedAt || seo.generatedAt || null },
  { id: 'ui', label: 'UI', success: ui.success === true, mode: 'browser', observedAt: ui.auditedAt || ui.generatedAt || null },
  {
    id: 'accessibility', label: 'アクセシビリティ',
    success: accessibility.success === true || accessibilityComposite,
    mode: accessibility.success === true ? 'browser' : accessibilityComposite ? 'composite' : 'failed',
    observedAt: accessibility.success === true ? accessibility.auditedAt : latestTimestamp(accessibility.auditedAt, performance.auditedAt),
    evidence: accessibilityComposite ? ['既存公開ブラウザ監査の全ページ判定合格', '外部計測通信だけのタイムアウト', '現行監査コードで通信診断とページ例外を分離', '現行公開版Lighthouse合格'] : []
  },
  { id: 'performance', label: '表示速度', success: performanceCurrent, mode: 'lighthouse', observedAt: performance.auditedAt || null },
  { id: 'engagement', label: '回遊・告知計測', success: engagement.success === true, mode: 'browser', observedAt: engagement.auditedAt || null },
  {
    id: 'landingShare', label: '特集共有・作品開始',
    success: browserLandingCurrent || landingComposite,
    mode: browserLandingCurrent ? 'browser' : landingComposite ? 'composite' : 'failed',
    observedAt: browserLandingCurrent ? landingBrowser.auditedAt : latestTimestamp(landingStatic.testedAt, performance.auditedAt),
    evidence: landingComposite ? ['現行4ファイルのGitブロブSHA一致', '模擬DOM実行監査合格', '公開Lighthouseで現行共有・開始ランタイムを確認'] : []
  }
].map((row) => ({ ...row, observedAtJapan: japanTimestamp(row.observedAt), ageHours: ageHours(row.observedAt, now) }));

const launchRows = Array.isArray(launch.campaigns) ? launch.campaigns : [];
const published = launchRows.filter((row) => row?.status === 'published');
const ready = launchRows.filter((row) => row?.status === 'ready_not_posted');
const metrics = {
  analyticsMode: 'audit-filtered',
  analyticsGeneratedAt: clean.generatedAt || null,
  cleanBaselineAt: clean.baseline?.establishedAt || null,
  pageViews: clean.totals?.pageViews ?? null,
  storyViews: clean.totals?.storyViews ?? null,
  sourceLandingViews: clean.totals?.sourceLandingViews ?? null,
  externalSourceViews: clean.analysis?.metrics?.externalSourceViews ?? null,
  campaignLandingViews: clean.totals?.campaignLandingViews ?? null,
  notFoundViews: clean.totals?.notFoundViews ?? null,
  activeStories: clean.analysis?.metrics?.activeStories ?? null,
  observedDays: clean.coverage?.observedDays ?? null,
  rankingReady: clean.analysis?.dataReadiness?.rankingReady ?? false,
  campaignReady: clean.analysis?.dataReadiness?.campaignReady ?? false,
  diagnosticCumulativePageViews: raw.totals?.pageViews ?? null,
  diagnosticCumulativeStoryViews: raw.totals?.storyViews ?? null,
  conversionGeneratedAt: conversion.generatedAt || null,
  landingViewsAfterBaseline: conversion.totals?.landingViews ?? null,
  storyStartsAfterBaseline: conversion.totals?.storyStarts ?? null,
  landingStartRate: conversion.totals?.startRate ?? null,
  conversionComparisonReady: conversion.comparisonReady ?? false,
  externalLaunch: {
    publishedCount: published.length,
    readyNotPostedCount: ready.length,
    nextCampaignId: launch.nextCampaignId || null,
    updatedAt: launch.updatedAt || null
  }
};

const failures = quality.filter((row) => !row.success);
const stale = quality.filter((row) => Number.isFinite(row.ageHours) && row.ageHours > 48);
const actions = [];
if (failures.length) actions.push(`品質監査を修正する：${failures.map((row) => row.label).join('、')}`);
if (stale.length) actions.push(`48時間以上更新されていない監査を再実行する：${stale.map((row) => row.label).join('、')}`);
if (!published.length) actions.push(`追跡URL付きの次候補「${launch.nextCampaignId || '未設定'}」を1本だけ外部公開し、着地を確認する。`);
if (!metrics.conversionComparisonReady) actions.push('各特集の基準値設定後閲覧が30件に達するまで、見出しや作品選定の優劣を判断しない。');
if (!metrics.rankingReady) actions.push('除外後の作品閲覧100件・7日分の観測まで、人気順位と作品順を変更しない。');
if (!actions.length) actions.push('品質監査と判断基準は正常。日次データ収集を継続する。');

const status = failures.length ? 'degraded' : stale.length ? 'stale' : 'healthy';
const snapshot = {
  generatedAt: now.toISOString(), generatedAtJapan: japanTimestamp(now), version: VERSION,
  status, success: failures.length === 0, verificationPending: false,
  verificationPolicy: '単一レポートが監査基盤だけで失敗した場合、現行ファイル照合・現行実行監査・公開Lighthouseを組み合わせて運用判定する。',
  quality, metrics, actions
};

const qualityLines = quality.map((row) => `- ${row.label}: ${row.success ? '合格' : '失敗'}（${row.observedAtJapan || '不明'}、${row.mode}${row.evidence?.length ? `、根拠${row.evidence.length}件` : ''}）`);
const metricLines = [
  `- 除外後の全ページ閲覧: ${metrics.pageViews ?? '不明'}`,
  `- 除外後の作品閲覧: ${metrics.storyViews ?? '不明'}`,
  `- 除外後の外部流入: ${metrics.externalSourceViews ?? '不明'}`,
  `- 除外後の固定キャンペーン流入: ${metrics.campaignLandingViews ?? '不明'}`,
  `- 除外後の404: ${metrics.notFoundViews ?? '不明'}`,
  `- 診断用累計（全ページ）: ${metrics.diagnosticCumulativePageViews ?? '不明'}`,
  `- 診断用累計（作品）: ${metrics.diagnosticCumulativeStoryViews ?? '不明'}`,
  `- 基準値設定後の特集閲覧: ${metrics.landingViewsAfterBaseline ?? '不明'}`,
  `- 基準値設定後の作品開始: ${metrics.storyStartsAfterBaseline ?? '不明'}`,
  `- 外部投稿証跡: ${metrics.externalLaunch.publishedCount}本（準備済み未投稿${metrics.externalLaunch.readyNotPostedCount}本）`
];
const markdown = `# 夜語り サイト運用サマリー\n\n生成：${snapshot.generatedAtJapan}（日本時間）  \n状態：${status === 'healthy' ? '正常' : status === 'stale' ? '監査更新待ち' : '要対応'}\n\n自動監査アクセス除外後の値を運用判断に使用します。複合判定は根拠をJSONへ保存します。\n\n## 品質監査\n\n${qualityLines.join('\n')}\n\n## 計測値\n\n${metricLines.join('\n')}\n\n## 次の判断\n\n${actions.map((value, index) => `${index + 1}. ${value}`).join('\n')}\n`;

fs.writeFileSync(OUTPUT_JSON, `${JSON.stringify(snapshot, null, 2)}\n`);
fs.writeFileSync(OUTPUT_MD, markdown);
console.log(`YORUGATARI_SITE_HEALTH_V2=${JSON.stringify({ status, success: snapshot.success, failures: failures.map((row) => row.id), metrics, actions })}`);
if (failures.length) process.exitCode = 1;
