import fs from 'node:fs';
import path from 'node:path';

const ROOT = 'jichitai-compare';
const read = p => JSON.parse(fs.readFileSync(p, 'utf8'));
const write = (p, v) => fs.writeFileSync(p, JSON.stringify(v, null, 2) + '\n');

const updates = [
  {
    code: '16210',
    service: 'bulkyWaste',
    oldUrl: 'https://www.city.nanto.toyama.jp/soshiki/seikatsukankyo/1/5/418.html',
    newUrl: 'https://www.city.nanto.toyama.jp/kurashi-tetsuzuki/gomi-kankyo-pets/5/2825.html',
    note: '2026-07-25の原因別再監査で、404となった粗大ごみ旧URLを現行の公式直接搬入案内へ更新。制度内容は変更なし。'
  },
  {
    code: '23342',
    service: 'bulkyWaste',
    oldUrl: 'https://www.town.toyoyama.lg.jp/kurashi/sigen/1000736.html',
    newUrl: 'https://www.town.toyoyama.lg.jp/kurashi/sigen/1007929/1000738.html',
    note: '2026-07-25の原因別再監査で、404となった粗大ごみ旧URLを令和8年7月更新の公式申込ページへ更新。制度内容は変更なし。'
  }
];

for (const update of updates) {
  const pref = update.code.slice(0, 2);
  const municipalityPath = path.join(ROOT, 'data', 'municipalities', pref, `${update.code}.json`);
  const taskPath = path.join(ROOT, 'operations', 'tasks', `${update.code}.json`);
  const municipality = read(municipalityPath);
  const task = read(taskPath);
  const service = municipality.services?.[update.service];
  if (!service) throw new Error(`${update.code}:${update.service} missing`);
  if (service.source?.url !== update.oldUrl) throw new Error(`${update.code}:${update.service} unexpected old URL ${service.source?.url}`);
  service.source.url = update.newUrl;
  service.source.checkedAt = '2026-07-25';
  municipality.updatedAt = '2026-07-25';
  const sourceIndex = task.officialSources.indexOf(update.oldUrl);
  if (sourceIndex < 0) throw new Error(`${update.code} task old URL missing`);
  task.officialSources[sourceIndex] = update.newUrl;
  task.lastCheckedAt = '2026-07-25';
  task.lastUpdatedAt = '2026-07-25T10:57:00+09:00';
  task.lastUpdatedBy = '中日本調査班A（原因別重点再監査）';
  if (!task.notes.includes(update.note)) task.notes.push(update.note);
  write(municipalityPath, municipality);
  write(taskPath, task);
}

const scopePrefectures = ['16','17','18','21','22','23','24','25','27','28'];
const municipalityCodes = scopePrefectures.flatMap(pref => {
  const dir = path.join(ROOT, 'data', 'municipalities', pref);
  return fs.readdirSync(dir).filter(name => /^\d{5}\.json$/.test(name)).map(name => name.slice(0, 5));
}).sort();
const duplicateNames = [];
const seenNames = new Map();
for (const code of municipalityCodes) {
  const municipality = read(path.join(ROOT, 'data', 'municipalities', code.slice(0,2), `${code}.json`));
  const key = `${municipality.prefecture}:${municipality.name}`;
  if (seenNames.has(key)) duplicateNames.push({ key, codes: [seenNames.get(key), code] });
  else seenNames.set(key, code);
}
const missingTasks = municipalityCodes.filter(code => !fs.existsSync(path.join(ROOT, 'operations', 'tasks', `${code}.json`)));
const issue3141 = [
  ['21207','temporaryChildcare'],['21504','temporaryChildcare'],['22219','temporaryChildcare'],['22305','temporaryChildcare'],
  ['22424','temporaryChildcare'],['22429','temporaryChildcare'],['23235','schoolMeals'],['23427','schoolMeals'],
  ['23561','schoolMeals'],['23562','schoolMeals'],['23563','temporaryChildcare'],['24205','schoolMeals'],
  ['24205','temporaryChildcare'],['24212','temporaryChildcare'],['24441','schoolMeals'],['24461','temporaryChildcare'],
  ['24543','schoolMeals'],['25441','temporaryChildcare'],['25442','temporaryChildcare'],['27232','sickChildCare'],
  ['27321','sickChildCare'],['27322','schoolMeals'],['27366','sickChildCare']
].map(([code, service]) => ({code, service}));

