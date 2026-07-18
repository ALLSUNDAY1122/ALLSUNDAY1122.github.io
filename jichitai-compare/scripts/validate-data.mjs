import { readFile } from 'node:fs/promises';

const raw = await readFile(new URL('../data/municipalities.json', import.meta.url), 'utf8');
const data = JSON.parse(raw);
const requiredMunicipalityFields = ['code', 'prefectureCode', 'prefecture', 'name', 'officialUrl', 'childMedical', 'sickChildCare'];
const seen = new Set();
let errors = 0;

for (const municipality of data.municipalities ?? []) {
  for (const field of requiredMunicipalityFields) {
    if (!(field in municipality)) {
      console.error(`${municipality.name ?? '(名称なし)'}: ${field} がありません`);
      errors += 1;
    }
  }
  if (seen.has(municipality.code)) {
    console.error(`自治体コードが重複しています: ${municipality.code}`);
    errors += 1;
  }
  seen.add(municipality.code);
  for (const url of [municipality.officialUrl, municipality.childMedical?.sourceUrl, municipality.sickChildCare?.sourceUrl]) {
    if (url && !url.startsWith('https://')) {
      console.error(`${municipality.name}: URLはhttps://で始めてください: ${url}`);
      errors += 1;
    }
  }
}

if (errors) process.exit(1);
console.log(`${data.municipalities.length}自治体のデータ検証に成功しました。`);
