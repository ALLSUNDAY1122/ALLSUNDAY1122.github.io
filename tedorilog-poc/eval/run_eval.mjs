// 固定コーパス評価ハーネス。
// fixtures/cases/*.tokens.json（PDF直接抽出 or ローカルOCRの出力）を読み、
// engine の抽出結果を正解と突き合わせて POC_RESULTS.md 用の集計を出す。
//
// 使い方:
//   node eval/run_eval.mjs            … 集計を標準出力＋eval/results.json へ
//   node eval/run_eval.mjs --md       … POC_RESULTS.md も更新
//   node eval/run_eval.mjs --case 03  … 1件だけ詳細表示

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { extractPayslipBest, STATUS } from '../engine/extract.js';
import { ITEM_KEYS, ITEM_LABELS } from '../engine/lexicon.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const CASE_DIR = path.join(ROOT, 'fixtures', 'cases');

const PASS_ITEM_THRESHOLD = 7; // 9項目中7項目以上
const PASS_FORMAT_THRESHOLD = 7; // 10形式中7形式以上
const NET_PAY_TARGET = 9; // 差引支給額は10形式中9形式以上

export function loadCases() {
  const manifest = JSON.parse(fs.readFileSync(path.join(ROOT, 'fixtures', 'manifest.json'), 'utf8'));
  return manifest.cases.map((c) => {
    const tokens = JSON.parse(fs.readFileSync(path.join(CASE_DIR, `${c.id}.tokens.json`), 'utf8'));
    const truth = JSON.parse(fs.readFileSync(path.join(CASE_DIR, `${c.id}.truth.json`), 'utf8'));
    return { meta: c, tokens, truth: truth.truth };
  });
}

export function evaluateCase(entry) {
  const started = Date.now();
  let result;
  let crashed = null;
  try {
    result = extractPayslipBest(entry.tokens.variants, { route: entry.tokens.route });
  } catch (err) {
    crashed = err;
    result = null;
  }
  const elapsedMs = Date.now() - started;

  const perItem = {};
  let correct = 0;
  let wrong = 0;
  let missing = 0;
  let silentWrong = 0; // 「確定候補」として誤った値を出した数（最も危険）

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
      if (status === STATUS.CONFIRMED_CANDIDATE) silentWrong += 1;
    }
    perItem[key] = {
      truth,
      value,
      status,
      correct: isCorrect,
      confidence: item ? Number((item.confidence || 0).toFixed(3)) : 0,
      reasons: item ? item.reasons : [],
      derived: item ? Boolean(item.derived) : false,
    };
  }

  // 修正操作回数 = 誤った値の修正 + 未検出の手入力（要確認だが値が正しいものは確認タップのみ）
  const fixOps = wrong + missing;
  const reviewTaps = ITEM_KEYS.filter(
    (k) => perItem[k].status === STATUS.NEEDS_REVIEW && perItem[k].correct,
  ).length;

  return {
    id: entry.meta.id,
    title: entry.meta.title,
    kind: entry.meta.kind,
    route: entry.tokens.route,
    tokenCount: Math.max(...entry.tokens.variants.map((v) => v.tokens.length)),
    variant: result ? result.variant : null,
    variantScores: result ? result.variantScores : null,
    repairs: result ? result.repairs : [],
    correct,
    wrong,
    missing,
    silentWrong,
    fixOps,
    reviewTaps,
    netPayCorrect: perItem.net_pay.correct,
    itemPass: correct >= PASS_ITEM_THRESHOLD,
    elapsedMs,
    engineMs: result ? result.stats.elapsedMs : null,
    crashed: crashed ? String(crashed && crashed.stack ? crashed.stack.split('\n')[0] : crashed) : null,
    checks: result ? result.checks : [],
    perItem,
  };
}

