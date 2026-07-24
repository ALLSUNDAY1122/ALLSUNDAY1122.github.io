import fs from 'node:fs';
import path from 'node:path';

const root = 'jichitai-compare';
const branch = 'audit/central-a-scope-verification-round-06-20260725';
const nowDate = '2026-07-25';
const nowTime = '2026-07-25T02:48:00+09:00';
const serviceKeys = ['childMedical','sickChildCare','childcareFee','schoolMeals','postpartumCare','temporaryChildcare','housingSupport','bulkyWaste','disasterPrevention'];
const read = (p) => JSON.parse(fs.readFileSync(p, 'utf8'));
const write = (p, value) => fs.writeFileSync(p, JSON.stringify(value, null, 2) + '\n');
const municipalityPath = (code) => path.join(root, 'data', 'municipalities', '23', `${code}.json`);
const taskPath = (code) => path.join(root, 'operations', 'tasks', `${code}.json`);

function retainOldSource(service, oldSource, description) {
  if (!oldSource?.url || oldSource.url === service.source?.url) return;
  const list = Array.isArray(service.additionalSources) ? [...service.additionalSources] : [];
  if (!list.some((item) => item?.url === oldSource.url)) list.unshift({ ...oldSource, description });
  service.additionalSources = list;
}

function replaceService(data, key, patch, oldDescription) {
  const old = data.services[key];
  const oldSource = old?.source;
  data.services[key] = { ...old, ...patch };
  retainOldSource(data.services[key], oldSource, oldDescription);
}

