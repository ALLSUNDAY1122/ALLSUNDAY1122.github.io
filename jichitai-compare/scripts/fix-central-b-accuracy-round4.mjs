import { readFile, writeFile } from 'node:fs/promises';

const mode = process.argv[2] ?? 'apply';
const ROOT = new URL('../', import.meta.url);
const AUDIT_PATH = new URL('operations/audits/central-b-accuracy-audit-20260725.json', ROOT);
const OUTPUT_PATH = new URL('operations/audits/central-b-accuracy-round-output.json', ROOT);
const BRANCH = 'quality/central-b-accuracy-audit-20260725';
const PR_NUMBER = 2926;
const NOW = '2026-07-25T01:20:00+09:00';

const corrections = {
  '29205': {
    municipalitySummary: '橿原市の子育て、教育、住宅、生活、防災に関する9制度を公式情報で確認。令和8年度こども誰でも通園、給食費無償化、産後ケアを反映し、子育て世帯専用住宅支援は未確認として記録。',
    service: {
      status: 'unavailable',
      summary: '令和8年度の子育て世帯を対象とする住宅取得・改修・家賃支援を市公式情報で確認できない。移住支援金は子ども要件・子ども加算のない一般制度である。',
      details: {
        checked: '市の令和8年度移住支援金、移住・定住、子育て支援、住宅関係補助を確認',
        excludedGeneralProgram: '橿原市移住支援金は単身60万円・世帯100万円の一般移住制度で、市公式案内に18歳未満の子ども要件または子ども加算の記載がない',
        excludedTrialStay: '移住検討者向けお試し滞在費は住宅取得・改修・家賃支援ではない',
        verificationPolicy: '子育て世帯専用の現行制度は企画政策課または住宅政策課へ確認する'
      },
      source: { url: 'https://www.city.kashihara.nara.jp/soshiki/1027/gyomu/3204.html', checkedAt: '2026-07-25' }
    },
    noteFilters: ['移住支援金', 'お試し滞在'],
    note: '住宅支援は、子ども要件・子ども加算のない一般移住支援金とお試し滞在費を子育て世帯向け制度としていたためunavailableへ訂正。'
  },
  '29207': {
    municipalitySummary: '五條市の子育て、教育、住宅、生活、防災に関する9制度を公式情報で確認。令和8年度こども誰でも通園、保育料・給食費無償化、産後ケアを反映し、子育て世帯専用住宅支援は未確認として記録。',
    service: {
      status: 'unavailable',
      summary: '令和8年度の子育て世帯を対象とする住宅取得・改修・家賃支援を市公式情報で確認できない。結婚新生活支援は子どもの有無を要件としない新婚世帯向け制度である。',
      details: {
        checked: '市の令和8年度結婚新生活支援、移住・定住、子育て支援、住宅関係補助を確認',
        excludedGeneralProgram: '結婚新生活支援は夫婦双方39歳以下・所得500万円未満等を要件とするが、子どもの有無または妊娠を要件としない',
        supportedCosts: '住宅賃借、取得、リフォーム、引越費用を支援する制度自体は存在するが、子育て世帯専用制度としては扱わない',
        verificationPolicy: '子育て世帯専用の現行制度は児童福祉課または都市計画課へ確認する'
      },
      source: { url: 'https://www.city.gojo.lg.jp/kurashi/hojokin/17035.html', checkedAt: '2026-07-25' }
    },
    noteFilters: ['結婚新生活'],
    note: '住宅支援は、子どもの有無を要件としない結婚新生活支援を子育て世帯向け制度としていたためunavailableへ訂正。'
  },
  '29208': {
    municipalitySummary: '御所市の子育て、教育、住宅、生活、防災に関する9制度を公式情報で確認。令和8年度こども誰でも通園、給食費無償化、産後ケアを反映し、子育て世帯専用住宅支援は未確認として記録。',
    service: {
      status: 'unavailable',
      summary: '令和8年度の子育て世帯を対象とする住宅取得・改修・家賃支援を市公式情報で確認できない。住宅取得補助金は子ども要件のない若年夫婦向け制度である。',
      details: {
        checked: '市の住宅取得補助金、移住・定住、子育て支援、住宅関係補助を確認',
        excludedGeneralProgram: '御所市住宅取得補助金は夫または妻のどちらかが45歳以下の若年夫婦を対象とし、子どもの有無または妊娠を要件としない',
        generalBenefit: '市内住宅の新築・購入に50万円を1度限り交付する一般の若年夫婦定住制度',
        verificationPolicy: '子育て世帯専用の現行制度は住宅課または子育て推進課へ確認する'
      },
      source: { url: 'https://www.city.gose.nara.jp/0000001028.html', checkedAt: '2026-07-25' }
    },
    noteFilters: ['住宅取得補助'],
    note: '住宅支援は、子ども要件のない若年夫婦向け住宅取得補助を子育て世帯向け制度としていたためunavailableへ訂正。'
  },
  '29210': {
    municipalitySummary: '香芝市の子育て、教育、住宅、生活、防災に関する9制度を公式情報で確認。令和8年度こども誰でも通園、産後ケア、学校給食を現行化し、子育て世帯専用住宅支援は未確認として記録。',
    service: {
      status: 'unavailable',
      summary: '令和8年度の子育て世帯を対象とする住宅取得・改修・家賃支援を市公式情報で確認できない。移住支援金は子ども加算のない一般制度である。',
      details: {
        checked: '市の令和8年度移住支援金、子育て支援、住まい・生活環境の補助一覧を確認',
        excludedGeneralProgram: '香芝市移住支援金は単身60万円・世帯100万円で、市公式案内に子ども要件または子ども加算の記載がない',
        excludedOtherPrograms: '子育て環境整備補助は法人・事業者の授乳・おむつ交換スペース等が対象で、世帯の住宅支援ではない',
        verificationPolicy: '子育て世帯専用の現行制度は都市政策交通課または児童福祉課へ確認する'
      },
      source: { url: 'https://www.city.kashiba.lg.jp/soshiki/16/53394.html', checkedAt: '2026-07-25' }
    },
    noteFilters: ['移住支援金'],
    note: '住宅支援は、子ども要件・子ども加算のない一般移住支援金を子育て世帯向け制度としていたためunavailableへ訂正。'
  }
};

