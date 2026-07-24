import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const tools = path.join(root, 'yorugatari', 'tools');
const analyticsPath = path.join(tools, 'analytics-snapshot-latest.json');
const conversionPath = path.join(tools, 'landing-conversion-latest.json');
const outputPath = path.join(tools, 'analytics-insights-latest.md');

function readJson(filePath) {
  const value = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  if (!value || value.success !== true) throw new Error(`Successful report required: ${filePath}`);
  return value;
}

function number(value) {
  return Number.isFinite(value) ? new Intl.NumberFormat('ja-JP').format(value) : '—';
}

function delta(value) {
  if (!Number.isFinite(value)) return '—';
  return value > 0 ? `+${number(value)}` : number(value);
}

function percent(value) {
  return Number.isFinite(value) ? `${value.toFixed(1)}%` : '—';
}

const sourceLabels = {
  direct: '直接',
  search: '検索',
  social: 'SNS',
  referral: 'その他の参照',
  campaign: 'キャンペーン'
};

const analytics = readJson(analyticsPath);
const conversion = readJson(conversionPath);
const readiness = analytics.analysis?.dataReadiness || {};
const metrics = analytics.analysis?.metrics || {};
const runDelta = analytics.analysis?.deltasFromPreviousRun || {};

const sources = (analytics.sources || [])
  .map((row) => `| ${sourceLabels[row.channel] || row.channel} | ${number(row.views)} |`)
  .join('\n');
const campaigns = (analytics.campaigns || [])
  .map((row) => `| ${row.label} | ${number(row.views)} | ${row.views >= 10 ? '比較候補' : '収集中'} |`)
  .join('\n');
const conversions = (conversion.landings || [])
  .map((row) => `| ${row.label} | ${number(row.pageViews)} | ${number(row.storyStarts)} | ${percent(row.startRate)} | ${row.comparisonReady ? '比較可能' : '収集中'} |`)
  .join('\n');
const topStories = (analytics.topStories || []).slice(0, 10)
  .map((row, index) => `| ${index + 1} | ${String(row.title || '').replace(/｜夜語り$/, '')} | ${number(row.views)} |`)
  .join('\n');

const reasons = (readiness.reasons || []).map((item) => `- ${item}`);
const actions = [
  ...(analytics.analysis?.actions || []),
  ...(conversion.actions || [])
].filter((item, index, values) => values.indexOf(item) === index).map((item) => `- ${item}`);

const output = `# 夜語り アクセス・特集開始分析\n\n` +
  `生成日時：${analytics.generatedAt}  \n集計日（日本時間）：${analytics.analysis?.japanDate || conversion.japanDate || '—'}\n\n` +
  `## 現在値\n\n` +
  `| 指標 | 累計 | 前回差分 |\n|---|---:|---:|\n` +
  `| 全ページ閲覧 | ${number(analytics.totals?.pageViews)} | ${delta(runDelta.pageViews)} |\n` +
  `| 作品閲覧 | ${number(analytics.totals?.storyViews)} | ${delta(runDelta.storyViews)} |\n` +
  `| 流入区分記録 | ${number(analytics.totals?.sourceLandingViews)} | ${delta(runDelta.sourceLandingViews)} |\n` +
  `| 固定キャンペーン流入 | ${number(analytics.totals?.campaignLandingViews)} | ${delta(runDelta.campaignLandingViews)} |\n` +
  `| 404閲覧 | ${number(analytics.totals?.notFoundViews)} | ${delta(runDelta.notFoundViews)} |\n\n` +
  `作品閲覧比率：${percent(metrics.storyViewShare)}  \n` +
  `閲覧のある作品：${number(metrics.activeStories)}／${number(analytics.coverage?.stories)}話（${percent(metrics.activeStoryRate)}）  \n` +
  `最多閲覧作品の作品閲覧内シェア：${percent(metrics.topStoryShare)}\n\n` +
  `## 特集から作品を読み始めた割合\n\n` +
  `基準値設定：${conversion.baseline?.establishedAt || '—'}  \n` +
  `作品名、作品URL、検索語、個人識別子は開始集計へ含めません。\n\n` +
  `| 特集 | 基準値後の閲覧 | 作品開始 | 開始率 | 判定 |\n|---|---:|---:|---:|---|\n` +
  `${conversions || '| — | — | — | — | データなし |'}\n\n` +
  `合計：閲覧${number(conversion.totals?.landingViews)}件、作品開始${number(conversion.totals?.storyStarts)}件、開始率${percent(conversion.totals?.startRate)}。  \n` +
  `各特集${number(conversion.threshold?.minimumViewsPerLanding)}閲覧に達するまで比較を保留します。\n\n` +
  `## 流入区分\n\n| 区分 | 累計 |\n|---|---:|\n${sources || '| — | — |'}\n\n` +
  `## 固定キャンペーン\n\n| 告知リンク | 流入 | 判定 |\n|---|---:|---|\n${campaigns || '| — | — | データなし |'}\n\n` +
  `告知素材：\`yorugatari/tools/external-launch-kit.md\`\n\n` +
  `## 上位作品（参考値）\n\n| 順位 | 作品 | 閲覧 |\n|---:|---|---:|\n${topStories || '| — | データなし | — |'}\n\n` +
  `## 判定\n\n` +
  `人気順の変更：${readiness.rankingReady ? '実施判断可能' : '保留'}  \n` +
  `流入施策の比較：${readiness.acquisitionReady ? '実施判断可能' : '母数収集中'}  \n` +
  `告知リンクの比較：${readiness.campaignReady ? '実施判断可能' : '母数収集中'}  \n` +
  `特集開始率の比較：${conversion.comparisonReady ? '実施判断可能' : '母数収集中'}\n\n` +
  `${reasons.length ? reasons.join('\n') : '- 通常アクセスの判定上の不足はありません。'}\n` +
  `${conversion.comparisonReady ? '' : `- 各特集の基準値後閲覧が${number(conversion.threshold?.minimumViewsPerLanding)}件未満です。`}\n\n` +
  `## 次に行うこと\n\n${actions.join('\n')}\n`;

fs.writeFileSync(outputPath, output);
console.log(`YORUGATARI_COMBINED_INSIGHTS=${JSON.stringify({ output: outputPath, landingViews: conversion.totals?.landingViews, storyStarts: conversion.totals?.storyStarts, comparisonReady: conversion.comparisonReady })}`);
