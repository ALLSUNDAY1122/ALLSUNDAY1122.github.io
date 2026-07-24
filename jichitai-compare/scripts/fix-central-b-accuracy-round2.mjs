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
const ROUND = 2;

const unavailableUpdates = {
  '26210': {
    service: 'housingSupport',
    summary: '令和8年度の八幡市公式子育て支援案内で、子育て世帯を対象とする住宅取得・改修・家賃支援を確認できない。',
    details: {
      checked: '令和8年度の子育て支援・助成一覧と市の住宅関連案内を確認',
      excludedGeneralProgram: '住居確保給付金は離職・収入減等による生活困窮者全般を対象とするため、子育て世帯向け住宅支援として扱わない',
      unconfirmed: '子育て世帯を対象とする住宅取得、住宅改修、家賃補助、転居費補助の現行制度',
      verificationPolicy: '制度の有無と募集状況は子育て支援課または住宅担当課へ確認する'
    },
    source: 'https://www.city.yawata.kyoto.jp/soshiki/45-2-0-0-0_3.html',
    additional: ['https://www.city.yawata.kyoto.jp/0000006221.html'],
    note: '住宅支援は、生活困窮者全般向け住居確保給付金を子育て世帯向け制度として扱っていたためunavailableへ訂正。'
  },
  '26211': {
    service: 'housingSupport',
    summary: '令和8年度の京田辺市公式子育て支援案内で、子育て世帯を対象とする住宅取得・改修・家賃支援を確認できない。',
    details: {
      checked: '令和8年度子育て応援ガイドブック、子育て助成・支援一覧、住宅関連案内を確認',
      excludedGeneralProgram: '住居確保給付金は離職・休業等による生活困窮者全般を対象とするため、子育て世帯向け住宅支援として扱わない',
      unconfirmed: '子育て世帯を対象とする住宅取得、住宅改修、家賃補助、転居費補助の現行制度',
      verificationPolicy: '制度の有無と募集状況は子育て支援課または住宅担当課へ確認する'
    },
    source: 'https://www.city.kyotanabe.lg.jp/kosodate/category/13-4-6-0-0-0-0-0-0-0.html',
    additional: ['https://www.city.kyotanabe.lg.jp/0000003744.html'],
    note: '住宅支援は、生活困窮者全般向け住居確保給付金を子育て世帯向け制度として扱っていたためunavailableへ訂正。'
  },
  '26213': {
    service: 'postpartumCare',
    summary: '妊産婦・新生児訪問や産後の交流行事は確認できるが、宿泊・通所・訪問型の産後ケア事業としての利用条件を示す市公式案内を確認できない。',
    details: {
      confirmed: '保健師等による妊産婦訪問、新生児訪問、産前・産後ケア専門員による情報提供、産後1年までの母子向け交流行事を実施',
      distinction: '一般の訪問指導・相談・交流行事は、母子保健法上の産後ケア事業の宿泊型・通所型・居宅訪問型とは区別する',
      unconfirmed: '産後ケア事業の利用類型、実施施設、利用上限、自己負担額、申請・決定方法',
      verificationPolicy: '産後ケア事業としての利用可否は南丹市こども家庭課へ確認する'
    },
    source: 'https://www.city.nantan.kyoto.jp/www/life/111/001/000/index_9836.html',
    additional: [
      'https://www.city.nantan.kyoto.jp/www/life/110/001/000/index_1018437.html',
      'https://www.city.nantan.kyoto.jp/www/life/111/001/000/index_9835.html'
    ],
    note: '産後ケアは、一般の妊産婦・新生児訪問と交流行事を正式な産後ケア事業としてverified記録していたためunavailableへ訂正。'
  },
  '26214': {
    service: 'housingSupport',
    summary: '令和8年度の木津川市公式子育て支援案内で、子育て世帯を対象とする住宅取得・改修・家賃支援を確認できない。',
    details: {
      checked: '子育て応援サイトの助成・支援、住宅・移住・耐震関連の現行案内を確認',
      excludedGeneralPrograms: '空家移住支援や木造住宅耐震改修は一般の移住者・住宅所有者向けであり、子育て世帯向け住宅支援として扱わない',
      unconfirmed: '子育て世帯を対象とする住宅取得、住宅改修、家賃補助、転居費補助の現行制度',
      verificationPolicy: '制度の有無と募集状況はこども未来課または住宅担当課へ確認する'
    },
    source: 'https://www.city.kizugawa.lg.jp/kosodate/category/7-19-0-0-0-0-0-0-0-0.html',
    additional: [],
    note: '住宅支援は、一般の移住・耐震制度を子育て世帯向け制度として扱っていたためunavailableへ訂正。'
  },
  '26303': {
    service: 'housingSupport',
    summary: '令和8年度の大山崎町公式子育て支援案内で、子育て世帯を対象とする住宅取得・改修・家賃支援を確認できない。',
    details: {
      checked: '町の子育て支援事業一覧、住宅窓断熱改修、木造住宅耐震改修の現行案内を確認',
      excludedGeneralPrograms: '窓断熱改修と木造住宅耐震改修は一般住宅向けであり、子育て世帯向け住宅支援として扱わない',
      unconfirmed: '子育て世帯を対象とする住宅取得、住宅改修、家賃補助、転居費補助の現行制度',
      verificationPolicy: '制度の有無と募集状況は福祉課または建設担当課へ確認する'
    },
    source: 'https://www.town.oyamazaki.kyoto.jp/kosodatekyoiku/kosodate/index.html',
    additional: [
      'https://www.town.oyamazaki.kyoto.jp/annai/keizaikankyoka/seisokankyokakari/kankyo_kogai/11406.html',
      'https://www.town.oyamazaki.kyoto.jp/annai/kensetsuka/toshikeikakukakari/taisinsinndann_kaisyuu/11437.html'
    ],
    note: '住宅支援は、一般住宅向け断熱・耐震改修を子育て世帯向け制度として扱っていたためunavailableへ訂正。'
  }
};

