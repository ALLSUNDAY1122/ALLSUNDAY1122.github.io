import { readFile, writeFile } from 'node:fs/promises';

const auditPath = 'operations/audits/central-b-accuracy-audit-20260725.json';
const branch = 'quality/central-b-accuracy-audit-20260725';
const checkedAt = '2026-07-25';
const updatedAt = '2026-07-25T03:18:00+09:00';

const corrections = {
  '30404': {
    name: '上富田町',
    summary: '上富田町の子育て、教育、住宅、生活、防災に関する9制度を公式情報で確認。学校給食費無償化、産後ケア、誰でも通園、18歳未満の帯同者加算がある移住支援金などを記録。',
    housing: {
      status: 'verified',
      summary: '東京圏から要件を満たして移住する2人以上世帯に100万円を交付し、18歳未満の帯同世帯員1人につき100万円を加算する。',
      details: {
        program: '上富田町移住支援金',
        household: '2人以上世帯は100万円',
        childAddition: '18歳未満の帯同世帯員1人につき100万円を加算',
        requirements: '東京圏での居住・通勤歴に加え、対象就業、テレワーク、起業等の要件を満たすこと',
        residency: '申請日から5年以上継続して上富田町に居住する意思が必要',
        distinction: '紀州材住宅補助は子どもの有無を要件としないため、この比較項目では移住支援金の子ども加算だけを記録'
      },
      source: { url: 'https://www.town.kamitonda.lg.jp/section/reiki/reiki_honbun/k541RG00000746.html', checkedAt }
    },
    note: '精度監査で、一般の紀州材住宅支援との混在を解消し、18歳未満の帯同者1人につき100万円加算する移住支援金へ限定。'
  },
  '30406': {
    name: 'すさみ町',
    summary: 'すさみ町の子育て、教育、住宅、生活、防災に関する9制度を公式情報で確認。保育料・学校給食費無償化、産後ケア、誰でも通園等を記録し、子育て世帯専用住宅支援は未確認として整理した。',
    housing: {
      status: 'unavailable',
      summary: '住宅新築、空き家改修、家財撤去の定住支援は子どもの有無を要件としないため、子育て世帯専用の現行住宅支援を確認できない。',
      details: {
        checked: '町の定住支援、移住・定住、子育て支援の現行案内を確認',
        excludedGeneralPrograms: '新築費10分の1・上限100万円、空き家改修費3分の2・上限50万円、家財撤去費上限8万円は一般定住支援',
        unconfirmed: '子ども要件または子ども加算がある住宅取得、改修、家賃、転居費支援',
        verificationPolicy: '新たな子育て住宅支援の公表時に再確認する'
      },
      source: { url: 'https://www.town.susami.lg.jp/kurashi/09/2021093000041.html', checkedAt }
    },
    note: '精度監査で、子ども要件・加算のない一般定住住宅支援を子育て世帯向け住宅支援から除外。'
  },
  '30421': {
    name: '那智勝浦町',
    summary: '那智勝浦町の子育て、教育、住宅、生活、防災に関する9制度を公式情報で確認。病児保育、学校給食費無償化、産後ケア、誰でも通園等を記録し、子育て世帯専用住宅支援は未確認として整理した。',
    housing: {
      status: 'unavailable',
      summary: '町外移住者等の空き家改修補助は子どもの有無を要件としないため、子育て世帯専用の現行住宅支援を確認できない。',
      details: {
        checked: '令和8年度空き家改修、移住・定住、新婚世帯、子育て支援の現行案内を確認',
        excludedGeneralProgram: '町外移住者等が居住する空き家の改修費3分の2・上限100万円を補助する一般移住制度',
        excludedMarriageProgram: '結婚新生活支援は婚姻・年齢等を要件とし、子どもの有無を要件としない',
        unconfirmed: '子ども要件または子ども加算がある住宅費支援',
        verificationPolicy: '子育て世帯区分がある現行制度の公表時に再確認する'
      },
      source: { url: 'https://www.town.nachikatsuura.wakayama.jp/info/1401', checkedAt }
    },
    note: '精度監査で、子ども要件のない一般空き家改修支援を子育て世帯向け住宅支援から除外。'
  },
  '30422': {
    name: '太地町',
    summary: '太地町の子育て、教育、住宅、生活、防災に関する9制度を公式情報で確認。広域病児保育、学校給食費無償化、誰でも通園、18歳未満帯同者加算がある移住支援事業などを記録。',
    housing: {
      status: 'verified',
      summary: '太地町が申請窓口となる和歌山県移住支援事業では、世帯向け支援に18歳未満の帯同者加算が設けられている。',
      details: {
        program: '和歌山県移住支援事業（太地町申請）',
        standardHousehold: '県の標準額は2人以上世帯100万円',
        standardChildAddition: '県の標準額は18歳未満の帯同者1人につき100万円加算',
        localApplication: '申請窓口は太地町役場総務課',
        requirements: '東京圏での居住・通勤歴、対象就業、起業、テレワーク等の要件がある',
        municipalityRule: '支援額や独自要件は市町村により異なる場合があるため、申請時は太地町の交付決定条件を適用',
        distinction: '空き家バンクの物件情報提供は住宅費補助ではないため分離'
      },
      source: { url: 'https://www.town.taiji.wakayama.jp/lifestage/sumai/sumai002.html', checkedAt },
      additionalSources: [
        { url: 'https://www.pref.wakayama.lg.jp/prefg/022200/d00216634.html', checkedAt }
      ]
    },
    note: '精度監査で、空き家バンクとの混在を解消し、太地町が申請窓口となる移住支援事業の18歳未満帯同者加算を明確化。'
  },
  '30424': {
    name: '古座川町',
    summary: '古座川町の子育て、教育、住宅、生活、防災に関する9制度を公式情報で確認。保育料・学校給食費無償化等を記録し、現行の個別条件を確認できない制度と子育て世帯専用住宅支援はunavailableとして整理した。',
    housing: {
      status: 'unavailable',
      summary: '移住定住者向け住宅新築・中古住宅購入等は子どもの有無を要件とすることを確認できず、子育て世帯専用の現行住宅支援を確認できない。',
      details: {
        checked: '町の移住定住、住宅新築、中古住宅、町産材、子育て支援の現行案内を確認',
        excludedGeneralPrograms: '移住定住目的の住宅新築・中古住宅購入等と町産材住宅支援は、公開情報上、子ども要件・子ども加算を確認できない',
        unconfirmed: '子ども要件または子ども加算がある住宅取得、改修、家賃、転居費支援',
        verificationPolicy: '現行要綱で子育て世帯区分を確認できた場合に再登録する'
      },
      source: { url: 'https://www.town.kozagawa.wakayama.jp/machidukuri/sub003.html', checkedAt }
    },
    note: '精度監査で、子ども要件を確認できない一般移住定住住宅支援を子育て世帯向け住宅支援から除外。'
  },
  '30427': {
    name: '北山村',
    summary: '北山村の子育て、教育、住宅、生活、防災に関する9制度を公式情報で確認。保育料・学校給食費無償化、小学生以下の子ども加算がある住宅取得・空き家改修支援などを記録。',
    housing: {
      status: 'verified',
      summary: '村外から転入して住宅を取得または空き家を改修する世帯に、小学生以下の子ども1人につき25万円を加算する。',
      details: {
        purchaseProgram: '北山村住宅取得補助金',
        purchaseBase: '村外からの転入者に取得費の10％、上限200万円を補助',
        purchaseChildAddition: '取得金額を上限に、小学生以下の子ども1人につき25万円を加算',
        renovationProgram: '北山村空き家改修補助金',
        renovationBase: '村外からの転入者に改修費の50％、上限100万円を補助',
        renovationChildAddition: '改修金額を上限に、小学生以下の子ども1人につき25万円を加算',
        conditions: '転入、定住、住宅、申請時期等の条件がある'
      },
      source: { url: 'https://www.vill.kitayama.wakayama.jp/kurashi/system/', checkedAt }
    },
    note: '精度監査で、一般的な住宅取得・定住住宅表示を、小学生以下1人25万円加算の住宅取得・空き家改修支援へ現行化。'
  },
  '30428': {
    name: '串本町',
    summary: '串本町の子育て、教育、住宅、生活、防災に関する9制度を公式情報で確認。病児保育、学校給食費無償化、産後ケア、誰でも通園等を記録し、子育て世帯専用住宅支援は未確認として整理した。',
    housing: {
      status: 'unavailable',
      summary: '紀州材住宅補助と移住就業支援は子どもの有無を要件とせず、現行要綱に子ども加算を確認できないため、子育て世帯専用の住宅支援を確認できない。',
      details: {
        checked: '紀州材利用促進事業、移住就業支援、住宅、子育て支援の現行要綱を確認',
        excludedTimberProgram: '紀州材住宅の新築・増改築支援は町内居住者・転入予定者一般が対象',
        migrationProgram: '移住就業支援は単身60万円、2人以上世帯100万円だが、令和7年7月15日施行の現行要綱に18歳未満加算額を定めていない',
        unconfirmed: '子ども要件または子ども加算がある住宅取得、改修、家賃、転居費支援',
        verificationPolicy: '移住支援要綱の改正または子育て住宅制度の新設時に再確認する'
      },
      source: { url: 'https://www.town.kushimoto.wakayama.jp/reiki_int/reiki_honbun/r218RG00001026.html', checkedAt },
      additionalSources: [
        { url: 'https://www.town.kushimoto.wakayama.jp/sangyo/ringyou/kisyuzai-hojo.html', checkedAt }
      ]
    },
    note: '精度監査で、子ども要件のない紀州材住宅支援と子ども加算のない移住就業支援を子育て世帯向け住宅支援から除外。'
  }
};

