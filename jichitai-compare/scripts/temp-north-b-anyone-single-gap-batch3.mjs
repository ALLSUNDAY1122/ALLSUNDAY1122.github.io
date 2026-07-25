import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve('jichitai-compare');
const today = '2026-07-25';
const now = '2026-07-25T15:20:00+09:00';
const read = (file) => JSON.parse(fs.readFileSync(file, 'utf8'));
const write = (file, value) => {
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
  console.log(`updated ${path.relative(root, file)}`);
};
const municipalityPath = (code) => path.join(root, 'data', 'municipalities', code.slice(0, 2), `${code}.json`);

function updateMunicipality(code, summary, start, additionalSource = null) {
  const file = municipalityPath(code);
  const data = read(file);
  const service = data.services.temporaryChildcare;
  service.summary = summary;
  service.details = { ...(service.details || {}), start };
  service.source.checkedAt = today;
  if (additionalSource) {
    service.additionalSources = [...(service.additionalSources || [])];
    if (!service.additionalSources.some((item) => item.url === additionalSource.url)) {
      service.additionalSources.push({ ...additionalSource, checkedAt: today });
    } else {
      service.additionalSources = service.additionalSources.map((item) => item.url === additionalSource.url ? { ...item, checkedAt: today } : item);
    }
  }
  data.updatedAt = today;
  write(file, data);
}

function updateTask(code, note) {
  const municipality = read(municipalityPath(code));
  const file = path.join(root, 'operations', 'tasks', `${code}.json`);
  const task = read(file);
  task.lastCheckedAt = today;
  task.lastUpdatedAt = now;
  task.lastUpdatedBy = '北日本調査班B・品質改善第2監査';
  task.officialSources = [...new Set(Object.values(municipality.services || {})
    .flatMap((service) => [service?.source?.url, ...(service?.additionalSources || []).map((item) => item?.url)])
    .filter(Boolean))];
  task.notes = [...(task.notes || []), note];
  write(file, task);
}

updateMunicipality(
  '04445',
  '2026年度から全国の自治体で開始される制度として、未就園の生後6か月から満3歳未満児が、加美町内2施設で月10時間まで1時間300円で利用できる。',
  '2026年度（町公式ページが全国開始年度として明記し、4月利用分の申請受付を案内）'
);
updateTask('04445', '2026-07-25誰でも通園単一条件第3群監査：加美町公式ページで令和8年度の全国開始年度と、4月利用分の申請受付を確認。町の厳密な開始日とは断定しない。');

updateMunicipality(
  '04505',
  '2026年4月から全国の自治体で実施される制度として、未就園の生後6か月から満3歳未満児が、美里町の実施施設で月10時間まで利用できる。',
  '2026年4月（町公式ページが全国実施開始月として明記）'
);
updateTask('04505', '2026-07-25誰でも通園単一条件第3群監査：美里町公式ページで令和8年4月から全国自治体で実施と確認。町内実施施設も現行掲載。');

updateMunicipality(
  '04581',
  '2026年度から、未就園の生後6か月から満3歳未満児が、女川町子育て支援センターで月10時間まで1時間300円で利用できる。',
  '2026年度'
);
updateTask('04581', '2026-07-25誰でも通園単一条件第3群監査：女川町公式ページで令和8年度より開始と確認。');

updateMunicipality(
  '05202',
  '2026年4月から、市内在住の未就園の生後6か月から満3歳未満児が、保護者の就労要件を問わず月10時間まで1時間300円で利用できる。通常の一時預かりも市内保育所・認定こども園等で実施する。',
  '2026年4月'
);
updateTask('05202', '2026-07-25誰でも通園単一条件第3群監査：能代市公式ページで令和8年4月開始を確認。');

updateMunicipality(
  '05206',
  '2026年4月1日から、未就園の生後6か月から満3歳未満児を、船越こども園で月10時間まで無料で受け入れるこども誰でも通園制度を実施する。通常の一時保育も実施する。',
  '2026年4月1日'
);
updateTask('05206', '2026-07-25誰でも通園単一条件第3群監査：男鹿市公式ページで令和8年度開始、利用期間を令和8年4月1日からと確認。');

