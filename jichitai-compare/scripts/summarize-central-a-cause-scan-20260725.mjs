import fs from 'node:fs';
import path from 'node:path';

const root = 'jichitai-compare';
const reportPath = path.join(root, 'operations', 'audits', 'central-a-cause-based-rescan-20260725.json');
const outputPath = path.join(root, 'operations', 'audits', 'central-a-cause-based-rescan-summary-20260725.json');
const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
const expected = {'16':15,'17':19,'18':17,'21':42,'22':35,'23':54,'24':29,'25':19,'27':43,'28':41};
const prefectureCounts = {};
const prefectureCodes = {};
for (const pref of Object.keys(expected)) {
  const dir = path.join(root, 'data', 'municipalities', pref);
  const codes = fs.readdirSync(dir).filter(f => /^\d{5}\.json$/.test(f)).map(f => f.replace('.json','')).sort();
  prefectureCounts[pref] = { expected: expected[pref], actual: codes.length, difference: codes.length - expected[pref] };
  prefectureCodes[pref] = codes;
}
const structuralTypes = {};
for (const finding of report.structuralAudit.findings) structuralTypes[finding.type] = (structuralTypes[finding.type] ?? 0) + 1;
const nonReachable = report.officialUrlRecheck.results.filter(x => !x.ok);
const keywordMisses = [];
for (const result of report.officialUrlRecheck.results) {
  for (const [pair, matched] of Object.entries(result.keywordResults ?? {})) {
    if (matched === false) keywordMisses.push({ pair, url: result.url, status: result.status, finalUrl: result.finalUrl });
  }
}
const correctedFailures = report.previousAudit.officialSourceRecheck.filter(x => x.nonReachable.length > 0);
const categories = {};
for (const [name, items] of Object.entries(report.causeCandidates.categories ?? {})) {
  categories[name] = items.map(x => ({ code:x.code, name:x.name, prefecture:x.prefecture, service:x.service, status:x.status, sourceUrl:x.sourceUrl, reasons:x.reasons }));
}
const summary = {
  schemaVersion: '1.0.0',
  auditId: 'central-a-cause-based-rescan-summary-20260725',
  generatedAt: new Date().toISOString(),
  sourceAudit: report.auditId,
  scope: report.scope,
  prefectureCounts,
  prefectureCodes,
  issue3141: report.issue3141,
  previousCorrectedMunicipalities: {
    count: report.previousAudit.correctedMunicipalityCount,
    codes: report.previousAudit.correctedMunicipalityCodes,
    officialSourceRecheckFailureMunicipalityCount: correctedFailures.length,
    failures: correctedFailures
  },
  structuralAudit: {
    findingCount: report.structuralAudit.findingCount,
    typeCounts: structuralTypes,
    findings: report.structuralAudit.findings
  },
  causeCandidates: {
    counts: report.causeCandidates.counts,
    categories
  },
  officialUrlRecheck: {
    uniqueUrlCount: report.officialUrlRecheck.uniqueUrlCount,
    reachableCount: report.officialUrlRecheck.reachableCount,
    nonReachableCount: report.officialUrlRecheck.nonReachableCount,
    nonReachable,
    keywordMissCount: keywordMisses.length,
    keywordMisses
  },
  decisionRule: '機械候補は誤り確定ではない。公式利用者向けページの対象・料金・施設・期間・申請条件を確認後にのみ修正する。'
};
fs.writeFileSync(outputPath, JSON.stringify(summary, null, 2) + '\n');
console.log(JSON.stringify({outputPath, scope:summary.scope, prefectureCounts, structuralTypes, candidateCounts:summary.causeCandidates.counts, nonReachableCount:summary.officialUrlRecheck.nonReachableCount, keywordMissCount:summary.officialUrlRecheck.keywordMissCount}, null, 2));