const verifiedUpdates = {
  '26322': {
    service: 'housingSupport',
    summary: '18歳未満の子どもがいる一定所得以下の世帯に、育児負担軽減のための住宅リフォーム費を2分の1、最大30万円まで補助する。',
    details: {
      program: '久御山町子育て応援住宅支援事業補助金',
      target: '18歳未満の子どもがいる世帯で、親権者の合計所得550万円未満、町税・府税の滞納がないこと',
      targetWork: 'リビング、台所、浴室、子ども部屋について、子育ての負担軽減を目的に行う20万円以上のリフォーム',
      rate: '補助対象工事費の2分の1',
      cap: '子ども1人10万円、2人20万円、3人以上30万円',
      threeGeneration: '新たな三世代同居または近居を行う場合は5万円を加算',
      application: '工事契約前に申請し、交付決定後に契約・着工する',
      availability: '申請書類を町公式ページで公開。予算残額と受付状況は契約前に町へ確認する'
    },
    source: 'https://www.town.kumiyama.lg.jp/0000006015.html',
    additional: [],
    note: '住宅支援を一般の省エネ・断熱補助から、実在する子育て応援住宅リフォーム補助へ訂正。'
  },
  '26343': {
    service: 'housingSupport',
    summary: '町外から井手町へUターンし、18歳未満の子どもまたは胎児を養育する世帯も、井手地区の町営・府営住宅募集へ申込みできる。',
    details: {
      program: '井手地区町営住宅・府営住宅の子育てUターン世帯申込',
      housing: '井手地区団地の町営住宅北団地・南団地、府営住宅井手団地',
      target: '申込時に町外在住で井手町へUターンし、18歳未満の子ども（胎児を含む）を養育する世帯',
      priorResidence: '過去に井手町内へ3か月以上継続して在住したことを住民票の除票等で確認できること',
      household: '高齢・障がい単身者向けを除き、原則2人以上の世帯',
      currentRecruitment: '令和8年2月から3月の募集では9戸を募集し、令和8年4月入居予定と案内',
      application: '募集期間ごとに配布される募集案内を確認し、いづみ人権交流センター内の担当課へ申込む',
      distinction: '東京圏からの一般移住支援金ではなく、子育てUターン世帯が利用できる公営住宅制度として記録'
    },
    source: 'https://www.town.ide.kyoto.jp/soshiki/kensatsuka/osirase/3977.html',
    additional: [],
    note: '住宅支援を一般移住支援金から、子育てUターン世帯が申込み可能な町営・府営住宅制度へ訂正。'
  }
};

