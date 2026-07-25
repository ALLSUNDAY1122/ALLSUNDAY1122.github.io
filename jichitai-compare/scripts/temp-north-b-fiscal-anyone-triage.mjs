import fs from 'node:fs';
import path from 'node:path';

const projectDir = path.resolve('jichitai-compare');
const sourcePath = path.join(projectDir, 'operations', 'audits', 'north-b-horizontal-url-year-numeric-20260725.json');
const outputPath = path.join(projectDir, 'operations', 'audits', 'north-b-fiscal-anyone-triage-20260725.json');
const source = JSON.parse(fs.readFileSync(sourcePath, 'utf8'));

const highRiskServices = new Set(['temporaryChildcare','schoolMeals','postpartumCare','sickChildCare','childcareFee','housingSupport']);
const currentPattern = /令和8年度|2026年度|令和8年|2026年/;
const historicalStartPattern = /令和[67]年度から|202[45]年度から|202[45]年\d*月?から|開始年度|開始した|無償化を開始/;
const explicitGapPattern = /令和8年度.*(?:確認できない|未確認)|2026年度.*(?:確認できない|未確認)/;
const disasterContextPattern = /ハザードマップ|防災|津波|洪水|土砂|ため池|地震/;

function fiscalCategory(item) {
  const summary = item.summary || '';
  const hasCurrent = currentPattern.test(summary);
  const historicalStart = historicalStartPattern.test(summary);
  const explicitGap = explicitGapPattern.test(summary);
  const oldUrlOnly = (item.oldYearUrls || []).length > 0 && (item.fiscalReferences || []).length === 0;
  const highRisk = highRiskServices.has(item.service);

  if (explicitGap) return { category: 'explicit_current_year_gap', priority: 100, reason: '令和8年度の継続条件を確認できないと明記' };
  if (item.status === 'verified' && highRisk && !hasCurrent && !historicalStart && (item.fiscalReferences || []).length > 0) {
    return { category: 'verified_old_year_without_current_context', priority: 90, reason: '高リスク制度が旧年度表現のみでverified' };
  }
  if (item.status === 'unavailable' && highRisk && !hasCurrent && (item.fiscalReferences || []).length > 0) {
    return { category: 'unavailable_old_year_reference', priority: 80, reason: '旧年度情報のみを根拠にunavailable' };
  }
  if (oldUrlOnly && highRisk) return { category: 'old_year_url_high_risk', priority: 70, reason: '高リスク制度の出典URLに旧年度文字列' };
  if (hasCurrent) return { category: 'current_year_context_present', priority: 20, reason: '令和8年度記載があり旧年度は比較・履歴の可能性' };
  if (historicalStart) return { category: 'historical_start_year', priority: 15, reason: '制度開始年度の履歴表現' };
  if (disasterContextPattern.test(summary)) return { category: 'static_disaster_material', priority: 10, reason: '年度更新頻度が低い防災資料' };
  if (oldUrlOnly) return { category: 'old_year_url_only', priority: 30, reason: 'URL文字列のみ旧年度。本文の現行性を確認' };
  return { category: 'manual_context_review', priority: 50, reason: '旧年度表現の意味を人手確認' };
}

const fiscalCandidates = (source.fiscalYearCandidates || []).map((item) => ({
  ...item,
  ...fiscalCategory(item)
})).sort((a,b) => b.priority - a.priority || a.code.localeCompare(b.code) || a.service.localeCompare(b.service));

function anyonePriority(item) {
  const missing = item.missing || [];
  const missingWeight = {
    startYear: 15,
    targetAge: 25,
    fee: 25,
    facility: 20,
    hoursOrLimit: 25
  };
  let priority = missing.reduce((sum, key) => sum + (missingWeight[key] || 10), 0);
  const summary = item.summary || '';
  if (/令和8年度|2026年度/.test(summary)) priority -= 10;
  if (/通常の一時預かり|一時保育/.test(summary) && !/誰でも通園|乳児等通園支援/.test(summary)) priority -= 20;
  if (missing.length >= 4) priority += 20;
  return Math.max(priority, 0);
}

const anyoneCandidates = (source.anyoneChildcareCompletenessCandidates || []).map((item) => ({
  ...item,
  priority: anyonePriority(item),
  category: (item.missing || []).length >= 4 ? 'major_condition_gap' : (item.missing || []).length >= 2 ? 'multiple_condition_gap' : 'single_condition_gap'
})).sort((a,b) => b.priority - a.priority || a.code.localeCompare(b.code));

const fiscalCategoryCounts = {};
for (const item of fiscalCandidates) fiscalCategoryCounts[item.category] = (fiscalCategoryCounts[item.category] || 0) + 1;
const anyoneCategoryCounts = {};
for (const item of anyoneCandidates) anyoneCategoryCounts[item.category] = (anyoneCategoryCounts[item.category] || 0) + 1;

const report = {
  schemaVersion: '1.0.0',
  auditId: 'north-b-fiscal-anyone-triage-20260725',
  sessionId: 'north-b',
  createdAt: new Date().toISOString(),
  status: 'machine_triage_completed',
  sourceAudit: 'operations/audits/north-b-horizontal-url-year-numeric-20260725.json',
  summary: {
    fiscalCandidateCount: fiscalCandidates.length,
    fiscalPriority80Plus: fiscalCandidates.filter((x) => x.priority >= 80).length,
    fiscalPriority50Plus: fiscalCandidates.filter((x) => x.priority >= 50).length,
    fiscalCategoryCounts,
    anyoneCandidateCount: anyoneCandidates.length,
    anyonePriority70Plus: anyoneCandidates.filter((x) => x.priority >= 70).length,
    anyonePriority50Plus: anyoneCandidates.filter((x) => x.priority >= 50).length,
    anyoneCategoryCounts
  },
  fiscalPriorityQueue: fiscalCandidates,
  anyonePriorityQueue: anyoneCandidates,
  reviewPolicy: '自動分類だけで制度内容やstatusは変更しない。旧年度候補は令和8年度の継続確認、高リスク制度、主出典の現行性を優先する。誰でも通園候補は対象月齢・料金・施設・利用時間/月上限の複数欠落を優先し、利用者向け公式案内がない場合は推測しない。'
};

fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, `${JSON.stringify(report, null, 2)}\n`);
console.log(JSON.stringify(report.summary, null, 2));
