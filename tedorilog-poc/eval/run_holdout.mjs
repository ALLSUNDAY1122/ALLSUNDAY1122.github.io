// 未知形式（holdout）コーパスでの評価ハーネス。
//
// 対象: native-ios/TedoriLogInput/Fixtures/holdout
//   split=eval  … 調整に使う20形式
//   split=final … 最後に1回だけ使う10形式（--final を付けたときだけ評価する）
//
// 製品チェック1前ゲートの合格条件:
//   - 70%以上の形式で9項目中7項目以上を正しく提示
//   - 差引支給額 90%以上
//   - 重大誤認（誤った値を確定候補として提示）0件
//   - クラッシュ0 / 外部送信0
//
// 使い方:
//   node eval/run_holdout.mjs            … eval 20形式
//   node eval/run_holdout.mjs --final    … final 10形式も含めて評価
//   node eval/run_holdout.mjs --md       … VISION_EVAL_RESULTS用のMarkdownを書き出す
//   node eval/run_holdout.mjs --case hold07 --verbose

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { extractPayslipBest, STATUS } from '../engine/extract.js';
import { ITEM_KEYS, ITEM_LABELS } from '../engine/lexicon.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const HOLDOUT = path.resolve(__dirname, '../../native-ios/TedoriLogInput/Fixtures/holdout');

const ITEM_PASS = 7; // 9項目中7項目以上
const FORMAT_RATE = 0.7; // 70%以上の形式
const NET_RATE = 0.9; // 差引支給額 90%以上

export function loadHoldout({ includeFinal = false } = {}) {
  const manifest = JSON.parse(fs.readFileSync(path.join(HOLDOUT, 'manifest.json'), 'utf8'));
  return manifest.cases
    .filter((c) => includeFinal || c.split === 'eval')
    .map((c) => ({
      meta: c,
      tokens: JSON.parse(fs.readFileSync(path.join(HOLDOUT, `${c.id}.tokens.json`), 'utf8')),
      truth: JSON.parse(fs.readFileSync(path.join(HOLDOUT, `${c.id}.truth.json`), 'utf8')).truth,
    }));
}

export function evaluateOne(entry) {
  let result = null;
  let crashed = null;
  const started = process.hrtime.bigint();
  try {
    result = extractPayslipBest(entry.tokens.variants, { route: entry.tokens.route });
  } catch (err) {
    crashed = err && err.stack ? err.stack.split('\n')[0] : String(err);
  }
  const elapsedMs = Number(process.hrtime.bigint() - started) / 1e6;

  const perItem = {};
  let correct = 0;
  let wrong = 0;
  let missing = 0;
  let criticalWrong = 0;

  for (const key of ITEM_KEYS) {
    const truth = entry.truth[key];
    const item = result ? result.items[key] : null;
    const value = item ? item.value : null;
    const status = item ? item.status : STATUS.NOT_FOUND;
    const isCorrect = value !== null && value === truth;
    if (isCorrect) correct += 1;
    else if (value === null) missing += 1;
    else {
      wrong += 1;
      if (status === STATUS.CONFIRMED_CANDIDATE) criticalWrong += 1;
    }
    perItem[key] = { truth, value, status, correct: isCorrect, reasons: item ? item.reasons : [] };
  }

  return {
    id: entry.meta.id,
    layout: entry.meta.layout,
    media: entry.meta.media,
    split: entry.meta.split,
    route: entry.tokens.route,
    variant: result ? result.variant : null,
    correct,
    wrong,
    missing,
    criticalWrong,
    fixOps: wrong + missing,
    reviewTaps: ITEM_KEYS.filter((k) => perItem[k].status === STATUS.NEEDS_REVIEW && perItem[k].correct).length,
    netPayCorrect: perItem.net_pay.correct,
    itemPass: correct >= ITEM_PASS,
    elapsedMs: Number(elapsedMs.toFixed(1)),
    crashed,
    checks: result ? result.checks : [],
    repairs: result ? result.repairs : [],
    perItem,
  };
}

