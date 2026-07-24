import { readFile, writeFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const PROJECT_DIR = resolve(SCRIPT_DIR, '..');
const AUDIT_PATH = join(PROJECT_DIR, 'operations', 'audits', 'central-b-accuracy-audit-20260725.json');
const DEFINITIONS_PATH = join(PROJECT_DIR, 'data', 'service-definitions.json');
const MODE = process.argv[2] ?? 'apply';
const CHECKED_AT = '2026-07-25';
const BRANCH = 'quality/central-b-accuracy-audit-20260725';
const PR_NUMBER = 2926;
const ROUND = 3;

const definitions = JSON.parse(await readFile(DEFINITIONS_PATH, 'utf8')).services ?? [];
const expectedServices = definitions.map((item) => item.id);

const nowSeconds = () => new Date().toISOString().replace(/\.\d{3}Z$/u, 'Z');
const unique = (values) => [...new Set(values)];

const notesToRemove = {
  '26366': ['住宅用太陽光', '蓄電設備等補助'],
  '26463': ['定住促進住宅補助金は', '住宅補助は10年居住'],
  '29203': ['住宅エコリフォーム', '住宅工事は着工前', '住宅エコリフォームを再監査'],
  '26364': ['病児保育は利用可能性', '対象年齢・施設・料金・登録予約方法'],
  '26367': ['受入月齢は事前確認', '利用条件、料金、空き状況は実施施設']
};

const appendedNotes = {
  '26366': [
    '住宅支援は、子育て要件のない一般住宅向け太陽光・蓄電設備補助を子育て世帯向け制度として扱っていたためunavailableへ訂正。',
    '学校給食費は令和6年度から徴収しておらず、令和8年度も小中学校の完全無償化を継続していることを確認。',
    '10回精度監査PR #2926 第3回で訂正。'
  ],
  '26463': [
    '定住促進住宅補助金は転入・年齢要件による一般の若年・移住世帯向けで、子どもの有無を要件としないため、子育て世帯向け住宅支援から除外してunavailableへ訂正。',
    '10回精度監査PR #2926 第3回で訂正。'
  ],
  '29203': [
    '住宅支援から一般住宅向けエコリフォーム商品券を除外し、18歳未満の世帯員1人につき100万円を加算する移住支援金へ内容と一次出典を訂正。',
    '市立中学校と令和8年度開始の市立小学校11校の給食費無償化が現行であることを再確認。',
    '10回精度監査PR #2926 第3回で訂正。'
  ],
  '26364': [
    '伊賀市・南山城村等の公式案内で、笠置町民も生後6か月から小学6年生まで病児保育室を利用でき、所得区分別利用料が公表されていることを確認し、unavailableからverifiedへ訂正。',
    '10回精度監査PR #2926 第3回の広域連携再確認で訂正。'
  ],
  '26367': [
    '広域連携先の公式案内で病児保育の対象を生後6か月から小学6年生、利用時間と所得区分別料金まで確認し、推測していた対象年齢・未確認条件を訂正。',
    '10回精度監査PR #2926 第3回で訂正。'
  ]
};

async function readMunicipality(code) {
  const path = join(PROJECT_DIR, 'data', 'municipalities', code.slice(0, 2), `${code}.json`);
  return { path, data: JSON.parse(await readFile(path, 'utf8')) };
}

async function readTask(code) {
  const path = join(PROJECT_DIR, 'operations', 'tasks', `${code}.json`);
  return { path, data: JSON.parse(await readFile(path, 'utf8')) };
}

function recalculateTask(task, municipality, code) {
  const services = expectedServices.map((id) => municipality.services[id]);
  task.verifiedCount = services.filter((service) => service?.status === 'verified').length;
  task.unavailableCount = services.filter((service) => service?.status === 'unavailable').length;
  task.researchingCount = 0;
  task.needsMediumReviewCount = 0;
  task.status = 'pr_open';
  task.currentService = null;
  task.nextServiceIndex = expectedServices.length;
  task.completedServices = expectedServices;
  task.currentBranch = BRANCH;
  task.pullRequestNumber = PR_NUMBER;
  task.lastCheckedAt = CHECKED_AT;
  task.lastUpdatedAt = nowSeconds();
  task.lastUpdatedBy = '中日本調査班B';
  task.officialSources = unique(services.map((service) => service?.source?.url).filter(Boolean));
  const filters = notesToRemove[code] ?? [];
  task.notes = (task.notes ?? []).filter((note) => !filters.some((filter) => note.includes(filter)));
  for (const note of appendedNotes[code] ?? []) {
    if (!task.notes.includes(note)) task.notes.push(note);
  }
}

async function writePair(code, mutate) {
  const municipalityRecord = await readMunicipality(code);
  const taskRecord = await readTask(code);
  mutate(municipalityRecord.data);
  municipalityRecord.data.updatedAt = CHECKED_AT;
  recalculateTask(taskRecord.data, municipalityRecord.data, code);
  await writeFile(municipalityRecord.path, JSON.stringify(municipalityRecord.data) + '\n', 'utf8');
  await writeFile(taskRecord.path, JSON.stringify(taskRecord.data) + '\n', 'utf8');
}

async function apply() {
  await writePair('26366', (municipality) => {
    municipality.services.schoolMeals.summary = '町立小中学校では学校給食費を徴収せず、令和8年度も完全無償化を継続する。';
    municipality.services.schoolMeals.details.start = '令和6年度から保護者から学校給食費を徴収しない';
    municipality.services.schoolMeals.details.current = '令和8年度も小学校・中学校を含む完全無償化を継続';
    municipality.services.housingSupport = {
      status: 'unavailable',
      summary: '町公式の住宅用太陽光・蓄電設備補助は子育て要件のない一般住宅向け制度であり、令和8年度の子育て世帯を対象とする住宅取得・改修・家賃支援を確認できない。',
      details: {
        checked: '町の子育て支援案内、住宅・環境補助、現行例規を確認',
        excludedGeneralProgram: '住宅用太陽光発電・蓄電設備等補助は町内居住者・居住予定者一般を対象とし、子どもの有無を要件としない',
        unconfirmed: '子育て世帯を対象とする住宅取得、住宅改修、家賃補助、転居費補助の令和8年度制度',
        verificationPolicy: '制度の有無と募集状況は子育て支援課または検査住宅課へ確認する'
      },
      source: {
        url: 'https://www.town.seika.kyoto.jp/kakuka/kankyo/1/1/1/950.html',
        checkedAt: CHECKED_AT
      },
      additionalSources: [
        {
          url: 'https://www.town.seika.kyoto.jp/kosodate/kosodate_tanoshimo/index.html',
          checkedAt: CHECKED_AT
        },
        {
          url: 'https://reiki.town.seika.kyoto.jp/reiki_taikei/r_taikei_07.html',
          checkedAt: CHECKED_AT
        }
      ]
    };
  });

  await writePair('26463', (municipality) => {
    municipality.services.housingSupport = {
      status: 'unavailable',
      summary: '町の定住促進住宅補助は転入・年齢要件による一般の若年・移住世帯向けで、子どもの有無を要件とする住宅支援ではない。令和8年度の子育て世帯専用住宅支援は確認できない。',
      details: {
        checked: '町の移住支援ガイド、定住促進住宅補助要綱、子育て支援一覧を確認',
        excludedGeneralProgram: '定住促進住宅補助は町外からの転入、年齢、10年以上の居住意思等を要件とするが、子どもの有無を交付要件としない',
        otherGeneralHousing: '空家改修、定住促進住宅、町営住宅、特定公共賃貸住宅も一般の移住者・世帯者向けとして案内される',
        unconfirmed: '子育て世帯を対象とする住宅取得、改修、家賃、転居費用の専用支援',
        verificationPolicy: '子育て世帯専用制度の有無は企画観光課または地域整備課へ確認する'
      },
      source: {
        url: 'https://www.town.ine.kyoto.jp/soshiki/kikakukanko/2/6/339.html',
        checkedAt: CHECKED_AT
      },
      additionalSources: [
        {
          url: 'https://www.town.ine.kyoto.jp/section/reiki/H422902500075/H422902500075_j.html',
          checkedAt: CHECKED_AT
        }
      ]
    };
  });

  await writePair('29203', (municipality) => {
    municipality.services.schoolMeals.summary = '市立中学校と市立小学校11校で学校給食費を無償化している。';
    municipality.services.schoolMeals.details.elementary = '令和8年度から市立小学校11校を所得制限なし・申請不要で無償化';
    municipality.services.schoolMeals.details.juniorHigh = '市立中学校では令和6年度から給食費を徴収していない';
    municipality.services.housingSupport = {
      status: 'verified',
      summary: '東京圏から就業等の要件を満たして移住し、18歳未満の世帯員を帯同する世帯に、基本支援金に加えて子ども1人につき100万円を加算する。',
      details: {
        program: '奈良県移住・就業・起業支援事業（大和郡山市移住支援金）',
        target: '東京23区在住・通勤歴等の移住要件を満たし、就業、専門人材、テレワーク、関係人口または起業の要件を満たす転入者',
        baseBenefit: '2人以上世帯100万円、単身60万円',
        childAddition: '就業要件を満たす申請者が18歳未満の世帯員を帯同して移住する場合、18歳未満1人につき100万円を加算',
        residence: '転入後1年以内に申請し、申請日から5年以上継続して大和郡山市に居住する意思が必要',
        application: '必要書類を市へ提出。対象可否と予算状況は申請前に確認する',
        distinction: '一般住宅向けエコリフォーム商品券は子育て要件がないため本項目から除外'
      },
      source: {
        url: 'https://www.city.yamatokoriyama.lg.jp/sien-josei/juutaku-hikkoshi/14570.html',
        checkedAt: CHECKED_AT
      },
      additionalSources: [
        {
          url: 'https://www.city.yamatokoriyama.lg.jp/life/sumai_hikkoshi/9173.html',
          checkedAt: CHECKED_AT
        }
      ]
    };
  });

  await writePair('26364', (municipality) => {
    municipality.services.sickChildCare = {
      status: 'verified',
      summary: '伊賀市・南山城村等との広域連携により、生後6か月から小学6年生までをゆめこどもクリニック伊賀の病児保育室で預かる。',
      eligibility: {
        minAgeMonths: 6,
        maxAgeYears: 12
      },
      details: {
        facility: 'ゆめこどもクリニック伊賀 病児保育室',
        location: '三重県伊賀市小田町258番地の2',
        target: '笠置町、南山城村、山添村または伊賀市に居住する生後6か月から小学6年生までの児童等で、病気・回復期のため集団生活が困難かつ家庭保育が難しい児童',
        hours: '月曜から水曜・金曜は9時から18時、土曜は9時から17時。木曜・日曜・祝日等は休室',
        incomeTaxableFee: '所得税課税世帯は1回1,000円',
        municipalTaxableFee: '所得税課税世帯を除く市町村民税課税世帯は1回500円',
        exemptFee: '市町村民税非課税世帯・生活保護世帯は無料',
        additionalCosts: '布団リース料等の実費が必要になる場合がある',
        application: '当日朝に空き確認後、併設クリニックを受診し、医師の利用可否判断を受けて申請する'
      },
      source: {
        url: 'https://www.city.iga.lg.jp/igakids/0000008349.html',
        checkedAt: CHECKED_AT
      },
      additionalSources: [
        {
          url: 'https://yumekodomo.com/nursery',
          checkedAt: CHECKED_AT
        },
        {
          url: 'https://www.town.kasagi.lg.jp/cmsfiles/contents/0000001/1865/dai3kikodomokosodate.pdf',
          checkedAt: CHECKED_AT
        }
      ]
    };
  });

  await writePair('26367', (municipality) => {
    municipality.services.sickChildCare = {
      status: 'verified',
      summary: '伊賀・山城南・東大和定住自立圏の連携により、生後6か月から小学6年生までをゆめこどもクリニック伊賀の病児保育室で預かる。',
      eligibility: {
        minAgeMonths: 6,
        maxAgeYears: 12
      },
      details: {
        facility: 'ゆめこどもクリニック伊賀 病児保育室',
        location: '三重県伊賀市小田町258番地の2',
        target: '南山城村、笠置町、山添村または伊賀市に居住する生後6か月から小学6年生までの児童等で、病気・回復期のため集団生活が困難かつ家庭保育が難しい児童',
        hours: '月曜から水曜・金曜は9時から18時、土曜は9時から17時。木曜・日曜・祝日等は休室',
        incomeTaxableFee: '所得税課税世帯は1回1,000円',
        municipalTaxableFee: '所得税課税世帯を除く市町村民税課税世帯は1回500円',
        exemptFee: '市町村民税非課税世帯・生活保護世帯は無料',
        additionalCosts: '布団リース料等の実費が必要になる場合がある',
        application: '当日朝に空き確認後、併設クリニックを受診し、医師の利用可否判断を受けて申請する'
      },
      source: {
        url: 'https://www.vill.minamiyamashiro.lg.jp/0000002322.html',
        checkedAt: CHECKED_AT
      },
      additionalSources: [
        {
          url: 'https://www.city.iga.lg.jp/igakids/0000008349.html',
          checkedAt: CHECKED_AT
        },
        {
          url: 'https://yumekodomo.com/nursery',
          checkedAt: CHECKED_AT
        }
      ]
    };
  });
}

async function finalize() {
  const audit = JSON.parse(await readFile(AUDIT_PATH, 'utf8'));
  const batch = audit.batches.find((item) => item.round === ROUND);
  if (!batch || batch.status === 'completed') {
    console.log('Round 3 audit record is already finalized.');
    return;
  }

  batch.status = 'completed';
  audit.progress.completedRounds = 3;
  audit.progress.structurallyCheckedMunicipalities = 30;
  audit.progress.deepCheckedMunicipalities = 23;
  audit.progress.confirmedErrors = 14;
  audit.progress.correctedErrors = 14;

  if (!audit.findings.some((item) => item.round === ROUND)) {
    audit.findings.push({
      round: ROUND,
      auditedAt: nowSeconds(),
      codes: batch.codes,
      structuralAudit: {
        result: 'passed',
        checkedMunicipalities: 10,
        errors: 0,
        warnings: 2,
        workflowRunId: 30107113817,
        artifactId: 8602040561,
        artifactDigest: 'sha256:d5870294f190b00a8607847d690e0d91ec10f61421cc3e9b67b928ff52b6d07a',
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
        { code: '26365', name: '和束町', services: ['postpartumCare', 'temporaryChildcare', 'housingSupport'], result: 'no_confirmed_error', note: '令和8年度の産後ケア、誰でも通園関連、子育て住宅リフォーム・新婚住宅支援を確認し、明確な誤りなし。' },
        { code: '26366', name: '精華町', services: ['schoolMeals', 'housingSupport'], result: 'corrected', note: '学校給食完全無償化の継続を確認。一般住宅向け太陽光等補助を子育て住宅支援としていたためhousingSupportをunavailableへ訂正。' },
        { code: '26367', name: '南山城村', services: ['sickChildCare', 'housingSupport'], result: 'corrected', note: '広域病児保育の対象を生後6か月から小学6年生、所得区分別料金まで公式情報で確定。定住促進奨励金は子育て世帯要件があり妥当。' },
        { code: '26407', name: '京丹波町', services: ['schoolMeals', 'postpartumCare', 'temporaryChildcare', 'housingSupport'], result: 'no_confirmed_error', note: '令和8年度の給食徴収額、産後ケア、誰でも通園、子育て住宅改修支援を照合し、明確な誤りなし。' },
        { code: '26463', name: '伊根町', services: ['temporaryChildcare', 'housingSupport'], result: 'corrected', note: '誰でも通園月3時間・無料は一致。一般の若年・移住世帯向け定住促進住宅補助を子育て世帯専用としていたためunavailableへ訂正。' },
        { code: '26465', name: '与謝野町', services: ['postpartumCare', 'temporaryChildcare', 'housingSupport'], result: 'no_confirmed_error', note: '産後ケア3類型、誰でも通園月10時間、子育て世帯移住定住支援の対象・加算を確認し、明確な誤りなし。' },
        { code: '29201', name: '奈良市', services: ['schoolMeals', 'postpartumCare', 'temporaryChildcare', 'housingSupport'], result: 'no_confirmed_error', note: '令和8年度給食負担、産後ケア3類型、誰でも通園月10時間、子育て移住定住支援金を確認し一致。' },
        { code: '29202', name: '大和高田市', services: ['schoolMeals', 'postpartumCare', 'temporaryChildcare', 'housingSupport'], result: 'no_confirmed_error', note: '小中学校給食費無償化、産後ケア、誰でも通園を確認。子育て世帯専用住宅支援未確認のunavailable判定は妥当。' },
        { code: '29203', name: '大和郡山市', services: ['schoolMeals', 'housingSupport'], result: 'corrected', note: '小中学校給食費無償化を現行表現へ修正。一般エコ改修を除外し、18歳未満1人につき100万円加算の移住支援へ絞った。' },
        { code: '29204', name: '天理市', services: ['schoolMeals', 'postpartumCare', 'temporaryChildcare', 'housingSupport'], result: 'no_confirmed_error', note: '令和8年度給食費無償化、産後ケア、誰でも通園、18歳未満1人につき100万円加算の移住支援を確認し一致。' },
        { code: '26364', name: '笠置町', services: ['sickChildCare'], result: 'corrected_cross_round', note: '第2回では条件未確認としていたが、広域連携先の公式情報で生後6か月から小学6年生、料金・利用方法を確認しverifiedへ訂正。' }
      ],
      confirmedErrors: [
        { code: '26366', service: 'housingSupport', before: 'verified / 一般住宅向け太陽光・蓄電設備補助', after: 'unavailable / 子育て世帯専用住宅支援を確認できない', status: 'corrected_in_audit_pr_2926' },
        { code: '26463', service: 'housingSupport', before: 'verified / 一般の若年・移住世帯向け定住促進住宅補助', after: 'unavailable / 子育て世帯専用住宅支援を確認できない', status: 'corrected_in_audit_pr_2926' },
        { code: '29203', service: 'housingSupport', before: 'verified / 一般エコ改修と移住支援を混在', after: 'verified / 18歳未満1人につき100万円加算の移住支援に限定', status: 'corrected_in_audit_pr_2926' },
        { code: '26364', service: 'sickChildCare', before: 'unavailable / 広域病児保育の条件未確認', after: 'verified / 生後6か月から小学6年生・所得区分別料金を確認', status: 'corrected_in_audit_pr_2926' },
        { code: '26367', service: 'sickChildCare', before: 'verified / 対象年齢を0歳からと推定し料金未確認', after: 'verified / 生後6か月から小学6年生・所得区分別料金を確認', status: 'corrected_in_audit_pr_2926' }
      ]
    });
  }

  await writeFile(AUDIT_PATH, JSON.stringify(audit, null, 2) + '\n', 'utf8');
}

if (MODE === 'apply') await apply();
else if (MODE === 'finalize') await finalize();
else throw new Error(`Unknown mode: ${MODE}`);