function recomputeTask(code, note) {
  const data = read(municipalityPath(code));
  const task = read(taskPath(code));
  const completedServices = serviceKeys.filter((key) => ['verified','unavailable'].includes(data.services[key]?.status));
  const count = (status) => serviceKeys.filter((key) => data.services[key]?.status === status).length;
  const nextServiceIndex = serviceKeys.findIndex((key) => !['verified','unavailable'].includes(data.services[key]?.status));
  task.status = nextServiceIndex === -1 ? 'merged' : task.status;
  task.completedServices = completedServices;
  task.verifiedCount = count('verified');
  task.researchingCount = count('researching');
  task.unavailableCount = count('unavailable');
  task.needsMediumReviewCount = count('needs_medium_review');
  task.nextServiceIndex = nextServiceIndex === -1 ? serviceKeys.length : nextServiceIndex;
  task.currentService = nextServiceIndex === -1 ? null : serviceKeys[nextServiceIndex];
  task.officialSources = [...new Set(serviceKeys
    .filter((key) => ['verified','unavailable'].includes(data.services[key]?.status) && /^https:\/\//.test(data.services[key]?.source?.url || ''))
    .map((key) => data.services[key].source.url))];
  task.lastCheckedAt = nowDate;
  task.lastUpdatedAt = nowTime;
  task.lastUpdatedBy = '中日本調査班A（担当範囲再監査）';
  task.notes = Array.isArray(task.notes) ? task.notes : [];
  if (!task.notes.includes(note)) task.notes.push(note);
  write(taskPath(code), task);
}

function updateMunicipality(code, updater, note) {
  const data = read(municipalityPath(code));
  updater(data);
  data.status = 'verified';
  data.updatedAt = nowDate;
  write(municipalityPath(code), data);
  recomputeTask(code, note);
}

updateMunicipality('23100', () => {}, '2026-07-25の担当範囲再監査で、9制度完了後も残っていた自治体上位statusをverifiedへ修正。');

updateMunicipality('23205', (data) => {
  replaceService(data, 'schoolMeals', {
    status: 'verified',
    summary: '令和8年度は小学校給食費を無償化し、中学校は1食290円、幼稚園は1食230円を保護者負担とする。',
    details: {
      fiscalYear: '令和8年度',
      standardRate: '小学校1食330円、中学校1食380円、幼稚園1食290円',
      parentBurden: '小学校0円、中学校1食290円、幼稚園1食230円',
      publicSupport: '国・県・市の公費負担により小学校を無償化し、中学校・幼稚園の負担を軽減'
    },
    source: { url: 'https://www.city.handa.lg.jp/_res/projects/default_project/_page_/001/011/636/r8shuyoujigyou.pdf', checkedAt: nowDate }
  }, '経済的に就学困難な世帯への就学援助');
}, '2026-07-25の担当範囲再監査で、令和8年度の小学校給食費無償化と中学校・幼稚園の負担軽減を追加。');

updateMunicipality('23220', (data) => {
  replaceService(data, 'schoolMeals', {
    status: 'verified',
    summary: '令和8年度は市立小中学校の学校給食費を完全無償化し、食物アレルギーで弁当を持参する児童生徒にも相当額を補助する。',
    details: {
      fiscalYear: '令和8年度',
      elementary: '全額公費支援により保護者負担0円',
      juniorHigh: '全額公費支援により保護者負担0円',
      allergySupport: '食物アレルギーにより毎食弁当を持参する児童生徒の保護者にも同様の補助'
    },
    source: { url: 'https://www.city.inazawa.aichi.jp/cmsfiles/contents/0000002/2491/R08_yosangaiyou.pdf', checkedAt: nowDate }
  }, '経済的理由で就学困難な世帯への就学援助');
}, '2026-07-25の担当範囲再監査で、令和8年度の小中学校給食費完全無償化を追加。');

updateMunicipality('23221', (data) => {
  replaceService(data, 'schoolMeals', {
    status: 'verified',
    summary: '令和8年度は小学校給食費を無償化し、中学校は保護者負担を1食330円に据え置く。就学援助認定の中学生には給食を現物支給する。',
    details: {
      fiscalYear: '令和8年度',
      standardRate: '食材費相当額は小学校1食350円、中学校1食400円',
      elementaryParentBurden: '国・市負担により0円',
      juniorHighParentBurden: '市の負担軽減により1食330円',
      financialAssistance: '就学援助認定の中学生は給食費の引落しを行わず現物支給'
    },
    source: { url: 'https://www.city.shinshiro.lg.jp/kosodate/kyoiku/kyuushoku/kyuusyokuhi.html', checkedAt: nowDate }
  }, '就学援助制度の学校給食費案内');
}, '2026-07-25の担当範囲再監査で、令和8年度の小学校給食費無償化と中学校1食330円を追加。');

updateMunicipality('23237', (data) => {
  replaceService(data, 'schoolMeals', {
    status: 'verified',
    summary: '令和8年度は市立小中学校の学校給食費を無償化し、保護者負担を0円とする。',
    details: {
      fiscalYear: '令和8年度',
      period: '2026年4月から2027年3月',
      target: '市内小中学校に在籍する児童生徒の保護者',
      procedure: '保護者による申請手続きは不要'
    },
    source: { url: 'https://www.city.ama.aichi.jp/kurashi/iinkai/1002356/1011105.html', checkedAt: nowDate }
  }, '再監査前の自治体トップページ');
  replaceService(data, 'postpartumCare', {
    status: 'verified',
    summary: '産後1年未満の母子へ、宿泊・デイサービス・訪問型の産後ケアを合計7日まで提供する。',
    details: {
      target: 'あま市に住所がある産後1年未満の母親と乳児で、心身の不調や育児不安等がある人',
      types: '宿泊型、デイサービス型、訪問型',
      fee: '宿泊1泊4,500円、デイサービス1日1,000円、訪問2時間500円',
      exemption: '生活保護世帯・市町村民税非課税世帯は無料',
      limit: '3類型合計7日まで。宿泊型は最大6泊7日'
    },
    source: { url: 'https://www.city.ama.aichi.jp/kurashi/1002024/1004953.html', checkedAt: nowDate }
  }, '再監査前の出産・子育て案内ページ');
  replaceService(data, 'bulkyWaste', {
    status: 'verified',
    summary: '粗大ごみはLINE・インターネット・電話で事前予約し、粗大ごみシールを貼って収集を依頼する。',
    details: {
      reservation: '市公式LINE、インターネット受付センター、電話受付のいずれかで予約',
      telephone: '052-444-0303',
      ticket: '収集時は指定取扱所で購入した粗大ごみシールが必要',
      note: '年末等は受付が混雑し、収集が翌月以降になる場合がある'
    },
    source: { url: 'https://www.city.ama.aichi.jp/kurashi/recycle/gomi/1006838.html', checkedAt: nowDate }
  }, '再監査前のごみ案内トップページ');
  replaceService(data, 'disasterPrevention', {
    status: 'verified',
    summary: '避難所、洪水・内水・高潮、地震等を収録した改訂版防災ハザードマップを公開する。',
    details: {
      updated: '2026年3月更新',
      sections: '避難所マップ、風水害編、地震編、その他の災害編、避難と準備編',
      flood: '新川・日光川・五条川・蟹江川・福田川・木曽川・庄内川の洪水マップを公開',
      other: '内水、高潮、地震の各ハザードマップを公開'
    },
    source: { url: 'https://www.city.ama.aichi.jp/kurashi/safety/bousai/1002250.html', checkedAt: nowDate }
  }, '再監査前の自治体トップページ');
}, '2026-07-25の担当範囲再監査で、給食費・産後ケア・粗大ごみ・防災情報の誤ったunavailableを修正。');

updateMunicipality('23238', (data) => {
  replaceService(data, 'childMedical', {
    status: 'verified',
    summary: '0歳から18歳年度末まで、通院・入院の保険診療自己負担額を助成する。',
    details: {
      ageCondition: '18歳到達後最初の3月31日まで',
      coverage: '通院・入院の保険診療自己負担額',
      payment: '受給者証を医療機関窓口で提示。県外受診等は払い戻し申請',
      note: '2024年10月診療分から高校生年代の通院費まで対象を拡大'
    },
    source: { url: 'https://www.city.nagakute.lg.jp/iryo_kenko_fukushi/2/11/6399.html', checkedAt: nowDate }
  }, '再監査前の自治体トップページ');
  replaceService(data, 'schoolMeals', {
    status: 'verified',
    summary: '令和8年度は小学校給食費を0円とし、中学校の保護者負担を1食290円とする。',
    details: {
      fiscalYear: '令和8年度',
      standardRate: '小学校1食330円、中学校1食380円',
      elementaryParentBurden: '0円',
      juniorHighParentBurden: '1食290円'
    },
    source: { url: 'https://www.city.nagakute.lg.jp/kosodate_kyoiku/gakkokyushoku_hoikuenkyushoku/1/14523.html', checkedAt: nowDate }
  }, '再監査前の自治体トップページ');
  replaceService(data, 'bulkyWaste', {
    status: 'verified',
    summary: '粗大ごみは電話またはインターネットで予約し、1点800円の処理券を貼って1回5点まで収集を依頼する。',
    details: {
      reservation: '粗大ごみ受付センターへの電話またはインターネット予約',
      limit: '1回5点まで',
      fee: '粗大ごみ処理券1点800円',
      collection: '収集日の午前8時30分までに指定場所へ排出'
    },
    source: { url: 'https://www.city.nagakute.lg.jp/kurashi_tetsuzuki/gomi_kankyo/gomi/kateigomi/sodai/12045.html', checkedAt: nowDate }
  }, '再監査前の自治体トップページ');
  replaceService(data, 'disasterPrevention', {
    status: 'verified',
    summary: '地震・液状化・洪水・避難所等を掲載した長久手市防災マップを公開する。',
    details: {
      edition: '2026年3月配布版',
      hazards: '地震、液状化、洪水等',
      evacuation: '指定避難所・避難場所と防災情報を掲載',
      distribution: '市ウェブサイトでPDF版を公開'
    },
    source: { url: 'https://www.city.nagakute.lg.jp/soshiki/kurashibunkabu/anshinanzenka/1/2/bosai_category/bosai_map/1129.html', checkedAt: nowDate }
  }, '再監査前の自治体トップページ');
}, '2026-07-25の担当範囲再監査で、子ども医療費・給食費・粗大ごみ・防災情報の誤ったunavailableを修正。');

updateMunicipality('23302', (data) => {
  replaceService(data, 'schoolMeals', {
    status: 'verified',
    summary: '令和8年4月から町立小学校の学校給食費を無償化する。中学校の給食費は別途保護者負担とする。',
    details: {
      fiscalYear: '令和8年度',
      start: '2026年4月',
      elementary: '国の給食費負担軽減交付金と町の支援により保護者負担0円',
      juniorHigh: '小学校無償化の対象外で、別途給食費を負担'
    },
    source: { url: 'https://www.town.aichi-togo.lg.jp/material/files/group/27/gikaidayori159sokuhou.pdf', checkedAt: nowDate }
  }, '従前の学校給食費定額案内');
}, '2026-07-25の担当範囲再監査で、令和8年4月開始の小学校給食費無償化を追加。');

updateMunicipality('23342', (data) => {
  replaceService(data, 'schoolMeals', {
    status: 'verified',
    summary: '令和8年度は小学校給食を1食330円・月額5,700円、中学校給食を1食380円・月額6,560円で実施する。',
    details: {
      fiscalYear: '令和8年度',
      days: '年間186日予定',
      elementary: '1食330円、月額5,700円',
      juniorHigh: '1食380円、月額6,560円'
    },
    source: { url: 'https://www.town.toyoyama.lg.jp/_res/projects/default_project/_page_/001/007/127/r080218_siryou3-1.pdf', checkedAt: nowDate }
  }, '経済的に就学困難な児童生徒への就学援助');
}, '2026-07-25の担当範囲再監査で、令和8年度の小中学校給食費を追加。');

updateMunicipality('23424', (data) => {
  replaceService(data, 'schoolMeals', {
    status: 'verified',
    summary: '令和8年度は町立小学校の給食費を無償化し、中学校も補助金により保護者負担を軽減する。',
    details: {
      fiscalYear: '令和8年度',
      elementary: '学校給食費を無償化',
      juniorHigh: '補助金を交付して保護者負担を軽減',
      budget: '小中学校給食費補助金1億4,846万1千円'
    },
    source: { url: 'https://www.town.oharu.aichi.jp/secure/6075/r8gaiyou.pdf', checkedAt: nowDate }
  }, '経済的理由で就学困難な世帯への就学援助');
}, '2026-07-25の担当範囲再監査で、令和8年度の小学校給食費無償化と中学校負担軽減を追加。');

updateMunicipality('23441', (data) => {
  replaceService(data, 'schoolMeals', {
    status: 'verified',
    summary: '令和8年度は小学校給食費を無償化し、中学校の保護者負担を1食300円とする。',
    details: {
      fiscalYear: '令和8年度',
      elementaryParentBurden: '0円',
      juniorHighParentBurden: '1食300円',
      funding: '国の交付金を活用して負担を軽減'
    },
    source: { url: 'https://www.town.agui.lg.jp/0000008282.html', checkedAt: nowDate }
  }, '経済的理由で就学困難な世帯への就学援助');
}, '2026-07-25の担当範囲再監査で、令和8年度の小学校給食費無償化と中学校1食300円を追加。');

const expected = {
  '23100':'名古屋市','23201':'豊橋市','23202':'岡崎市','23203':'一宮市','23204':'瀬戸市','23205':'半田市','23206':'春日井市','23207':'豊川市','23208':'津島市','23209':'碧南市','23210':'刈谷市','23211':'豊田市','23212':'安城市','23213':'西尾市','23214':'蒲郡市','23215':'犬山市','23216':'常滑市','23217':'江南市','23219':'小牧市','23220':'稲沢市','23221':'新城市','23222':'東海市','23223':'大府市','23224':'知多市','23225':'知立市','23226':'尾張旭市','23227':'高浜市','23228':'岩倉市','23229':'豊明市','23230':'日進市','23231':'田原市','23232':'愛西市','23233':'清須市','23234':'北名古屋市','23235':'弥富市','23236':'みよし市','23237':'あま市','23238':'長久手市','23302':'東郷町','23342':'豊山町','23361':'大口町','23362':'扶桑町','23424':'大治町','23425':'蟹江町','23427':'飛島村','23441':'阿久比町','23442':'東浦町','23445':'南知多町','23446':'美浜町','23447':'武豊町','23501':'幸田町','23561':'設楽町','23562':'東栄町','23563':'豊根村'
};
const reportPath = path.join(root, 'operations', 'control', 'central-a-scope-round-06-aichi-20260725.json');
const report = read(reportPath);
const initialSuspects = report.substantiveSuspects || [];
const findings = [];
const unavailable = [];
const municipalities = [];
for (const [code, name] of Object.entries(expected)) {
  const data = read(municipalityPath(code));
  const task = read(taskPath(code));
  const counts = { verified: 0, unavailable: 0, needs_medium_review: 0, researching: 0 };
  for (const key of serviceKeys) {
    const status = data.services[key]?.status;
    if (Object.hasOwn(counts, status)) counts[status]++;
    if (status === 'unavailable') unavailable.push({ code, name, service: key, summary: data.services[key].summary || '' });
  }
  const completed = serviceKeys.filter((key) => ['verified','unavailable'].includes(data.services[key]?.status));
  const officialSources = [...new Set(serviceKeys.filter((key) => ['verified','unavailable'].includes(data.services[key]?.status)).map((key) => data.services[key]?.source?.url).filter((url) => /^https:\/\//.test(url || '')))];
  if (data.code !== code || data.name !== name || data.prefectureCode !== '23' || data.prefecture !== '愛知県') findings.push({ type: 'municipality_identity_mismatch', code });
  if (JSON.stringify(Object.keys(data.services || {}).sort()) !== JSON.stringify([...serviceKeys].sort())) findings.push({ type: 'service_key_mismatch', code });
  if (JSON.stringify(task.completedServices) !== JSON.stringify(completed)) findings.push({ type: 'completed_services_mismatch', code });
  if (task.verifiedCount !== counts.verified || task.unavailableCount !== counts.unavailable || task.needsMediumReviewCount !== counts.needs_medium_review || task.researchingCount !== counts.researching) findings.push({ type: 'status_count_mismatch', code });
  if (JSON.stringify(task.officialSources) !== JSON.stringify(officialSources)) findings.push({ type: 'official_sources_mismatch', code });
  if (completed.length === 9 && data.status !== 'verified') findings.push({ type: 'top_level_status_mismatch', code });
  if (completed.length === 9 && task.status !== 'merged') findings.push({ type: 'task_status_mismatch', code });
  const highRisk = {};
  for (const key of ['schoolMeals','postpartumCare','temporaryChildcare','housingSupport']) {
    const service = data.services[key];
    highRisk[key] = { status: service?.status || null, summary: service?.summary || '', source: service?.source?.url || '', checkedAt: service?.source?.checkedAt || null };
  }
  municipalities.push({ code, name, status: data.status, updatedAt: data.updatedAt, taskStatus: task.status, taskLastCheckedAt: task.lastCheckedAt, verifiedCount: counts.verified, unavailableCount: counts.unavailable, needsMediumReviewCount: counts.needs_medium_review, officialSourceCount: officialSources.length, taskOfficialSourceCount: (task.officialSources || []).length, highRisk });
}
report.generatedAt = nowTime;
report.initialStructuralFindingCount = 1;
report.structuralFindingCount = findings.length;
report.resolvedStructuralFindingCount = 1;
report.initialUnavailableCount = 15;
report.unavailableCount = unavailable.length;
report.initialSubstantiveSuspectCount = initialSuspects.length;
report.substantiveSuspectCount = 5;
report.findings = findings;
report.unavailable = unavailable;
report.municipalities = municipalities;
report.confirmedErrorCount = 16;
report.correctedMunicipalityCodes = ['23100','23205','23220','23221','23237','23238','23302','23342','23424','23441'];
report.confirmedCorrections = [
  { type: 'top_level_status_mismatch', count: 1, municipalityCodes: ['23100'] },
  { type: 'false_unavailable', count: 8, municipalityCodes: ['23237','23238'], services: ['schoolMeals','postpartumCare','childMedical','bulkyWaste','disasterPrevention'] },
  { type: 'current_program_omission', service: 'schoolMeals', count: 7, municipalityCodes: ['23205','23220','23221','23302','23342','23424','23441'] }
];
report.confirmedAccurateExamples = [
  { code: '23208', service: 'schoolMeals', detail: '津島市の市立小中学校給食費完全無償化を現行公式ページで確認' },
  { code: '23209', service: 'schoolMeals', detail: '碧南市の小学校無償・中学校1食350円を確認' },
  { code: '23211', service: 'schoolMeals', detail: '豊田市の市立小中学校等の給食費無償化を確認' },
  { code: '23212', service: 'schoolMeals', detail: '安城市の市立小中学校給食費無償化を確認' },
  { code: '23217', service: 'schoolMeals', detail: '江南市の小学校1食350円・中学校1食380円を確認' },
  { code: '23229', service: 'postpartumCare', detail: '豊明市の出産後1年以内の宿泊・通所型産後ケアを確認' },
  { code: '23236', service: 'schoolMeals', detail: 'みよし市の市立小中学校給食費無償化を確認' },
  { code: '23563', service: 'schoolMeals', detail: '豊根村の村立小中学校給食費無料化を確認' }
];
report.needsFurtherReview = [
  { code: '23235', name: '弥富市', service: 'schoolMeals', detail: '令和8年度の一般世帯の給食費・負担軽減条件を公式公開情報だけでは確定できない' },
  { code: '23427', name: '飛島村', service: 'schoolMeals', detail: '令和8年度の一般世帯の給食費条件を公式公開情報だけでは確定できない' },
  { code: '23561', name: '設楽町', service: 'schoolMeals', detail: '規則上の徴収額は確認できるが令和8年度の実負担を確定できない' },
  { code: '23562', name: '東栄町', service: 'schoolMeals', detail: '就学援助は確認できるが令和8年度の一般世帯の給食費を確定できない' },
  { code: '23563', name: '豊根村', service: 'temporaryChildcare', detail: '通常の一時保育は確認できるが、こども誰でも通園制度の現行利用条件を確定できない' }
];
report.substantiveSuspects = report.needsFurtherReview.map((item) => ({ severity: 'review', type: item.service === 'temporaryChildcare' ? 'possible_any_child_access_omission' : 'school_meal_currentness_check', ...item }));
report.initialSubstantiveSuspects = initialSuspects;
write(reportPath, report);

const trackerPath = path.join(root, 'operations', 'control', 'central-a-scope-verification-20260724.json');
const tracker = read(trackerPath);
tracker.branch = branch;
tracker.batches = tracker.batches.filter((item) => item.batch !== 6);
tracker.batches.push({
  batch: 6,
  prefectureCode: '23',
  prefectureName: '愛知県',
  municipalityCount: 54,
  status: 'completed_with_corrections_and_review',
  checkedMunicipalities: 54,
  checkedServices: 486,
  initialStructuralFindingCount: 1,
  structuralFindingCount: findings.length,
  resolvedStructuralFindingCount: 1,
  initialUnavailableCount: 15,
  unavailableCount: unavailable.length,
  initialSubstantiveSuspectCount: initialSuspects.length,
  substantiveSuspectCount: 5,
  report: 'operations/control/central-a-scope-round-06-aichi-20260725.json',
  confirmedErrors: 16,
  correctedMunicipalityCodes: report.correctedMunicipalityCodes,
  confirmedAccurateSuspectCodes: ['23208','23209','23211','23212','23217','23229','23236','23563'],
  needsFurtherReviewCodes: ['23235','23427','23561','23562','23563'],
  nextStep: '第7回として三重県29自治体を監査する',
  completedAt: nowTime
});
tracker.summary = { completedBatches: 6, checkedMunicipalities: 182, confirmedErrors: 51, needsFurtherReview: 11, correctedErrors: 51 };
tracker.nextAction = '第7回として三重県29自治体を監査する';
tracker.rebuiltRound6At = nowTime;
write(trackerPath, tracker);
