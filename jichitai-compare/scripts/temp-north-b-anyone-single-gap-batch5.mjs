import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve('jichitai-compare');
const today = '2026-07-25';
const now = '2026-07-25T16:25:00+09:00';
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
    if (!service.additionalSources.some((item) => item.url === additionalSource)) {
      service.additionalSources.push({ url: additionalSource, checkedAt: today });
    } else {
      service.additionalSources = service.additionalSources.map((item) => item.url === additionalSource ? { ...item, checkedAt: today } : item);
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
    .map((service) => service?.source?.url)
    .filter(Boolean))];
  task.notes = [...(task.notes || []), note];
  write(file, task);
}

updateMunicipality(
  '06204',
  '2026年度から全国で実施される制度として、酒田市在住の生後6か月から3歳未満の未就園児が月10時間まで利用できる。市内施設では2026年4月から順次受入れを開始する。',
  '2026年4月（最初の実施施設。6月・7月に順次追加）'
);
updateTask('06204', '2026-07-25誰でも通園単一条件第5群監査：酒田市公式の実施予定施設一覧で、最初の施設が令和8年4月開始、以後6月・7月に順次追加と確認。');

updateMunicipality(
  '06207',
  '2026年4月から、未就園の生後6か月から満3歳未満児が、就労要件を問わず月10時間まで1時間300円で利用できる。',
  '2026年4月'
);
updateTask('06207', '2026-07-25誰でも通園単一条件第5群監査：上山市公式ページで令和8年4月から実施と確認。');

updateMunicipality(
  '06208',
  '2026年度に開始した制度として、未就園の生後6か月から満3歳未満児が、村山市ひばり保育園を月10時間まで1時間300円で利用できる。',
  '2026年度（市広報が制度開始を案内。厳密な開始日は未確認）',
  'https://www.city.murayama.lg.jp/shisei/kokoku/shiminnnotomo/r8_siminnotomo.html'
);
updateTask('06208', '2026-07-25誰でも通園単一条件第5群監査：令和8年度市広報一覧で「こども誰でも通園制度開始」を確認し、現行利用者向け公式ページで実施条件を再確認。厳密な開始日は断定しない。');

updateMunicipality(
  '06209',
  '2026年4月から、未就園の生後6か月から満3歳未満児が、保護者の就労要件を問わず月10時間まで利用できる。',
  '2026年4月'
);
updateTask('06209', '2026-07-25誰でも通園単一条件第5群監査：長井市公式ページで令和8年4月から実施と確認。');

updateMunicipality(
  '06210',
  '2026年1月13日から最初の3施設で開始し、その後、市立保育園等へ順次拡大した。未就園の生後6か月から3歳未満児が月10時間まで利用できる。',
  '2026年1月13日（最初の3施設。以後順次追加）'
);
updateTask('06210', '2026-07-25誰でも通園単一条件第5群監査：天童市公式の施設一覧で、小百合保育園等3施設が令和8年1月13日開始、以後2月・5月・6月に順次追加と確認。');

updateMunicipality(
  '06211',
  '2026年度に市内3施設で開始した制度として、未就園の生後6か月から3歳未満児が、保護者の就労要件を問わず月10時間まで1時間300円で利用できる。',
  '2026年度（市施政方針と現行利用案内で市内3施設の実施を確認）',
  'https://www.city.higashine.yamagata.jp/section_list/section001/room/878'
);
updateTask('06211', '2026-07-25誰でも通園単一条件第5群監査：令和8年度施政方針で市内3施設の実施予定を確認し、現行利用案内で3施設の実施を確認。厳密な開始日は断定しない。');

updateMunicipality(
  '06301',
  '2026年度から全国で実施される制度として、未就園の生後6か月から3歳未満児が、安達峰一郎記念保育所を月10時間まで1時間300円で利用できる。',
  '2026年度（町計画の全国実施年度と現行町内実施を確認。町固有の開始日は未公表）',
  'https://www.town.yamanobe.yamagata.jp/soshiki/8/kodomokosodate.html'
);
updateTask('06301', '2026-07-25誰でも通園単一条件第5群監査：町子ども・子育て支援事業計画で令和8年度の全国実施を確認し、現行利用案内で町内実施を確認。町固有の開始日は断定しない。');

const auditPath = path.join(root, 'operations', 'audits', 'north-b-anyone-single-gap-batch5-review-20260725.json');
write(auditPath, {
  schemaVersion: '1.0.0',
  auditId: 'north-b-anyone-single-gap-batch5-review-20260725',
  sessionId: 'north-b',
  reviewedAt: now,
  status: 'corrections_applied',
  sourceAudit: 'operations/audits/north-b-fiscal-anyone-triage-20260725.json',
  scope: {
    candidatesReviewed: 10,
    municipalitiesCorrected: 7,
    noChangeMunicipalities: 3,
    statusChanges: 0,
    remainingSingleConditionCandidates: 22
  },
  corrected: [
    { code: '06204', municipality: '酒田市', result: '令和8年4月から施設を順次開始したことを追記' },
    { code: '06207', municipality: '上山市', result: '令和8年4月開始を追記' },
    { code: '06208', municipality: '村山市', result: '令和8年度開始を市広報から限定追記' },
    { code: '06209', municipality: '長井市', result: '令和8年4月開始を追記' },
    { code: '06210', municipality: '天童市', result: '最初の3施設の令和8年1月13日開始と順次拡大を追記' },
    { code: '06211', municipality: '東根市', result: '令和8年度の市内3施設実施を限定追記' },
    { code: '06301', municipality: '山辺町', result: '令和8年度の全国実施年度と町内実施を限定追記' }
  ],
  noChange: [
    { code: '06205', municipality: '新庄市', result: '現行公式案内に自治体固有の開始時期の明記がないため現状維持' },
    { code: '06206', municipality: '寒河江市', result: '現行公式案内に自治体固有の開始時期の明記がないため現状維持' },
    { code: '06212', municipality: '尾花沢市', result: '利用上限・時間等を示す現行利用者向け公式案内を確認できないため現状維持' }
  ],
  policy: 'ページ更新日を制度開始日とみなさない。自治体固有日がない場合は、公式計画・施政方針・広報で確認できる年度と現行実施を限定して記録する。'
});

const checkpointPath = path.join(root, 'operations', 'control', 'session-checkpoints', 'north-b.json');
const checkpoint = read(checkpointPath);
checkpoint.updatedAt = now;
checkpoint.workingBranch = 'audit/north-b-anyone-single-gap-batch5-20260725';
checkpoint.pullRequestNumber = null;
checkpoint.ciStatus = 'pending';
checkpoint.nextAction = '誰でも通園の単一条件欠落残り22件を優先度順に再確認する。';
checkpoint.fiscalAnyoneAudit = {
  ...(checkpoint.fiscalAnyoneAudit || {}),
  singleGapBatch5Reviewed: 10,
  singleGapBatch5CorrectedMunicipalities: ['06204','06207','06208','06209','06210','06211','06301'],
  singleGapBatch5NoChangeMunicipalities: ['06205','06206','06212'],
  remainingAnyonePriorityBelow50: 22,
  singleGapBatch5AuditFile: 'operations/audits/north-b-anyone-single-gap-batch5-review-20260725.json',
  status: 'single_gap_batch5_corrections_pending_ci'
};
write(checkpointPath, checkpoint);
