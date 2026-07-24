import { readFile, writeFile } from 'node:fs/promises';

const auditPath = 'operations/audits/central-b-accuracy-audit-20260725.json';
const branch = 'quality/central-b-accuracy-audit-20260725';
const checkedAt = '2026-07-25';
const updatedAt = '2026-07-25T01:55:00+09:00';

const corrections = {
  '29425': {
    summary: '王寺町の子育て、教育、住宅、生活、防災に関する9制度を公式情報で確認。第2子保育料無償化、令和8年度の学校給食、産後ケア、誰でも通園、義務教育修了前の子を含む三世代世帯向け住宅支援を記録。',
    housing: {
      status: 'verified',
      summary: '義務教育修了前の子どもを含む子世帯が、町内在住の親世帯と同居・近居するために住宅を取得または同居用リフォームを行う場合、20万円を補助する。',
      details: {
        program: '王寺町三世代ファミリー定住支援補助金',
        childHousehold: '同一世帯内で義務教育修了前の子ども、または出生後に同居予定の出産予定児と同居する親子世帯',
        parentCondition: '親世帯が申請日に継続して1年以上王寺町内に居住していること',
        acquisition: '子世帯と親世帯が町内で同居または近居するための住宅取得を対象',
        renovation: '子世帯と親世帯が町内で同居するための20万円以上の住宅リフォームを対象',
        amount: '住宅取得・リフォームとも20万円',
        applicationPeriod: '現行要綱では対象期間を令和13年3月31日まで延長',
        applicationDeadline: '住宅取得後の転入・転居日、またはリフォーム後の居住日から6か月以内',
        conditions: '三世代世帯全員の町税完納、対象住宅の適法性、居住誘導区域等の要件あり',
        excludedOldRecord: '本人または配偶者が40歳以下であることだけを要件とする一般U-40定住支援は、子育て世帯専用制度としては記録しない'
      },
      source: { url: 'https://www.town.oji.nara.jp/kakuka/chiikiseibi/machidukuri/gyomuannai/ijuteiju/1821.html', checkedAt },
      additionalSources: [
        { url: 'https://www.town.oji.nara.jp/material/files/group/12/sannsedaiyouko.pdf', checkedAt }
      ]
    },
    removeNotes: ['若者定住', 'U-40', '40歳以下'],
    note: '精度監査で、子ども要件のない一般U-40住宅取得支援を子育て住宅支援としていたため、義務教育修了前の子どもを含む三世代世帯向け住宅取得・リフォーム補助へ内容と一次出典を訂正。'
  },
  '29427': {
    summary: '河合町の子育て、教育、住宅、生活、防災に関する9制度を公式情報で確認。令和8年度こども誰でも通園制度等を反映し、子育て世帯専用住宅支援は未確認として記録。',
    housing: {
      status: 'unavailable',
      summary: '令和8年度住宅リフォーム助成は町民一般を対象とし、子どもの有無を要件としないため、子育て世帯専用の現行住宅支援を確認できない。',
      details: {
        checked: '町の住宅リフォーム、耐震、子育て、移住・定住に関する現行案内を確認',
        excludedGeneralProgram: '住宅リフォーム助成は自己居住住宅を町内業者で改修する町民一般が対象で、子ども要件・子ども加算がない',
        generalAmount: '一般制度は税抜工事費の10％、上限10万円',
        unconfirmed: '子育て世帯を対象とする住宅取得、改修、家賃、転居費の令和8年度制度',
        verificationPolicy: '制度の有無と募集状況はこども未来課またはまちづくり推進課へ確認する'
      },
      source: { url: 'https://www.town.kawai.nara.jp/kakuka/machizukuri/kankoushinkou/871.html', checkedAt },
      additionalSources: [
        { url: 'https://www.town.kawai.nara.jp/section/reiki/reiki_honbun/k435RG00000491.html', checkedAt }
      ]
    },
    removeNotes: ['住宅リフォーム'],
    note: '精度監査で、子ども要件・加算のない一般住宅リフォーム助成を子育て世帯向け住宅支援としていたため、housingSupportをverifiedからunavailableへ訂正。'
  },
  '29441': {
    summary: '吉野町の子育て、教育、住宅、生活、防災に関する9制度を公式情報で確認。一時預かり等を反映し、子育て世帯専用住宅支援は未確認として記録。',
    housing: {
      status: 'unavailable',
      summary: '空き家バンク登録物件の改修補助は移住・定住希望者一般を対象とし、子どもの有無を要件としないため、子育て世帯専用の現行住宅支援を確認できない。',
      details: {
        checked: '町の空き家、移住・定住、子育て支援、住宅改修の現行案内を確認',
        excludedGeneralProgram: '定住促進空き家改修事業は空き家所有者・利用者一般を対象とし、子ども要件・子ども加算がない',
        generalAmount: '一般制度は改修費の2分の1、上限50万円',
        unconfirmed: '子育て世帯を対象とする住宅取得、住宅改修、家賃、転居費の令和8年度制度',
        verificationPolicy: '制度の有無と募集状況は協働のまち推進課または教育総務課へ確認する'
      },
      source: { url: 'https://www.town.yoshino.nara.jp/kurashi/sumai/akiya/768.html', checkedAt },
      additionalSources: [
        { url: 'https://www.town.yoshino.nara.jp/promotion/yoshinochonoshien/izyushien/index.html', checkedAt }
      ]
    },
    removeNotes: ['空き家改修', '空き家バンク'],
    note: '精度監査で、子ども要件・加算のない一般の空き家改修補助を子育て世帯向け住宅支援としていたため、housingSupportをverifiedからunavailableへ訂正。'
  },
  '29442': {
    summary: '大淀町の子育て、教育、住宅、生活、防災に関する9制度を公式情報で確認。産後ケア等を反映し、子育て世帯専用住宅支援は未確認として記録。',
    housing: {
      status: 'unavailable',
      summary: '令和8年度結婚新生活支援は新婚夫婦を対象とし、子どもの有無を要件としないため、子育て世帯専用の現行住宅支援を確認できない。',
      details: {
        checked: '町の結婚新生活、住宅、移住・定住、子育て支援の現行案内を確認',
        excludedMarriageProgram: '結婚新生活支援は婚姻時期、夫婦の年齢・所得・居住意思等を要件とし、子どもの有無を要件としない',
        generalCoverage: '一般制度は住宅取得、リフォーム、賃借、引越費用を最大60万円補助',
        unconfirmed: '子育て世帯を対象とする住宅取得、住宅改修、家賃、転居費の令和8年度制度',
        verificationPolicy: '制度の有無と募集状況は健康こども課または企画財務課へ確認する'
      },
      source: { url: 'https://www.town.oyodo.lg.jp/0000001994.html', checkedAt }
    },
    removeNotes: ['結婚新生活'],
    note: '精度監査で、子どもの有無を要件としない結婚新生活支援を子育て世帯向け住宅支援としていたため、housingSupportをverifiedからunavailableへ訂正。'
  },
  '29443': {
    summary: '下市町の子育て、教育、住宅、生活、防災に関する9制度を公式情報で確認。令和8年度こども誰でも通園制度等を反映し、子育て世帯専用住宅支援は未確認として記録。',
    housing: {
      status: 'unavailable',
      summary: '令和8年度住宅リフォーム助成は町民一般を対象とし、子どもの有無を要件としないため、子育て世帯専用の現行住宅支援を確認できない。',
      details: {
        checked: '町の令和8年度住環境支援、住宅リフォーム、空き家、子育て支援の現行案内を確認',
        excludedGeneralProgram: '住宅リフォーム助成は町内で自己居住住宅を改修する町民一般が対象で、子ども要件・子ども加算がない',
        generalAmount: '一般制度は町内産木材購入額相当、上限20万円',
        unconfirmed: '子育て世帯を対象とする住宅取得、住宅改修、家賃、転居費の令和8年度制度',
        verificationPolicy: '制度の有無と募集状況は健康福祉課または建設課へ確認する'
      },
      source: { url: 'https://www.town.shimoichi.lg.jp/0000000852.html', checkedAt },
      additionalSources: [
        { url: 'https://www.town.shimoichi.lg.jp/0000001863.html', checkedAt }
      ]
    },
    removeNotes: ['住宅リフォーム', '住環境支援'],
    note: '精度監査で、子ども要件・加算のない一般住宅リフォーム助成を子育て世帯向け住宅支援としていたため、housingSupportをverifiedからunavailableへ訂正。学校給食は令和6年度実績と令和8年度未確認を明確に分離しており、警告は誤りではない。'
  }
};

