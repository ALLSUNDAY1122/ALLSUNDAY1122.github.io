import { readFile, writeFile } from 'node:fs/promises';

const ROOT = new URL('../', import.meta.url);
const NOW = '2026-07-25T03:18:00+09:00';
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

await updateMunicipality('33213', (municipality, task) => {
  municipality.services.postpartumCare.source = {
    url: 'https://www.city.akaiwa.lg.jp/kosodate/ninshinshussan/2907.html',
    checkedAt: DATE
  };
  task.notes.push('2026-07-25: 産後ケアの削除済みPDF出典を、赤磐市の現行「産後ケア事業・産後子育てサポーター派遣事業」ページへ更新。制度内容は維持。');
});

await updateMunicipality('33346', (municipality, task) => {
  const service = municipality.services.temporaryChildcare;
  service.summary = '生後6か月から就学前の子どもを和気にこにこ園で一時預かり';
  service.eligibility = {
    minAgeMonths: 6,
    maxAgeYears: 5
  };
  service.details = {
    target: '仕事、冠婚葬祭、病気、疲れ、看護、介護等により保護者が一時的に保育できない、生後6か月から就学前の子ども',
    facility: '和気にこにこ園',
    fee: '日額1,800円',
    application: '利用日の事前予約が必要'
  };
  service.source = {
    url: 'https://www.town.wake.lg.jp/soshiki/kodomo/gyomu/14/1/189.html',
    checkedAt: DATE
  };
  delete municipality.services.bulkyWaste.additionalSources;
  task.notes.push('2026-07-25: 一時預かりを現行公式案内に合わせ、実施施設を和気にこにこ園、利用料を日額1,800円へ訂正。旧PDFの2施設・800円/1,600円条件を削除。');
  task.notes.push('2026-07-25: 粗大ごみの削除済み補助PDFを出典から除外。現行条例の主出典で料金条件を確認。');
});

await updateMunicipality('40224', (municipality, task) => {
  municipality.services.disasterPrevention.details.publication = '福津市防災マップ（2024年2月発刊）';
  municipality.services.disasterPrevention.source = {
    url: 'https://www.city.fukutsu.lg.jp/soshiki/kiki/anshin/1/1/1200.html',
    checkedAt: DATE
  };
  task.notes.push('2026-07-25: 削除済み防災マップ索引URLを、2024年2月発刊の福津市防災マップを掲載する現行防災情報ページへ更新。');
});

const audit = {
  schemaVersion: '1.0.0',
  auditId: 'west-a-source-link-remediation-batch01-20260725',
  auditedAt: NOW,
  sourceAudit: {
    pullRequestNumber: 3051,
    normalGetCiRunNumber: 7470,
    municipalityCount: 226,
    referenceCount: 2691,
    uniqueUrlCount: 2444,
    hardFailureUrlCount: 28,
    softWarningUrlCount: 159,
    redirectUrlCount: 11
  },
  corrections: [
    {
      code: '33213',
      name: '赤磐市',
      service: 'postpartumCare',
      type: 'source_url_replacement',
      materialContentChanged: false
    },
    {
      code: '33346',
      name: '和気町',
      service: 'temporaryChildcare',
      type: 'material_content_and_source_correction',
      before: '町内2園、4時間800円・4時間超8時間1,600円',
      after: '和気にこにこ園、日額1,800円'
    },
    {
      code: '33346',
      name: '和気町',
      service: 'bulkyWaste',
      type: 'broken_additional_source_removal',
      materialContentChanged: false
    },
    {
      code: '40224',
      name: '福津市',
      service: 'disasterPrevention',
      type: 'source_url_replacement',
      materialContentChanged: false
    }
  ],
  confirmedFalsePositives: [
    {
      codes: ['33203', '33606'],
      names: ['津山市', '鏡野町'],
      url: 'https://www.town.kagamino.lg.jp/soshiki/26/1882.html',
      reason: '自動取得では404だが、公式ページは現存し2026年7月1日の病児保育室たんぽぽ再開案内を含む'
    },
    {
      codes: ['40384'],
      names: ['遠賀町'],
      url: 'https://www.town.onga.lg.jp/soshiki/11/1433.html',
      reason: '自動取得では404だが、公式ページは現存し登録条件と一致'
    }
  ],
  remainingHardFailureUrlCountAfterBatch: 24,
  status: 'batch01_corrections_prepared'
};

await writeJson('operations/audits/west-a-source-link-remediation-batch01-20260725.json', audit);