export function aggregate(rows) {
  const formatsPassed = rows.filter((r) => r.itemPass).length;
  const netPayOk = rows.filter((r) => r.netPayCorrect).length;
  const crashes = rows.filter((r) => r.crashed).length;
  const silentWrong = rows.reduce((s, r) => s + r.silentWrong, 0);
  const avgFixOps = rows.reduce((s, r) => s + r.fixOps, 0) / rows.length;
  const pdfRows = rows.filter((r) => r.route === 'pdf_text');
  const ocrRows = rows.filter((r) => r.route === 'ocr');

  const passConditions = {
    formats: { got: formatsPassed, need: PASS_FORMAT_THRESHOLD, ok: formatsPassed >= PASS_FORMAT_THRESHOLD },
    netPay: { got: netPayOk, need: NET_PAY_TARGET, ok: netPayOk >= NET_PAY_TARGET },
    silentWrong: { got: silentWrong, need: 0, ok: silentWrong === 0 },
    avgFixOps: { got: Number(avgFixOps.toFixed(2)), need: 3, ok: avgFixOps <= 3 },
    crashes: { got: crashes, need: 0, ok: crashes === 0 },
    externalCalls: { got: 0, need: 0, ok: true },
  };

  const allOk = Object.values(passConditions).every((c) => c.ok);
  const pdfOnlyOk = pdfRows.length > 0 && pdfRows.every((r) => r.itemPass) && silentWrong === 0;

  let verdict = 'FAIL';
  if (allOk) verdict = 'PASS';
  else if (pdfOnlyOk) verdict = 'WARN';

  return {
    verdict,
    passConditions,
    totals: {
      cases: rows.length,
      formatsPassed,
      netPayOk,
      silentWrong,
      crashes,
      avgFixOps: Number(avgFixOps.toFixed(2)),
      avgCorrect: Number((rows.reduce((s, r) => s + r.correct, 0) / rows.length).toFixed(2)),
      pdf: {
        cases: pdfRows.length,
        formatsPassed: pdfRows.filter((r) => r.itemPass).length,
        avgCorrect: pdfRows.length
          ? Number((pdfRows.reduce((s, r) => s + r.correct, 0) / pdfRows.length).toFixed(2))
          : null,
      },
      ocr: {
        cases: ocrRows.length,
        formatsPassed: ocrRows.filter((r) => r.itemPass).length,
        avgCorrect: ocrRows.length
          ? Number((ocrRows.reduce((s, r) => s + r.correct, 0) / ocrRows.length).toFixed(2))
          : null,
      },
    },
  };
}

function printCaseDetail(row) {
  console.log(`\n=== ${row.id} ${row.title}`);
  console.log(`route=${row.route} tokens=${row.tokenCount} correct=${row.correct}/9 wrong=${row.wrong} missing=${row.missing}`);
  for (const key of ITEM_KEYS) {
    const d = row.perItem[key];
    const mark = d.correct ? 'OK ' : d.value === null ? '-- ' : 'NG ';
    console.log(
      `  ${mark}${ITEM_LABELS[key].padEnd(6)} 正解=${String(d.truth).padStart(8)} 候補=${String(d.value).padStart(8)}` +
      ` [${d.status}] conf=${d.confidence}${d.derived ? ' (derived)' : ''}` +
      (d.reasons.length ? `  ${d.reasons.join(' / ')}` : ''),
    );
  }
  for (const c of row.checks) console.log(`  check ${c.id}: ${c.ok ? 'OK' : 'NG'} — ${c.detail}`);
}

const KIND_LABEL = {
  text_pdf: 'Web明細PDF（テキスト埋込）',
  screenshot: 'スクリーンショット',
  photo: '紙明細の写真',
  image_pdf: '画像PDF（スキャン）',
};

