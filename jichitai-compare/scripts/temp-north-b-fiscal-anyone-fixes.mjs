import fs from 'node:fs';
import path from 'node:path';

const projectDir = path.resolve('jichitai-compare');
const today = '2026-07-25';
const now = '2026-07-25T12:59:00+09:00';

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function writeJson(file, value) {
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
  console.log(`updated ${path.relative(projectDir, file)}`);
}

function updateMunicipality(code, mutate) {
  const file = path.join(projectDir, 'data', 'municipalities', code.slice(0, 2), `${code}.json`);
  const data = readJson(file);
  mutate(data);
  data.updatedAt = today;
  writeJson(file, data);
}

function updateTask(code, sourceUrls, note) {
  const file = path.join(projectDir, 'operations', 'tasks', `${code}.json`);
  const task = readJson(file);
  task.lastCheckedAt = today;
  task.lastUpdatedAt = now;
  task.lastUpdatedBy = '北日本調査班B・品質改善第2監査';
  task.officialSources = [...new Set([...(task.officialSources || []), ...sourceUrls])];
  task.notes = [...(task.notes || []), note];
  writeJson(file, task);
}

updateMunicipality('01604', (data) => {
  const temporary = data.services.temporaryChildcare;
  temporary.summary = '認定こども園の幼稚園型園児を対象に、平日午後と就労世帯向け土曜日の一時預かりを実施する。';
  delete temporary.details.other;
  temporary.details.verification = '現行の町公式ページでは、こども誰でも通園制度の対象月齢、料金、施設、利用時間、月上限を確認できないため登録しない。';
  temporary.source.checkedAt = today;

  const housing = data.services.housingSupport;
  housing.summary = '第5期（令和7年度から令和9年度）の制度として、住宅取得に最大200万円を交付し、子どもの人数に応じて固定資産税相当額を最大5年間支援する。';
  housing.details.currentYear = '令和8年度は第5期の対象期間内';
  housing.source.checkedAt = today;
});
updateTask('01604', [
  'https://www.niikappu.jp/kurashi/kosodate/ninteikodomoen/hoikusho.html',
  'https://www.niikappu.jp/kurashi/sekatsu/sumai/teijyu/lifestyle/seido.html'
], '2026-07-25追加監査：現行公式ページに誰でも通園の具体条件がないため、未確認の「別途実施」記載を削除。住宅支援は第5期（令和7～9年度）で令和8年度も有効と再確認。');

updateMunicipality('04606', (data) => {
  const service = data.services.temporaryChildcare;
  service.summary = '町内在住の満1歳から就学前児の一時預かりに加え、未就園の生後6か月から満3歳未満児が月10時間まで基本1時間300円でこども誰でも通園制度を利用できる。';
  service.eligibility.minAgeMonths = 6;
  service.eligibility.maxAgeYears = 6;
  service.details = {
    temporaryTarget: '町内在住で保育所、幼稚園、認定こども園等に在籍していない満1歳から就学前の児童',
    temporaryFacility: '地域子育て支援センター',
    temporaryHours: '午前9時から12時または午後1時から4時',
    temporaryCapacity: '各時間帯3人',
    temporaryLimit: '原則週3日まで',
    anyoneStart: '2026年4月1日',
    anyoneTarget: '保育所等に在籍していない生後6か月から満3歳未満の子ども。利用施設は満1歳から受入れ',
    anyoneLimit: '子ども1人につき月10時間まで。1回最低1時間、未利用分の翌月繰越不可',
    anyoneFee: '基本1時間300円。給食代や雑費等が別途必要となる場合があり、所得状況による負担軽減制度あり',
    anyoneFacility: '歌津地区子育て支援センター',
    anyoneHours: '毎週水曜日9時から11時30分。祝日・年末年始を除く',
    anyoneMethod: '定期利用、1時間当たり定員4人',
    anyoneApplication: '町の利用認定後、総合支援システムで初回面談と利用予約を行う'
  };
  service.source.checkedAt = today;
  const anyoneUrl = 'https://www.town.minamisanriku.miyagi.jp/soshiki/1004/8117.html';
  service.additionalSources = (service.additionalSources || []).map((item) => item.url === anyoneUrl ? { ...item, checkedAt: today } : item);
});
updateTask('04606', [
  'https://www.town.minamisanriku.miyagi.jp/soshiki/1004/1988.html',
  'https://www.town.minamisanriku.miyagi.jp/soshiki/1004/8117.html'
], '2026-07-25追加監査：こども誰でも通園制度の対象、月10時間、基本1時間300円、歌津地区子育て支援センター、水曜9:00～11:30、定期利用、初回面談・予約手順を公式ページで再確認し追記。');

