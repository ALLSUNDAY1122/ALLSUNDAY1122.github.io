import { readFile, writeFile } from 'node:fs/promises';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const PROJECT_DIR = resolve(SCRIPT_DIR, '..');
const PROGRESS_FILE = join(PROJECT_DIR, 'operations', 'progress.json');
const INDEX_FILE = join(PROJECT_DIR, 'index.html');

const progress = JSON.parse(await readFile(PROGRESS_FILE, 'utf8'));
const count = progress.registeredMunicipalities;
if (!Number.isInteger(count) || count < 1) {
  throw new Error(`registeredMunicipalitiesが不正です: ${count}`);
}

const source = await readFile(INDEX_FILE, 'utf8');
const heroPattern = /\d+自治体・9制度/gu;
const descriptionPattern = /登録状況：\d+自治体の生成データを公開中/gu;

if (!heroPattern.test(source)) {
  throw new Error('トップページの比較対象件数表記を検出できません。');
}
heroPattern.lastIndex = 0;
if (!descriptionPattern.test(source)) {
  throw new Error('トップページの登録状況表記を検出できません。');
}
descriptionPattern.lastIndex = 0;

const updated = source
  .replace(heroPattern, `${count}自治体・9制度`)
  .replace(descriptionPattern, `登録状況：${count}自治体の生成データを公開中`);

await writeFile(INDEX_FILE, updated, 'utf8');
console.log(`${relative(PROJECT_DIR, INDEX_FILE)}の自治体件数を${count}件へ同期しました。`);
