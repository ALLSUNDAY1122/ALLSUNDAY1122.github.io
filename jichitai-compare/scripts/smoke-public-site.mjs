import { readFile } from 'node:fs/promises';

const BASE_URL = 'https://allsunday1122.github.io/jichitai-compare';
const MAX_ATTEMPTS = 40;
const RETRY_DELAY_MS = 15000;

const expectedMunicipalities = JSON.parse(
  await readFile(new URL('../data/generated/municipalities.json', import.meta.url), 'utf8')
);
const expectedDefinitions = JSON.parse(
  await readFile(new URL('../data/service-definitions.json', import.meta.url), 'utf8')
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
  const [html, appJs, municipalities, definitions] = await Promise.all([
    fetchResource('/'),
    fetchResource('/app.js'),
    fetchResource('/data/generated/municipalities.json', 'json'),
    fetchResource('/data/service-definitions.json', 'json')
  ]);

  assert(html.includes('app.js'), '公開HTMLから app.js を確認できません');
  assert(
    appJs.includes('./data/generated/municipalities.json'),
    '公開app.jsが生成済みJSONを参照していません'
  );
  assert(
    sameJson(municipalities, expectedMunicipalities),
    '公開自治体JSONがmainの生成済みJSONと一致しません'
  );
  assert(
    sameJson(definitions, expectedDefinitions),
    '公開制度定義JSONがmainの制度定義と一致しません'
  );

  const codes = municipalities.municipalities.map((item) => item.code);
  const serviceCount = definitions.services.length;
  for (const municipality of municipalities.municipalities) {
    assert(
      Object.keys(municipality.services ?? {}).length === serviceCount,
      `${municipality.code}: 制度数が${serviceCount}件ではありません`
    );
  }

  return { codes, serviceCount };
}

let lastError;
for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt += 1) {
  try {
    const result = await verifyPublishedSite();
    console.log(`公開確認成功: ${result.codes.join(', ')} / 各${result.serviceCount}制度`);
    process.exit(0);
  } catch (error) {
    lastError = error;
    console.warn(`[${attempt}/${MAX_ATTEMPTS}] ${error.message}`);
    if (attempt < MAX_ATTEMPTS) await sleep(RETRY_DELAY_MS);
  }
}

throw new Error(`公開確認に失敗しました: ${lastError?.message ?? 'unknown error'}`);