function municipalityPath(code) {
  return join(PROJECT_DIR, 'data', 'municipalities', code.slice(0, 2), `${code}.json`);
}

function taskPath(code) {
  return join(PROJECT_DIR, 'operations', 'tasks', `${code}.json`);
}

async function readJson(path) {
  return JSON.parse(await readFile(path, 'utf8'));
}

async function writeJson(path, value) {
  await writeFile(path, JSON.stringify(value, null, 2) + '\n', 'utf8');
}

function primarySources(municipality, serviceIds) {
  return [...new Set(serviceIds.map((id) => municipality.services[id]?.source?.url).filter(Boolean))];
}

function jstNow() {
  const shifted = new Date(Date.now() + 9 * 60 * 60 * 1000).toISOString().replace('Z', '+09:00');
  return shifted;
}

async function applyUpdates() {
  const audit = await readJson(AUDIT_PATH);
  const batch = audit.batches.find((item) => item.round === ROUND);
  if (!batch || batch.status === 'completed') {
    console.log('Round 2 is already completed; no data update required.');
    return;
  }

  const serviceIds = (await readJson(DEFINITIONS_PATH)).services.map((item) => item.id);
  const allUpdates = { ...unavailableUpdates, ...verifiedUpdates };

  for (const [code, update] of Object.entries(allUpdates)) {
    const municipality = await readJson(municipalityPath(code));
    const service = municipality.services[update.service];

    service.status = code in unavailableUpdates ? 'unavailable' : 'verified';
    service.summary = update.summary;
    service.details = update.details;
    service.source = { url: update.source, checkedAt: CHECKED_AT };
    service.additionalSources = update.additional.map((url) => ({ url, checkedAt: CHECKED_AT }));
    if (service.additionalSources.length === 0) delete service.additionalSources;
    if (service.status === 'unavailable') delete service.eligibility;
    municipality.updatedAt = CHECKED_AT;
    await writeJson(municipalityPath(code), municipality);

    const task = await readJson(taskPath(code));
    const statuses = serviceIds.map((id) => municipality.services[id]?.status);
    task.status = 'pr_open';
    task.currentService = null;
    task.nextServiceIndex = serviceIds.length;
    task.completedServices = [...serviceIds];
    task.verifiedCount = statuses.filter((status) => status === 'verified').length;
    task.researchingCount = 0;
    task.unavailableCount = statuses.filter((status) => status === 'unavailable').length;
    task.needsMediumReviewCount = 0;
    task.currentBranch = BRANCH;
    task.pullRequestNumber = PR_NUMBER;
    task.lastCheckedAt = CHECKED_AT;
    task.lastUpdatedAt = jstNow();
    task.lastUpdatedBy = '中日本調査班B';
    task.officialSources = primarySources(municipality, serviceIds);
    task.notes = (task.notes ?? []).filter((note) => !note.includes('住宅支援') && !(update.service === 'postpartumCare' && note.includes('産後')));
    task.notes.push(update.note, `10回精度監査PR #${PR_NUMBER} 第2回で訂正。`);
    task.blockers = [];
    await writeJson(taskPath(code), task);
  }

  console.log(`Applied ${Object.keys(allUpdates).length} Round 2 corrections.`);
}

