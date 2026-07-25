import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve('jichitai-compare');
const today = '2026-07-25';
const now = '2026-07-25T14:48:00+09:00';
const read = (file) => JSON.parse(fs.readFileSync(file, 'utf8'));
const write = (file, value) => {
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
  console.log(`updated ${path.relative(root, file)}`);
};
const municipalityPath = (code) => path.join(root, 'data', 'municipalities', code.slice(0, 2), `${code}.json`);

function updateMunicipality(code, summary, start) {
  const file = municipalityPath(code);
  const data = read(file);
  const service = data.services.temporaryChildcare;
  service.summary = summary;
  service.details = { ...(service.details || {}), start };
  service.source.checkedAt = today;
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
    .map((service) => service?.source?.url)
    .filter(Boolean))];
  task.notes = [...(task.notes || []), note];
  write(file, task);
}

updateMunicipality(
  '04202',
  '2026年4月から、保育施設等に在籍していない生後6か月から満3歳未満の子どもが、就労要件を問わず月10時間まで利用できる。',
  '2026年4月'
);
updateTask('04202', '2026-07-25誰でも通園単一条件監査：石巻市公式ページで令和8年4月から実施と確認。');

updateMunicipality(
  '04203',
  '2026年4月から、保育所等を利用していない生後6か月から3歳未満の子どもが、就労要件を問わず月10時間まで利用できる。',
  '2026年4月'
);
updateTask('04203', '2026-07-25誰でも通園単一条件監査：塩竈市公式ページで令和8年4月開始を確認。');

updateMunicipality(
  '04206',
  '2026年4月から、保育所等に在籍していない生後6か月から3歳未満の子どもが、就労要件を問わず月10時間まで利用できる。',
  '2026年4月'
);
updateTask('04206', '2026-07-25誰でも通園単一条件監査：白石市公式ページで令和8年4月から実施と確認。');

updateMunicipality(
  '04207',
  '2026年4月から、保育所等に在籍していない生後6か月から3歳未満の子どもが、就労要件を問わず月10時間まで利用できる。',
  '2026年4月'
);
updateTask('04207', '2026-07-25誰でも通園単一条件監査：名取市公式ページで令和8年4月から実施と確認。');

updateMunicipality(
  '04208',
  '2026年4月1日から、角田市内在住の生後6か月から3歳未満の未就園児が、就労要件を問わず月10時間まで利用できる。',
  '2026年4月1日'
);
updateTask('04208', '2026-07-25誰でも通園単一条件監査：角田市公式ページで制度開始を令和8年4月1日と確認。');

updateMunicipality(
  '04211',
  '2026年4月開始のこども誰でも通園制度として、生後6か月から3歳未満の未就園児が、就労要件を問わず月10時間まで1時間300円で利用できる。',
  '2026年4月（市公式ページが制度の全国一斉開始時期として明記）'
);
updateTask('04211', '2026-07-25誰でも通園単一条件監査：岩沼市公式ページで制度の全国一斉開始時期が令和8年4月と明記され、市内実施施設も現行掲載されていることを確認。');

const auditPath = path.join(root, 'operations', 'audits', 'north-b-anyone-single-gap-batch1-review-20260725.json');
write(auditPath, {
  schemaVersion: '1.0.0',
  auditId: 'north-b-anyone-single-gap-batch1-review-20260725',
  sessionId: 'north-b',
  reviewedAt: now,
  status: 'corrections_applied',
  sourceAudit: 'operations/audits/north-b-fiscal-anyone-triage-20260725.json',
  scope: {
    candidatesReviewed: 10,
    municipalitiesCorrected: 6,
    noChangeMunicipalities: 4,
    statusChanges: 0,
    remainingSingleConditionCandidates: 59
  },
  corrected: [
    { code: '04202', municipality: '石巻市', result: '令和8年4月から実施を追記' },
    { code: '04203', municipality: '塩竈市', result: '令和8年4月開始を追記' },
    { code: '04206', municipality: '白石市', result: '令和8年4月から実施を追記' },
    { code: '04207', municipality: '名取市', result: '令和8年4月から実施を追記' },
    { code: '04208', municipality: '角田市', result: '令和8年4月1日開始を追記' },
    { code: '04211', municipality: '岩沼市', result: '市公式ページに明記された制度の全国一斉開始時期（令和8年4月）を追記' }
  ],
  noChange: [
    { code: '01586', municipality: 'むかわ町', result: '現行利用者向けページに自治体としての開始年月の明記がないため現状維持' },
    { code: '01601', municipality: '日高町', result: '2026年4月8日更新ページで実施条件は確認できるが、開始年月の明記がないため現状維持' },
    { code: '04205', municipality: '気仙沼市', result: '2026年5月27日更新ページで実施条件は確認できるが、開始年月の明記がないため現状維持' },
    { code: '04209', municipality: '多賀城市', result: '2026年4月24日更新ページで実施条件は確認できるが、開始年月の明記がないため現状維持' }
  ],
  policy: 'ページ更新日を制度開始日とみなさない。自治体としての開始年月が明記されている場合のみ補正する。'
});

const checkpointPath = path.join(root, 'operations', 'control', 'session-checkpoints', 'north-b.json');
const checkpoint = read(checkpointPath);
checkpoint.updatedAt = now;
checkpoint.workingBranch = 'audit/north-b-anyone-single-gap-batch1-20260725';
checkpoint.pullRequestNumber = null;
checkpoint.ciStatus = 'pending';
checkpoint.nextAction = '誰でも通園の単一条件欠落残り59件を優先度順に再確認する。';
checkpoint.fiscalAnyoneAudit = {
  ...(checkpoint.fiscalAnyoneAudit || {}),
  singleGapBatch1Reviewed: 10,
  singleGapBatch1CorrectedMunicipalities: ['04202','04203','04206','04207','04208','04211'],
  singleGapBatch1NoChangeMunicipalities: ['01586','01601','04205','04209'],
  remainingAnyonePriorityBelow50: 59,
  singleGapBatch1AuditFile: 'operations/audits/north-b-anyone-single-gap-batch1-review-20260725.json',
  status: 'single_gap_batch1_corrections_pending_ci'
};
write(checkpointPath, checkpoint);
