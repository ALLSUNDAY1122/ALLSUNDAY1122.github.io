const BASE_URL = 'https://allsunday1122.github.io/jichitai-compare';
const EXPECTED_CODES = ['12203', '12227', '13123'];
const EXPECTED_SERVICE_COUNT = 9;
const MAX_ATTEMPTS = 40;
const RETRY_DELAY_MS = 15000;

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function fetchWithRetry(path, kind = 'text') {
  const url = `${BASE_URL}${path}`;
  let lastError;

  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt += 1) {
    try {
      const response = await fetch(url, {
        headers: { 'cache-control': 'no-cache' },
        redirect: 'follow'
      });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      return kind === 'json' ? await response.json() : await response.text();
    } catch (error) {
      lastError = error;
      console.warn(`[${attempt}/${MAX_ATTEMPTS}] ${url}: ${error.message}`);
      if (attempt < MAX_ATTEMPTS) await sleep(RETRY_DELAY_MS);
    }
  }

  throw new Error(`${url} の取得に失敗しました: ${lastError?.message ?? 'unknown error'}`);
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const [html, appJs, municipalities, definitions] = await Promise.all([
  fetchWithRetry('/'),
  fetchWithRetry('/app.js'),
  fetchWithRetry('/data/generated/municipalities.json', 'json'),
  fetchWithRetry('/data/service-definitions.json', 'json')
]);

assert(html.includes('app.js'), '公開HTMLから app.js を確認できません');
assert(appJs.includes('./data/generated/municipalities.json'), '公開app.jsが生成済みJSONを参照していません');
assert(Array.isArray(municipalities.municipalities), '公開自治体JSONの形式が不正です');
assert(municipalities.meta?.municipalityCount === EXPECTED_CODES.length, '公開自治体数が3件ではありません');

const codes = municipalities.municipalities.map((item) => item.code);
assert(JSON.stringify(codes) === JSON.stringify(EXPECTED_CODES), `自治体コード順が不正です: ${codes.join(',')}`);

for (const municipality of municipalities.municipalities) {
  assert(Object.keys(municipality.services ?? {}).length === EXPECTED_SERVICE_COUNT, `${municipality.code}: 制度数が9件ではありません`);
}

assert(Array.isArray(definitions.services), '公開制度定義の形式が不正です');
assert(definitions.services.length === EXPECTED_SERVICE_COUNT, '公開制度定義数が9件ではありません');

console.log(`公開確認成功: ${codes.join(', ')} / 各${EXPECTED_SERVICE_COUNT}制度`);
