import fs from 'node:fs';

const file = 'jichitai-compare/operations/control/session-checkpoints/west-b.json';
const data = JSON.parse(fs.readFileSync(file, 'utf8'));
const rv = data.roughValidation ?? {};

const correction = {
  pullRequestNumber: 3142,
  ciRunNumber: 7663,
  mergeCommit: '908a8a04af5fd6c62e73ff75cc875d6a430fded5'
};
const audit = {
  pullRequestNumber: 3147,
  ciRunNumber: 7670,
  mergeCommit: '830a138e4f5ccc8764f746f97f7244ff18acf839'
};

rv.status = 'completed';
rv.plannedCycles = 10;
rv.completedCycles = 10;
rv.auditedMunicipalityCount = 250;
rv.auditedServiceCount = 2250;
rv.remainingMunicipalityCount = 0;
rv.detectedResearchContentErrorCount = 3;
rv.correctedResearchContentErrorCount = 3;
rv.detectedSourceMaintenanceIssueCount = 14;
rv.correctedSourceMaintenanceIssueCount = 14;
rv.completedAt = '2026-07-25T05:02:00+09:00';
rv.totalCheckedUrlCount = 2500;
rv.totalManualSpotCheckCount = 50;
rv.lastCycle = {
  cycle: 10,
  auditPullRequestNumber: audit.pullRequestNumber,
  auditCiRunNumber: audit.ciRunNumber,
  auditMergeCommit: audit.mergeCommit,
  auditFile: 'jichitai-compare/operations/audits/west-b-rough-validation-cycle-10-20260725.json',
  reviewFile: 'jichitai-compare/operations/audits/west-b-rough-validation-cycle-10-review-20260725.json',
  municipalityCount: 25,
  serviceCount: 225,
  checkedUrlCount: 250,
  prefectureCodes: ['47'],
  manualSpotCheckCount: 5,
  contentErrorCount: 0,
  correctedContentErrorCount: 0,
  sourceMaintenanceIssueCount: 2,
  correctedSourceMaintenanceIssueCount: 2,
  networkOnlyWarningCount: 1,
  correctionPullRequestNumbers: [correction.pullRequestNumber],
  correctionCiRunNumbers: [correction.ciRunNumber],
  correctionMergeCommits: [correction.mergeCommit]
};

const history = Array.isArray(rv.cycleHistory) ? rv.cycleHistory.filter(item => Number(item.cycle) < 9) : [];
history.push({
  cycle: 9,
  municipalityCount: 25,
  serviceCount: 225,
  checkedUrlCount: 250,
  contentErrorCount: 1,
  correctedContentErrorCount: 1,
  sourceMaintenanceIssueCount: 3,
  correctedSourceMaintenanceIssueCount: 3,
  networkOnlyWarningCount: 1,
  manualSpotCheckCount: 5,
  auditPullRequestNumber: audit.pullRequestNumber,
  auditCiRunNumber: audit.ciRunNumber,
  correctionPullRequestNumber: correction.pullRequestNumber,
  correctionCiRunNumber: correction.ciRunNumber
});
history.push({
  cycle: 10,
  municipalityCount: 25,
  serviceCount: 225,
  checkedUrlCount: 250,
  contentErrorCount: 0,
  correctedContentErrorCount: 0,
  sourceMaintenanceIssueCount: 2,
  correctedSourceMaintenanceIssueCount: 2,
  networkOnlyWarningCount: 1,
  manualSpotCheckCount: 5,
  auditPullRequestNumber: audit.pullRequestNumber,
  auditCiRunNumber: audit.ciRunNumber,
  correctionPullRequestNumber: correction.pullRequestNumber,
  correctionCiRunNumber: correction.ciRunNumber
});
rv.cycleHistory = history;
rv.nextCycle = null;
rv.completionSummary = {
  municipalityCount: 250,
  serviceCount: 2250,
  checkedUrlCount: 2500,
  manualSpotCheckCount: 50,
  detectedResearchContentErrorCount: 3,
  correctedResearchContentErrorCount: 3,
  detectedSourceMaintenanceIssueCount: 14,
  correctedSourceMaintenanceIssueCount: 14,
  unresolvedIssueCount: 0,
  conclusion: '西日本B担当250自治体・2,250制度の概略検証10回を完了し、検出した内容誤りと出典保守問題を全件修正した。'
};
data.roughValidation = rv;
data.updatedAt = '2026-07-25T05:02:00+09:00';
data.nextAction = '概略検証10回は完了。新規調査は再開せず、公式情報更新・差し戻し・識別異常・CI失敗・公開ページ不具合が発生した場合のみ保守対応する。';

fs.writeFileSync(file, JSON.stringify(data, null, 2) + '\n');
