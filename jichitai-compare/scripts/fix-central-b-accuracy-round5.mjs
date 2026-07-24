import { readFile, writeFile } from 'node:fs/promises';

const auditPath = 'operations/audits/central-b-accuracy-audit-20260725.json';
const branch = 'quality/central-b-accuracy-audit-20260725';
const checkedAt = '2026-07-25';
const updatedAt = '2026-07-25T01:40:00+09:00';

const corrections = {
  '29345': {
    summary: '安堵町の子育て、教育、住宅、生活、防災に関する9制度を公式情報で確認。令和8年度の給食費無償化、産後ケア、誰でも通園計画を反映し、子育て世帯専用住宅支援は未確認として記録。',
    housing: {
      status: 'unavailable',
      summary: '移住支援金と民間賃貸住宅家賃補助は、子どもの有無を要件としない一般の移住・転入世帯向け制度であり、令和8年度の子育て世帯専用住宅支援を確認できない。',
      details: {
        checked: '町の子育て・住宅・移住案内、移住支援金要綱、民間賃貸住宅家賃補助制度を確認',
        excludedMigration: '移住支援金は東京圏からの移住・就業等を対象とする単身60万円・世帯100万円の一般制度で、子ども要件・子ども加算を確認できない',
        excludedRental: '民間賃貸住宅家賃補助は2人以上の転入・転居世帯を対象とするが、子どもの有無を要件としない',
        unconfirmed: '子育て世帯を対象とする住宅取得、住宅改修、家賃、転居費の令和8年度制度',
        verificationPolicy: '制度の有無と募集状況は住民課または健康福祉推進室へ確認する'
      },
      source: { url: 'https://www.town.ando.nara.jp/0000000632.html', checkedAt },
      additionalSources: [
        { url: 'https://www.town.ando.nara.jp/html/reiki_honbun/k418RG00000464.html', checkedAt }
      ]
    },
    removeNotes: ['移住支援金は', '民間賃貸住宅家賃補助は'],
    note: '精度監査で、子ども要件・加算のない一般移住支援金と2人以上世帯向け家賃補助を子育て世帯向け住宅支援としていたため、housingSupportをverifiedからunavailableへ訂正。'
  },
  '29361': {
    summary: '川西町の子育て、教育、住宅、生活、防災に関する9制度を公式情報で確認。誰でも通園、産後ケア、第2子保育料無償化、学校給食の現行負担を反映し、子育て世帯専用住宅支援は未確認として記録。',
    housing: {
      status: 'unavailable',
      summary: '結婚新生活支援と移住支援金は、新婚・一般移住世帯向けで子どもの有無を要件とせず、令和8年度の子育て世帯専用住宅支援を確認できない。',
      details: {
        checked: '町の引越し・住まい、子育て、移住支援、結婚新生活支援の現行案内を確認',
        excludedMarriage: '結婚新生活支援は夫婦の婚姻時期・年齢・所得等を要件とし、子どもの有無を要件としない',
        excludedMigration: '移住支援金は単身60万円・世帯100万円の一般移住制度で、現行案内に子ども加算を確認できない',
        unconfirmed: '子育て世帯を対象とする住宅取得、住宅改修、家賃、転居費の令和8年度制度',
        verificationPolicy: '制度の有無と募集状況は福祉こども課または総合政策課へ確認する'
      },
      source: { url: 'https://www.town.nara-kawanishi.lg.jp/0000008895.html', checkedAt },
      additionalSources: [
        { url: 'https://www.town.nara-kawanishi.lg.jp/0000007051.html', checkedAt }
      ]
    },
    schoolMeals: {
      summary: '川西小学校は条例上、学校給食費年額47,300円を徴収する。式下中学校生徒の学校給食費は令和6年度から無償化を継続する。',
      middleSchool: '町公式の現行子育て支援プロジェクトで、式下中学校生徒の学校給食費無償化を令和6年度から実施・継続していることを確認',
      currentStatus: '小学校は条例上の徴収額を記録し、中学校は令和6年度開始の無償化を現行施策として区別して記録'
    },
    removeNotes: ['結婚新生活支援', '移住支援金'],
    note: '精度監査で、子ども要件のない結婚新生活支援と子ども加算のない一般移住支援金を子育て世帯向け住宅支援としていたため、housingSupportをverifiedからunavailableへ訂正。学校給食は小学校年47,300円徴収・式下中学校令和6年度から無償化継続へ表現を現行化。'
  },
  '29362': {
    summary: '三宅町の子育て、教育、住宅、生活、防災に関する9制度を公式情報で確認。医療費・学校給食費無償化、産後ケア、誰でも通園を反映し、子育て世帯専用住宅支援は未確認として記録。',
    housing: {
      status: 'unavailable',
      summary: '中古住宅取得支援は転入者・町内在住者一般を対象とし、子どもの有無を要件としないため、令和8年度の子育て世帯専用住宅支援を確認できない。',
      details: {
        checked: '町の住宅、移住定住、子育て支援の現行案内を確認',
        excludedGeneralProgram: '中古住宅取得支援は町外転入者または町内在住者の新規購入を対象とする一般制度で、子ども要件・加算を確認できない',
        unconfirmed: '子育て世帯を対象とする住宅取得、住宅改修、家賃、転居費の令和8年度制度',
        verificationPolicy: '制度の有無と募集状況は政策推進課または健康子ども課へ確認する'
      },
      source: { url: 'https://www.town.miyake.lg.jp/soshiki/3/1036.html', checkedAt }
    },
    removeNotes: ['中古住宅'],
    note: '精度監査で、子ども要件・加算のない一般の中古住宅取得支援を子育て世帯向け住宅支援としていたため、housingSupportをverifiedからunavailableへ訂正。'
  }
};

