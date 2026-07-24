import { readFile, writeFile } from 'node:fs/promises';

const auditPath = 'operations/audits/central-b-accuracy-audit-20260725.json';
const branch = 'quality/central-b-accuracy-audit-20260725';
const checkedAt = '2026-07-25';
const updatedAt = '2026-07-25T02:45:00+09:00';

const corrections = {
  '30206': {
    prefectureCode: '30',
    summary: '田辺市の子育て、教育、住宅、生活、防災に関する9制度を公式情報で確認。令和8年度の給食費無償化、産後ケア、誰でも通園、18歳未満の帯同者加算がある移住支援金などを記録。',
    housing: {
      status: 'verified',
      summary: '東京圏から要件を満たして移住する2人以上世帯に100万円を交付し、18歳未満の帯同者1人につき100万円を加算する。',
      details: {
        program: '田辺市移住支援金',
        household: '2人以上世帯は100万円',
        childAddition: '申請年度4月1日時点で18歳未満の帯同世帯員1人につき100万円を加算（配偶者を除く）',
        migrationRequirements: '東京圏の居住・通勤歴に加え、対象就業、テレワーク、起業、関係人口等のいずれかを満たすこと',
        application: '転入後1年以内に申請し、申請前に移住定住推進係へ相談',
        residency: '申請後5年以上の田辺市内居住意思、市税完納等の要件あり',
        excludedGeneralPrograms: '県外移住者一般向け空き家改修と子ども要件のない結婚新生活支援は、この比較項目の中心制度として混在させない'
      },
      source: { url: 'https://www.city.tanabe.lg.jp/soshiki/kikaku/2/4/6_1/197.html', checkedAt }
    },
    removeNotes: ['空き家活用', '結婚新生活'],
    note: '精度監査で、一般移住者向け空き家改修・新婚支援を子育て住宅支援と混在させていたため、18歳未満1人100万円加算の移住支援金へ内容を限定して訂正。'
  },
  '30207': {
    prefectureCode: '30',
    summary: '新宮市の子育て、教育、住宅、生活、防災に関する9制度を公式情報で確認。病児保育、給食費無償化、産後ケア、誰でも通園等を記録し、子育て世帯専用住宅支援は未確認として整理した。',
    housing: {
      status: 'unavailable',
      summary: '空き家改修助成は県外移住者一般を対象とし、子どもの有無を要件としないため、子育て世帯専用の現行住宅支援を確認できない。',
      details: {
        checked: '市の空き家改修、住宅リフォーム、移住・定住、子育て支援に関する現行案内を確認',
        excludedGeneralProgram: '空き家改修助成は県外移住者が居住する空き家の改修を対象とし、県補助後の2分の1・上限50万円を助成する一般制度',
        currentGeneralProgram: '令和8年度住宅リフォーム助成も市民一般向けで、2026年5月22日に受付終了',
        unconfirmed: '子育て世帯を対象とする住宅取得、改修、家賃、転居費の現行制度',
        verificationPolicy: '制度の有無と募集状況は企画調整課または子育て推進担当へ確認する'
      },
      source: { url: 'https://www.city.shingu.lg.jp/Info/2712', checkedAt },
      additionalSources: [
        { url: 'https://www.city.shingu.lg.jp/Info/2415', checkedAt }
      ]
    },
    removeNotes: ['空き家改修'],
    note: '精度監査で、子ども要件・加算のない県外移住者一般向け空き家改修助成を子育て世帯向け住宅支援としていたため、housingSupportをverifiedからunavailableへ訂正。'
  },
  '30208': {
    prefectureCode: '30',
    summary: '紀の川市の子育て、教育、住宅、生活、防災に関する9制度を公式情報で確認。給食費無償化、産後ケア、誰でも通園、16歳未満の児童がいる世帯への住宅取得加算などを記録。',
    housing: {
      status: 'verified',
      summary: '45歳未満の住宅取得者が基礎要件を満たし、世帯に16歳未満の児童等がいる場合、基礎額30万円に児童加算10万円を上乗せする。',
      details: {
        program: '紀の川市若者定住促進住宅取得奨励金（児童加算）',
        baseRequirement: '登記受付日に45歳未満で市内住宅を取得し、定住意思、市税完納等の基礎要件を満たすこと',
        baseAmount: '30万円',
        childAddition: '登記受付日に16歳未満、または登記後に出生した児童が世帯にいる場合10万円加算',
        transferAddition: '別途、要件を満たす転入者が世帯にいる場合10万円加算',
        maximum: '基礎額と加算を合わせ最大50万円',
        eligibleHousing: '令和8年1月1日から12月31日までに所有権保存・移転登記を受けた床面積50平方メートル以上の市内住宅',
        application: '登記受付年の4月1日から翌年1月31日までに地域創生課へ申請'
      },
      source: { url: 'https://www.city.kinokawa.lg.jp/006/2020032724.html', checkedAt }
    },
    removeNotes: ['若者定住'],
    note: '精度監査で、45歳未満一般向けの基礎額と子育て支援を混在させていたため、16歳未満の児童等がいる世帯への10万円加算を明示して訂正。'
  },
  '30209': {
    prefectureCode: '30',
    summary: '岩出市の子育て、教育、住宅、生活、防災に関する9制度を公式情報で確認。病児保育、産後ケア、誰でも通園等を記録し、子育て世帯専用住宅支援は現行受付を確認できないものとして整理した。',
    housing: {
      status: 'unavailable',
      summary: '結婚世帯向け住宅取得補助は子どもの有無を要件とせず、18歳未満加算のある移住支援金は令和8年度の申請受付開始を確認できないため、子育て世帯専用の現行住宅支援を確認できない。',
      details: {
        checked: '市の令和8年度結婚・妊娠・共育て支援、移住支援、住宅、子育て支援の現行案内を確認',
        excludedMarriageProgram: '住宅購入・新築補助は婚姻時期、夫婦の年齢・所得等を要件とし、子どもの有無を要件としない',
        migrationProgramStatus: '移住支援金には18歳未満1人100万円加算があるが、公式ページは令和7年度受付終了後、令和8年度以降は改めて案内するとしている',
        unconfirmed: '令和8年度に現在申請できる子育て世帯向け住宅取得、改修、家賃、転居費制度',
        verificationPolicy: '移住支援金の令和8年度受付開始または新制度の公表時に再確認する'
      },
      source: { url: 'https://www.city.iwade.lg.jp/soshiki/2/10237.html', checkedAt },
      additionalSources: [
        { url: 'https://www.city.iwade.lg.jp/soshiki/16/1996.html', checkedAt }
      ]
    },
    removeNotes: ['結婚', '移住支援'],
    note: '精度監査で、子ども要件のない結婚世帯向け住宅取得補助と受付未確認の移住支援を子育て住宅支援としていたため、housingSupportをverifiedからunavailableへ訂正。'
  },
  '30304': {
    prefectureCode: '30',
    summary: '紀美野町の子育て、教育、住宅、生活、防災に関する9制度を公式情報で確認。保育料・給食費無償化、産後ケア、誰でも通園、18歳年度末までの子を養育する世帯等への定住促進加算を記録。',
    housing: {
      status: 'verified',
      summary: '50歳未満の住宅新築・購入・増改築等の基礎要件を満たし、18歳年度末までの子を養育する世帯または出産予定世帯には10万円を加算する。',
      details: {
        program: '紀美野町定住促進補助金（子育て世帯加算）',
        baseRequirement: '申請者が基準時点で50歳未満で、対象住宅に5年以上継続居住し、税滞納がないこと等',
        eligibleWork: '住宅の新築、購入、増改築・リフォーム等',
        childHousehold: '18歳に達する日以後最初の3月31日までの子を養育する世帯、または出産予定世帯',
        familyAddition: '基礎補助額に10万円を加算',
        distinction: '移住者加算・新婚世帯加算もあるが、この比較項目では子育て世帯加算に限定して記録',
        application: '先着順で予定金額到達時に終了するため、契約・工事前に企画管財課へ確認'
      },
      source: { url: 'https://www.town.kimino.wakayama.jp/sagasu/kikakukanzaika/jyuutakuhojo/195.html', checkedAt }
    },
    removeNotes: ['定住促進'],
    note: '精度監査で、一般・移住・新婚区分を混在させていたため、18歳年度末までの子を養育する世帯または出産予定世帯への10万円加算へ表示範囲を限定。'
  },
  '30341': {
    prefectureCode: '30',
    summary: 'かつらぎ町の子育て、教育、住宅、生活、防災に関する9制度を公式情報で確認。保育料・給食費無償化、産後ケア、誰でも通園等を記録し、子育て世帯専用住宅支援は未確認として整理した。',
    housing: {
      status: 'unavailable',
      summary: '空き家バンク物件の改修・家財片付け補助は移住者等一般を対象とし、子どもの有無を要件としないため、子育て世帯専用の現行住宅支援を確認できない。',
      details: {
        checked: '町の空き家活用、移住・定住、住宅、子育て支援の現行案内を確認',
        excludedGeneralProgram: '空き家改修は2分の1・上限100万円、家財片付けは上限8万円だが、子ども要件・子ども加算がない',
        unconfirmed: '子育て世帯を対象とする住宅取得、改修、家賃、転居費の現行制度',
        verificationPolicy: '制度の有無と募集状況は企画公室またはこども未来課へ確認する'
      },
      source: { url: 'https://www.town.katsuragi.wakayama.jp/teijyu/020/010/2023-0920-1532-16.html', checkedAt }
    },
    removeNotes: ['空き家活用'],
    note: '精度監査で、子ども要件・加算のない一般空き家改修・片付け補助を子育て世帯向け住宅支援としていたため、housingSupportをverifiedからunavailableへ訂正。'
  },
  '30344': {
    prefectureCode: '30',
    summary: '高野町の子育て、教育、住宅、生活、防災に関する9制度を公式情報で確認。保育料等無償化、一時預かり、誰でも通園等を記録し、子育て世帯専用住宅支援は未確認として整理した。',
    housing: {
      status: 'unavailable',
      summary: '住宅新築・中古住宅購入・空き家水回り改修補助は町民または移住者一般を対象とし、子どもの有無を要件としないため、子育て世帯専用の現行住宅支援を確認できない。',
      details: {
        checked: '町の移住定住推進補助、住宅、子育て支援の現行案内を確認',
        excludedGeneralProgram: '新築費2分の1・上限200万円、中古住宅購入費2分の1・上限80万円、水回り改修費2分の1・上限100万円は子ども要件・子ども加算がない',
        unconfirmed: '子育て世帯を対象とする住宅取得、改修、家賃、転居費の現行制度',
        verificationPolicy: '制度の有無と募集状況は観光振興課移住定住地域振興室または介護福祉課へ確認する'
      },
      source: { url: 'https://www.town.koya.wakayama.jp/sangyo/chiikisinnkou/19765.html', checkedAt }
    },
    removeNotes: ['移住定住推進', '住宅新築'],
    note: '精度監査で、子ども要件・加算のない一般の住宅新築・購入・改修補助を子育て世帯向け住宅支援としていたため、housingSupportをverifiedからunavailableへ訂正。'
  },
  '30361': {
    prefectureCode: '30',
    summary: '湯浅町の子育て、教育、住宅、生活、防災に関する9制度を公式情報で確認。病児保育、給食費無償化、産後ケア、誰でも通園、18歳未満の帯同者加算がある移住支援金などを記録。',
    housing: {
      status: 'verified',
      summary: '東京圏から要件を満たして移住する2人以上世帯に100万円を交付し、18歳未満の帯同者1人につき100万円を加算する。',
      details: {
        program: '湯浅町移住支援金',
        household: '2人以上世帯は100万円',
        childAddition: '18歳未満の帯同者1人につき100万円を加算',
        migrationRequirements: '東京圏の居住・通勤歴、対象就業・起業等の要件を満たすこと',
        application: '転入後1年以内等の申請要件があるため、ふるさと振興課へ事前確認',
        currentContext: '令和8年4月更新の町支援施策一覧でも移住・住まい支援を案内',
        excludedGeneralPrograms: '40歳以下のみを要件とする定住促進奨励金と子ども要件のない新生活支援は、この比較項目の中心制度として混在させない'
      },
      source: { url: 'https://www.town.yuasa.wakayama.jp/soshiki/4/9634.html', checkedAt },
      additionalSources: [
        { url: 'https://www.town.yuasa.wakayama.jp/soshiki/3/8991.html', checkedAt }
      ]
    },
    removeNotes: ['定住促進奨励金', '新生活支援'],
    note: '精度監査で、年齢要件のみの住宅取得支援等を子育て住宅支援と混在させていたため、18歳未満1人100万円加算の移住支援金へ内容を限定して訂正。'
  }
};

