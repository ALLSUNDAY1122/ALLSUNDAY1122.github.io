import { readFile, writeFile } from 'node:fs/promises';

const ROOT = new URL('../', import.meta.url);
const NOW = '2026-07-25T03:34:00+09:00';
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

await updateMunicipality('43443', (municipality, task) => {
  const service = municipality.services.bulkyWaste;
  service.summary = '地区指定業者へ事前申込みし、1点500円で戸別収集';
  service.details = {
    application: '居住地区の指定収集業者へ事前に申し込む',
    fee: '粗大ごみ1品目につき500円',
    sizeLimit: '縦・横・高さの3辺合計が400cm未満まで収集可能',
    collection: '指定日時に自宅の庭先等へ出し、業者の収集時に料金を支払う',
    excluded: 'テレビ、冷蔵庫・冷凍庫、エアコン、洗濯機・衣類乾燥機は町収集の対象外'
  };
  service.source = {
    url: 'https://www.town.mashiki.lg.jp/kiji0032329/',
    checkedAt: DATE
  };
  task.notes.push('2026-07-25: 粗大ごみの旧index.html付きURLを現行URLへ更新し、1品目500円・3辺合計400cm未満の条件を公式案内に基づき明記。');
});

await updateMunicipality('40610', (municipality, task) => {
  const service = municipality.services.postpartumCare;
  service.source.checkedAt = DATE;
  delete service.additionalSources;
  task.notes.push('2026-07-25: 産後ケアの削除済み追加PDFを除去。アウトリーチ型・課税世帯減免を掲載する現行母子保健ページを主出典として再確認。');
});

await updateMunicipality('40646', (municipality, task) => {
  const service = municipality.services.bulkyWaste;
  service.source.checkedAt = DATE;
  delete service.additionalSources;
  task.notes.push('2026-07-25: 粗大ごみの削除済み旧PDFを除去。2026年6月更新の3年保存版ごみ分別ガイド掲載ページを主出典として再確認。');
});

const audit = {
  schemaVersion: '1.0.0',
  auditId: 'west-a-source-link-remediation-batch02-20260725',
  auditedAt: NOW,
  sourceAudit: {
    pullRequestNumber: 3051,
    normalGetCiRunNumber: 7470,
    initialHardFailureUrlCount: 28,
    falsePositiveUrlCountThroughBatch02: 3,
    correctedUrlCountBeforeBatch02: 4,
    unresolvedUrlCountBeforeBatch02: 21
  },
  corrections: [
    {
      code: '43443',
      name: '益城町',
      service: 'bulkyWaste',
      type: 'material_content_and_source_correction',
      before: '品目・大きさ別料金を申込時に確認、旧index.html付きURL',
      after: '1品目500円、3辺合計400cm未満、現行URL'
    },
    {
      code: '40610',
      name: '福智町',
      service: 'postpartumCare',
      type: 'broken_additional_source_removal',
      materialContentChanged: false
    },
    {
      code: '40646',
      name: '上毛町',
      service: 'bulkyWaste',
      type: 'broken_additional_source_removal',
      materialContentChanged: false
    }
  ],
  confirmedFalsePositives: [
    {
      code: '39212',
      name: '香美市',
      service: 'schoolMeals',
      url: 'https://www.city.kami.lg.jp/soshiki/46/syugakuenjo.html',
      reason: '自動取得では404だが現行公式ページが存在し、学校給食費を就学援助対象として掲載'
    }
  ],
  unresolvedHardFailureUrlCountAfterBatch02: 18,
  status: 'batch02_corrections_prepared'
};

await writeJson('operations/audits/west-a-source-link-remediation-batch02-20260725.json', audit);
