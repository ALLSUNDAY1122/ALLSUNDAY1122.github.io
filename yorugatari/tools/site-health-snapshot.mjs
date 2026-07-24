import fs from 'node:fs';
import path from 'node:path';

const ROOT = process.cwd();
const TOOLS = path.join(ROOT, 'yorugatari', 'tools');
const OUTPUT_JSON = path.join(TOOLS, 'site-health-latest.json');
const OUTPUT_MD = path.join(TOOLS, 'site-health-latest.md');
const REPORT_VERSION = '20260724-002';

const reportDefinitions = [
  { id: 'seo', label: 'SEO', file: 'seo-audit-latest.json', timestampKeys: ['auditedAt', 'generatedAt'] },
  { id: 'ui', label: 'UI', file: 'ui-audit-latest.json', timestampKeys: ['auditedAt', 'generatedAt'] },
  { id: 'accessibility', label: 'アクセシビリティ', file: 'accessibility-audit-latest.json', timestampKeys: ['auditedAt', 'generatedAt'] },
  { id: 'performance', label: '表示速度', file: 'performance-audit-latest.json', timestampKeys: ['auditedAt', 'generatedAt'] },
  { id: 'engagement', label: '回遊・告知計測', file: 'engagement-audit-latest.json', timestampKeys: ['auditedAt', 'generatedAt'] },
  { id: 'landingShare', label: '特集共有・作品開始', file: 'landing-share-audit-latest.json', timestampKeys: ['auditedAt', 'generatedAt'] }
];

function readJson(filename) {
  const filePath = path.join(TOOLS, filename);
  try {
    return { exists: true, value: JSON.parse(fs.readFileSync(filePath, 'utf8')) };
  } catch (error) {
    return { exists: false, value: null, error: error instanceof Error ? error.message : String(error) };
  }
}

function timestamp(report, keys) {
  for (const key of keys) {
    if (report && typeof report[key] === 'string') return report[key];
  }
  return null;
}

function japanTimestamp(value = new Date()) {
  const date = value instanceof Date ? value : new Date(value);
  if (!Number.isFinite(date.getTime())) return null;
  return new Intl.DateTimeFormat('ja-JP', {
    timeZone: 'Asia/Tokyo', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hour12: false
  }).format(date);
}

function ageHours(value, now) {
  if (!value) return null;
  const instant = new Date(value);
  if (!Number.isFinite(instant.getTime())) return null;
  return Math.round(((now.getTime() - instant.getTime()) / 36e5) * 10) / 10;
}

const now = new Date();
const quality = reportDefinitions.map((definition) => {
  const loaded = readJson(definition.file);
  const observedAt = loaded.exists ? timestamp(loaded.value, definition.timestampKeys) : null;
  return {
    id: definition.id,
    label: definition.label,
    file: definition.file,
    exists: loaded.exists,
    success: loaded.exists && loaded.value?.success === true,
    observedAt,
    observedAtJapan: observedAt ? japanTimestamp(observedAt) : null,
    ageHours: ageHours(observedAt, now),
    error: loaded.error || null
  };
});

const cleanLoaded = readJson('analytics-clean-latest.json');
const rawLoaded = readJson('analytics-snapshot-latest.json');
const conversionLoaded = readJson('landing-conversion-latest.json');
const clean = cleanLoaded.value || {};
const raw = rawLoaded.value || {};
const conversion = conversionLoaded.value || {};
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
  diagnosticCumulativePageViews: raw.totals?.pageViews ?? clean.rawReference?.totals?.pageViews ?? null,
  diagnosticCumulativeStoryViews: raw.totals?.storyViews ?? clean.rawReference?.totals?.storyViews ?? null,
  conversionGeneratedAt: conversion.generatedAt || null,
  landingViewsAfterBaseline: conversion.totals?.landingViews ?? null,
  storyStartsAfterBaseline: conversion.totals?.storyStarts ?? null,
  landingStartRate: conversion.totals?.startRate ?? null,
  conversionComparisonReady: conversion.comparisonReady ?? false
};

