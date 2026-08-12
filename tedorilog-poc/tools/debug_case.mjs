// 1ケースの行構造・ラベル判定・金額判定をダンプする調査用ツール。
// 使い方: node tools/debug_case.mjs case07
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildLayout } from '../engine/layout.js';
import { matchItemLabel, matchTotalLabel, isOtherDeduction } from '../engine/lexicon.js';
import { parseAmount } from '../engine/normalize.js';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const id = process.argv[2];
if (!id) {
  console.error('usage: node tools/debug_case.mjs <caseId>');
  process.exit(1);
}
const data = JSON.parse(fs.readFileSync(path.join(ROOT, 'fixtures', 'cases', `${id}.tokens.json`), 'utf8'));
const layout = buildLayout(data.tokens);
console.log(`route=${data.route} slope=${layout.slope} medianHeight=${layout.medianHeight} rows=${layout.rows.length}`);
for (const row of layout.rows) {
  const parts = row.tokens.map((t) => {
    const amount = parseAmount(t.text);
    const digitRatio = (t.text.match(/\d/g) || []).length / t.text.length;
    if (amount && digitRatio >= 0.5) return `${t.text} [金額 ${amount.value} conf=${amount.confidence.toFixed(2)} ocr=${(t.conf ?? 1).toFixed(2)}]`;
    const total = matchTotalLabel(t.text);
    if (total) return `${t.text} [合計:${total.key} ${total.score.toFixed(2)}]`;
    const item = matchItemLabel(t.text);
    if (item) return `${t.text} [${item.key} ${item.score.toFixed(2)}${item.loose ? ' loose' : ''}]`;
    if (isOtherDeduction(t.text)) return `${t.text} [その他控除]`;
    return `${t.text} [-]`;
  });
  console.log(String(row.index).padStart(3), parts.join('   ||   '));
}