async function readJson(path) {
  return JSON.parse(await readFile(path, 'utf8'));
}

async function writeJson(path, value, pretty = false) {
  await writeFile(path, JSON.stringify(value, null, pretty ? 2 : undefined) + '\n', 'utf8');
}

async function applyCorrections() {
  for (const [code, correction] of Object.entries(corrections)) {
    const municipalityPath = new URL(`data/municipalities/29/${code}.json`, ROOT);
    const taskPath = new URL(`operations/tasks/${code}.json`, ROOT);
    const municipality = await readJson(municipalityPath);
    const task = await readJson(taskPath);

    municipality.summary = correction.municipalitySummary;
    municipality.updatedAt = '2026-07-25';
    municipality.services.housingSupport = correction.service;

    if (code === '29210') {
      municipality.services.schoolMeals.summary = '令和8年度は市立小中学校で学校給食費を徴収し、市負担の増額により食材費高騰後も保護者負担を据え置く。経済的要件を満たす世帯には就学援助がある。';
      municipality.services.schoolMeals.details.universalFreeStatus = '令和8年度は通常徴収を継続し、市負担増額により保護者負担額を据え置く';
    }

    const services = Object.values(municipality.services);
    task.verifiedCount = services.filter((item) => item.status === 'verified').length;
    task.unavailableCount = services.filter((item) => item.status === 'unavailable').length;
    task.researchingCount = 0;
    task.needsMediumReviewCount = 0;
    task.status = 'pr_open';
    task.currentBranch = BRANCH;
    task.pullRequestNumber = PR_NUMBER;
    task.lastCheckedAt = '2026-07-25';
    task.lastUpdatedAt = NOW;
    task.lastUpdatedBy = '中日本調査班B';
    task.officialSources = [...new Set(services.map((item) => item.source.url))];
    task.notes = (task.notes ?? []).filter((note) => !correction.noteFilters.some((pattern) => note.includes(pattern)));
    task.notes.push(correction.note, '10回精度監査PR #2926 第4回で訂正。');

    await writeJson(municipalityPath, municipality);
    await writeJson(taskPath, task);
  }
}

