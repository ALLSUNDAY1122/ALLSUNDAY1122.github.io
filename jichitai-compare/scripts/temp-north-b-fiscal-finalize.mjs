import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve('jichitai-compare');
const today = '2026-07-25';
const now = '2026-07-25T13:20:00+09:00';
const read = (file) => JSON.parse(fs.readFileSync(file, 'utf8'));
const write = (file, value) => fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
const municipalityPath = (code) => path.join(root, 'data', 'municipalities', code.slice(0, 2), `${code}.json`);

function updateMunicipality(code, mutate) {
  const file = municipalityPath(code);
  const data = read(file);
  mutate(data);
  data.updatedAt = today;
  write(file, data);
  console.log(`updated municipality ${code}`);
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
  if (!(task.notes || []).includes(note)) task.notes = [...(task.notes || []), note];
  write(file, task);
  console.log(`updated task ${code}`);
}

updateMunicipality('04401', (data) => {
  const service = data.services.sickChildCare;
  service.summary = '令和8年4月1日時点で町内の病児・病後児保育実施施設はなく、第三期計画では周辺自治体への広域的受入れ依頼を方針としている。';
  service.details = {
    currentAvailability: '令和8年4月1日時点の町内無償化対象施設一覧で、病（後）児保育事業実施施設は「－」',
    inTownFacility: '町内実施施設なし',
    futurePolicy: '松島町子ども・子育て支援事業計画（第三期）では、周辺自治体へ広域的な受入れを依頼する方針',
    guidance: '実際の広域利用可否、利用施設、対象、料金、登録方法は町こども支援班へ確認が必要'
  };
  service.source = { url: 'https://www.town.miyagi-matsushima.lg.jp/index.cfm/6%2C36300%2C17%2C124%2Chtml', checkedAt: today };
  service.additionalSources = [{ url: 'https://www.town.miyagi-matsushima.lg.jp/page/1360.html', checkedAt: today }];
});
updateTask('04401', '2026-07-25旧年度候補再監査：令和8年4月1日時点の町内施設一覧で病（後）児保育実施施設なしを確認。現行ページを主出典、第三期計画を方針確認の追加出典へ整理。');

updateMunicipality('04422', (data) => {
  const service = data.services.childcareFee;
  service.source.checkedAt = today;
  service.additionalSources = [];
  service.details.currentConfirmation = '令和8年度入園案内でも3歳未満児を含む保育料無料を確認';
});
updateTask('04422', '2026-07-25旧年度候補再監査：0～2歳を含む保育料無償化を現行専用ページと令和8年度入園案内で確認。旧年度文字列を含む冗長な追加出典を削除。');

updateMunicipality('05212', (data) => {
  const service = data.services.schoolMeals;
  const oldAnnouncement = service.source.url;
  service.source = { url: 'https://www.city.daisen.lg.jp/reiki/reiki_honbun/r154RG00000819.html', checkedAt: today };
  service.additionalSources = [{ url: oldAnnouncement, checkedAt: today }];
  service.details.currentBasis = '現行の学校給食センター条例施行規則第5条で、市立小中学校児童生徒の保護者が負担する給食費を徴収しないと規定';
});
updateTask('05212', '2026-07-25旧年度候補再監査：学校給食費無償化の主出典を現行例規へ更新。弁当持参者・市外校通学者への相当額補助は従来の市公式案内を追加出典として維持。');

updateMunicipality('05213', (data) => {
  const service = data.services.schoolMeals;
  service.source = { url: 'https://www1.g-reiki.net/city.kitaakita/reiki_honbun/r406RG00000646.html', checkedAt: today };
  service.additionalSources = [];
  service.details.currentBasis = '現行の北秋田市学校給食センター条例施行規則で、2025年4月1日以後の小中学校給食費の保護者負担を0円と規定';
});
updateTask('05213', '2026-07-25旧年度候補再監査：学校給食費0円の主出典を令和7年度会議資料から現行例規へ更新し、令和8年度も継続する根拠を確定。');

updateMunicipality('06382', (data) => {
  const service = data.services.temporaryChildcare;
  const newsletter = service.source.url;
  service.summary = '生後6か月から就学前児の一時保育等を実施する。町公式の保育園だよりでは未就園児向けこども誰でも通園制度も案内するが、施設・料金・利用時間・月上限は確認できない。';
  service.details = {
    temporaryFacilities: '川西町子育て支援センター、川西町立小松保育所',
    supportCenterTarget: '満1歳から小学校就学前まで',
    supportCenterHours: '平日9時から16時のうち3時間程度',
    supportCenterFee: '1時間700円',
    nurseryTarget: '生後6か月から小学校就学前まで',
    nurseryHours: '平日8時30分から17時',
    nurseryFee: '1日3歳未満4,000円・3歳以上2,000円、半日3歳未満2,000円・3歳以上1,000円、給食270円',
    nurseryLimit: '月8回まで',
    anyChildConfirmed: '町公式の保育園だよりで、生後6か月から3歳までと案内する未就園児向け制度の実施と事前申請・アカウント登録を確認',
    anyChildUnconfirmed: '実施施設、利用料金、利用時間、月間利用上限は利用者向け公式案内で確認できないため推測しない'
  };
  service.source = { url: 'https://town.kawanishi.yamagata.jp/kenko/kosodateshien/2024-0906-1025-68.html', checkedAt: today };
  service.additionalSources = [{ url: newsletter, checkedAt: today }];
});
updateTask('06382', '2026-07-25旧年度候補再監査：通常の一時預かり・一時保育ページを主出典へ変更。誰でも通園は町公式だよりで実施のみ確認し、施設・料金・時間・月上限は未確認として明示。');