updateMunicipality('06428', (data) => {
  const service = data.services.temporaryChildcare;
  service.summary = '庄内町在住の未就園の生後6か月から満3歳未満児が、町内2施設で平日9時から11時に月10時間まで1時間300円でこども誰でも通園制度を利用できる。';
  service.details = {
    program: '庄内町乳児等通園支援事業（こども誰でも通園制度）',
    start: '2026年度から実施',
    target: '庄内町在住で保育園・認定こども園等に通っていない生後6か月から満3歳未満の子ども',
    employmentRequirement: 'なし',
    facilities: '余目保育園、認定こども園からふる',
    hours: '両施設とも平日9時から11時',
    usageLimit: '子ども1人につき月10時間まで、1時間単位。未利用分の翌月繰越不可',
    fee: '1時間300円。おやつ代・教材費等が別途必要となる場合あり',
    application: '総合支援システムで町へ認定申請後、利用施設を選択して初回面談・予約を行う',
    cancellation: '利用当日0時以降のキャンセルまたは無断キャンセルは利用時間から減算'
  };
  service.source.checkedAt = today;
});
updateTask('06428', [
  'https://www.town.shonai.lg.jp/kurashi/kosodate/shien/kodomodaredemo.html'
], '2026-07-25追加監査：こども誰でも通園制度の対象、余目保育園・認定こども園からふる、平日9:00～11:00、月10時間、1時間300円、面談・予約手順を公式ページで再確認し追記。');

const triagePath = path.join(projectDir, 'operations', 'audits', 'north-b-fiscal-anyone-triage-20260725.json');
const triage = readJson(triagePath);
triage.status = 'manual_review_phase1_completed';
triage.reviewedAt = now;
triage.manualReview = {
  fiscalPriority80PlusReviewed: 10,
  anyonePriority50PlusReviewed: 4,
  confirmedCorrections: [
    { code: '01604', municipality: '新冠町', service: 'temporaryChildcare', action: 'unsupported_anyone_reference_removed' },
    { code: '01604', municipality: '新冠町', service: 'housingSupport', action: 'current_fiscal_period_clarified' },
    { code: '04606', municipality: '南三陸町', service: 'temporaryChildcare', action: 'anyone_conditions_completed' },
    { code: '06428', municipality: '庄内町', service: 'temporaryChildcare', action: 'anyone_conditions_completed' }
  ],
  noChangeConfirmed: [
    { code: '06213', municipality: '南陽市', services: ['schoolMeals','housingSupport'], decision: '令和8年度条件を確認できずunavailable維持' },
    { code: '06302', municipality: '中山町', services: ['schoolMeals'], decision: '令和7年度要綱は令和8年5月31日失効、令和8年度継続を確認できずunavailable維持' },
    { code: '06367', municipality: '戸沢村', services: ['temporaryChildcare'], decision: '制度開始告知のみで利用者向け条件不足のためunavailable維持' },
    { code: '05213', municipality: '北秋田市', services: ['childcareFee'], decision: '令和7～9年度実施計画に継続事業として掲載、verified維持' },
    { code: '05215', municipality: '仙北市', services: ['childcareFee'], decision: '令和8年度入園案内で現行条件を確認、verified維持' },
    { code: '06365', municipality: '大蔵村', services: ['postpartumCare','temporaryChildcare'], decision: '公式事業ページで実施を確認。未掲載条件は推測せず現状維持' },
    { code: '06461', municipality: '遊佐町', services: ['childcareFee'], decision: '令和8年度入園案内と負担額表を確認、verified維持' },
    { code: '01608', municipality: '様似町', services: ['sickChildCare'], decision: '現行施設・広域利用条件を確認できずunavailable維持' }
  ],
  remaining: {
    fiscalPriority50To79: 14,
    anyonePriorityBelow50: 74
  }
};
writeJson(triagePath, triage);