function serviceSources(municipality) {
  return [...new Set(Object.values(municipality.services)
    .map((service) => service?.source?.url)
    .filter(Boolean))];
}

async function applyCorrections() {
  for (const [code, config] of Object.entries(corrections)) {
    const municipalityPath = `data/municipalities/${config.prefectureCode}/${code}.json`;
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
    task.researchingCount = Object.values(municipality.services).filter((service) => service.status === 'researching').length;
    task.lastCheckedAt = checkedAt;
    task.lastUpdatedAt = updatedAt;
    task.lastUpdatedBy = '中日本調査班B';
    task.officialSources = serviceSources(municipality);
    task.notes = (task.notes ?? []).filter((note) => !config.removeNotes.some((phrase) => note.includes(phrase)));
    if (!task.notes.includes(config.note)) task.notes.push(config.note);

    await writeFile(municipalityPath, JSON.stringify(municipality) + '\n', 'utf8');
    await writeFile(taskPath, JSON.stringify(task) + '\n', 'utf8');
  }
}

async function finalizeAudit() {
  const audit = JSON.parse(await readFile(auditPath, 'utf8'));
  const output = JSON.parse(await readFile('operations/audits/central-b-accuracy-round-output.json', 'utf8'));
  const round = audit.batches.find((item) => item.round === 8);
  if (!round) throw new Error('Round 8 batch is missing.');
  if (output.round !== 8 || output.errorCount !== 0) throw new Error('Round 8 audit output is not clean.');
  round.status = 'completed';

  audit.progress.completedRounds = 8;
  audit.progress.structurallyCheckedMunicipalities = 79;
  audit.progress.deepCheckedMunicipalities = 72;
  audit.progress.confirmedErrors = 39;
  audit.progress.correctedErrors = 39;

  audit.findings = audit.findings.filter((finding) => finding.round !== 8);
  audit.findings.push({
    round: 8,
    auditedAt: new Date().toISOString(),
    codes: round.codes,
    structuralAudit: {
      result: 'passed',
      checkedMunicipalities: 9,
      errors: 0,
      warnings: 3,
      workflowRunId: 30113337925,
      artifactId: 8604413156,
      artifactDigest: 'sha256:8f21ffbaeabd608b9a91d08074f102d6e4c99b300a89dfd0da0f3739fa85de4e',
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
      { code: '30206', name: '田辺市', services: ['schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'corrected', note: '給食費無償化、産後ケア、誰でも通園は一致。住宅支援を18歳未満1人100万円加算の移住支援金へ限定。' },
      { code: '30207', name: '新宮市', services: ['schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'corrected', note: '給食費無償化、産後ケア、誰でも通園は一致。子ども要件のない一般空き家改修助成を除外。' },
      { code: '30208', name: '紀の川市', services: ['schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'corrected', note: '給食費無償化、産後ケア、誰でも通園は一致。住宅取得奨励金の児童加算10万円を明確化。' },
      { code: '30209', name: '岩出市', services: ['schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'corrected', note: '産後ケア・誰でも通園は一致。給食費は現行負担未確認の警告を維持。一般新婚住宅支援と受付未確認の移住支援を除外。' },
      { code: '30304', name: '紀美野町', services: ['sickChildCare','schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'corrected', note: '病児保育は利用条件未公表のunavailable判定が妥当。給食費無償化、産後ケア、誰でも通園は一致。住宅支援を子育て世帯10万円加算へ限定。' },
      { code: '30341', name: 'かつらぎ町', services: ['schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'corrected', note: '給食費無償化、産後ケア、誰でも通園は一致。子ども要件のない一般空き家改修補助を除外。' },
      { code: '30343', name: '九度山町', services: ['schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'no_confirmed_error', note: '令和8年度給食費徴収、産後ケア、誰でも通園、新婚・子育て世帯向け家賃補助と地域優良賃貸住宅を確認。' },
      { code: '30344', name: '高野町', services: ['schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'corrected', note: '保育料無償化・誰でも通園は一致。産後ケアの令和8年度条件未確認警告は妥当。子ども要件のない一般移住住宅補助を除外。' },
      { code: '30361', name: '湯浅町', services: ['schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'corrected', note: '給食費無償化、産後ケア、誰でも通園は一致。住宅支援を18歳未満1人100万円加算の移住支援金へ限定。' }
    ],
    confirmedErrors: [
      { code: '30206', service: 'housingSupport', before: 'verified / 子ども加算付き移住支援と一般空き家・新婚制度を混在', after: 'verified / 18歳未満1人100万円加算の移住支援金に限定', status: 'corrected_in_audit_pr_2926' },
      { code: '30207', service: 'housingSupport', before: 'verified / 子ども要件のない県外移住者向け空き家改修', after: 'unavailable / 子育て世帯専用住宅支援を確認できない', status: 'corrected_in_audit_pr_2926' },
      { code: '30208', service: 'housingSupport', before: 'verified / 一般若年住宅取得支援と児童加算を混在', after: 'verified / 16歳未満児童等の10万円加算を明確化', status: 'corrected_in_audit_pr_2926' },
      { code: '30209', service: 'housingSupport', before: 'verified / 子ども要件のない新婚住宅支援と受付未確認の移住支援', after: 'unavailable / 現行の子育て世帯専用住宅支援を確認できない', status: 'corrected_in_audit_pr_2926' },
      { code: '30304', service: 'housingSupport', before: 'verified / 一般・移住・新婚・子育て加算を混在', after: 'verified / 子育て世帯または出産予定世帯の10万円加算に限定', status: 'corrected_in_audit_pr_2926' },
      { code: '30341', service: 'housingSupport', before: 'verified / 子ども要件のない一般空き家改修・片付け補助', after: 'unavailable / 子育て世帯専用住宅支援を確認できない', status: 'corrected_in_audit_pr_2926' },
      { code: '30344', service: 'housingSupport', before: 'verified / 子ども要件のない一般移住住宅補助', after: 'unavailable / 子育て世帯専用住宅支援を確認できない', status: 'corrected_in_audit_pr_2926' },
      { code: '30361', service: 'housingSupport', before: 'verified / 年齢要件のみの住宅取得支援等を混在', after: 'verified / 18歳未満1人100万円加算の移住支援金に限定', status: 'corrected_in_audit_pr_2926' }
    ]
  });

  await writeFile(auditPath, JSON.stringify(audit, null, 2) + '\n', 'utf8');
}

const mode = process.argv[2];
if (mode === 'apply') await applyCorrections();
else if (mode === 'finalize') await finalizeAudit();
else throw new Error('Usage: node scripts/fix-central-b-accuracy-round8.mjs <apply|finalize>');