const triageFile = path.join(root, 'operations', 'audits', 'north-b-fiscal-anyone-triage-20260725.json');
const triage = read(triageFile);
triage.status = 'manual_review_phase2_completed';
triage.phase2ReviewedAt = now;
triage.manualReview = triage.manualReview || {};
triage.manualReview.phase2 = {
  fiscalPriority50To79Reviewed: 14,
  confirmedCorrections: [
    { code: '04401', municipality: '松島町', service: 'sickChildCare', action: 'current_page_promoted_to_primary' },
    { code: '04422', municipality: '大郷町', service: 'childcareFee', action: 'redundant_old_year_additional_removed' },
    { code: '05212', municipality: '大仙市', service: 'schoolMeals', action: 'current_regulation_promoted_to_primary' },
    { code: '05213', municipality: '北秋田市', service: 'schoolMeals', action: 'current_regulation_promoted_to_primary' },
    { code: '06382', municipality: '川西町', service: 'temporaryChildcare', action: 'normal_care_promoted_and_anyone_gaps_clarified' }
  ],
  noChangeConfirmed: [
    { code: '04505', municipality: '美里町', service: 'postpartumCare', decision: 'URL文字列は2025だが現行ページとして対象・類型・料金を確認' },
    { code: '05212', municipality: '大仙市', service: 'postpartumCare', decision: '同一ページが2026年6月更新され令和8年度料金表を掲載' },
    { code: '05303', municipality: '小坂町', service: 'temporaryChildcare', decision: '町こども計画で事業・施設を確認。未掲載条件は推測せず現状維持' },
    { code: '05349', municipality: '八峰町', service: 'postpartumCare', decision: 'URL文字列は2025だが2026年4月更新の現行案内' },
    { code: '05368', municipality: '大潟村', service: 'sickChildCare', decision: '現行子育て情報で実施条件を確認できずunavailable維持' },
    { code: '06204', municipality: '酒田市', service: 'temporaryChildcare', decision: 'URL文字列は2025だが現行の誰でも通園ページで条件を確認' },
    { code: '06301', municipality: '山辺町', service: 'childcareFee', decision: 'URL文字列は2025だが令和8年度入園案内として更新済み' },
    { code: '06428', municipality: '庄内町', service: 'childcareFee', decision: 'URL文字列は2025だが令和8年度入所案内として現行' },
    { code: '06461', municipality: '遊佐町', service: 'postpartumCare', decision: 'URL文字列は2025だが2026年4月更新の現行案内' }
  ],
  statusChanges: 0,
  remainingFiscalLowPriority: 16,
  remainingAnyonePriorityBelow50: 74
};
triage.manualReview.remaining = { fiscalLowPriority: 16, anyonePriorityBelow50: 74 };
write(triageFile, triage);

const checkpointFile = path.join(root, 'operations', 'control', 'session-checkpoints', 'north-b.json');
const checkpoint = read(checkpointFile);
checkpoint.updatedAt = now;
checkpoint.workingBranch = 'audit/north-b-fiscal-anyone-final-20260725';
checkpoint.pullRequestNumber = null;
checkpoint.ciStatus = 'pending';
checkpoint.nextAction = '旧年度・誰でも通園再監査PRのCIとmain統合後、確定修正8自治体・監査記録・checkpointをregion/northへ限定同期する。続いて旧年度低優先16件と誰でも通園優先度50未満74件を確認する。';
checkpoint.fiscalAnyoneAudit = {
  auditFile: 'operations/audits/north-b-fiscal-anyone-triage-20260725.json',
  fiscalCandidates: 40,
  anyoneCandidates: 78,
  phase1FiscalReviewed: 10,
  phase1AnyoneReviewed: 4,
  phase2FiscalReviewed: 14,
  totalConfirmedCorrectionMunicipalities: ['01604','04606','06428','04401','04422','05212','05213','06382'],
  statusChanges: 0,
  unsupportedAnyoneReferenceRemoved: 1,
  anyoneConditionsCompleted: 2,
  remainingFiscalLowPriority: 16,
  remainingAnyonePriorityBelow50: 74,
  status: 'awaiting_ci'
};
write(checkpointFile, checkpoint);