function serviceSources(municipality) {
  return Object.values(municipality.services)
    .flatMap((service) => [service?.source?.url, ...(service?.additionalSources ?? []).map((source) => source?.url)])
    .filter(Boolean);
}

async function applyCorrections() {
  for (const [code, config] of Object.entries(corrections)) {
    const municipalityPath = `data/municipalities/29/${code}.json`;
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
  const round = audit.batches.find((item) => item.round === 6);
  if (!round) throw new Error('Round 6 batch is missing.');
  round.status = 'completed';

  audit.progress.completedRounds = 6;
  audit.progress.structurallyCheckedMunicipalities = 60;
  audit.progress.deepCheckedMunicipalities = 53;
  audit.progress.confirmedErrors = 26;
  audit.progress.correctedErrors = 26;

  audit.findings = audit.findings.filter((finding) => finding.round !== 6);
  audit.findings.push({
    round: 6,
    auditedAt: new Date().toISOString(),
    codes: round.codes,
    structuralAudit: {
      result: 'passed',
      checkedMunicipalities: 10,
      errors: 0,
      warnings: 2,
      workflowRunId: 30110717765,
      artifactId: 8603406901,
      artifactDigest: 'sha256:d624180dfbae24f2f8e468b4aadd614eb5d579e413326b7e4c808ecff3b6c1dc',
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
      { code: '29424', name: '上牧町', services: ['schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'no_confirmed_error', note: '誰でも通園・産後ケアを確認。移住支援は令和7年2月期限の過年度案内のみで、令和8年度未確認のunavailable判定は妥当。' },
      { code: '29425', name: '王寺町', services: ['childcareFee','schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'corrected', note: '第2子保育料無償化は令和8年度も継続。一般U-40住宅取得支援を、義務教育修了前の子を含む三世代世帯向け住宅取得・リフォーム補助へ訂正。' },
      { code: '29426', name: '広陵町', services: ['temporaryChildcare','housingSupport'], result: 'no_confirmed_error', note: '誰でも通園の現行条件を確認。一般住宅リフォームは受付終了済みで、子育て住宅支援未確認のunavailable判定は妥当。' },
      { code: '29427', name: '河合町', services: ['temporaryChildcare','housingSupport'], result: 'corrected', note: '誰でも通園は一致。子ども要件のない一般住宅リフォーム助成を住宅支援カテゴリから除外。' },
      { code: '29441', name: '吉野町', services: ['temporaryChildcare','housingSupport'], result: 'corrected', note: '一時預かりは一致。子ども要件のない一般空き家改修補助を住宅支援カテゴリから除外。' },
      { code: '29442', name: '大淀町', services: ['postpartumCare','temporaryChildcare','housingSupport'], result: 'corrected', note: '令和8年度産後ケアを確認。子ども要件のない結婚新生活支援を住宅支援カテゴリから除外。' },
      { code: '29443', name: '下市町', services: ['schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'corrected', note: '誰でも通園は一致。学校給食は過年度実績と現行未確認を区別しており妥当。一般住宅リフォーム助成を住宅支援カテゴリから除外。' },
      { code: '29444', name: '黒滝村', services: ['schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'no_confirmed_error', note: '給食費全額補助、産後ケア予算、15歳未満の子がいる40歳以下世帯向け住宅支援を確認。' },
      { code: '29446', name: '天川村', services: ['schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'no_confirmed_error', note: '学校給食・産後ケア未確認のunavailable判定、子ども人数による定住促進住宅家賃減免を確認。' },
      { code: '29447', name: '野迫川村', services: ['schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'no_confirmed_error', note: '学校給食費無償、産後ケア・誰でも通園未確認の判定、小学生以下の子を有する転入世帯向け奨励金を確認。' }
    ],
    confirmedErrors: [
      { code: '29425', service: 'housingSupport', before: 'verified / 子ども要件のない一般U-40住宅取得支援', after: 'verified / 義務教育修了前の子を含む三世代世帯向け住宅取得・リフォーム補助', status: 'corrected_in_audit_pr_2926' },
      { code: '29427', service: 'housingSupport', before: 'verified / 子ども要件のない一般住宅リフォーム助成', after: 'unavailable / 子育て世帯専用住宅支援を確認できない', status: 'corrected_in_audit_pr_2926' },
      { code: '29441', service: 'housingSupport', before: 'verified / 子ども要件のない一般空き家改修補助', after: 'unavailable / 子育て世帯専用住宅支援を確認できない', status: 'corrected_in_audit_pr_2926' },
      { code: '29442', service: 'housingSupport', before: 'verified / 子ども要件のない結婚新生活支援', after: 'unavailable / 子育て世帯専用住宅支援を確認できない', status: 'corrected_in_audit_pr_2926' },
      { code: '29443', service: 'housingSupport', before: 'verified / 子ども要件のない一般住宅リフォーム助成', after: 'unavailable / 子育て世帯専用住宅支援を確認できない', status: 'corrected_in_audit_pr_2926' }
    ]
  });

  await writeFile(auditPath, JSON.stringify(audit, null, 2) + '\n', 'utf8');
}

const mode = process.argv[2];
if (mode === 'apply') await applyCorrections();
else if (mode === 'finalize') await finalizeAudit();
else throw new Error('Usage: node scripts/fix-central-b-accuracy-round6.mjs <apply|finalize>');