async function finalizeAudit() {
  const audit = await readJson(AUDIT_PATH);
  const batch = audit.batches.find((item) => item.round === ROUND);
  if (!batch || batch.status === 'completed') {
    console.log('Round 2 audit is already finalized.');
    return;
  }

  batch.status = 'completed';
  audit.progress = {
    completedRounds: 2,
    structurallyCheckedMunicipalities: 20,
    deepCheckedMunicipalities: 13,
    confirmedErrors: 9,
    correctedErrors: 9
  };

  if (!audit.findings.some((item) => item.round === ROUND)) {
    audit.findings.push({
      round: ROUND,
      auditedAt: '2026-07-25T00:45:00+09:00',
      codes: batch.codes,
      structuralAudit: {
        result: 'passed',
        checkedMunicipalities: 10,
        errors: 0,
        warnings: 0,
        workflowRunId: 30105670612,
        artifactId: 8601465139,
        artifactDigest: 'sha256:2ef43242fcdc6882c132cc63287c30d7e7034a112218c838cc5c2574a65ead61',
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
        { code: '26210', name: '八幡市', services: ['housingSupport'], result: 'corrected', note: '生活困窮者全般向け住居確保給付金を子育て世帯向け住宅支援としていたためunavailableへ訂正。' },
        { code: '26211', name: '京田辺市', services: ['housingSupport'], result: 'corrected', note: '生活困窮者全般向け住居確保給付金を子育て世帯向け住宅支援としていたためunavailableへ訂正。' },
        { code: '26213', name: '南丹市', services: ['postpartumCare'], result: 'corrected', note: '一般の妊産婦・新生児訪問と交流行事を正式な産後ケア事業としていたためunavailableへ訂正。' },
        { code: '26214', name: '木津川市', services: ['housingSupport'], result: 'corrected', note: '一般の移住・耐震制度を子育て世帯向け住宅支援としていたためunavailableへ訂正。' },
        { code: '26303', name: '大山崎町', services: ['housingSupport'], result: 'corrected', note: '一般住宅向け断熱・耐震改修を子育て世帯向け住宅支援としていたためunavailableへ訂正。' },
        { code: '26322', name: '久御山町', services: ['housingSupport'], result: 'corrected', note: '一般の省エネ・断熱補助から、子育て世帯向け住宅リフォーム補助へ内容と一次出典を訂正。' },
        { code: '26343', name: '井手町', services: ['housingSupport'], result: 'corrected', note: '一般移住支援金から、子育てUターン世帯が申込み可能な公営住宅制度へ内容と一次出典を訂正。' },
        { code: '26364', name: '笠置町', services: ['sickChildCare', 'temporaryChildcare', 'housingSupport'], result: 'no_confirmed_error', note: '利用条件未公開部分を推測せず区別した記録と、子育て住宅改修・新婚住宅支援の記録は妥当。' }
      ],
      confirmedErrors: [
        { code: '26210', service: 'housingSupport', before: 'verified / 一般の住居確保給付金', after: 'unavailable / 子育て世帯向け現行住宅支援を確認できない', status: 'corrected_in_audit_pr_2926' },
        { code: '26211', service: 'housingSupport', before: 'verified / 一般の住居確保給付金', after: 'unavailable / 子育て世帯向け現行住宅支援を確認できない', status: 'corrected_in_audit_pr_2926' },
        { code: '26213', service: 'postpartumCare', before: 'verified / 一般訪問・交流行事', after: 'unavailable / 正式な産後ケア利用条件を確認できない', status: 'corrected_in_audit_pr_2926' },
        { code: '26214', service: 'housingSupport', before: 'verified / 一般の移住・耐震制度', after: 'unavailable / 子育て世帯向け現行住宅支援を確認できない', status: 'corrected_in_audit_pr_2926' },
        { code: '26303', service: 'housingSupport', before: 'verified / 一般の断熱・耐震制度', after: 'unavailable / 子育て世帯向け現行住宅支援を確認できない', status: 'corrected_in_audit_pr_2926' },
        { code: '26322', service: 'housingSupport', before: 'verified / 一般の省エネ・断熱補助', after: 'verified / 子育て応援住宅リフォーム補助', status: 'corrected_in_audit_pr_2926' },
        { code: '26343', service: 'housingSupport', before: 'verified / 一般移住支援金', after: 'verified / 子育てUターン世帯向け公営住宅申込', status: 'corrected_in_audit_pr_2926' }
      ]
    });
  }

  await writeJson(AUDIT_PATH, audit);
  console.log('Finalized Round 2 audit.');
}

if (MODE === 'apply') {
  await applyUpdates();
} else if (MODE === 'finalize') {
  await finalizeAudit();
} else {
  throw new Error(`Unknown mode: ${MODE}`);
}