function serviceSources(municipality) {
  return [...new Set(Object.values(municipality.services)
    .map((service) => service?.source?.url)
    .filter(Boolean))];
}

async function applyCorrections() {
  for (const [code, config] of Object.entries(corrections)) {
    const municipalityPath = `data/municipalities/30/${code}.json`;
    const taskPath = `operations/tasks/${code}.json`;
    const municipality = JSON.parse(await readFile(municipalityPath, 'utf8'));
    const task = JSON.parse(await readFile(taskPath, 'utf8'));

    municipality.summary = config.summary;
    municipality.updatedAt = checkedAt;
    municipality.services.housingSupport = config.housing;

    task.status = 'pr_open';
    task.currentBranch = branch;
    task.pullRequestNumber = 2926;
    task.verifiedCount = Object.values(municipality.services).filter((service) => service.status === 'verified').length;
    task.unavailableCount = Object.values(municipality.services).filter((service) => service.status === 'unavailable').length;
    task.researchingCount = 0;
    task.needsMediumReviewCount = 0;
    task.lastCheckedAt = checkedAt;
    task.lastUpdatedAt = updatedAt;
    task.lastUpdatedBy = '中日本調査班B';
    task.officialSources = serviceSources(municipality);
    task.notes = (task.notes ?? []).filter((note) => !/住宅|移住|空き家|紀州材|定住/u.test(note));
    task.notes.push(config.note);

    await writeFile(municipalityPath, JSON.stringify(municipality) + '\n', 'utf8');
    await writeFile(taskPath, JSON.stringify(task) + '\n', 'utf8');
  }
}

