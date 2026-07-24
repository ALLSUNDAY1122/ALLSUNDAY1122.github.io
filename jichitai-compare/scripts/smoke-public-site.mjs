import { readFile } from 'node:fs/promises';

const BASE_URL = 'https://allsunday1122.github.io/jichitai-compare';
const MAX_ATTEMPTS = 40;
const RETRY_DELAY_MS = 15000;
const SAMPLE_MUNICIPALITIES = [
  { code: '01100', name: '札幌市', region: 'north' },
  { code: '13123', name: '江戸川区', region: 'east' },
  { code: '27100', name: '大阪市', region: 'central' },
  { code: '47382', name: '与那国町', region: 'west-b' }
];

const expectedMunicipalities = JSON.parse(
  await readFile(new URL('../data/generated/municipalities.json', import.meta.url), 'utf8')
);
const expectedDefinitions = JSON.parse(
  await readFile(new URL('../data/service-definitions.json', import.meta.url), 'utf8')
);
const expectedPages = JSON.parse(
  await readFile(new URL('../data/generated/municipality-pages.json', import.meta.url), 'utf8')
);

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical);
  if (value === null || typeof value !== 'object') return value;
  return Object.fromEntries(
    Object.entries(value)
      .sort(([left], [right]) => left.localeCompare(right))
      .map(([key, child]) => [key, canonical(child)])
  );
}

function sameJson(left, right) {
  return JSON.stringify(canonical(left)) === JSON.stringify(canonical(right));
}

async function fetchResource(path, kind = 'text') {
  const response = await fetch(`${BASE_URL}${path}`, {
    headers: { 'cache-control': 'no-cache' },
    redirect: 'follow'
  });
  if (!response.ok) throw new Error(`${path}: HTTP ${response.status}`);
  return kind === 'json' ? await response.json() : await response.text();
}

async function verifyPublishedSite() {
  const [
    [html, appJs, municipalities, definitions, aboutPage, privacyPage, sitemap],
    samplePages
  ] = await Promise.all([
    Promise.all([
      fetchResource('/'),
      fetchResource('/app.js'),
      fetchResource('/data/generated/municipalities.json', 'json'),
      fetchResource('/data/service-definitions.json', 'json'),
      fetchResource('/about/'),
      fetchResource('/privacy/'),
      fetchResource('/sitemap.xml')
    ]),
    Promise.all(
      SAMPLE_MUNICIPALITIES.map(async (sample) => ({
        ...sample,
        html: await fetchResource(`/municipality/${sample.code}/`)
      }))
    )
  ]);

  assert(html.includes('app.js'), '公開HTMLから app.js を確認できません');
  assert(html.includes('1741自治体・9制度'), '公開HTMLの全国件数表示が不正です');
  assert(html.includes('./about/'), '公開HTMLに運営方針へのリンクがありません');
  assert(html.includes('./privacy/'), '公開HTMLにプライバシーへのリンクがありません');
  assert(
    appJs.includes('./data/generated/municipalities.json'),
    '公開app.jsが生成済みJSONを参照していません'
  );
  assert(
    appJs.includes('./municipality/'),
    '公開app.jsに自治体別ページへの導線がありません'
  );
  assert(
    !appJs.includes('制度なし・対象外'),
    '公開app.jsにunavailableの旧誤表示が残っています'
  );
  assert(
    sameJson(municipalities, expectedMunicipalities),
    '公開自治体JSONがmainの生成済みJSONと一致しません'
  );
  assert(
    sameJson(definitions, expectedDefinitions),
    '公開制度定義JSONがmainの制度定義と一致しません'
  );

  const serviceCount = definitions.services.length;
  for (const municipality of municipalities.municipalities) {
    assert(
      Object.keys(municipality.services ?? {}).length === serviceCount,
      `${municipality.code}: 制度数が${serviceCount}件ではありません`
    );
  }

  for (const sample of samplePages) {
    const expectedCanonical = `${BASE_URL}/municipality/${sample.code}/`;
    const label = `${sample.region}:${sample.code} ${sample.name}`;
    assert(sample.html.includes(`<h1>${sample.name}</h1>`), `${label}: 公開自治体ページのh1が不正です`);
    assert(
      sample.html.includes(`<link rel="canonical" href="${expectedCanonical}">`),
      `${label}: 公開自治体ページのcanonicalが不正です`
    );
    assert(sample.html.includes('自治体公式情報'), `${label}: 公開自治体ページに公式情報リンクがありません`);
    assert(!sample.html.includes('制度なし・対象外'), `${label}: 公開自治体ページに旧誤表示が残っています`);
    assert(
      sitemap.includes(`<loc>${expectedCanonical}</loc>`),
      `${label}: 公開sitemapに自治体ページがありません`
    );
  }

  assert(aboutPage.includes('<h1>運営・情報掲載方針</h1>'), '運営方針ページを確認できません');
  assert(privacyPage.includes('<h1>プライバシーポリシー</h1>'), 'プライバシーページを確認できません');

  const sitemapCount = (sitemap.match(/<url>/gu) ?? []).length;
  const expectedSitemapCount = expectedPages.municipalityCount + 3;
  assert(
    sitemapCount === expectedSitemapCount,
    `公開sitemap件数が不正です: ${sitemapCount}/${expectedSitemapCount}`
  );

  return {
    municipalityCount: municipalities.municipalities.length,
    serviceCount,
    staticPageCount: expectedPages.municipalityCount,
    sitemapCount,
    sampleCount: samplePages.length
  };
}

let lastError;
for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt += 1) {
  try {
    const result = await verifyPublishedSite();
    console.log(
      `公開確認成功: ${result.municipalityCount}自治体・各${result.serviceCount}制度・個別${result.staticPageCount}ページ・代表${result.sampleCount}自治体・sitemap ${result.sitemapCount} URL`
    );
    process.exit(0);
  } catch (error) {
    lastError = error;
    console.warn(`[${attempt}/${MAX_ATTEMPTS}] ${error.message}`);
    if (attempt < MAX_ATTEMPTS) await sleep(RETRY_DELAY_MS);
  }
}

throw new Error(`公開確認に失敗しました: ${lastError?.message ?? 'unknown error'}`);
