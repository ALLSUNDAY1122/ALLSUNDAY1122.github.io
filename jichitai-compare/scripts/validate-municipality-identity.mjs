import { readdir, readFile, rm, writeFile } from 'node:fs/promises';
import { basename, dirname, extname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const PROJECT_DIR = resolve(SCRIPT_DIR, '..');
const MUNICIPALITY_DIR = join(PROJECT_DIR, 'data', 'municipalities');
const REPORT_FILE = join(PROJECT_DIR, 'identity-validation-errors.json');

const PREFECTURE_NAMES = new Map([
  ['01','北海道'],['02','青森県'],['03','岩手県'],['04','宮城県'],['05','秋田県'],['06','山形県'],['07','福島県'],
  ['08','茨城県'],['09','栃木県'],['10','群馬県'],['11','埼玉県'],['12','千葉県'],['13','東京都'],['14','神奈川県'],
  ['15','新潟県'],['16','富山県'],['17','石川県'],['18','福井県'],['19','山梨県'],['20','長野県'],['21','岐阜県'],
  ['22','静岡県'],['23','愛知県'],['24','三重県'],['25','滋賀県'],['26','京都府'],['27','大阪府'],['28','兵庫県'],
  ['29','奈良県'],['30','和歌山県'],['31','鳥取県'],['32','島根県'],['33','岡山県'],['34','広島県'],['35','山口県'],
  ['36','徳島県'],['37','香川県'],['38','愛媛県'],['39','高知県'],['40','福岡県'],['41','佐賀県'],['42','長崎県'],
  ['43','熊本県'],['44','大分県'],['45','宮崎県'],['46','鹿児島県'],['47','沖縄県']
]);

// municipality-assignment-policy.json / MUNICIPALITY_ASSIGNMENTS.md の西日本担当件数。
const EXPECTED_WEST_COUNTS = new Map([
  ['31',19],['32',19],['33',27],['34',23],['35',19],['36',24],['37',17],['38',20],['39',34],
  ['40',60],['41',20],['42',21],['43',45],['44',18],['45',26],['46',43],['47',41]
]);

const issues = [];

function addIssue(type, message, details = {}) {
  console.error(`ERROR: ${message}`);
  issues.push({ type, message, ...details });
}

function normalizeText(value) {
  return typeof value === 'string' ? value.normalize('NFKC').trim() : '';
}

function normalizeUrl(value) {
  if (typeof value !== 'string' || value.trim() === '') return '';
  try {
    const url = new URL(value.trim());
    url.hash = '';
    if (url.pathname !== '/') url.pathname = url.pathname.replace(/\/+$/u, '');
    return url.toString();
  } catch {
    return value.trim();
  }
}

async function collectJsonFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = [];
  for (const entry of entries.sort((a, b) => a.name.localeCompare(b.name, 'ja'))) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) files.push(...await collectJsonFiles(path));
    else if (entry.isFile() && extname(entry.name) === '.json') files.push(path);
  }
  return files;
}

async function readJson(path) {
  try {
    return JSON.parse(await readFile(path, 'utf8'));
  } catch (cause) {
    addIssue('invalid_json', `${relative(PROJECT_DIR, path)}: JSONを読み込めません: ${cause.message}`);
    return null;
  }
}

function sourceFingerprint(municipality) {
  const urls = Object.values(municipality?.services ?? {})
    .map((service) => normalizeUrl(service?.source?.url))
    .filter(Boolean)
    .sort();
  return urls.length >= 5 ? urls.join('\n') : '';
}

function registerUnique(map, key, record, type, label) {
  if (!key) return;
  const previous = map.get(key);
  if (previous && previous.code !== record.code) {
    addIssue(type, `${label}が重複しています: ${previous.code} ${previous.name} / ${record.code} ${record.name}`, {
      first: previous,
      second: record
    });
    return;
  }
  map.set(key, record);
}

