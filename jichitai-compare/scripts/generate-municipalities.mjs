import { mkdir, readdir, readFile, rename, writeFile } from 'node:fs/promises';
import { basename, dirname, extname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const PROJECT_DIR = resolve(SCRIPT_DIR, '..');
const SOURCE_DIR = join(PROJECT_DIR, 'data', 'municipalities');
const OUTPUT_FILE = join(PROJECT_DIR, 'data', 'generated', 'municipalities.json');
const REQUIRED_SERVICES = [
  'childMedical',
  'sickChildCare',
  'childcareFee',
  'schoolMeals',
  'postpartumCare',
  'temporaryChildcare',
  'housingSupport',
  'bulkyWaste',
  'disasterPrevention'
];

function fail(message) {
  throw new Error(message);
}

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

async function collectJsonFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = [];

  for (const entry of entries.sort((a, b) => a.name.localeCompare(b.name, 'ja'))) {
    const fullPath = join(directory, entry.name);
    if (entry.isDirectory()) {
      files.push(...await collectJsonFiles(fullPath));
    } else if (entry.isFile() && extname(entry.name) === '.json') {
      files.push(fullPath);
    }
  }

  return files;
}

function validateMunicipality(municipality, filePath, seenCodes) {
  const relativePath = relative(PROJECT_DIR, filePath).replaceAll('\\', '/');
  if (!isPlainObject(municipality)) fail(`${relativePath}: JSONのルートはオブジェクトにしてください。`);

  const requiredFields = [
    'schemaVersion',
    'code',
    'prefectureCode',
    'prefecture',
    'name',
    'officialUrl',
    'status',
    'summary',
    'updatedAt',
    'services'
  ];
  for (const field of requiredFields) {
    if (!(field in municipality)) fail(`${relativePath}: ${field} がありません。`);
  }

  if (!/^\d{5}$/.test(municipality.code)) fail(`${relativePath}: codeは5桁の数字文字列にしてください。`);
  if (!/^\d{2}$/.test(municipality.prefectureCode)) fail(`${relativePath}: prefectureCodeは2桁の数字文字列にしてください。`);
  if (basename(filePath, '.json') !== municipality.code) fail(`${relativePath}: ファイル名と自治体コードが一致しません。`);
  if (basename(dirname(filePath)) !== municipality.prefectureCode) fail(`${relativePath}: 親ディレクトリと都道府県コードが一致しません。`);
  if (seenCodes.has(municipality.code)) fail(`${relativePath}: 自治体コードが重複しています: ${municipality.code}`);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(municipality.updatedAt)) fail(`${relativePath}: updatedAtはYYYY-MM-DD形式にしてください。`);
  if (!isPlainObject(municipality.services)) fail(`${relativePath}: servicesはオブジェクトにしてください。`);

  const serviceIds = Object.keys(municipality.services);
  for (const serviceId of REQUIRED_SERVICES) {
    if (!serviceIds.includes(serviceId)) fail(`${relativePath}: services.${serviceId} がありません。`);
  }
  for (const serviceId of serviceIds) {
    if (!REQUIRED_SERVICES.includes(serviceId)) fail(`${relativePath}: 未定義の制度IDがあります: ${serviceId}`);
  }

  seenCodes.add(municipality.code);
}

function toPublicMunicipality(municipality) {
  const {
    schemaVersion: _schemaVersion,
    updatedAt: _updatedAt,
    ...publicData
  } = municipality;
  return publicData;
}

async function main() {
  const files = await collectJsonFiles(SOURCE_DIR);
  if (!files.length) fail('自治体別JSONが見つかりません。');

  const seenCodes = new Set();
  const sourceMunicipalities = [];

  for (const filePath of files) {
    let municipality;
    try {
      municipality = JSON.parse(await readFile(filePath, 'utf8'));
    } catch (error) {
      fail(`${relative(PROJECT_DIR, filePath)}: JSONを読み込めません: ${error.message}`);
    }
    validateMunicipality(municipality, filePath, seenCodes);
    sourceMunicipalities.push(municipality);
  }

  sourceMunicipalities.sort((a, b) => a.code.localeCompare(b.code));
  const updatedAt = sourceMunicipalities
    .map((municipality) => municipality.updatedAt)
    .sort()
    .at(-1);

  const generated = {
    meta: {
      version: '1.0.0',
      updatedAt,
      municipalityCount: sourceMunicipalities.length,
      disclaimer: '制度の正式な対象可否は各自治体へ確認してください。'
    },
    municipalities: sourceMunicipalities.map(toPublicMunicipality)
  };

  const output = `${JSON.stringify(generated, null, 2)}\n`;
  await mkdir(dirname(OUTPUT_FILE), { recursive: true });
  const temporaryFile = `${OUTPUT_FILE}.tmp`;
  await writeFile(temporaryFile, output, 'utf8');
  await rename(temporaryFile, OUTPUT_FILE);

  console.log(`${sourceMunicipalities.length}自治体の公開用JSONを生成しました: ${relative(PROJECT_DIR, OUTPUT_FILE)}`);
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
