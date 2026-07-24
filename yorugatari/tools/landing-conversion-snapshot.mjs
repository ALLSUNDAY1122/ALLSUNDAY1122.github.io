import fs from 'node:fs';
import path from 'node:path';

const ROOT = process.cwd();
const TOOLS = path.join(ROOT, 'yorugatari', 'tools');
const LATEST = path.join(TOOLS, 'landing-conversion-latest.json');
const HISTORY = path.join(TOOLS, 'landing-conversion-history.json');
const API = 'https://page-views-api.ratneshc.com/api/v1/views';
const SITE_ID = 'allsunday1122.github.io';
const MIN_VIEWS_FOR_COMPARISON = 30;
const definitions = [
  {
    id: 'five-minute',
    label: '5分で読める12選',
    pagePath: '/yorugatari/5min-horror.html',
    startPath: '/yorugatari/__landing-start/five-minute'
  },
  {
    id: 'bedtime',
    label: '寝る前の8選',
    pagePath: '/yorugatari/bedtime-horror.html',
    startPath: '/yorugatari/__landing-start/bedtime'
  }
];

function readJson(filePath, fallback) {
  try { return JSON.parse(fs.readFileSync(filePath, 'utf8')); } catch { return fallback; }
}

function japanDate(instant = new Date()) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Tokyo',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  }).format(instant);
}

function rate(starts, views) {
  if (!Number.isFinite(starts) || !Number.isFinite(views) || views <= 0) return null;
  return Math.round((starts / views) * 1000) / 10;
}

async function getViews(trackingPath) {
  const url = API + '?site=' + encodeURIComponent(SITE_ID) + '&path=' + encodeURIComponent(trackingPath);
  let lastError = null;
  for (let attempt = 1; attempt <= 4; attempt += 1) {
    try {
      const response = await fetch(url, {
        headers: { 'user-agent': 'Yorugatari-Landing-Conversion/1.0' },
        signal: AbortSignal.timeout(20000)
      });
      if (!response.ok) throw new Error('HTTP ' + response.status);
      const data = await response.json();
      const views = Number(data?.views);
      if (!Number.isFinite(views) || views < 0) throw new Error('Invalid views response');
      return views;
    } catch (error) {
      lastError = error;
      if (attempt < 4) await new Promise((resolve) => setTimeout(resolve, attempt * 750));
    }
  }
  throw new Error(`${trackingPath}: ${lastError?.message || 'request failed'}`);
}

const errors = [];
const landings = [];
for (const definition of definitions) {
  let pageViews = null;
  let storyStarts = null;
  try { pageViews = await getViews(definition.pagePath); } catch (error) { errors.push({ path: definition.pagePath, message: error.message }); }
  try { storyStarts = await getViews(definition.startPath); } catch (error) { errors.push({ path: definition.startPath, message: error.message }); }
  landings.push({
    ...definition,
    pageViews,
    storyStarts,
    startRate: rate(storyStarts, pageViews),
    comparisonReady: Number.isFinite(pageViews) && pageViews >= MIN_VIEWS_FOR_COMPARISON
  });
}

const totalLandingViews = landings.reduce((sum, row) => sum + (Number.isFinite(row.pageViews) ? row.pageViews : 0), 0);
const totalStoryStarts = landings.reduce((sum, row) => sum + (Number.isFinite(row.storyStarts) ? row.storyStarts : 0), 0);
const comparisonReady = landings.every((row) => row.comparisonReady);
const actions = [];
if (totalStoryStarts === 0) actions.push('特集からの作品開始はまだ0件のため、開始率の優劣を判断しない。');
if (!comparisonReady) actions.push(`各特集の閲覧が${MIN_VIEWS_FOR_COMPARISON}件に達するまで、特集同士の比較を保留する。`);
if (comparisonReady) actions.push('開始率を比較し、開始率の高い見出し・選定方針を次の特集へ再利用する。');

const report = {
  generatedAt: new Date().toISOString(),
  japanDate: japanDate(),
  success: errors.length === 0,
  definitions: {
    landingView: '特集ページ自体の累計閲覧数',
    storyStart: '特集からいずれかの作品を開いたセッションを、特集単位で1回だけ集計',
    privacy: '開いた作品名、作品URL、検索語、個人識別子は開始集計へ含めない'
  },
  threshold: { minimumViewsPerLanding: MIN_VIEWS_FOR_COMPARISON },
  totals: {
    landingViews: totalLandingViews,
    storyStarts: totalStoryStarts,
    startRate: rate(totalStoryStarts, totalLandingViews)
  },
  comparisonReady,
  actions,
  landings,
  errors
};

const history = readJson(HISTORY, []);
const nextHistory = (Array.isArray(history) ? history : [])
  .filter((row) => row?.date !== report.japanDate)
  .concat({
    date: report.japanDate,
    generatedAt: report.generatedAt,
    totals: report.totals,
    landings: landings.map(({ id, label, pageViews, storyStarts, startRate }) => ({ id, label, pageViews, storyStarts, startRate }))
  })
  .sort((left, right) => left.date.localeCompare(right.date))
  .slice(-180);

fs.writeFileSync(LATEST, JSON.stringify(report, null, 2) + '\n');
fs.writeFileSync(HISTORY, JSON.stringify(nextHistory, null, 2) + '\n');
console.log(`YORUGATARI_LANDING_CONVERSION=${JSON.stringify(report)}`);
if (!report.success) process.exit(1);