async function main() {
  await rm(REPORT_FILE, { force: true });

  const files = await collectJsonFiles(MUNICIPALITY_DIR);
  const namesByPrefecture = new Map();
  const officialUrls = new Map();
  const sourceFingerprints = new Map();
  const countsByPrefecture = new Map();
  const codesByPrefecture = new Map();

  for (const filePath of files) {
    const municipality = await readJson(filePath);
    if (!municipality) continue;

    const path = relative(PROJECT_DIR, filePath).replaceAll('\\', '/');
    const code = normalizeText(municipality.code);
    const prefectureCode = normalizeText(municipality.prefectureCode);
    const name = normalizeText(municipality.name);
    const prefecture = normalizeText(municipality.prefecture);
    const record = { code, name, path };

    countsByPrefecture.set(prefectureCode, (countsByPrefecture.get(prefectureCode) ?? 0) + 1);
    const codes = codesByPrefecture.get(prefectureCode) ?? [];
    codes.push(code);
    codesByPrefecture.set(prefectureCode, codes);

    if (!/^\d{5}$/u.test(code)) {
      addIssue('invalid_code', `${path}: codeは5桁の数字文字列にしてください`, { record });
      continue;
    }
    if (!/^\d{2}$/u.test(prefectureCode)) addIssue('invalid_prefecture_code', `${path}: prefectureCodeは2桁の数字文字列にしてください`, { record });
    if (code.slice(0, 2) !== prefectureCode) {
      addIssue('code_prefecture_mismatch', `${path}: 自治体コード先頭2桁とprefectureCodeが一致しません`, { code, prefectureCode });
    }
    if (basename(filePath, '.json') !== code) addIssue('filename_code_mismatch', `${path}: ファイル名と自治体コードが一致しません`, { record });
    if (basename(dirname(filePath)) !== prefectureCode) addIssue('directory_prefecture_mismatch', `${path}: 親ディレクトリとprefectureCodeが一致しません`, { record });

    const expectedPrefecture = PREFECTURE_NAMES.get(prefectureCode);
    if (!expectedPrefecture) addIssue('unknown_prefecture', `${path}: 未知の都道府県コードです: ${prefectureCode}`, { record });
    else if (prefecture !== expectedPrefecture) {
      addIssue('prefecture_name_mismatch', `${path}: 都道府県名がコードと一致しません: 期待=${expectedPrefecture}, 実際=${prefecture}`, { record });
    }

    registerUnique(namesByPrefecture, `${prefectureCode}:${name}`, record, 'duplicate_name_in_prefecture', `同一都道府県内の自治体名「${name}」`);
    registerUnique(officialUrls, normalizeUrl(municipality.officialUrl), record, 'duplicate_official_url', `自治体公式URL「${municipality.officialUrl}」`);
    registerUnique(sourceFingerprints, sourceFingerprint(municipality), record, 'duplicate_source_fingerprint', '5制度以上で完全一致する一次情報URL構成');
  }

  for (const [prefectureCode, expected] of EXPECTED_WEST_COUNTS) {
    const actual = countsByPrefecture.get(prefectureCode) ?? 0;
    if (actual !== expected) {
      addIssue('prefecture_count_mismatch', `${prefectureCode} ${PREFECTURE_NAMES.get(prefectureCode)}: 自治体数が割当台帳と一致しません: 期待=${expected}, 実際=${actual}`, {
        prefectureCode,
        expected,
        actual,
        codes: [...(codesByPrefecture.get(prefectureCode) ?? [])].sort()
      });
    }
  }

  if (issues.length > 0) {
    await writeFile(REPORT_FILE, `${JSON.stringify({
      generatedAt: new Date().toISOString(),
      municipalityFileCount: files.length,
      errorCount: issues.length,
      issues
    }, null, 2)}\n`, 'utf8');
    console.error(`自治体識別検証失敗: ${issues.length}件のエラー`);
    process.exitCode = 1;
    return;
  }

  console.log(`自治体識別検証成功: ${files.length}自治体（西日本476自治体の件数、コード・都道府県・名称・URL・source複製を確認）`);
}

main().catch(async (cause) => {
  console.error(cause);
  await writeFile(REPORT_FILE, `${JSON.stringify({ fatal: cause.message }, null, 2)}\n`, 'utf8');
  process.exitCode = 1;
});
