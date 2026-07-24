import fs from 'node:fs';
import path from 'node:path';

const auditsDir = path.join(process.cwd(), 'jichitai-compare', 'operations', 'audits');
const correctionRef = process.env.CORRECTION_REF || null;

const cycle9 = {
  schemaVersion: '1.0.0',
  reviewId: 'west-b-rough-validation-cycle-09-review-20260725',
  auditId: 'west-b-rough-validation-cycle-09-20260725',
  sessionId: 'west-b', cycle: 9, plannedCycles: 10,
  reviewedAt: '2026-07-25T04:44:00+09:00',
  scope: {municipalityCount:25, serviceCount:225, checkedUrlCount:250, prefectureCodes:['45','47'], prefectureCounts:{'45':9,'47':16}},
  results: {structuralErrorCount:0, detectedResearchContentErrorCount:1, correctedResearchContentErrorCount:1, detectedSourceMaintenanceIssueCount:3, correctedSourceMaintenanceIssueCount:3, networkOnlyWarningCount:1, manualSpotCheckCount:5, manualSpotCheckFailureCount:0},
  researchContentCorrections: [{code:'47302', name:'大宜味村', service:'childcareFee', finding:'旧案内失効後の現行規則で、0～5歳児の保育料と村内児童の給食費が無償であることを確認し、一般的な国制度中心の登録内容を村独自の現行条件へ訂正', correctionRef}],
  sourceMaintenanceCorrections: [
    {code:'45442', name:'日之影町', service:'sickChildCare', oldUrl:'https://www.town.hinokage.lg.jp/docs/2025032100014/file_contents/2025.pdf', newUrl:'https://www.town.hinokage.lg.jp/docs/2016052500038/index.html', correctionRef},
    {code:'45442', name:'日之影町', service:'childcareFee', oldUrl:'https://www.town.hinokage.lg.jp/docs/2025032100014/file_contents/2025.pdf', newUrl:'https://www.town.hinokage.lg.jp/docs/2016022500143/', correctionRef},
    {code:'45443', name:'五ヶ瀬町', service:'sickChildCare', oldUrl:'https://www.town.gokase.miyazaki.jp/material/files/group/5/gokasekodomokeikaku_soan.pdf', newUrl:'https://www.town.gokase.miyazaki.jp/material/files/group/5/gokase_kodomokeikaku.pdf', correctionRef}
  ],
  networkOnlyWarnings: [{code:'47211', name:'沖縄市', service:'temporaryChildcare', reason:'監査時404だったが、同一公式URLの令和8年度こども誰でも通園制度案内を再確認できたため一時的応答と判定'}],
  manualSpotChecks: [
    {code:'45405', name:'川南町', service:'schoolMeals', result:'passed', finding:'町立小中学校の学校給食費を無償化し、保護者負担なしであることを公式ページで確認'},
    {code:'45431', name:'美郷町', service:'housingSupport', result:'passed', finding:'空き家バンク物件の改修費を2分の1・上限50万円補助する制度を確認'},
    {code:'47205', name:'宜野湾市', service:'childMedical', result:'passed', finding:'0歳から18歳年度末までの入院・通院保険診療自己負担助成を確認'},
    {code:'47211', name:'沖縄市', service:'temporaryChildcare', result:'passed', finding:'未就園の生後6か月から3歳未満児が公立4園で月10時間まで利用できる令和8年度制度を確認'},
    {code:'47301', name:'国頭村', service:'bulkyWaste', result:'passed', finding:'粗大・不燃ごみをやんばる美化センターへ直接搬入できる現行案内を確認'}
  ],
  conclusion:'passed_after_correction'
};

const cycle10 = {
  schemaVersion: '1.0.0',
  reviewId: 'west-b-rough-validation-cycle-10-review-20260725',
  auditId: 'west-b-rough-validation-cycle-10-20260725',
  sessionId: 'west-b', cycle: 10, plannedCycles: 10,
  reviewedAt: '2026-07-25T04:44:00+09:00',
  scope: {municipalityCount:25, serviceCount:225, checkedUrlCount:250, prefectureCodes:['47'], prefectureCounts:{'47':25}},
  results: {structuralErrorCount:0, detectedResearchContentErrorCount:0, correctedResearchContentErrorCount:0, detectedSourceMaintenanceIssueCount:2, correctedSourceMaintenanceIssueCount:2, networkOnlyWarningCount:1, manualSpotCheckCount:5, manualSpotCheckFailureCount:0},
  sourceMaintenanceCorrections: [
    {code:'47328', name:'中城村', service:'temporaryChildcare', oldUrl:'https://www.vill.nakagusuku.okinawa.jp/UserFiles/File/kikaku/plan/r8_taikou1_kai.pdf', newUrl:'https://www.vill.nakagusuku.okinawa.jp/userfiles/files/sonsei/transformation/daigoji/jisshikeikaku/pfm4dmuehxbj.pdf', correctionRef},
    {code:'47350', name:'南風原町', service:'schoolMeals', oldUrl:'https://www.town.haebaru.lg.jp/soshiki/17/16025.html', newUrl:'https://www.town.haebaru.lg.jp/soshiki/18/16025.html', correctionRef}
  ],
  networkOnlyWarnings: [{code:'47382', name:'与那国町', service:'childcareFee', reason:'監査時404だったが、令和8年度保育所入所案内が現行公式カテゴリ内に掲載されていることを再確認したため一時的応答と判定'}],
  manualSpotChecks: [
    {code:'47311', name:'恩納村', service:'postpartumCare', result:'passed', finding:'産後1年未満の母子へ宿泊・通所・訪問型を提供する現行産後ケアを確認'},
    {code:'47325', name:'嘉手納町', service:'housingSupport', result:'passed', finding:'住宅リフォーム費50％、条件別上限20～50万円と子育て加算30万円を確認'},
    {code:'47348', name:'与那原町', service:'schoolMeals', result:'passed', finding:'2026年4月から町立小中学校の学校給食費を完全無償化していることを確認'},
    {code:'47356', name:'渡名喜村', service:'housingSupport', result:'passed', finding:'45歳未満世帯または中学生以下の子を扶養する世帯等へ多用途住宅を低廉な家賃で提供する制度を確認'},
    {code:'47361', name:'久米島町', service:'housingSupport', result:'passed', finding:'2026年度の移住定住・子育て世帯向け空き家改修費補助を確認'}
  ],
  conclusion:'passed_after_correction'
};

fs.writeFileSync(path.join(auditsDir, 'west-b-rough-validation-cycle-09-review-20260725.json'), JSON.stringify(cycle9, null, 2) + '\n');
fs.writeFileSync(path.join(auditsDir, 'west-b-rough-validation-cycle-10-review-20260725.json'), JSON.stringify(cycle10, null, 2) + '\n');