async function finalizeAudit() {
  const audit = await readJson(AUDIT_PATH);
  const output = await readJson(OUTPUT_PATH);
  const round = audit.batches.find((item) => item.round === 4);
  if (!round || round.status === 'completed') return;
  if (output.round !== 4 || output.errorCount !== 0) throw new Error('Round 4 audit output is not successful.');

  round.status = 'completed';
  audit.progress = {
    completedRounds: 4,
    structurallyCheckedMunicipalities: 40,
    deepCheckedMunicipalities: 33,
    confirmedErrors: 18,
    correctedErrors: 18
  };
  audit.findings.push({
    round: 4,
    auditedAt: new Date().toISOString(),
    codes: round.codes,
    structuralAudit: {
      result: 'passed',
      checkedMunicipalities: 10,
      errors: 0,
      warnings: 1,
      workflowRunId: 30108243999,
      artifactId: 8602506744,
      artifactDigest: 'sha256:24198f4540cfbc9cb2e5c136cc49e57832fb246b76b20f64ffb3a9edeae3aa14',
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
      { code: '29205', name: '橿原市', services: ['schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'corrected', note: '給食費無償化、産後ケア、誰でも通園は一致。子ども要件・加算のない一般移住支援金を住宅支援から除外。' },
      { code: '29206', name: '桜井市', services: ['schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'no_confirmed_error', note: '令和8年度給食支援、産後ケア、誰でも通園、子ども加算付き移住支援・新婚支援を確認し一致。' },
      { code: '29207', name: '五條市', services: ['childcareFee','schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'corrected', note: '保育料・給食費無償化、産後ケア、誰でも通園は一致。子ども要件のない結婚新生活支援を住宅支援から除外。' },
      { code: '29208', name: '御所市', services: ['schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'corrected', note: '給食費無償化、産後ケア、誰でも通園は一致。子ども要件のない若年夫婦向け住宅取得補助を除外。' },
      { code: '29209', name: '生駒市', services: ['schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'no_confirmed_error', note: '給食徴収額、産後ケア3類型、誰でも通園月4時間、18歳未満1人100万円加算の移住支援を確認。' },
      { code: '29210', name: '香芝市', services: ['schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'corrected', note: '給食費は通常徴収・市負担増額による据置へ表現修正。子ども要件・加算のない一般移住支援金を住宅支援から除外。' },
      { code: '29211', name: '葛城市', services: ['schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'no_confirmed_error', note: '産後ケア、誰でも通園、子ども人数加算付き住宅取得支援・移住支援を確認し一致。' },
      { code: '29212', name: '宇陀市', services: ['sickChildCare','schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'no_confirmed_error', note: '令和8年度病児保育、給食費無償化、産後ケア、誰でも通園、子ども加算付き定住支援を確認し一致。' },
      { code: '29322', name: '山添村', services: ['sickChildCare','schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'no_confirmed_error', note: '広域病児保育、給食費無償化、産後ケア、誰でも通園基準、子育て加算付き定住支援を確認。' },
      { code: '29342', name: '平群町', services: ['sickChildCare','postpartumCare','temporaryChildcare','housingSupport'], result: 'no_confirmed_error', note: '病児保育、産後ケア、誰でも通園、若年移住・新婚住宅支援を確認し明確な誤りなし。' }
    ],
    confirmedErrors: Object.keys(corrections).map((code) => ({
      code,
      service: 'housingSupport',
      before: 'verified / 子ども要件のない一般移住・新婚・若年夫婦向け制度',
      after: 'unavailable / 子育て世帯専用の現行住宅支援を確認できない',
      status: 'corrected_in_audit_pr_2926'
    }))
  });
  await writeJson(AUDIT_PATH, audit, true);
}

if (mode === 'apply') await applyCorrections();
else if (mode === 'finalize') await finalizeAudit();
else throw new Error(`Unknown mode: ${mode}`);