async function finalizeAudit() {
  const audit = JSON.parse(await readFile(auditPath, 'utf8'));
  const output = JSON.parse(await readFile('operations/audits/central-b-accuracy-round-output.json', 'utf8'));
  const round = audit.batches.find((item) => item.round === 10);
  if (!round) throw new Error('Round 10 batch is missing.');
  if (output.round !== 10 || output.errorCount !== 0) throw new Error('Round 10 audit output is not clean.');
  round.status = 'completed';

  audit.progress.completedRounds = 10;
  audit.progress.structurallyCheckedMunicipalities = 95;
  audit.progress.deepCheckedMunicipalities = 88;
  audit.progress.confirmedErrors = 57;
  audit.progress.correctedErrors = 57;

  audit.findings = audit.findings.filter((finding) => finding.round !== 10);
  audit.findings.push({
    round: 10,
    auditedAt: new Date().toISOString(),
    codes: round.codes,
    structuralAudit: {
      result: 'passed',
      checkedMunicipalities: 7,
      errors: 0,
      warnings: 0,
      workflowRunId: 30116052212,
      artifactId: 8605455009,
      artifactDigest: 'sha256:6a2090559967ef8fde9cb89117363d2950bc22a94f8aab030a2f3285fd186ef3',
      postCorrectionWorkflowRunId: Number(process.env.GITHUB_RUN_ID ?? 0),
      postCorrectionResult: 'success',
      checks: [
        '自治体コード・都道府県コード',
        '必須9制度',
        'verified/unavailable件数',
        'task集計・完了位置',
        '制度主出典とtask公式出典',
        '公式HTTPS URL・確認日',
        'verified制度の対象年齢',
        '過年度・未確認表現'
      ]
    },
    deepChecks: [
      { code: '30404', name: '上富田町', services: ['sickChildCare','schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'corrected', note: '病児保育、給食費無償化、産後ケア、誰でも通園は一致。住宅支援を18歳未満1人100万円加算の移住支援金へ限定。' },
      { code: '30406', name: 'すさみ町', services: ['sickChildCare','schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'corrected', note: '給食費無償化、産後ケア、誰でも通園は一致。子ども要件のない一般定住住宅支援を除外。' },
      { code: '30421', name: '那智勝浦町', services: ['sickChildCare','schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'corrected', note: '病児保育、給食費無償化、産後ケア、誰でも通園は一致。子ども要件のない一般空き家改修支援を除外。' },
      { code: '30422', name: '太地町', services: ['sickChildCare','schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'corrected', note: '病児保育、給食費無償化、誰でも通園は一致。県移住支援事業の18歳未満帯同者加算へ表示を限定。' },
      { code: '30424', name: '古座川町', services: ['sickChildCare','schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'corrected', note: '保育料・給食費無償化は維持。子ども要件を確認できない一般移住定住住宅支援を除外。' },
      { code: '30427', name: '北山村', services: ['schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'corrected', note: '保育料・給食費無償化は一致。住宅取得・空き家改修の小学生以下1人25万円加算を明確化。' },
      { code: '30428', name: '串本町', services: ['sickChildCare','schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'corrected', note: '病児保育、給食費無償化、産後ケア、誰でも通園は一致。子ども要件・加算のない一般住宅・移住支援を除外。' }
    ],
    confirmedErrors: [
      { code: '30404', service: 'housingSupport', before: 'verified / 一般紀州材住宅支援と子ども加算未記載の移住支援を混在', after: 'verified / 18歳未満1人100万円加算の移住支援金に限定', status: 'corrected_in_audit_pr_2926' },
      { code: '30406', service: 'housingSupport', before: 'verified / 子ども要件のない一般定住住宅支援', after: 'unavailable / 子育て世帯専用住宅支援を確認できない', status: 'corrected_in_audit_pr_2926' },
      { code: '30421', service: 'housingSupport', before: 'verified / 子ども要件のない一般空き家改修支援', after: 'unavailable / 子育て世帯専用住宅支援を確認できない', status: 'corrected_in_audit_pr_2926' },
      { code: '30422', service: 'housingSupport', before: 'verified / 移住支援と空き家バンクを混在し子ども加算不明', after: 'verified / 県移住支援事業の18歳未満帯同者加算に限定', status: 'corrected_in_audit_pr_2926' },
      { code: '30424', service: 'housingSupport', before: 'verified / 子ども要件を確認できない一般移住定住住宅支援', after: 'unavailable / 子育て世帯専用住宅支援を確認できない', status: 'corrected_in_audit_pr_2926' },
      { code: '30427', service: 'housingSupport', before: 'verified / 一般住宅取得・定住住宅の概要のみ', after: 'verified / 小学生以下1人25万円加算の住宅取得・空き家改修支援', status: 'corrected_in_audit_pr_2926' },
      { code: '30428', service: 'housingSupport', before: 'verified / 子ども要件のない紀州材住宅支援', after: 'unavailable / 現行要綱に子育て世帯専用住宅支援を確認できない', status: 'corrected_in_audit_pr_2926' }
    ]
  });

  await writeFile(auditPath, JSON.stringify(audit, null, 2) + '\n', 'utf8');
}

const mode = process.argv[2];
if (mode === 'apply') await applyCorrections();
else if (mode === 'finalize') await finalizeAudit();
else throw new Error('Usage: node scripts/fix-central-b-accuracy-round10.mjs apply|finalize');