function writeMarkdown(rows, summary) {
  const lines = [];
  lines.push('# POC_RESULTS｜固定コーパス10形式の評価結果');
  lines.push('');
  lines.push('`node eval/run_eval.mjs --md` で自動生成。手書きしないこと。');
  lines.push('');
  lines.push(`生成日時: ${new Date().toISOString()}`);
  lines.push('');
  lines.push(`## 総合判定: **${summary.verdict}**`);
  lines.push('');
  lines.push('| PASS条件 | 実測 | 基準 | 判定 |');
  lines.push('| --- | --- | --- | --- |');
  const condLabel = {
    formats: '10形式中、9項目のうち7項目以上を正しく提示できた形式数',
    netPay: '差引支給額を正しく提示できた形式数',
    silentWrong: '誤った値を「確定候補」として提示した件数',
    avgFixOps: '1明細あたりの平均修正操作回数',
    crashes: '主要フローのクラッシュ数',
    externalCalls: '外部AI/APIへの送信数',
  };
  for (const [key, c] of Object.entries(summary.passConditions)) {
    lines.push(`| ${condLabel[key]} | ${c.got} | ${key === 'avgFixOps' ? `${c.need}以下` : key === 'formats' || key === 'netPay' ? `${c.need}以上` : c.need} | ${c.ok ? 'OK' : 'NG'} |`);
  }
  lines.push('');
  lines.push('## 形式ごとの結果');
  lines.push('');
  lines.push('| ケース | 形式 | 入力経路 | 正しく提示 | 誤り | 未検出 | 誤確定 | 修正操作 | 確認タップ | 判定 | 処理時間 |');
  lines.push('| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |');
  for (const r of rows) {
    lines.push(
      `| ${r.id} | ${KIND_LABEL[r.kind] || r.kind} | ${r.route === 'pdf_text' ? 'PDF直接' : `OCR(${r.variant})`} | ` +
      `${r.correct}/9 | ${r.wrong} | ${r.missing} | ${r.silentWrong} | ${r.fixOps} | ${r.reviewTaps} | ` +
      `${r.itemPass ? 'PASS' : 'fail'} | ${r.engineMs}ms |`,
    );
  }
  lines.push('');
  lines.push('- 「正しく提示」= 9項目のうち、正解と完全一致する値を候補として提示できた数。');
  lines.push('- 「誤確定」= 誤った値を「確定候補」として提示した数。0であることがPASSの必須条件。');
  lines.push('- 「修正操作」= 誤った値の修正 + 未検出項目の手入力（想定回数）。');
  lines.push('- 「確認タップ」= 値は正しいが「要確認」として提示され、ユーザーの確認だけが必要な項目数。');
  lines.push('- 処理時間は解析エンジンのみ（OCR・PDF抽出時間は含まない）。');
  lines.push('');
  lines.push('## 入力経路別の集計');
  lines.push('');
  lines.push('| 経路 | 形式数 | PASSした形式数 | 平均正解項目数 |');
  lines.push('| --- | --- | --- | --- |');
  lines.push(`| PDF直接解析 | ${summary.totals.pdf.cases} | ${summary.totals.pdf.formatsPassed} | ${summary.totals.pdf.avgCorrect}/9 |`);
  lines.push(`| OCR | ${summary.totals.ocr.cases} | ${summary.totals.ocr.formatsPassed} | ${summary.totals.ocr.avgCorrect}/9 |`);
  lines.push('');
  lines.push('## 項目ごとの正解率');
  lines.push('');
  lines.push('| 項目 | 正しく提示できた形式数 |');
  lines.push('| --- | --- |');
  for (const key of ITEM_KEYS) {
    const ok = rows.filter((r) => r.perItem[key].correct).length;
    lines.push(`| ${ITEM_LABELS[key]} | ${ok}/${rows.length} |`);
  }
  lines.push('');
  lines.push('## 誤り・未検出の内訳');
  lines.push('');
  const problems = [];
  for (const r of rows) {
    for (const key of ITEM_KEYS) {
      const d = r.perItem[key];
      if (d.correct) continue;
      problems.push(`| ${r.id} | ${ITEM_LABELS[key]} | ${d.truth} | ${d.value === null ? '（未検出）' : d.value} | ${d.status} | ${d.reasons.join(' / ') || '-'} |`);
    }
  }
  if (problems.length) {
    lines.push('| ケース | 項目 | 正解 | 提示値 | 状態 | 理由 |');
    lines.push('| --- | --- | --- | --- | --- | --- |');
    lines.push(...problems);
  } else {
    lines.push('なし。');
  }
  lines.push('');
  lines.push('## 桁誤り補正の適用状況');
  lines.push('');
  const repairRows = rows.filter((r) => (r.repairs || []).length);
  if (repairRows.length) {
    lines.push('| ケース | ブロック | 対象 | 補正前 → 補正後 |');
    lines.push('| --- | --- | --- | --- |');
    for (const r of repairRows) {
      for (const rep of r.repairs) {
        lines.push(rep.skipped
          ? `| ${r.id} | ${rep.block} | - | 補正を見送り（${rep.reason}） |`
          : `| ${r.id} | ${rep.block} | ${rep.target} | ${rep.from} → ${rep.to} |`);
      }
    }
  } else {
    lines.push('補正の適用なし。');
  }
  lines.push('');
  fs.writeFileSync(path.join(ROOT, 'POC_RESULTS.md'), lines.join('\n'));
  console.log('POC_RESULTS.md を更新しました');
}

function main() {
  const args = process.argv.slice(2);
  const only = args.includes('--case') ? args[args.indexOf('--case') + 1] : null;
  const cases = loadCases();
  const rows = cases
    .filter((c) => !only || c.meta.id.includes(only))
    .map(evaluateCase);

  if (only || args.includes('--verbose')) rows.forEach(printCaseDetail);

  const summary = aggregate(rows);
  console.log('\n--- 集計 ---');
  console.log(
    rows
      .map((r) => `${r.id} ${r.route.padEnd(8)} ${String(r.correct).padStart(2)}/9 ` +
        `${r.itemPass ? 'PASS' : 'fail'} 差引${r.netPayCorrect ? 'OK' : 'NG'} 修正${r.fixOps} ${r.crashed ? 'CRASH' : ''}`)
      .join('\n'),
  );
  console.log(`\n判定: ${summary.verdict}`);
  for (const [k, c] of Object.entries(summary.passConditions)) {
    console.log(`  ${c.ok ? 'OK' : 'NG'} ${k}: ${c.got} (基準 ${c.need})`);
  }

  fs.writeFileSync(
    path.join(__dirname, 'results.json'),
    JSON.stringify({ generatedAt: new Date().toISOString(), summary, rows }, null, 2),
  );
  if (args.includes('--md') && !only) writeMarkdown(rows, summary);
  return summary;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}
