import fs from 'node:fs';
import path from 'node:path';

const root = path.join(process.cwd(), 'jichitai-compare');
const now = '2026-07-25T04:40:00+09:00';
const date = '2026-07-25';
const definitions = JSON.parse(fs.readFileSync(path.join(root, 'data', 'service-definitions.json'), 'utf8'));
const serviceIds = definitions.services.map(item => item.id);

function syncTaskSources(task, municipality) {
  task.officialSources = [...new Set(serviceIds.map(id => municipality.services[id]?.source?.url).filter(Boolean))];
  task.lastCheckedAt = date;
  task.lastUpdatedAt = now;
  task.lastUpdatedBy = '西日本調査班B';
  task.notes = Array.isArray(task.notes) ? task.notes : [];
}

const replacements = [
  {code:'45442', pref:'45', service:'sickChildCare', old:'https://www.town.hinokage.lg.jp/docs/2025032100014/file_contents/2025.pdf', url:'https://www.town.hinokage.lg.jp/docs/2016052500038/index.html', note:'概略検証第9回で旧2025年度PDFの失効を確認し、病児・病後児保育利用料2,000円補助を掲載する現行公式ページへ更新。'},
  {code:'45442', pref:'45', service:'childcareFee', old:'https://www.town.hinokage.lg.jp/docs/2025032100014/file_contents/2025.pdf', url:'https://www.town.hinokage.lg.jp/docs/2016022500143/', note:'概略検証第9回で旧2025年度PDFの失効を確認し、令和6年度からの保育料・副食費完全無償化を掲載する現行公式ページへ更新。'},
  {code:'45443', pref:'45', service:'sickChildCare', old:'https://www.town.gokase.miyazaki.jp/material/files/group/5/gokasekodomokeikaku_soan.pdf', url:'https://www.town.gokase.miyazaki.jp/material/files/group/5/gokase_kodomokeikaku.pdf', note:'概略検証第9回でこども計画素案PDFの失効を確認し、令和7～11年度の最終版こども計画PDFへ更新。'},
  {code:'47328', pref:'47', service:'temporaryChildcare', old:'https://www.vill.nakagusuku.okinawa.jp/UserFiles/File/kikaku/plan/r8_taikou1_kai.pdf', url:'https://www.vill.nakagusuku.okinawa.jp/userfiles/files/sonsei/transformation/daigoji/jisshikeikaku/pfm4dmuehxbj.pdf', note:'概略検証第10回で旧パスの令和8年度実施計画PDF失効を確認し、現行公式サイト掲載の同年度施策大綱1 PDFへ更新。'},
  {code:'47350', pref:'47', service:'schoolMeals', old:'https://www.town.haebaru.lg.jp/soshiki/17/16025.html', url:'https://www.town.haebaru.lg.jp/soshiki/18/16025.html', note:'概略検証第10回で組織改編による旧URL失効を確認し、令和8年度給食費案内の現行公式URLへ更新。'}
];

const touched = new Set();
for (const r of replacements) {
  const sourcePath = path.join(root, 'data', 'municipalities', r.pref, `${r.code}.json`);
  const data = JSON.parse(fs.readFileSync(sourcePath, 'utf8'));
  const current = data.services[r.service].source.url;
  if (current !== r.old && current !== r.url) throw new Error(`${r.code} ${r.service}: unexpected source ${current}`);
  data.services[r.service].source.url = r.url;
  data.services[r.service].source.checkedAt = date;
  data.updatedAt = date;
  fs.writeFileSync(sourcePath, JSON.stringify(data, null, 2) + '\n');
  touched.add(r.code);

  const taskPath = path.join(root, 'operations', 'tasks', `${r.code}.json`);
  const task = JSON.parse(fs.readFileSync(taskPath, 'utf8'));
  syncTaskSources(task, data);
  if (!task.notes.includes(r.note)) task.notes.push(r.note);
  fs.writeFileSync(taskPath, JSON.stringify(task, null, 2) + '\n');
}

const ogimiPath = path.join(root, 'data', 'municipalities', '47', '47302.json');
const ogimi = JSON.parse(fs.readFileSync(ogimiPath, 'utf8'));
ogimi.services.childcareFee = {
  status: 'verified',
  summary: '0～5歳児の保育料を無償化し、村内児童の給食費も無償化',
  eligibility: {minAgeMonths: 6, maxAgeYears: 5},
  details: {
    facility: 'おおぎみこども園',
    childcareFee: '利用者負担額（保育料）は認定区分・所得階層にかかわらず徴収しない',
    mealFee: '大宜味村内に住所を有する児童の給食費は徴収しない',
    additionalFees: '延長保育は1時間200円、預かり保育は平日300円・土曜や長期休暇等900円',
    effective: '現行規則は令和7年4月1日施行',
    application: '令和8年度入園は教育・保育給付認定と施設利用申込みが必要'
  },
  source: {url:'https://www.vill.ogimi.okinawa.jp/section/reiki_int/reiki_honbun/q913RG00000549.html', checkedAt: date}
};
ogimi.updatedAt = date;
fs.writeFileSync(ogimiPath, JSON.stringify(ogimi, null, 2) + '\n');
touched.add('47302');

const ogimiTaskPath = path.join(root, 'operations', 'tasks', '47302.json');
const ogimiTask = JSON.parse(fs.readFileSync(ogimiTaskPath, 'utf8'));
syncTaskSources(ogimiTask, ogimi);
const ogimiNote = '概略検証第9回で保育料の旧案内失効と現行規則を確認。利用者負担額および村内児童の給食費が無償である現行内容へ訂正。';
if (!ogimiTask.notes.includes(ogimiNote)) ogimiTask.notes.push(ogimiNote);
fs.writeFileSync(ogimiTaskPath, JSON.stringify(ogimiTask, null, 2) + '\n');

console.log(`updated ${[...touched].sort().join(',')}`);
