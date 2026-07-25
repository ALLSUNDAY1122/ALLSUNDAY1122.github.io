import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve('jichitai-compare');
const today = '2026-07-25';
const now = '2026-07-25T15:08:00+09:00';
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

updateMunicipality('04214', '2026年4月から、0歳から就学前までの児童を対象とする一時保育に加え、未在園の生後6か月から満3歳未満児が月10時間までこども誰でも通園制度を利用できる。', '2026年4月');
updateTask('04214', '2026-07-25誰でも通園単一条件第2群監査：東松島市公式ページで令和8年4月から実施と確認。');

updateMunicipality('04215', '2026年度から全国で開始されるこども誰でも通園制度として、未就園の生後6か月から満3歳未満児が月10時間まで利用できる。一時預かりは生後6か月から就学前までを対象とする。', '2026年度（市公式ページが全国開始年度として明記）');
updateTask('04215', '2026-07-25誰でも通園単一条件第2群監査：大崎市公式ページで令和8年度から全国自治体で開始と明記され、市内実施施設も現行掲載されていることを確認。');

updateMunicipality('04216', '2026年4月から、未入所の生後6か月以上の未就学児を対象とする一時保育に加え、未就園の生後6か月から満3歳未満児が月10時間までこども誰でも通園制度を利用できる。', '2026年4月');
updateTask('04216', '2026-07-25誰でも通園単一条件第2群監査：富谷市公式ページで令和8年4月から実施と確認。');

updateMunicipality('04321', '2026年度から全国で本格開始するこども誰でも通園制度として、大河原町内の未就園の生後6か月から満3歳未満児が月10時間まで利用できる。通常の一時預かりは生後6か月から就学前までを対象とする。', '2026年度（町公式ページが全国本格開始年度として明記）');
updateTask('04321', '2026-07-25誰でも通園単一条件第2群監査：大河原町公式ページで令和8年度から全国本格開始と明記され、町立桜保育所の現行実施条件も確認。');

updateMunicipality('04323', '2026年4月から、満10か月から就学前までの一時保育に加え、未就園の生後6か月から満3歳未満児が月10時間までこども誰でも通園制度を利用できる。', '2026年4月');
updateTask('04323', '2026-07-25誰でも通園単一条件第2群監査：柴田町公式ページで令和8年4月から実施と確認。');

updateMunicipality('04324', '2026年4月から、町内在住の未就園の生後6か月から満3歳未満児が、かわさきこども園で月10時間までこども誰でも通園制度を利用できる。通常の一時預かりは満10か月以上の未就学児を対象とする。', '2026年4月');
updateTask('04324', '2026-07-25誰でも通園単一条件第2群監査：川崎町公式ページで令和8年4月開始を確認。');

updateMunicipality('04362', '2026年4月から、町内在住の未就園の生後6か月から満3歳未満児が、つばめの杜保育所で月10時間までこども誰でも通園制度を利用できる。通常の一時預かりは生後6か月から就学前までを対象とする。', '2026年4月');
updateTask('04362', '2026-07-25誰でも通園単一条件第2群監査：山元町公式ページで令和8年4月スタートを確認。');

updateMunicipality('04406', '2026年4月1日から、満6か月以上の就学前児童の一時預かりに加え、未就園の生後6か月から満3歳未満児が月10時間までこども誰でも通園制度を利用できる。', '2026年4月1日');
updateTask('04406', '2026-07-25誰でも通園単一条件第2群監査：利府町公式ページで制度利用開始日を令和8年4月1日と確認。');

updateMunicipality('04421', '2026年4月1日から、未就園の生後6か月から満3歳未満児が町内2こども園で月10時間までこども誰でも通園制度を利用できる。通常の一時預かりは生後5か月から6歳児を対象とする。', '2026年4月1日');
updateTask('04421', '2026-07-25誰でも通園単一条件第2群監査：大和町公式ページで利用期間を令和8年4月1日から令和9年3月31日までと確認。');

const auditPath = path.join(root, 'operations', 'audits', 'north-b-anyone-single-gap-batch2-review-20260725.json');
write(auditPath, {
  schemaVersion: '1.0.0',
  auditId: 'north-b-anyone-single-gap-batch2-review-20260725',
  sessionId: 'north-b',
  reviewedAt: now,
  status: 'corrections_applied',
  sourceAudit: 'operations/audits/north-b-fiscal-anyone-triage-20260725.json',
  scope: { candidatesReviewed: 10, municipalitiesCorrected: 9, noChangeMunicipalities: 1, statusChanges: 0, remainingSingleConditionCandidates: 49 },
  corrected: [
    { code: '04214', municipality: '東松島市', result: '令和8年4月から実施を追記' },
    { code: '04215', municipality: '大崎市', result: '令和8年度の全国開始年度を追記' },
    { code: '04216', municipality: '富谷市', result: '令和8年4月から実施を追記' },
    { code: '04321', municipality: '大河原町', result: '令和8年度の全国本格開始年度を追記' },
    { code: '04323', municipality: '柴田町', result: '令和8年4月から実施を追記' },
    { code: '04324', municipality: '川崎町', result: '令和8年4月開始を追記' },
    { code: '04362', municipality: '山元町', result: '令和8年4月開始を追記' },
    { code: '04406', municipality: '利府町', result: '令和8年4月1日開始を追記' },
    { code: '04421', municipality: '大和町', result: '令和8年4月1日開始を追記' }
  ],
  noChange: [
    { code: '04401', municipality: '松島町', result: '現行制度・施設・料金は確認できるが、町公式ページに開始年月の明記がないため現状維持' }
  ],
  policy: 'ページ更新日を制度開始日とみなさない。全国開始年度のみの記載は、その旨を限定して記録する。'
});

const checkpointPath = path.join(root, 'operations', 'control', 'session-checkpoints', 'north-b.json');
const checkpoint = read(checkpointPath);
checkpoint.updatedAt = now;
checkpoint.workingBranch = 'audit/north-b-anyone-single-gap-batch2-20260725';
checkpoint.pullRequestNumber = null;
checkpoint.ciStatus = 'pending';
checkpoint.nextAction = '誰でも通園の単一条件欠落残り49件を優先度順に再確認する。';
checkpoint.fiscalAnyoneAudit = {
  ...(checkpoint.fiscalAnyoneAudit || {}),
  singleGapBatch2Reviewed: 10,
  singleGapBatch2CorrectedMunicipalities: ['04214','04215','04216','04321','04323','04324','04362','04406','04421'],
  singleGapBatch2NoChangeMunicipalities: ['04401'],
  remainingAnyonePriorityBelow50: 49,
  singleGapBatch2AuditFile: 'operations/audits/north-b-anyone-single-gap-batch2-review-20260725.json',
  status: 'single_gap_batch2_corrections_pending_ci'
};
write(checkpointPath, checkpoint);
