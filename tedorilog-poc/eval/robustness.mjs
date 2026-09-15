// 追加検証: 固定コーパスへ人工的なOCR劣化を注入し、精度と安全性の落ち方を見る。
//
// 固定コーパスだけで調整するとルールがそのコーパスへ過剰適合しうる。
// 「もっと読み取りが悪い端末・環境」を想定した劣化を乱数で与え、
//   - 正しく提示できる項目数がどこまで落ちるか
//   - 誤った値を「確定候補」として出してしまわないか（安全性）
// を測る。
//
// 使い方: node eval/robustness.mjs [試行回数] [劣化強度(0-1)]

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { extractPayslipBest } from '../engine/extract.js';
import { ITEM_KEYS } from '../engine/lexicon.js';
import { loadCases } from './run_eval.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// 決定的な擬似乱数（結果を再現できるようにする）
function makeRandom(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 4294967296;
  };
}

const CONFUSABLE_DIGITS = { 0: '96', 1: '74', 2: '73', 3: '85', 4: '91', 5: '68', 6: '58', 7: '12', 8: '36', 9: '04' };
const CONFUSABLE_KANA = '口日目田巳己力刀夕タ二ニハ八';

function perturbTokens(tokens, rnd, strength) {
  const out = [];
  for (const token of tokens) {
    if (rnd() < 0.03 * strength) continue; // トークン欠落
    let text = token.text;
    text = text.replace(/\d/g, (d) => {
      if (rnd() >= 0.05 * strength) return d;
      const alts = CONFUSABLE_DIGITS[d] || '0';
      return alts[Math.floor(rnd() * alts.length)];
    });
    if (/[一-鿿ァ-ヿ]/.test(text) && rnd() < 0.12 * strength) {
      const i = Math.floor(rnd() * text.length);
      text = text.slice(0, i) + CONFUSABLE_KANA[Math.floor(rnd() * CONFUSABLE_KANA.length)] + text.slice(i + 1);
    }
    const jitter = (token.h || 10) * 0.12 * strength;
    out.push({
      ...token,
      text,
      x: token.x + (rnd() - 0.5) * jitter,
      y: token.y + (rnd() - 0.5) * jitter,
      conf: Math.max(0.05, (token.conf ?? 1) - rnd() * 0.25 * strength),
    });
  }
  return out;
}

function main() {
  const trials = Number(process.argv[2] || 200);
  const strength = Number(process.argv[3] || 1);
  const cases = loadCases();
  const rnd = makeRandom(20260812);

  let totalCorrect = 0;
  let totalItems = 0;
  let silentWrong = 0;
  let crashes = 0;
  let runs = 0;
  const perCase = new Map();

  for (let t = 0; t < trials; t++) {
    for (const entry of cases) {
      const variants = entry.tokens.variants.map((v) => ({
        name: v.name,
        tokens: perturbTokens(v.tokens, rnd, strength),
      }));
      let result;
      try {
        result = extractPayslipBest(variants, { route: entry.tokens.route });
      } catch (err) {
        crashes += 1;
        continue;
      }
      runs += 1;
      let correct = 0;
      for (const key of ITEM_KEYS) {
        const item = result.items[key];
        totalItems += 1;
        if (item.value !== null && item.value === entry.truth[key]) {
          correct += 1;
          totalCorrect += 1;
        } else if (item.value !== null && item.status === 'confident') {
          silentWrong += 1;
        }
      }
      const stat = perCase.get(entry.meta.id) || { correct: 0, runs: 0, pass: 0 };
      stat.correct += correct;
      stat.runs += 1;
      if (correct >= 7) stat.pass += 1;
      perCase.set(entry.meta.id, stat);
    }
  }

  const summary = {
    trials,
    strength,
    runs,
    avgCorrectPerSlip: Number((totalCorrect / runs).toFixed(2)),
    itemAccuracy: Number((totalCorrect / totalItems).toFixed(4)),
    silentWrong,
    silentWrongRate: Number((silentWrong / totalItems).toFixed(5)),
    crashes,
    perCase: Object.fromEntries(
      [...perCase.entries()].map(([id, s]) => [id, {
        avgCorrect: Number((s.correct / s.runs).toFixed(2)),
        passRate: Number((s.pass / s.runs).toFixed(3)),
      }]),
    ),
  };

  console.log(`劣化注入テスト: ${runs} 回（${trials}試行 × ${cases.length}形式）強度=${strength}`);
  console.log(`  1明細あたり平均正解項目数: ${summary.avgCorrectPerSlip}/9`);
  console.log(`  項目正解率: ${(summary.itemAccuracy * 100).toFixed(1)}%`);
  console.log(`  誤った値を確定候補にした件数: ${silentWrong}（${(summary.silentWrongRate * 100).toFixed(3)}%）`);
  console.log(`  クラッシュ: ${crashes}`);
  for (const [id, s] of Object.entries(summary.perCase)) {
    console.log(`  ${id}: 平均 ${s.avgCorrect}/9  7項目以上の達成率 ${(s.passRate * 100).toFixed(0)}%`);
  }
  fs.writeFileSync(path.join(__dirname, 'robustness.json'), JSON.stringify(summary, null, 2));
  return summary;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}