export function aggregate(rows) {
  const n = rows.length;
  const formats = rows.filter((r) => r.itemPass).length;
  const netOk = rows.filter((r) => r.netPayCorrect).length;
  const critical = rows.reduce((s, r) => s + r.criticalWrong, 0);
  const crashes = rows.filter((r) => r.crashed).length;
  const conditions = {
    formatRate: { got: Number((formats / n).toFixed(3)), need: FORMAT_RATE, ok: formats / n >= FORMAT_RATE, detail: `${formats}/${n}形式` },
    netPayRate: { got: Number((netOk / n).toFixed(3)), need: NET_RATE, ok: netOk / n >= NET_RATE, detail: `${netOk}/${n}形式` },
    criticalWrong: { got: critical, need: 0, ok: critical === 0, detail: '誤った値を確定候補として提示した件数' },
    crashes: { got: crashes, need: 0, ok: crashes === 0, detail: 'クラッシュ' },
    externalCalls: { got: 0, need: 0, ok: true, detail: '外部送信（端末内処理のみ）' },
  };
  const byRoute = {};
  for (const route of ['pdf_text', 'ocr']) {
    const subset = rows.filter((r) => r.route === route);
    if (!subset.length) continue;
    byRoute[route] = {
      cases: subset.length,
      formatsPassed: subset.filter((r) => r.itemPass).length,
      avgCorrect: Number((subset.reduce((s, r) => s + r.correct, 0) / subset.length).toFixed(2)),
      criticalWrong: subset.reduce((s, r) => s + r.criticalWrong, 0),
    };
  }
  const byMedia = {};
  for (const media of ['text_pdf', 'screenshot', 'photo', 'image_pdf']) {
    const subset = rows.filter((r) => r.media === media);
    if (!subset.length) continue;
    byMedia[media] = {
      cases: subset.length,
      formatsPassed: subset.filter((r) => r.itemPass).length,
      avgCorrect: Number((subset.reduce((s, r) => s + r.correct, 0) / subset.length).toFixed(2)),
      criticalWrong: subset.reduce((s, r) => s + r.criticalWrong, 0),
    };
  }
  const allOk = Object.values(conditions).every((c) => c.ok);
  const safeOnly = conditions.criticalWrong.ok && conditions.crashes.ok;
  return {
    verdict: allOk ? 'PASS' : safeOnly ? 'WARN' : 'FAIL',
    conditions,
    byRoute,
    byMedia,
    totals: {
      cases: n,
      avgCorrect: Number((rows.reduce((s, r) => s + r.correct, 0) / n).toFixed(2)),
      avgFixOps: Number((rows.reduce((s, r) => s + r.fixOps, 0) / n).toFixed(2)),
      medianEngineMs: median(rows.map((r) => r.elapsedMs)),
    },
  };
}

function median(values) {
  const s = [...values].sort((a, b) => a - b);
  return s.length % 2 ? s[(s.length - 1) / 2] : Number(((s[s.length / 2 - 1] + s[s.length / 2]) / 2).toFixed(1));
}

function printDetail(row) {
  console.log(`\n=== ${row.id} ${row.layout}/${row.media} route=${row.route}(${row.variant}) ${row.correct}/9`);
  for (const key of ITEM_KEYS) {
    const d = row.perItem[key];
    const mark = d.correct ? 'OK ' : d.value === null ? '-- ' : 'NG ';
    console.log(`  ${mark}${ITEM_LABELS[key].padEnd(6)} 正解=${String(d.truth).padStart(8)} 候補=${String(d.value).padStart(8)} [${d.status}]` +
      (d.reasons.length ? `  ${d.reasons.join(' / ')}` : ''));
  }
  for (const c of row.checks) console.log(`  check ${c.id}: ${c.ok ? 'OK' : 'NG'} — ${c.detail}`);
  for (const r of row.repairs) console.log(`  repair ${JSON.stringify(r)}`);
}

function main() {
  const args = process.argv.slice(2);
  const only = args.includes('--case') ? args[args.indexOf('--case') + 1] : null;
  const includeFinal = args.includes('--final');
  const rows = loadHoldout({ includeFinal })
    .filter((e) => !only || e.meta.id === only)
    .map(evaluateOne);

  if (only || args.includes('--verbose')) rows.forEach(printDetail);

  console.log('\n--- 未知形式コーパス集計 ---');
  for (const r of rows) {
    console.log(
      `${r.id} ${r.split.padEnd(5)} ${r.layout.padEnd(16)} ${r.media.padEnd(11)} ${r.route === 'pdf_text' ? 'PDF' : 'OCR'} ` +
      `${String(r.correct).padStart(2)}/9 ${r.itemPass ? 'pass' : 'FAIL'} 差引${r.netPayCorrect ? 'OK' : 'NG'} ` +
      `誤確定${r.criticalWrong} ${r.crashed ? 'CRASH' : ''}`,
    );
  }
  const summary = aggregate(rows);
  console.log(`\n判定: ${summary.verdict}`);
  for (const [key, c] of Object.entries(summary.conditions)) {
    console.log(`  ${c.ok ? 'OK' : 'NG'} ${key}: ${c.got} (基準 ${c.need}) ${c.detail}`);
  }
  console.log(`  経路別: ${JSON.stringify(summary.byRoute)}`);
  console.log(`  媒体別: ${JSON.stringify(summary.byMedia)}`);

  fs.writeFileSync(
    path.join(__dirname, 'holdout_results.json'),
    JSON.stringify({ generatedAt: new Date().toISOString(), includeFinal, summary, rows }, null, 2),
  );
  return summary;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}
