import { readFile, writeFile } from 'node:fs/promises';

const ROOT = new URL('../', import.meta.url);
const DATE = '2026-07-25';
const NOW = '2026-07-25T04:28:00+09:00';

async function readJson(relativePath) {
  return JSON.parse(await readFile(new URL(relativePath, ROOT), 'utf8'));
}

async function writeJson(relativePath, value) {
  await writeFile(new URL(relativePath, ROOT), `${JSON.stringify(value)}\n`);
}

const municipalityPath = 'data/municipalities/33/33643.json';
const taskPath = 'operations/tasks/33643.json';
const municipality = await readJson(municipalityPath);
const task = await readJson(taskPath);
const childcareFee = municipality.services.childcareFee;

childcareFee.summary = '保育園は所得に応じ月額0～14,000円、幼稚園の基本・預かり・延長保育は無償';
childcareFee.details = {
  facilities: '西粟倉保育園・西粟倉幼稚園',
  nurseryFee: '西粟倉保育園は所得により月額0～14,000円。多子減免制度あり',
  kindergartenFee: '西粟倉幼稚園は基本保育料、預かり保育料、夕方延長保育料を無償化',
  holidayAndSaturdayCare: '長期休業中の預かり保育と土曜日保育も無償。おやつ代は1日50円等の実費が必要',
  application: '入園希望者は幼稚園または教育委員会へ申し込む。令和8年度途中入園は村公式オンライン申請を利用可能'
};
childcareFee.source = {
  url: 'https://www.vill.nishiawakura.okayama.jp/wp/%EF%BC%96%EF%BC%8E%E4%BF%9D%E8%82%B2%E5%9C%92%E3%83%BB%E5%B9%BC%E7%A8%9A%E5%9C%92%E3%82%92%E5%88%A9%E7%94%A8/',
  checkedAt: DATE
};
childcareFee.additionalSources = [
  {
    url: 'https://www.vill.nishiawakura.okayama.jp/wp/yokuarusitumon/',
    checkedAt: DATE
  },
  {
    url: 'https://www.vill.nishiawakura.okayama.jp/wp/news/%E4%BB%A4%E5%92%8C%EF%BC%96%E5%B9%B4%E5%BA%A6%E4%BF%9D%E8%82%B2%E5%9C%92%E3%83%BB%E5%B9%BC%E7%A8%9A%E5%9C%92%E3%83%BB%E6%94%BE%E8%AA%B2%E5%BE%8C%E5%85%90%E7%AB%A5%E3%82%AF%E3%83%A9%E3%83%96%E3%81%AE/',
    checkedAt: DATE
  }
];
municipality.updatedAt = DATE;

task.lastCheckedAt = DATE;
task.lastUpdatedAt = NOW;
task.lastUpdatedBy = '西日本調査班A';
task.notes = [...new Set([
  ...(task.notes ?? []),
  '2026-07-25: URLソフト警告再確認で、旧保育料ページの幼稚園月額2,500円・預かり有料を採用していた誤りを検出。現行公式案内に基づき、幼稚園の基本・預かり・延長・長期休業・土曜保育を無償へ訂正。保育園は所得により月額0～14,000円、多子減免あり。'
])];
task.officialSources = [...new Set(Object.values(municipality.services).map((service) => service.source.url))];

await writeJson(municipalityPath, municipality);
await writeJson(taskPath, task);

await writeJson('operations/audits/west-a-source-link-soft-warning-review-20260725.json', {
  schemaVersion: '1.0.0',
  auditId: 'west-a-source-link-soft-warning-review-20260725',
  auditedAt: NOW,
  sourceAudit: {
    pullRequestNumber: 3051,
    normalGetCiRunNumber: 7470,
    municipalityCount: 226,
    referenceCount: 2691,
    uniqueUrlCount: 2444,
    softWarningCount: 159,
    statusCounts: {
      '403': 8,
      '429': 5,
      timeout: 98,
      fetchFailed: 48
    },
    warningDomainCount: 21
  },
  classification: {
    domainWideScannerFailureUrlCount: 139,
    vendorReikiAccessRestrictionUrlCount: 8,
    rateLimitedUrlCount: 5,
    companionHostConnectionFailureUrlCount: 4,
    individuallyRecheckedUrlCount: 3,
    remainingSuspectedBrokenLinkCount: 0,
    remainingUnclassifiedWarningCount: 0
  },
  manualOfficialRechecks: [
    {
      code: '43214',
      name: '阿蘇市',
      service: 'housingSupport',
      result: 'current_official_page_confirmed',
      correctionRequired: false
    },
    {
      code: '40605',
      name: '川崎町',
      service: 'postpartumCare',
      result: 'current_official_page_and_reiki_confirmed',
      correctionRequired: false
    },
    {
      code: '46404',
      name: '長島町',
      services: ['temporaryChildcare', 'housingSupport', 'bulkyWaste', 'disasterPrevention'],
      result: 'rate_limited_pages_confirmed_by_official_search',
      correctionRequired: false
    },
    {
      code: '33643',
      name: '西粟倉村',
      services: ['childcareFee', 'temporaryChildcare'],
      result: 'pages_confirmed_and_outdated_fee_content_detected',
      correctionRequired: true
    },
    {
      codes: ['33663', '39301'],
      names: ['久米南町', '東洋町'],
      result: 'companion_host_failures_confirmed_as_scanner_limitations',
      correctionRequired: false
    }
  ],
  correction: {
    code: '33643',
    name: '西粟倉村',
    service: 'childcareFee',
    before: '幼稚園基本保育料月額2,500円、預かり・延長・長期休業を有料として登録',
    after: '幼稚園の基本・預かり・延長・長期休業・土曜保育は無償。保育園は所得により月額0～14,000円、多子減免あり',
    reason: '旧保育料ページと現行利用案内が矛盾し、令和8年度募集・現行FAQは無償化を示す'
  },
  result: {
    status: 'completed_with_one_material_correction',
    newlyDetectedMaterialResearchErrorCount: 1,
    newlyDetectedBrokenLinkCount: 0,
    unresolvedWarningCount: 0
  }
});