updateMunicipality(
  '05207',
  '2024年度から市内で実施しているこども誰でも通園制度を、2026年度から子ども・子育て支援法に基づく給付として継続し、未就園の生後6か月から満3歳未満児が市内2施設で月10時間まで利用できる。',
  '2024年度（2026年度から法定給付へ移行）'
);
updateTask('05207', '2026-07-25誰でも通園単一条件第3群監査：湯沢市公式ページで市内事業は2024年度開始、2026年度から法定給付として全国実施へ移行と確認。');

updateMunicipality(
  '05209',
  '2026年度から、未就園の生後6か月から満3歳未満児が、毛馬内保育園を月10時間まで利用できるこども誰でも通園制度を実施する。通常の一時預かりも実施する。',
  '2026年度',
  { url: 'https://www.city.kazuno.lg.jp/soshiki/somu/gyosei/gyomu/2/4/r8/14219.html' }
);
updateTask('05209', '2026-07-25誰でも通園単一条件第3群監査：鹿角市議会行政報告で令和8年度から毛馬内保育園において実施と確認。');

updateMunicipality(
  '05211',
  '2026年4月から、未就園の生後6か月から満3歳未満児が、市内2施設で月10時間まで1時間300円で利用できる。通常の一時預かりも実施する。',
  '2026年4月'
);
updateTask('05211', '2026-07-25誰でも通園単一条件第3群監査：潟上市公式ページで令和8年4月開始を確認。');

const auditPath = path.join(root, 'operations', 'audits', 'north-b-anyone-single-gap-batch3-review-20260725.json');
write(auditPath, {
  schemaVersion: '1.0.0',
  auditId: 'north-b-anyone-single-gap-batch3-review-20260725',
  sessionId: 'north-b',
  reviewedAt: now,
  status: 'corrections_applied',
  sourceAudit: 'operations/audits/north-b-fiscal-anyone-triage-20260725.json',
  scope: { candidatesReviewed: 10, municipalitiesCorrected: 8, noChangeMunicipalities: 2, statusChanges: 0, remainingSingleConditionCandidates: 39 },
  corrected: [
    { code: '04445', municipality: '加美町', result: '令和8年度の全国開始年度と4月利用分申請受付の文脈を追記' },
    { code: '04505', municipality: '美里町', result: '令和8年4月の全国実施開始月を追記' },
    { code: '04581', municipality: '女川町', result: '令和8年度開始を追記' },
    { code: '05202', municipality: '能代市', result: '令和8年4月開始を追記' },
    { code: '05206', municipality: '男鹿市', result: '令和8年4月1日開始を追記' },
    { code: '05207', municipality: '湯沢市', result: '市内事業は2024年度開始、2026年度から法定給付へ移行と追記' },
    { code: '05209', municipality: '鹿角市', result: '令和8年度開始を市議会行政報告から追記' },
    { code: '05211', municipality: '潟上市', result: '令和8年4月開始を追記' }
  ],
  noChange: [
    { code: '04424', municipality: '大衡村', result: '現行利用案内に開始年月の明記がないため現状維持' },
    { code: '05203', municipality: '横手市', result: '現行利用案内に開始年月の明記がないため現状維持' }
  ],
  policy: 'ページ更新日を制度開始日とみなさない。全国開始年度のみの記載は、その旨を限定して記録する。先行実施自治体は実際の開始年度を優先する。'
});

const checkpointPath = path.join(root, 'operations', 'control', 'session-checkpoints', 'north-b.json');
const checkpoint = read(checkpointPath);
checkpoint.updatedAt = now;
checkpoint.workingBranch = 'audit/north-b-anyone-single-gap-batch3-20260725';
checkpoint.pullRequestNumber = null;
checkpoint.ciStatus = 'pending';
checkpoint.nextAction = '誰でも通園の単一条件欠落残り39件を優先度順に再確認する。';
checkpoint.fiscalAnyoneAudit = {
  ...(checkpoint.fiscalAnyoneAudit || {}),
  singleGapBatch3Reviewed: 10,
  singleGapBatch3CorrectedMunicipalities: ['04445','04505','04581','05202','05206','05207','05209','05211'],
  singleGapBatch3NoChangeMunicipalities: ['04424','05203'],
  remainingAnyonePriorityBelow50: 39,
  singleGapBatch3AuditFile: 'operations/audits/north-b-anyone-single-gap-batch3-review-20260725.json',
  status: 'single_gap_batch3_corrections_pending_ci'
};
write(checkpointPath, checkpoint);
