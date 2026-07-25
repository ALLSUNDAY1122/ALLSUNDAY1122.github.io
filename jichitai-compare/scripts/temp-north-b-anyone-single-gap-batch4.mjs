import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve('jichitai-compare');
const today = '2026-07-25';
const now = '2026-07-25T15:52:00+09:00';
const read = (file) => JSON.parse(fs.readFileSync(file, 'utf8'));
const write = (file, value) => fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
const municipalityPath = (code) => path.join(root, 'data', 'municipalities', code.slice(0, 2), `${code}.json`);

function updateMunicipality(code, summary, start, additionalSources = []) {
  const file = municipalityPath(code);
  const data = read(file);
  const service = data.services.temporaryChildcare;
  service.summary = summary;
  service.details = { ...(service.details || {}), start };
  service.source.checkedAt = today;
  if (additionalSources.length) {
    const current = service.additionalSources || [];
    const merged = [...current];
    for (const source of additionalSources) {
      const index = merged.findIndex((item) => item.url === source.url);
      const next = { ...source, checkedAt: today };
      if (index >= 0) merged[index] = { ...merged[index], ...next };
      else merged.push(next);
    }
    service.additionalSources = merged;
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
  task.officialSources = [...new Set(Object.values(municipality.services || {}).map((service) => service?.source?.url).filter(Boolean))];
  task.notes = [...(task.notes || []), note];
  write(file, task);
}

const fixes = [
  ['05212','2026年4月から、未就園の生後6か月から満3歳未満児が、就労要件を問わず月10時間まで利用できる。通常の一時預かりも実施する。','2026年4月','大仙市公式ページで令和8年4月開始を確認。',[]],
  ['05346','2026年4月1日から、藤里保育園で未就園の生後6か月から満3歳未満児が月10時間まで利用できる。通常の一時保育も実施する。','2026年4月1日','藤里町公式ページで令和8年4月1日開始を確認。',[]],
  ['05348','2026年度から、未就園の生後6か月から満3歳未満児が月10時間まで利用できる。通常の一時預かりも実施する。','2026年度','三種町公式ページで令和8年度開始を確認。',[]],
  ['05349','2026年4月1日から、未就園の生後6か月から満3歳未満児が町内2園で月10時間まで無料利用できる。通常の一時保育も実施する。','2026年4月1日','八峰町広報2026年4月号で令和8年4月1日開始を確認。',[]],
  ['05363','2026年4月から、未就園の生後6か月から満3歳未満児が八郎潟たいようこども園を月10時間まで利用できる。ファミリー・サポートも実施する。','2026年4月','八郎潟町第3期子ども・子育て支援事業計画変更ページで令和8年4月開始を確認。',[{url:'https://www.town.hachirogata.akita.jp/kosodate/1001485/1004478.html'}]],
  ['05368','2026年4月から、未就園の生後6か月から満3歳未満児が大潟こども園を月10時間まで利用できる。通常の一時預かりも実施する。','2026年4月','大潟村公式ページで令和8年4月開始を確認。',[]],
  ['05463','2026年度から、未就園の生後6か月から満3歳未満児がにしもないこども園を月10時間まで1時間200円で利用できる。通常の一時預かりも実施する。','2026年度','羽後町公式ページで令和8年度開始を確認。',[]],
  ['06201','2024年7月から市内2施設で先行実施し、2026年度から本格実施・実施施設拡大となった。未就園の生後6か月から満3歳未満児が月10時間まで利用できる。','2024年7月（2026年度から本格実施・施設拡大）','山形市公式記者会見で2024年7月開始と2026年度本格実施を確認。',[{url:'https://www.city.yamagata-yamagata.lg.jp/shiseijoho/shicho/1006793/1016167/1016484.html'}]],
  ['06202','2026年4月1日から、未就園の生後6か月から満3歳未満児が公立緑ケ丘保育園を月10時間まで利用できる。通常の一時預かりも実施する。','2026年4月1日','米沢市公式ページで令和8年4月1日開始を確認。',[]],
  ['06203','一部施設では2026年1月から先行実施し、2026年4月から市の実施期間として、未就園の生後6か月から満3歳未満児が月10時間まで利用できる。','2026年1月5日（一部施設先行。市の実施期間は2026年4月から）','鶴岡市公式ページで一部施設の2026年1月先行開始と市の実施期間2026年4月開始を確認。',[]]
];
for (const [code, summary, start, note, sources] of fixes) {
  updateMunicipality(code, summary, start, sources);
  updateTask(code, `2026-07-25誰でも通園単一条件第4群監査：${note}`);
}

write(path.join(root, 'operations', 'audits', 'north-b-anyone-single-gap-batch4-review-20260725.json'), {
  schemaVersion: '1.0.0', auditId: 'north-b-anyone-single-gap-batch4-review-20260725', sessionId: 'north-b', reviewedAt: now,
  status: 'corrections_applied', sourceAudit: 'operations/audits/north-b-fiscal-anyone-triage-20260725.json',
  scope: { candidatesReviewed: 10, municipalitiesCorrected: 10, noChangeMunicipalities: 0, statusChanges: 0, remainingSingleConditionCandidates: 29 },
  corrected: [
    {code:'05212',municipality:'大仙市',result:'2026年4月開始'}, {code:'05346',municipality:'藤里町',result:'2026年4月1日開始'},
    {code:'05348',municipality:'三種町',result:'2026年度開始'}, {code:'05349',municipality:'八峰町',result:'2026年4月1日開始'},
    {code:'05363',municipality:'八郎潟町',result:'2026年4月開始'}, {code:'05368',municipality:'大潟村',result:'2026年4月開始'},
    {code:'05463',municipality:'羽後町',result:'2026年度開始'}, {code:'06201',municipality:'山形市',result:'2024年7月先行開始・2026年度本格実施'},
    {code:'06202',municipality:'米沢市',result:'2026年4月1日開始'}, {code:'06203',municipality:'鶴岡市',result:'2026年1月一部施設先行・2026年4月本実施'}
  ],
  policy: '更新日を開始日とみなさない。先行実施と法定制度本実施を区別し、公式情報に記載された最初の利用開始時期を記録する。'
});

const checkpointPath = path.join(root, 'operations', 'control', 'session-checkpoints', 'north-b.json');
const checkpoint = read(checkpointPath);
checkpoint.updatedAt = now;
checkpoint.workingBranch = 'audit/north-b-anyone-single-gap-batch4-20260725';
checkpoint.pullRequestNumber = null;
checkpoint.ciStatus = 'pending';
checkpoint.nextAction = '誰でも通園の単一条件欠落残り29件を優先度順に再確認する。';
checkpoint.fiscalAnyoneAudit = {
  ...(checkpoint.fiscalAnyoneAudit || {}),
  singleGapBatch4Reviewed: 10,
  singleGapBatch4CorrectedMunicipalities: fixes.map(([code]) => code),
  singleGapBatch4NoChangeMunicipalities: [],
  remainingAnyonePriorityBelow50: 29,
  singleGapBatch4AuditFile: 'operations/audits/north-b-anyone-single-gap-batch4-review-20260725.json',
  status: 'single_gap_batch4_corrections_pending_ci'
};
write(checkpointPath, checkpoint);
