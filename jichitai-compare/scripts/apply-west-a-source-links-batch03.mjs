import { readFile, writeFile } from 'node:fs/promises';

const ROOT = new URL('../', import.meta.url);
const NOW = '2026-07-25T03:48:00+09:00';
const DATE = '2026-07-25';

async function readJson(relativePath) {
  return JSON.parse(await readFile(new URL(relativePath, ROOT), 'utf8'));
}

async function writeJson(relativePath, value) {
  await writeFile(new URL(relativePath, ROOT), `${JSON.stringify(value)}\n`);
}

function primarySourceUrls(municipality) {
  return [...new Set(Object.values(municipality.services).map((service) => service.source.url))];
}

async function updateMunicipality(code, updater) {
  const prefectureCode = code.slice(0, 2);
  const dataPath = `data/municipalities/${prefectureCode}/${code}.json`;
  const taskPath = `operations/tasks/${code}.json`;
  const municipality = await readJson(dataPath);
  const task = await readJson(taskPath);

  updater(municipality, task);
  municipality.updatedAt = DATE;
  task.lastCheckedAt = DATE;
  task.lastUpdatedAt = NOW;
  task.lastUpdatedBy = '西日本調査班A';
  task.officialSources = primarySourceUrls(municipality);
  task.notes = [...new Set(task.notes)];

  await writeJson(dataPath, municipality);
  await writeJson(taskPath, task);
}

await updateMunicipality('37324', (municipality, task) => {
  municipality.services.temporaryChildcare.source = {
    url: 'https://www.town.shodoshima.lg.jp/kosodachi/kosodate/7/kodomo-kyoiku/kyoikuiinkaikosodachi/kosodatetorikumi/8902.html',
    checkedAt: DATE
  };
  task.notes.push('2026-07-25: こども誰でも通園制度の出典が無関係な国民保護モデル計画PDFを指していたため、第3期すくすく子育ち応援アクションプランの現行公式ページへ訂正。unavailable判定は維持。');
});

await updateMunicipality('46533', (municipality, task) => {
  const service = municipality.services.bulkyWaste;
  service.summary = '粗大ごみは沖永良部クリーンセンターへ直接搬入し、10kg当たり100円';
  service.details = {
    target: '家具、マットレス、畳、自転車、ストーブ等の粗大ごみ',
    method: '町の通常収集ではなく沖永良部クリーンセンターへ直接搬入',
    fee: '粗大ごみは10kg当たり100円。10kg未満は10kgとして計算',
    excluded: '家電リサイクル対象品は販売店等へ依頼'
  };
  service.source = {
    url: 'https://www.town.wadomari.lg.jp/tyoumin/gomisyori.html',
    checkedAt: DATE
  };
  task.notes.push('2026-07-25: 粗大ごみの旧計画PDF出典を現行処分手数料ページへ更新し、直接搬入料金を10kg当たり100円として明記。');
});

const audit = {
  schemaVersion: '1.0.0',
  auditId: 'west-a-source-link-remediation-final-20260725',
  auditedAt: NOW,
  sourceAudit: {
    pullRequestNumber: 3051,
    firstCiRunNumber: 7451,
    normalGetCiRunNumber: 7470,
    municipalityCount: 226,
    referenceCount: 2691,
    uniqueUrlCount: 2444,
    initialHardFailureUrlCount: 28,
    softWarningUrlCount: 159,
    redirectUrlCount: 11
  },
  classification: {
    correctedUrlCount: 9,
    confirmedCmsFalsePositiveUrlCount: 19,
    unresolvedUrlCount: 0
  },
  correctionsByBatch: [
    {
      batch: 1,
      pullRequestNumber: 3074,
      urlCount: 4,
      municipalities: ['33213 赤磐市', '33346 和気町', '40224 福津市']
    },
    {
      batch: 2,
      pullRequestNumber: 3089,
      urlCount: 3,
      municipalities: ['40610 福智町', '40646 上毛町', '43443 益城町']
    },
    {
      batch: 3,
      urlCount: 2,
      municipalities: ['37324 小豆島町', '46533 和泊町']
    }
  ],
  materialCorrections: [
    {
      code: '33346',
      name: '和気町',
      service: 'temporaryChildcare',
      before: '町内2園、4時間800円・4時間超8時間1,600円',
      after: '和気にこにこ園、日額1,800円'
    },
    {
      code: '43443',
      name: '益城町',
      service: 'bulkyWaste',
      before: '品目・大きさ別料金を申込時に確認',
      after: '1品目500円、3辺合計400cm未満'
    },
    {
      code: '37324',
      name: '小豆島町',
      service: 'temporaryChildcare',
      before: '無関係な国民保護モデル計画PDFを制度出典として登録',
      after: '第3期すくすく子育ち応援アクションプラン公式ページ'
    },
    {
      code: '46533',
      name: '和泊町',
      service: 'bulkyWaste',
      before: '重量等に応じた現行料金表に従う',
      after: '粗大ごみ10kg当たり100円'
    }
  ],
  falsePositiveMunicipalities: [
    '33203 津山市', '33606 鏡野町', '33643 西粟倉村', '39212 香美市', '40384 遠賀町',
    '43484 津奈木町', '43505 多良木町', '43507 水上村', '46216 日置市', '46524 宇検村',
    '46525 瀬戸内町', '46530 徳之島町', '46532 伊仙町', '46535 与論町'
  ],
  result: {
    status: 'completed_with_corrections',
    remainingBrokenOrMisassignedSourceUrlCount: 0,
    newlyDetectedMaterialResearchErrorCount: 3,
    newlyDetectedSourceMisassignmentCount: 1,
    sourceMaintenanceOnlyCount: 5
  }
};

await writeJson('operations/audits/west-a-source-link-remediation-final-20260725.json', audit);