const failedQuality = quality.filter((row) => !row.exists || !row.success);
const staleQuality = quality.filter((row) => Number.isFinite(row.ageHours) && row.ageHours > 48);
const actions = [];
if (failedQuality.length) actions.push(`失敗または未保存の監査を修正する：${failedQuality.map((row) => row.label).join('、')}`);
if (staleQuality.length) actions.push(`48時間以上更新されていない監査を再実行する：${staleQuality.map((row) => row.label).join('、')}`);
if ((metrics.externalSourceViews ?? 0) === 0) actions.push('追跡URLを使った外部投稿を1本だけ実行し、検索・SNS・参照流入の着地を確認する。');
if (!metrics.conversionComparisonReady) actions.push('各特集の基準値設定後閲覧が30件に達するまで、見出しや作品選定の優劣を判断しない。');
if (!metrics.rankingReady) actions.push('人気順位や作品の並び順は変更せず、除外後の作品閲覧100件・7日分の観測まで収集を続ける。');
if ((metrics.notFoundViews ?? 0) > 0) actions.push('除外後の404発生パスを確認し、内部リンクまたはサイトマップを修正する。');
if (!actions.length) actions.push('品質監査と判断基準は正常。日次データ収集を継続する。');

const status = failedQuality.length ? 'degraded' : staleQuality.length ? 'stale' : 'healthy';
const snapshot = {
  generatedAt: now.toISOString(),
  generatedAtJapan: japanTimestamp(now),
  version: REPORT_VERSION,
  status,
  success: failedQuality.length === 0,
  quality,
  metrics,
  actions
};

const qualityLines = quality.map((row) => {
  const state = !row.exists ? '未保存' : row.success ? '合格' : '失敗';
  const observed = row.observedAtJapan || '不明';
  const age = Number.isFinite(row.ageHours) ? `${row.ageHours}時間前` : '経過不明';
  return `- ${row.label}: ${state}（${observed}、${age}）`;
});
const metricLines = [
  `- 除外後の全ページ閲覧: ${metrics.pageViews ?? '不明'}`,
  `- 除外後の作品閲覧: ${metrics.storyViews ?? '不明'}`,
  `- 除外後の流入区分: ${metrics.sourceLandingViews ?? '不明'}`,
  `- 除外後の外部流入: ${metrics.externalSourceViews ?? '不明'}`,
  `- 除外後の固定キャンペーン流入: ${metrics.campaignLandingViews ?? '不明'}`,
  `- 除外後の404: ${metrics.notFoundViews ?? '不明'}`,
  `- 診断用累計（全ページ）: ${metrics.diagnosticCumulativePageViews ?? '不明'}`,
  `- 診断用累計（作品）: ${metrics.diagnosticCumulativeStoryViews ?? '不明'}`,
  `- 基準値設定後の特集閲覧: ${metrics.landingViewsAfterBaseline ?? '不明'}`,
  `- 基準値設定後の作品開始: ${metrics.storyStartsAfterBaseline ?? '不明'}`,
  `- 特集開始率: ${metrics.landingStartRate == null ? '判定前' : `${metrics.landingStartRate}%`}`,
  `- 作品順位判定: ${metrics.rankingReady ? '可能' : '保留'}`,
  `- 特集比較判定: ${metrics.conversionComparisonReady ? '可能' : '保留'}`
];
const actionLines = actions.map((action, index) => `${index + 1}. ${action}`);
const markdown = `# 夜語り サイト運用サマリー\n\n生成：${snapshot.generatedAtJapan}（日本時間）  \n状態：${status === 'healthy' ? '正常' : status === 'stale' ? '監査更新待ち' : '要対応'}\n\n自動監査アクセス除外後の値を運用判断に使用します。累計値は診断用です。\n\n## 品質監査\n\n${qualityLines.join('\n')}\n\n## 計測値\n\n${metricLines.join('\n')}\n\n## 次の判断\n\n${actionLines.join('\n')}\n`;

fs.writeFileSync(OUTPUT_JSON, `${JSON.stringify(snapshot, null, 2)}\n`);
fs.writeFileSync(OUTPUT_MD, markdown);
console.log(`YORUGATARI_SITE_HEALTH=${JSON.stringify({ status, success: snapshot.success, failed: failedQuality.map((row) => row.id), stale: staleQuality.map((row) => row.id), metrics, actions })}`);
if (!snapshot.success) process.exitCode = 1;