const decision = {
  schemaVersion: '1.0.0',
  auditId: 'central-a-cause-based-decisions-20260725',
  decidedAt: '2026-07-25T10:57:00+09:00',
  session: '中日本調査班A',
  scope: {
    prefectureCodes: scopePrefectures,
    municipalityCountAfterCorrection: municipalityCodes.length,
    serviceCountAfterCorrection: municipalityCodes.length * 9,
    expectedMunicipalityCount: 314,
    expectedServiceCount: 2826,
    duplicateMunicipalityNamesAfterCorrection: duplicateNames,
    missingTaskCodesAfterCorrection: missingTasks
  },
  confirmedCorrections: [
    {
      type: 'municipality_code_duplicate',
      municipalityName: '菰野町',
      wrongCode: '24361',
      correctCode: '24341',
      action: ['data/municipalities/24/24361.jsonを削除', 'operations/tasks/24361.jsonを削除'],
      basis: '現行自治体コードと第7回監査PR #3066の正規データを照合し、同一自治体の二重登録を確認'
    },
    ...updates.map(update => ({
      type: 'stale_official_url',
      municipalityCode: update.code,
      service: update.service,
      oldUrl: update.oldUrl,
      newUrl: update.newUrl,
      contentChanged: false
    }))
  ],
  mechanicalScreening: {
    sourceAudit: 'operations/audits/central-a-cause-based-rescan-20260725.json',
    candidateCounts: {
      weakPrimarySource: 46,
      numericOrConditionCompleteness: 81,
      generalHousingMisclassification: 149,
      fiscalYearRisk: 33,
      schoolMealScopeAmbiguity: 24,
      verifiedUnavailableRisk: 1
    },
    interpretation: '候補数は重複を含む機械抽出件数であり、誤り件数ではない。公式利用者向け情報で確定した項目だけを修正する。',
    knownFalsePositive: {
      municipalityCode: '21604',
      service: 'temporaryChildcare',
      reason: 'unavailable説明文中に制度名が含まれたため抽出された。対象・料金・施設・期間が公式公開されていないため変更しない。'
    }
  },
  pastCorrectionRecheck: {
    correctedMunicipalityCount: 54,
    primarySourceSlotsChecked: 486,
    confirmedStaleUrlsCorrected: 2,
    transientOrAccessLimitedWithoutDataChange: [
      {municipalityCode:'25441',service:'housingSupport',result:'fetch_failed_only'},
      {municipalityCode:'27232',service:'childcareFee',result:'official_page_reachable_on_manual_recheck'}
    ]
  },
  issue3141: {
    issueNumber: 3141,
    unresolvedItemCount: issue3141.length,
    items: issue3141,
    decision: '対象、料金、施設、期間等が揃った新しい利用者向け公式情報を確認できない項目は変更しない。今回の自動抽出では解消0件。'
  },
  nextPriority: [
    '条例・計画・予算案のみを主出典とする46候補を、利用者向け現行ページの有無で再判定する',
    '子育て固有条件が見当たらない住宅支援候補を制度定義に照らして確認する',
    '学校給食費24候補を一般世帯負担・部分助成・無償化に分けて公式確認する'
  ]
};

if (decision.scope.municipalityCountAfterCorrection !== 314) throw new Error(`municipality count ${decision.scope.municipalityCountAfterCorrection}`);
if (decision.scope.serviceCountAfterCorrection !== 2826) throw new Error(`service count ${decision.scope.serviceCountAfterCorrection}`);
if (duplicateNames.length) throw new Error(`duplicate municipality names remain: ${JSON.stringify(duplicateNames)}`);
if (missingTasks.length) throw new Error(`missing tasks remain: ${missingTasks.join(',')}`);
write(path.join(ROOT, 'operations', 'audits', 'central-a-cause-based-decisions-20260725.json'), decision);
console.log(JSON.stringify(decision.scope, null, 2));