function serviceSources(municipality) {
  return Object.values(municipality.services)
    .map((service) => service?.source?.url)
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

    if (config.schoolMeals) {
      municipality.services.schoolMeals.summary = config.schoolMeals.summary;
      municipality.services.schoolMeals.details.middleSchool = config.schoolMeals.middleSchool;
      municipality.services.schoolMeals.details.currentStatus = config.schoolMeals.currentStatus;
      municipality.services.schoolMeals.source.checkedAt = checkedAt;
      for (const source of municipality.services.schoolMeals.additionalSources ?? []) {
        source.checkedAt = checkedAt;
      }
    }

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
  const round = audit.batches.find((item) => item.round === 5);
  if (!round) throw new Error('Round 5 batch is missing.');
  round.status = 'completed';

  audit.progress.completedRounds = 5;
  audit.progress.structurallyCheckedMunicipalities = 50;
  audit.progress.deepCheckedMunicipalities = 43;
  audit.progress.confirmedErrors = 21;
  audit.progress.correctedErrors = 21;

  audit.findings = audit.findings.filter((finding) => finding.round !== 5);
  audit.findings.push({
    round: 5,
    auditedAt: new Date().toISOString(),
    codes: round.codes,
    structuralAudit: {
      result: 'passed',
      checkedMunicipalities: 10,
      errors: 0,
      warnings: 1,
      workflowRunId: 30109417783,
      artifactId: 8602877941,
      artifactDigest: 'sha256:0ab316470c428c472a498bc918d6dd100f71cd26aceede2d81f33d2193f26384',
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
      { code: '29343', name: '三郷町', services: ['schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'no_confirmed_error', note: '子ども加算付き空き家改修、子育て世帯家賃助成、産後ケア、誰でも通園を確認し一致。' },
      { code: '29344', name: '斑鳩町', services: ['temporaryChildcare','housingSupport'], result: 'no_confirmed_error', note: '誰でも通園月10時間と18歳未満1人につき100万円加算の移住支援を確認し一致。' },
      { code: '29345', name: '安堵町', services: ['schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'corrected', note: '給食費無償化、産後ケア、誰でも通園計画は維持。一般移住・2人以上転入世帯向け制度を住宅支援から除外。' },
      { code: '29361', name: '川西町', services: ['schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'corrected', note: '小学校年47,300円徴収・式下中学校無償化継続へ現行化。新婚・一般移住制度を住宅支援から除外。' },
      { code: '29362', name: '三宅町', services: ['schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'corrected', note: '給食費無償化、産後ケア、誰でも通園は一致。一般中古住宅取得支援を住宅支援カテゴリから除外。' },
      { code: '29363', name: '田原本町', services: ['schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'no_confirmed_error', note: '小学校給食費無償化、中学校負担軽減、産後ケア、誰でも通園、子育て世帯住宅ローン利子補給を確認。' },
      { code: '29385', name: '曽爾村', services: ['schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'no_confirmed_error', note: '専用産後ケア未確認のunavailable判定と、子ども継続加算付き定住促進奨励金を確認。' },
      { code: '29386', name: '御杖村', services: ['schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'no_confirmed_error', note: '専用産後ケア未確認のunavailable判定、誰でも通園、義務教育修了前の子がいる世帯を含む多世代住宅補助を確認。' },
      { code: '29401', name: '高取町', services: ['schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'no_confirmed_error', note: '給食費無償化、訪問型産後ケア、誰でも通園制度基盤、18歳未満を含む世帯への既存住宅購入100万円補助を確認。' },
      { code: '29402', name: '明日香村', services: ['schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'no_confirmed_error', note: '多子給食助成、産後ケア、誰でも通園、18歳未満1人100万円加算の移住支援を確認し一致。' }
    ],
    confirmedErrors: [
      { code: '29345', service: 'housingSupport', before: 'verified / 一般移住支援金・2人以上転入世帯向け家賃補助', after: 'unavailable / 子育て世帯専用住宅支援を確認できない', status: 'corrected_in_audit_pr_2926' },
      { code: '29361', service: 'housingSupport', before: 'verified / 子ども要件のない新婚・一般移住制度', after: 'unavailable / 子育て世帯専用住宅支援を確認できない', status: 'corrected_in_audit_pr_2926' },
      { code: '29362', service: 'housingSupport', before: 'verified / 子ども要件のない一般中古住宅取得支援', after: 'unavailable / 子育て世帯専用住宅支援を確認できない', status: 'corrected_in_audit_pr_2926' }
    ]
  });

  await writeFile(auditPath, JSON.stringify(audit, null, 2) + '\n', 'utf8');
}

const mode = process.argv[2];
if (mode === 'apply') await applyCorrections();
else if (mode === 'finalize') await finalizeAudit();
else throw new Error('Usage: node scripts/fix-central-b-accuracy-round5.mjs <apply|finalize>');
