import fs from 'node:fs';
import path from 'node:path';

const projectDir = path.resolve('jichitai-compare');
const reportPath = path.join(projectDir, 'operations', 'audits', 'north-b-horizontal-url-year-numeric-20260725.json');
const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));

report.status = 'review_completed';
report.reviewedAt = '2026-07-25T12:32:00+09:00';
report.reviewResult = {
  machineDetectedBrokenUrlCount: 16,
  confirmedMaintenanceCount: 12,
  affectedMunicipalityCount: 10,
  browserConfirmedAccessibleCount: 4,
  verifiedStatusChanges: 0,
  contentFactChanges: 0,
  policy: 'URLのHTTP機械判定だけでは制度内容を変更せず、現行公式ページを確認できたもののみ差し替えまたは冗長な追加出典を削除した。通常ブラウザで現行ページを確認できた4件は機械誤検出としてデータを維持した。'
};
report.confirmedMaintenance = [
  { code: '04215', municipality: '大崎市', service: 'sickChildCare', action: 'replace_primary', result: '現行の病児・病後児保育ページへ更新' },
  { code: '04301', municipality: '蔵王町', service: 'disasterPrevention', action: 'replace_additional', result: '防災重点ため池ページの現行URLへ更新' },
  { code: '04321', municipality: '大河原町', service: 'schoolMeals', action: 'remove_additional', result: '主出典で内容確認できるため切れた旧追加出典を削除' },
  { code: '04401', municipality: '松島町', service: 'sickChildCare', action: 'remove_additional', result: '第三期計画の現行主ページを維持し旧PDF追加出典を削除' },
  { code: '04401', municipality: '松島町', service: 'postpartumCare', action: 'replace_primary_remove_additional', result: '令和8年6月広報の産後ケア案内へ更新し旧PDFを削除' },
  { code: '04421', municipality: '大和町', service: 'postpartumCare', action: 'replace_primary', result: '令和7・8年度産後ケア案内PDFへ更新' },
  { code: '04424', municipality: '大衡村', service: 'childcareFee', action: 'replace_additional', result: '令和8年度入園案内ページへ更新' },
  { code: '04445', municipality: '加美町', service: 'disasterPrevention', action: 'replace_primary', result: '現行ハザードマップURLへ更新' },
  { code: '05206', municipality: '男鹿市', service: 'postpartumCare', action: 'replace_primary', result: '令和8年度支援制度一覧の産後ケア案内へ更新' },
  { code: '06202', municipality: '米沢市', service: 'postpartumCare', action: 'replace_primary', result: '現行組織配下の産後ケアページへ更新' },
  { code: '06301', municipality: '山辺町', service: 'housingSupport', action: 'replace_primary', result: '令和8年度住宅リフォーム支援要綱へ更新' }
];
report.browserConfirmedMachineFalsePositives = [
  { code: '04212', municipality: '登米市', service: 'housingSupport', url: 'https://www.city.tome.miyagi.jp/machi/shisejoho/ijuteju/bank/akiyakaisyu.html' },
  { code: '04444', municipality: '色麻町', service: 'temporaryChildcare', url: 'https://www.town.shikama.miyagi.jp/kurashi/3238.html' },
  { code: '05361', municipality: '五城目町', service: 'childcareFee', url: 'https://www.town.gojome.akita.jp/up/files/kenkouiryoufukusi/kosodate/01_siori.pdf' },
  { code: '06321', municipality: '河北町', service: 'temporaryChildcare', url: 'https://www.town.kahoku.yamagata.jp/soshiki/7741.html' }
];
report.integration = {
  pullRequest: 3232,
  branch: 'audit/north-b-url-year-numeric-20260725',
  generatedData: 'updated',
  staticPages: 'updated',
  validation: 'success',
  nextAction: '一時ファイル削除後に通常CIを確認し、mainへ統合する。'
};

fs.writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);
console.log(JSON.stringify(report.reviewResult, null, 2));
