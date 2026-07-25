import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve('jichitai-compare');
const today = '2026-07-25';
const now = '2026-07-25T14:28:00+09:00';
const read = (file) => JSON.parse(fs.readFileSync(file, 'utf8'));
const write = (file, value) => {
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
  console.log(`updated ${path.relative(root, file)}`);
};
const municipalityPath = (code) => path.join(root, 'data', 'municipalities', code.slice(0, 2), `${code}.json`);

function updateMunicipality(code, mutate) {
  const file = municipalityPath(code);
  const data = read(file);
  mutate(data);
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

updateMunicipality('01607', (data) => {
  const service = data.services.temporaryChildcare;
  service.summary = '保育所等を利用していない生後6か月から満3歳未満児が、就労要件を問わず月10時間まで、世帯区分に応じ1時間0円から300円でこども誰でも通園制度を利用できる。';
  service.details = {
    ...service.details,
    facilities: '町内の保育施設および地域子育て支援センター',
    fee: '世帯区分に応じ1時間0円、60円、90円、150円または300円',
    mealFee: '給食を利用する場合は400円',
    payment: '利用施設へ支払い',
    startYear: '利用者向け現行ページでは制度開始年度を明記していないため未確認'
  };
  service.source.checkedAt = today;
});
updateTask('01607', '2026-07-25誰でも通園複数条件監査：町公式ページで町内保育施設・地域子育て支援センター、世帯区分別1時間0～300円、給食400円を確認。開始年度は明記がなく推測しない。');

updateMunicipality('01609', (data) => {
  const service = data.services.temporaryChildcare;
  service.summary = '2026年4月1日から、保育所に在籍していない生後6か月から3歳未満児が、町内3保育所で月10時間まで1時間300円を基本に利用できる。';
  service.details = {
    ...service.details,
    start: '2026年4月1日',
    fee: '1時間300円。世帯区分に応じ150円、60円または無料の負担軽減あり',
    reservation: '認定後に施設面談を行い、予約システムから予約',
    payment: '利用時に現金で事前払い'
  };
  service.source.checkedAt = today;
});
updateTask('01609', '2026-07-25誰でも通園複数条件監査：2026年4月1日開始、町内3保育所、1時間300円、世帯区分別軽減、面談・予約手順を公式ページで再確認。');

updateMunicipality('04212', (data) => {
  const service = data.services.temporaryChildcare;
  service.summary = '2026年度から、保育施設を利用していない生後6か月から満3歳未満児が、就労要件を問わず月10時間まで利用できる。料金は施設ごとに設定する。';
  service.details = {
    ...service.details,
    start: '2026年度',
    facilitiesAsOf: '2026年4月1日時点の実施施設を市公式ページに掲載',
    fee: '施設ごとの設定額を施設へ直接支払い'
  };
  service.source.checkedAt = today;
});
updateTask('04212', '2026-07-25誰でも通園複数条件監査：令和8年度開始を市施政方針で確認。料金は施設ごとの設定額であるため固定額を推測しない。');

updateMunicipality('04444', (data) => {
  const service = data.services.temporaryChildcare;
  service.summary = '2026年4月1日から、保育施設等に在籍していない生後6か月から3歳未満の子どもが、月10時間まで1時間おおむね300円で利用できる。';
  service.details = {
    ...service.details,
    start: '2026年4月1日',
    fee: '1時間おおむね300円。最初の1時間後は30分当たり150円を目安に施設が設定',
    reduction: '生活保護世帯・住民税非課税世帯等は負担軽減の対象',
    facilityGuidance: '実施施設は総合支援システムで確認。令和8年度、わくわくゆめの樹こども園は実施しない'
  };
  service.source.checkedAt = today;
});
updateTask('04444', '2026-07-25誰でも通園複数条件監査：2026年4月1日開始、1時間おおむね300円、30分150円目安、世帯区分別軽減、令和8年度の施設案内を公式ページで確認。');

updateMunicipality('05204', (data) => {
  const service = data.services.temporaryChildcare;
  service.summary = '2026年4月から、未就園の生後6か月から満3歳未満児が市内5施設で月10時間までこども誰でも通園制度を利用できる。利用料は現行公式ページで確認できない。';
  service.details = {
    ...service.details,
    anyoneStart: '2026年4月',
    anyoneFee: '利用者向け現行公式ページでは確認できないため、市または利用施設へ確認が必要'
  };
  service.source.checkedAt = today;
  if (service.additionalSources?.[0]) service.additionalSources[0].checkedAt = today;
});
updateTask('05204', '2026-07-25誰でも通園複数条件監査：令和8年4月開始を市公式告知で確認。対象、月10時間、5施設は維持し、利用料は公式ページで確認できないため未確認と明示。');

updateMunicipality('05361', (data) => {
  const service = data.services.temporaryChildcare;
  service.summary = 'もりやまこども園の一時預かりに加え、2026年4月1日から未就園児向けこども誰でも通園制度を月10時間まで実施する。対象月齢と料金は現行公式情報で確認できない。';
  service.details = {
    ...service.details,
    anyChildUnconfirmed: '対象月齢、利用料金、利用可能時間は町公式の現行案内で確認できないため推測しない'
  };
  service.source.checkedAt = today;
});
updateTask('05361', '2026-07-25誰でも通園複数条件監査：2026年4月1日開始、もりやまこども園、月10時間を再確認。対象月齢・料金・利用時間は未公表のため推測せず未確認と明示。');

updateMunicipality('05434', (data) => {
  const service = data.services.temporaryChildcare;
  service.summary = '2026年度から、美郷町在住の未就園の生後6か月から満3歳未満児が、町内3園で平日・土曜9時から11時30分に月10時間まで1時間300円で利用できる。';
  service.details = {
    ...service.details,
    start: '2026年度',
    facilities: '千畑なかよし園、六郷わくわく園、仙南すこやか園',
    hours: '月曜日から土曜日の9時から11時30分。施設の開園日・受入状況による',
    fee: '1時間300円。最初の1時間後は30分当たり150円',
    reduction: '生活保護世帯、住民税非課税世帯等は負担軽減の対象',
    limit: '子ども1人につき月10時間まで'
  };
  service.source.checkedAt = today;
});
updateTask('05434', '2026-07-25誰でも通園複数条件監査：令和8年度開始、町内3園、月～土9:00～11:30、月10時間、1時間300円、30分150円、負担軽減を公式ページで確認。');

updateMunicipality('06364', (data) => {
  const service = data.services.temporaryChildcare;
  service.summary = '2026年度から、未就園の生後6か月から満3歳未満児が、就労要件を問わず月10時間まで利用できる。利用料は現行公式情報で確認できない。';
  service.details = {
    ...service.details,
    start: '2026年度',
    fee: '町公式の現行案内で確認できないため、利用認定時に町・施設へ確認が必要'
  };
  service.source.checkedAt = today;
});
updateTask('06364', '2026-07-25誰でも通園複数条件監査：令和8年度新規事業、生後6か月～満3歳未満、月10時間を町予算資料で確認。利用料は未確認のため推測しない。');

const auditPath = path.join(root, 'operations', 'audits', 'north-b-anyone-multiple-gap-review-20260725.json');
write(auditPath, {
  schemaVersion: '1.0.0',
  auditId: 'north-b-anyone-multiple-gap-review-20260725',
  sessionId: 'north-b',
  reviewedAt: now,
  status: 'corrections_applied',
  sourceAudit: 'operations/audits/north-b-fiscal-anyone-triage-20260725.json',
  scope: {
    candidatesReviewed: 9,
    municipalitiesCorrected: 8,
    noChangeMunicipalities: 1,
    statusChanges: 0,
    remainingAnyoneCandidates: 65
  },
  corrected: [
    { code: '01607', municipality: '浦河町', result: '世帯区分別1時間0～300円、給食400円、施設範囲を追記。開始年度は未確認を維持' },
    { code: '01609', municipality: 'えりも町', result: '2026年4月1日開始、1時間300円と負担軽減を追記' },
    { code: '04212', municipality: '登米市', result: '2026年度開始を追記。施設ごとの設定料金を維持' },
    { code: '04444', municipality: '色麻町', result: '2026年4月1日開始、1時間おおむね300円、負担軽減を追記' },
    { code: '05204', municipality: '大館市', result: '2026年4月開始を追記。料金は未確認と明示' },
    { code: '05361', municipality: '五城目町', result: '対象月齢・料金・利用時間の未公表を明示' },
    { code: '05434', municipality: '美郷町', result: '2026年度開始、3園、時間、1時間300円、月10時間を追記' },
    { code: '06364', municipality: '真室川町', result: '2026年度開始を追記。料金は未確認と明示' }
  ],
  noChange: [
    { code: '06324', municipality: '大江町', result: '生後6か月～満3歳未満・月10時間は確認済み。開始年度と料金を利用者向け公式情報で確定できないため現状維持' }
  ],
  policy: '開始年度・料金が公式情報で確認できない場合は推測しない。通常一時預かりと誰でも通園制度の条件を混同しない。'
});

const checkpointPath = path.join(root, 'operations', 'control', 'session-checkpoints', 'north-b.json');
const checkpoint = read(checkpointPath);
checkpoint.updatedAt = now;
checkpoint.workingBranch = 'audit/north-b-anyone-multiple-gap-latest-main-20260725';
checkpoint.pullRequestNumber = null;
checkpoint.ciStatus = 'pending';
checkpoint.nextAction = '誰でも通園の複数条件欠落9件の修正・CI・main・region/north・公開反映を完了後、単一条件欠落65件を再確認する。';
checkpoint.fiscalAnyoneAudit = {
  ...(checkpoint.fiscalAnyoneAudit || {}),
  multipleGapReviewed: 9,
  multipleGapCorrectedMunicipalities: ['01607','01609','04212','04444','05204','05361','05434','06364'],
  multipleGapNoChangeMunicipalities: ['06324'],
  remainingAnyonePriorityBelow50: 65,
  multipleGapAuditFile: 'operations/audits/north-b-anyone-multiple-gap-review-20260725.json',
  status: 'multiple_gap_corrections_pending_ci'
};
write(checkpointPath, checkpoint);
