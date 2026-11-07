// Swift移植版との一致確認用に、JS版エンジンの出力を固定ファイルへ書き出す。
// 使い方: node tools/export_golden.mjs
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { extractPayslipBest } from '../engine/extract.js';
import { ITEM_KEYS } from '../engine/lexicon.js';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const HOLDOUT = path.resolve(ROOT, '../native-ios/TedoriLogInput/Fixtures/holdout');
const manifest = JSON.parse(fs.readFileSync(path.join(HOLDOUT, 'manifest.json'), 'utf8'));

const golden = {};
for (const c of manifest.cases) {
  const tokens = JSON.parse(fs.readFileSync(path.join(HOLDOUT, `${c.id}.tokens.json`), 'utf8'));
  const result = extractPayslipBest(tokens.variants, { route: tokens.route });
  golden[c.id] = {
    variant: result.variant,
    items: Object.fromEntries(ITEM_KEYS.map((k) => [k, {
      value: result.items[k].value,
      status: result.items[k].status,
    }])),
    totals: { gross: result.totals.gross, deduction: result.totals.deduction },
  };
}
const out = path.join(HOLDOUT, 'golden_js.json');
fs.writeFileSync(out, JSON.stringify(golden, null, 1));
console.log(`golden_js.json を書き出しました (${Object.keys(golden).length}件)`);
