import { readFile, writeFile } from 'node:fs/promises';

const auditPath = 'operations/audits/central-b-accuracy-audit-20260725.json';
const branch = 'quality/central-b-accuracy-audit-20260725';
const checkedAt = '2026-07-25';
const updatedAt = '2026-07-25T03:05:00+09:00';

const corrections = {
  '30362': {
    prefectureCode: '30',
    summary: '広川町の子育て、教育、住宅、生活、防災に関する9制度を公式情報で確認。医療費・保育料・学校給食費の無償化、病児保育、産後ケア等を記録し、子育て世帯専用住宅支援は未確認として整理した。',
    services: {
      housingSupport: {
        status: 'unavailable',
        summary: '定住促進奨励金、住宅リフォーム、空き家改修は年齢・転入・住宅要件による一般制度で、子どもの有無を要件としないため、子育て世帯専用の現行住宅支援を確認できない。',
        details: {
          checked: '令和8年度の定住促進奨励金、住宅リフォーム、空き家改修、結婚新生活、子育て支援の公式案内を確認',
          excludedGeneralProgram: '住宅取得は60歳未満の申請者等へ50万円、町外転入者へ100万円を交付する一般制度で、子ども要件・子ども加算がない',
          otherGeneralPrograms: '住宅リフォームと空き家改修も住宅・移住要件による一般制度で、子育て世帯専用ではない',
          unconfirmed: '子育て世帯を対象とする住宅取得、改修、家賃、転居費の令和8年度制度',
          verificationPolicy: '制度の有無と募集状況は企画政策課または子育て健康推進課へ確認する'
        },
        source: { url: 'https://www.town.hirogawa.wakayama.jp/soumu/2022-0329-1004-18.html', checkedAt },
        additionalSources: [
          { url: 'https://www.town.hirogawa.wakayama.jp/ijyuteijyu/shienseido.html', checkedAt }
        ]
      }
    },
    removeNotes: ['定住促進奨励金', '住宅リフォーム', '空き家改修'],
    note: '精度監査で、子ども要件・加算のない一般の住宅取得・改修制度を子育て世帯向け住宅支援としていたため、housingSupportをverifiedからunavailableへ訂正。'
  },
  '30366': {
    prefectureCode: '30',
    summary: '有田川町の子育て、教育、住宅、生活、防災に関する9制度を公式情報で確認。病児保育、産後ケア、誰でも通園等を記録し、子育て世帯専用住宅支援は未確認として整理した。',
    services: {
      housingSupport: {
        status: 'unavailable',
        summary: '令和8年度すまい応援給付金は新築戸建住宅の取得者一般を対象とし、子どもの有無を要件としないため、子育て世帯専用の現行住宅支援を確認できない。',
        details: {
          checked: '町の令和8年度すまい応援給付金、住宅、移住・定住、子育て支援の現行案内を確認',
          excludedGeneralProgram: '町内で対象戸建住宅を新築・取得した個人へ10万円を給付する一般制度で、子ども要件・子ども加算がない',
          unconfirmed: '子育て世帯を対象とする住宅取得、改修、家賃、転居費の令和8年度制度',
          verificationPolicy: '制度の有無と募集状況は税務課またはこども教育課へ確認する'
        },
        source: { url: 'https://www.town.aridagawa.lg.jp/top/kakuka/kibi/8/1/zeikara/6854.html', checkedAt }
      }
    },
    removeNotes: ['すまい応援給付金', '住宅新築'],
    note: '精度監査で、子ども要件・加算のない新築住宅取得者一般向け給付金を子育て世帯向け住宅支援としていたため、housingSupportをverifiedからunavailableへ訂正。'
  },
  '30381': {
    prefectureCode: '30',
    summary: '美浜町の子育て、教育、住宅、生活、防災に関する9制度を公式情報で確認。18歳年度末までの医療費助成と御坊広域の病児・病後児保育を記録し、誰でも通園の町個別条件と子育て世帯専用住宅支援は未確認として整理した。',
    services: {
      sickChildCare: {
        status: 'verified',
        summary: '生後9週から就学前までを基本対象とし、特に必要な場合は小学3年生まで、御坊市の病児保育室ひまわりを利用できる。',
        eligibility: { minAgeMonths: 2, maxAgeYears: 9 },
        details: {
          facility: '社会医療法人黎明会北出病院 病児保育室ひまわり',
          location: '御坊市湯川町財部728番地2',
          residentArea: '美浜町、御坊市、由良町、日高町、印南町、日高川町の居住児童',
          usualTarget: '生後9週から就学前まで',
          exception: '特に必要な場合は小学3年生まで',
          condition: '医師が利用可能と認め、保護者の就労・疾病・冠婚葬祭等で家庭保育が困難なこと',
          procedure: '原則前日までに施設へ予約し、医師連絡票による病状確認を受ける'
        },
        source: { url: 'https://www.town.wakayama-inami.lg.jp/0000001371.html', checkedAt }
      },
      temporaryChildcare: {
        status: 'unavailable',
        summary: '令和8年度から全国実施となる制度の一般概要は確認できるが、美浜町の実施施設、利用時間、料金、認定・予約方法を示す町公式の利用者向け案内を確認できない。',
        details: {
          confirmed: '県公式案内で令和8年度から全市町村でこども誰でも通園制度を実施する方針を確認',
          currentAvailability: '美浜町公式サイトで実施施設、月10時間の具体的運用、利用料金、面談・予約方法を示す現行専用案内を確認できない',
          distinction: '県の制度概要だけから町内で現在予約可能な実施内容を推測しない',
          verificationPolicy: '実施施設と利用条件は美浜町教育課またはひまわりこども園へ確認する'
        },
        source: { url: 'https://www.town.mihama.wakayama.jp/docs/2014032700010/', checkedAt },
        additionalSources: [
          { url: 'https://www.pref.wakayama.lg.jp/prefg/040200/kosodateshienjigyo.html', checkedAt }
        ]
      },
      housingSupport: {
        status: 'unavailable',
        summary: '耐震ベッド・耐震シェルター補助は耐震性が不足する木造住宅一般を対象とし、子どもの有無を要件としないため、子育て世帯専用の現行住宅支援を確認できない。',
        details: {
          checked: '町の住宅耐震化、町営住宅、移住・定住、子育て支援の現行案内を確認',
          excludedGeneralProgram: '耐震ベッド・耐震シェルター購入・設置費を上限39万9千円補助する一般防災制度で、子ども要件・子ども加算がない',
          unconfirmed: '子育て世帯を対象とする住宅取得、改修、家賃、転居費の現行制度',
          verificationPolicy: '制度の有無と募集状況は防災まちづくりみらい課または子育て健康推進課へ確認する'
        },
        source: { url: 'https://www.town.mihama.wakayama.jp/docs/2024042300018/', checkedAt }
      }
    },
    removeNotes: ['耐震ベッド', '誰でも通園', '病児'],
    note: '精度監査で、美浜町民が利用できる御坊広域の病児・病後児保育を追加。県の一般案内だけでverifiedとしていた誰でも通園をunavailableへ変更し、子ども要件のない耐震支援を住宅支援カテゴリから除外。'
  },
  '30382': {
    prefectureCode: '30',
    summary: '日高町の子育て、教育、住宅、生活、防災に関する9制度を公式情報で確認。18歳年度末までの医療費助成、御坊広域の病児・病後児保育、産後ケア等を記録し、令和8年度未確認の制度は区別した。',
    services: {
      sickChildCare: {
        status: 'verified',
        summary: '生後9週から就学前までを基本対象とし、特に必要な場合は小学3年生まで、御坊市の病児保育室ひまわりを利用できる。',
        eligibility: { minAgeMonths: 2, maxAgeYears: 9 },
        details: {
          facility: '社会医療法人黎明会北出病院 病児保育室ひまわり',
          location: '御坊市湯川町財部728番地2',
          residentArea: '日高町、御坊市、美浜町、由良町、印南町、日高川町の居住児童',
          usualTarget: '生後9週から就学前まで',
          exception: '特に必要な場合は小学3年生まで',
          condition: '医師が利用可能と認め、保護者の就労・疾病・冠婚葬祭等で家庭保育が困難なこと',
          procedure: '原則前日までに施設へ予約し、医師連絡票による病状確認を受ける'
        },
        source: { url: 'https://www.town.wakayama-inami.lg.jp/0000001371.html', checkedAt }
      }
    },
    removeNotes: ['病児・病後児保育'],
    note: '精度監査で、公式広域案内に日高町民が対象として明記されている御坊市の病児・病後児保育を、unavailableからverifiedへ訂正。'
  },
  '30383': {
    prefectureCode: '30',
    summary: '由良町の子育て、教育、住宅、生活、防災に関する9制度を公式情報で確認。広域病児保育、産後ケア等を記録し、令和8年度未確認の制度と子育て世帯専用住宅支援は区別した。',
    services: {
      housingSupport: {
        status: 'unavailable',
        summary: '空き家バンクは定住希望者一般への物件情報・マッチング支援で、子どもの有無を要件とする住宅費補助ではないため、子育て世帯専用の現行住宅支援を確認できない。',
        details: {
          checked: '町の空き家バンク、移住体験住宅、住宅、子育て支援の現行案内を確認',
          excludedInformationProgram: '空き家バンクは賃貸・売買物件の情報提供と利用者登録を行う一般の移住定住支援で、住宅取得・改修・家賃費用の子ども要件付き補助ではない',
          unconfirmed: '子育て世帯を対象とする住宅取得、改修、家賃、転居費の令和8年度制度',
          verificationPolicy: '制度の有無と募集状況は産業振興課または住民福祉課へ確認する'
        },
        source: { url: 'https://www.town.yura.wakayama.jp/docs/2021081200033/', checkedAt }
      }
    },
    removeNotes: ['空き家バンク'],
    note: '精度監査で、一般の物件情報・マッチング制度である空き家バンクを子育て世帯向け住宅費支援としていたため、housingSupportをverifiedからunavailableへ訂正。'
  },
  '30390': {
    prefectureCode: '30',
    summary: '印南町の子育て、教育、住宅、生活、防災に関する9制度を公式情報で確認。広域病児保育、保育料軽減、学校給食費無償化、産後ケア等を記録し、子育て世帯専用住宅支援は未確認として整理した。',
    services: {
      housingSupport: {
        status: 'unavailable',
        summary: '若者定住促進の家賃・住宅取得助成は18歳以上45歳未満という年齢要件による一般制度で、子どもの有無を要件としないため、子育て世帯専用の現行住宅支援を確認できない。',
        details: {
          checked: '令和8年度の若者定住施策、家賃助成、住宅取得助成、子育て支援の公式案内と条例を確認',
          excludedGeneralProgram: '対象者は定住意思のある18歳以上45歳未満の若者で、家賃・住宅新築・購入・改築を支援するが、子ども要件・子ども加算がない',
          unconfirmed: '子育て世帯を対象とする住宅取得、改修、家賃、転居費の現行制度',
          verificationPolicy: '制度の有無と募集状況は企画産業課または教育委員会へ確認する'
        },
        source: { url: 'https://www.town.wakayama-inami.lg.jp/0000000318.html', checkedAt },
        additionalSources: [
          { url: 'https://www.town.wakayama-inami.lg.jp/reiki/reiki_honbun/n100RG00000441.html', checkedAt }
        ]
      }
    },
    removeNotes: ['若者定住', '家賃助成', '住宅取得'],
    note: '精度監査で、子ども要件・加算のない18～44歳の若者一般向け家賃・住宅取得助成を子育て世帯向け住宅支援としていたため、housingSupportをverifiedからunavailableへ訂正。'
  },
  '30391': {
    prefectureCode: '30',
    summary: 'みなべ町の子育て、教育、住宅、生活、防災に関する9制度を公式情報で確認。広域病児保育、産後ケア、誰でも通園、中学生以下の子と同居・扶養する世帯の新築住宅取得支援等を記録。',
    services: {
      housingSupport: {
        status: 'verified',
        summary: '中学生以下の子どもと同居し扶養する世帯が新築住宅等を取得する場合、対象経費の10分の1、上限100万円を補助する。',
        details: {
          program: 'みなべ町若者定住促進新築住宅取得支援事業補助金（子育て世帯要件）',
          childHousehold: '中学生以下の子どもと同居し、扶養する世帯',
          housing: '新築住宅または未使用建売住宅等の取得',
          subsidy: '対象経費の10分の1、上限100万円',
          conditions: '町内定住、税滞納なし、対象住宅・取得時期等の要件があり、交付決定前の工事等は対象外',
          excludedGeneralPath: '本人・配偶者が18～39歳という年齢要件だけで対象となる一般の若者区分と、移住者一般向け空き家改修は表示の中心に混在させない'
        },
        source: { url: 'https://www.town.minabe.lg.jp/kurashi/03/01/2022053100016.html', checkedAt }
      }
    },
    removeNotes: ['若者定住', '空き家改修'],
    note: '精度監査で、年齢要件のみの若者区分と一般空き家改修を混在させていたため、中学生以下の子と同居・扶養する世帯の新築住宅取得支援へ表示範囲を限定。'
  },
  '30392': {
    prefectureCode: '30',
    summary: '日高川町の子育て、教育、住宅、生活、防災に関する9制度を公式情報で確認。広域病児保育、給食費無償化、産後ケア、誰でも通園、中学生以下の子と同居・扶養する世帯の新築住宅取得支援等を記録。',
    services: {
      housingSupport: {
        status: 'verified',
        summary: '中学生以下の子どもと同居し扶養する世帯が新築住宅等を取得する場合、地域に応じ対象経費の10分の1、上限130万円または200万円を補助する。',
        details: {
          program: '日高川町若者定住促進新築住宅取得支援事業補助金（子育て世帯要件）',
          childHousehold: '中学生以下の子どもと同居し、扶養する世帯',
          kawabe: '川辺地域は対象経費の10％以内、上限130万円',
          nakatsuMiyama: '中津地域・美山地域は対象経費の10％以内、上限200万円',
          housing: '延床面積70平方メートル以上の新築住宅または未使用建売住宅',
          period: '令和7年4月1日から令和10年3月15日まで。住宅取得日から1年以内に申請',
          excludedGeneralPath: '本人・配偶者が18～39歳という年齢要件だけで対象となる一般の若者区分と、町外移住者一般向け空き家改修は表示の中心に混在させない'
        },
        source: { url: 'https://www.town.hidakagawa.lg.jp/kurashi/iju_teiju/shienseido/shintikushutoku.html', checkedAt }
      }
    },
    removeNotes: ['若者定住', '空き家改修'],
    note: '精度監査で、年齢要件のみの若者区分と一般空き家改修を混在させていたため、中学生以下の子と同居・扶養する世帯の新築住宅取得支援へ表示範囲を限定。'
  },
  '30401': {
    prefectureCode: '30',
    summary: '白浜町の子育て、教育、住宅、生活、防災に関する9制度を公式情報で確認。保育料・給食費無償化、病児保育、産後ケア、誰でも通園、18歳未満の帯同者加算がある移住支援金等を記録。',
    services: {
      housingSupport: {
        status: 'verified',
        summary: '東京圏から要件を満たして移住する世帯に移住支援金を交付し、18歳未満の帯同世帯員1人につき100万円を加算する。',
        details: {
          program: '白浜町移住支援金',
          childAddition: '18歳未満の帯同世帯員1人につき100万円を加算',
          origin: '東京23区在住者、または東京圏在住で23区へ通勤していた方等',
          requirements: '対象求人への就業、移住元企業でのテレワーク、県の起業支援事業活用等の要件を満たすこと',
          residency: '白浜町へ転入し、継続して居住する意思等の要件あり',
          application: '申請期限、世帯基本額、年度予算残額は申請前に総務課企画政策係へ確認',
          excludedGeneralProgram: '日置川地域の移住検討者向け滞在費補助は子ども要件のない一般制度のため、この比較項目の中心制度に混在させない'
        },
        source: { url: 'https://www.town.shirahama.wakayama.jp/soshiki/somu/kikaku/gyomu/1620711048086.html', checkedAt }
      }
    },
    removeNotes: ['移住支援', '滞在費'],
    note: '精度監査で、子ども加算額が未記載の一般移住支援表示を、18歳未満1人100万円加算の子育て世帯向け内容へ明確化。'
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
    for (const [serviceKey, serviceValue] of Object.entries(config.services)) {
      municipality.services[serviceKey] = serviceValue;
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
  const output = JSON.parse(await readFile('operations/audits/central-b-accuracy-round-output.json', 'utf8'));
  const round = audit.batches.find((item) => item.round === 9);
  if (!round) throw new Error('Round 9 batch is missing.');
  if (output.round !== 9 || output.errorCount !== 0) throw new Error('Round 9 audit output is not clean.');
  round.status = 'completed';

  audit.progress.completedRounds = 9;
  audit.progress.structurallyCheckedMunicipalities = 88;
  audit.progress.deepCheckedMunicipalities = 81;
  audit.progress.confirmedErrors = 50;
  audit.progress.correctedErrors = 50;

  audit.findings = audit.findings.filter((finding) => finding.round !== 9);
  audit.findings.push({
    round: 9,
    auditedAt: new Date().toISOString(),
    codes: round.codes,
    structuralAudit: {
      result: 'passed',
      checkedMunicipalities: 9,
      errors: 0,
      warnings: 2,
      workflowRunId: 30114670240,
      artifactId: 8604926759,
      artifactDigest: 'sha256:270543418e921c9e75f29ca58f15026fdcd6e5c832d7206713d2ce90451def74',
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
      { code: '30362', name: '広川町', services: ['sickChildCare','schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'corrected', note: '病児保育、給食費無償化、産後ケアは一致。子ども要件のない一般住宅取得・改修制度を住宅支援から除外。' },
      { code: '30366', name: '有田川町', services: ['sickChildCare','schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'corrected', note: '病児保育、産後ケア、誰でも通園は一致。一般新築住宅取得給付金を住宅支援から除外。' },
      { code: '30381', name: '美浜町', services: ['sickChildCare','schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'corrected', note: '御坊広域病児保育を追加。町個別条件未公表の誰でも通園をunavailableへ変更し、一般耐震支援を住宅支援から除外。' },
      { code: '30382', name: '日高町', services: ['sickChildCare','schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'corrected', note: '御坊広域病児保育を追加。令和7年度給食無償化と令和8年度未確認を区別する既存警告は妥当。' },
      { code: '30383', name: '由良町', services: ['childMedical','sickChildCare','schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'corrected', note: '広域病児保育・産後ケアは一致。一般の空き家物件情報制度を住宅費支援から除外。給食は過年度実績と現行未確認を区別。' },
      { code: '30390', name: '印南町', services: ['sickChildCare','schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'corrected', note: '病児保育、給食費無償化、産後ケアは一致。年齢要件のみの若者一般向け家賃・住宅取得助成を除外。' },
      { code: '30391', name: 'みなべ町', services: ['sickChildCare','schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'corrected', note: '病児保育、産後ケア、誰でも通園は一致。住宅支援を中学生以下の子と同居・扶養する世帯区分へ限定。' },
      { code: '30392', name: '日高川町', services: ['sickChildCare','schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'corrected', note: '病児保育、給食費無償化、産後ケア、誰でも通園は一致。住宅支援を中学生以下の子と同居・扶養する世帯区分へ限定。' },
      { code: '30401', name: '白浜町', services: ['sickChildCare','schoolMeals','postpartumCare','temporaryChildcare','housingSupport'], result: 'corrected', note: '病児保育、給食費無償化、産後ケア、誰でも通園は一致。移住支援の18歳未満1人100万円加算を明確化。' }
    ],
    confirmedErrors: [
      { code: '30362', service: 'housingSupport', before: 'verified / 子ども要件のない一般住宅取得・改修支援', after: 'unavailable / 子育て世帯専用住宅支援を確認できない', status: 'corrected_in_audit_pr_2926' },
      { code: '30366', service: 'housingSupport', before: 'verified / 子ども要件のない一般新築住宅取得給付金', after: 'unavailable / 子育て世帯専用住宅支援を確認できない', status: 'corrected_in_audit_pr_2926' },
      { code: '30381', service: 'sickChildCare', before: 'unavailable / 美浜町民の広域利用を未確認', after: 'verified / 御坊市の病児保育室ひまわりを利用可能', status: 'corrected_in_audit_pr_2926' },
      { code: '30381', service: 'temporaryChildcare', before: 'verified / 県の全市町村開始案内のみ', after: 'unavailable / 美浜町の利用者向け個別条件を確認できない', status: 'corrected_in_audit_pr_2926' },
      { code: '30381', service: 'housingSupport', before: 'verified / 子ども要件のない一般耐震支援', after: 'unavailable / 子育て世帯専用住宅支援を確認できない', status: 'corrected_in_audit_pr_2926' },
      { code: '30382', service: 'sickChildCare', before: 'unavailable / 制度記事はあるが条件未確認', after: 'verified / 御坊市の病児保育室ひまわりを利用可能', status: 'corrected_in_audit_pr_2926' },
      { code: '30383', service: 'housingSupport', before: 'verified / 一般の空き家バンク情報支援', after: 'unavailable / 子育て世帯専用住宅費支援を確認できない', status: 'corrected_in_audit_pr_2926' },
      { code: '30390', service: 'housingSupport', before: 'verified / 18～44歳の若者一般向け家賃・住宅取得助成', after: 'unavailable / 子育て世帯専用住宅支援を確認できない', status: 'corrected_in_audit_pr_2926' },
      { code: '30391', service: 'housingSupport', before: 'verified / 年齢要件のみの若者区分と子育て区分を混在', after: 'verified / 中学生以下の子と同居・扶養する世帯区分に限定', status: 'corrected_in_audit_pr_2926' },
      { code: '30392', service: 'housingSupport', before: 'verified / 年齢要件のみの若者区分と子育て区分を混在', after: 'verified / 中学生以下の子と同居・扶養する世帯区分に限定', status: 'corrected_in_audit_pr_2926' },
      { code: '30401', service: 'housingSupport', before: 'verified / 子ども加算額が不明な一般移住支援表示', after: 'verified / 18歳未満1人100万円加算を明確化', status: 'corrected_in_audit_pr_2926' }
    ]
  });

  await writeFile(auditPath, JSON.stringify(audit, null, 2) + '\n', 'utf8');
}

const mode = process.argv[2];
if (mode === 'apply') await applyCorrections();
else if (mode === 'finalize') await finalizeAudit();
else throw new Error('Usage: node scripts/fix-central-b-accuracy-round9.mjs <apply|finalize>');
