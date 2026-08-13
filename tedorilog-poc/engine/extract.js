// 給与明細トークン列から9項目の候補を抽出する中核ロジック。
// 重要: この関数は「候補」しか返さない。確定保存はUI側のユーザー確認を必ず経由する。

import { parseAmount, amountPlausibility } from './normalize.js';
import { matchItemLabel, matchTotalLabel, isOtherDeduction, ITEM_KEYS, ITEM_LABELS } from './lexicon.js';
import { buildLayout, detectAmountColumns, tokenRight, tokenCenterX } from './layout.js';
import { solveDigitErrors, aggregateCandidates } from './digit_repair.js';

export const STATUS = {
  CONFIRMED_CANDIDATE: 'confident', // 確定候補
  NEEDS_REVIEW: 'needs_review', // 要確認
  NOT_FOUND: 'not_found', // 未検出
};

const CONFIDENT_THRESHOLD = 0.6;
const REVIEW_THRESHOLD = 0.28;
const LOW_OCR_CONF = 0.55;
// OCR経路で「確定候補」にする最低の読み取り信頼度。
// 合計検算が偶然合ってしまう誤読を確定にしないため、PDF経路より厳しくする。
const OCR_CONFIDENT_MIN = 0.8;

function emptyItems() {
  const items = {};
  for (const key of ITEM_KEYS) {
    items[key] = {
      key,
      label: ITEM_LABELS[key],
      value: null,
      status: STATUS.NOT_FOUND,
      confidence: 0,
      reasons: [],
      evidence: [],
      alternatives: [],
    };
  }
  return items;
}

function box(t) {
  return { x: t.x, y: t.y, w: t.w, h: t.h, text: t.text };
}

/** 行ごとにラベル・金額・合計行を分類する。 */
function scanRows(layout) {
  const labelHits = [];
  const amountRefs = [];
  const totalHits = [];
  const otherDeductionHits = [];

  for (const row of layout.rows) {
    for (const token of row.tokens) {
      const parsed = parseAmount(token.text);
      const digitRatio = (token.text.match(/\d/g) || []).length / token.text.length;
      if (parsed && digitRatio >= 0.5) {
        amountRefs.push({ token, parsed, row: row.index });
        continue;
      }
      const total = matchTotalLabel(token.text);
      if (total) {
        totalHits.push({ token, match: total, row: row.index });
        continue;
      }
      const item = matchItemLabel(token.text);
      if (item) {
        labelHits.push({ token, match: item, row: row.index });
        continue;
      }
      if (isOtherDeduction(token.text)) {
        otherDeductionHits.push({ token, row: row.index });
      }
    }
  }
  return { labelHits, amountRefs, totalHits, otherDeductionHits };
}

function rowProfile(layout, amountRefs, labelTokens) {
  const amountsByRow = new Map();
  const labelsByRow = new Map();
  for (const a of amountRefs) {
    if (!amountsByRow.has(a.row)) amountsByRow.set(a.row, []);
    amountsByRow.get(a.row).push(a);
  }
  for (const l of labelTokens) {
    if (!labelsByRow.has(l.row)) labelsByRow.set(l.row, []);
    labelsByRow.get(l.row).push(l);
  }
  return { amountsByRow, labelsByRow };
}

/** 同一行でラベルの右側にある金額（次のラベルまで）を近い順に返す。 */
function rightCandidates(hit, amountsInRow, labelsInRow) {
  const labelRight = tokenRight(hit.token);
  const nextLabel = labelsInRow
    .filter((l) => l.token.x > hit.token.x + 1)
    .sort((a, b) => a.token.x - b.token.x)[0];
  const boundary = nextLabel ? nextLabel.token.x : Infinity;
  return amountsInRow
    .filter((a) => a.token.x >= labelRight - 1 && a.token.x < boundary)
    .sort((a, b) => a.token.x - b.token.x);
}

function leftCandidates(hit, amountsInRow) {
  return amountsInRow
    .filter((a) => tokenRight(a.token) <= hit.token.x + 1)
    .sort((a, b) => b.token.x - a.token.x);
}

/**
 * ラベル列と金額列を、左から右の順序を保ったまま対応付ける。
 * 表のセルは順番に並ぶので、単純な最近傍よりも順序を保つ方が崩れにくい
 * （ラベルが長いと中心がずれ、隣のセルの金額に吸い寄せられるため）。
 * @returns {Map<labelIndex, amountIndex>}
 */
function monotonicMatch(labelCenters, amountCenters) {
  const n = labelCenters.length;
  const m = amountCenters.length;
  const INF = Infinity;
  // dp[i][j] = ラベルi以降・金額j以降を対応付けたときの最小コスト
  const dp = Array.from({ length: n + 1 }, () => new Array(m + 1).fill(INF));
  const choice = Array.from({ length: n + 1 }, () => new Array(m + 1).fill(null));
  for (let j = 0; j <= m; j++) dp[n][j] = 0;
  for (let i = n - 1; i >= 0; i--) {
    for (let j = m - 1; j >= 0; j--) {
      const pair = Math.abs(labelCenters[i] - amountCenters[j]) + dp[i + 1][j + 1];
      const skipAmount = dp[i][j + 1] + 1; // 金額を飛ばす（余分な数値がある場合）
      if (pair <= skipAmount) {
        dp[i][j] = pair;
        choice[i][j] = 'pair';
      } else {
        dp[i][j] = skipAmount;
        choice[i][j] = 'skip';
      }
    }
  }
  const result = new Map();
  let i = 0;
  let j = 0;
  while (i < n && j < m) {
    if (choice[i][j] === 'pair') {
      result.set(i, j);
      i += 1;
      j += 1;
    } else {
      j += 1;
    }
  }
  return result;
}

/**
 * 列ヘッダ型（ラベルの真下に金額）の対応付け。
 */
function belowCandidate(hit, layout, profile, medianHeight) {
  const labelsInRow = (profile.labelsByRow.get(hit.row) || []).slice().sort((a, b) => a.token.x - b.token.x);
  const amountsInRow = profile.amountsByRow.get(hit.row) || [];
  if (labelsInRow.length < 2 || amountsInRow.length > 1) return null;

  for (let d = 1; d <= 2; d++) {
    const targetRow = hit.row + d;
    const amounts = (profile.amountsByRow.get(targetRow) || []).slice().sort((a, b) => a.token.x - b.token.x);
    const labels = profile.labelsByRow.get(targetRow) || [];
    if (amounts.length < 2 || labels.length > amounts.length) continue;
    const matching = monotonicMatch(
      labelsInRow.map((l) => tokenCenterX(l.token)),
      amounts.map((a) => tokenCenterX(a.token)),
    );
    const labelIndex = labelsInRow.indexOf(hit);
    const amountIndex = matching.get(labelIndex);
    if (amountIndex === undefined) continue;
    const amount = amounts[amountIndex];
    if (Math.abs(tokenCenterX(amount.token) - tokenCenterX(hit.token)) > medianHeight * 12) continue;
    return { amount, weight: d === 1 ? 0.85 : 0.6 };
  }
  return null;
}

function columnBonus(amountRef, columns, medianHeight) {
  if (!columns.length) return 1;
  const right = tokenRight(amountRef.token);
  const tol = Math.max(6, medianHeight * 1.2);
  return columns.some((c) => Math.abs(c.center - right) <= tol) ? 1.06 : 0.94;
}

function pairScore(hit, amountRef, posWeight, columns, medianHeight) {
  const ocrConf = 0.6 + 0.4 * Math.min(1, amountRef.token.conf ?? 1);
  return (
    hit.match.score *
    posWeight *
    amountPlausibility(amountRef.parsed.value) *
    amountRef.parsed.confidence *
    ocrConf *
    columnBonus(amountRef, columns, medianHeight)
  );
}

function buildPairs(hits, layout, profile, columns, medianHeight) {
  const pairs = [];
  for (const hit of hits) {
    const amountsInRow = profile.amountsByRow.get(hit.row) || [];
    const labelsInRow = profile.labelsByRow.get(hit.row) || [];
    const right = rightCandidates(hit, amountsInRow, labelsInRow);
    const posWeights = [1, 0.5, 0.28];
    right.slice(0, 3).forEach((a, i) => {
      pairs.push({ hit, amount: a, relation: 'same_row_right', score: pairScore(hit, a, posWeights[i], columns, medianHeight) });
    });
    if (!right.length) {
      const left = leftCandidates(hit, amountsInRow)[0];
      if (left) {
        pairs.push({ hit, amount: left, relation: 'same_row_left', score: pairScore(hit, left, 0.45, columns, medianHeight) });
      }
    }
    const below = belowCandidate(hit, layout, profile, medianHeight);
    if (below) {
      pairs.push({ hit, amount: below.amount, relation: 'column_below', score: pairScore(hit, below.amount, below.weight, columns, medianHeight) });
    }
  }
  return pairs.sort((a, b) => b.score - a.score);
}

function assignPairs(pairs) {
  const usedAmounts = new Set();
  const usedLabels = new Set();
  const assignedSingles = new Set();
  const accepted = [];
  const rejected = [];

  for (const pair of pairs) {
    const amountId = pair.amount.token;
    const labelId = pair.hit.token;
    const key = pair.hit.match.key;
    const isSingle = pair.hit.match.kind !== 'aggregate';
    if (usedAmounts.has(amountId) || usedLabels.has(labelId)) {
      rejected.push(pair);
      continue;
    }
    if (isSingle && assignedSingles.has(key)) {
      rejected.push(pair);
      continue;
    }
    if (pair.score < REVIEW_THRESHOLD * 0.5) {
      rejected.push(pair);
      continue;
    }
    usedAmounts.add(amountId);
    usedLabels.add(labelId);
    if (isSingle) assignedSingles.add(key);
    accepted.push(pair);
  }
  return { accepted, rejected };
}

function statusFor(score, ocrConf) {
  if (score >= CONFIDENT_THRESHOLD && ocrConf >= LOW_OCR_CONF) return STATUS.CONFIRMED_CANDIDATE;
  if (score >= REVIEW_THRESHOLD) return STATUS.NEEDS_REVIEW;
  return STATUS.NOT_FOUND;
}

function collectItems(accepted, rejected) {
  const items = emptyItems();
  for (const pair of accepted) {
    const key = pair.hit.match.key;
    const item = items[key];
    const value = pair.amount.parsed.value;
    const ocrConf = pair.amount.token.conf ?? 1;
    const part = {
      value,
      score: pair.score,
      relation: pair.relation,
      exactLabel: Boolean(pair.hit.match.exact) && !pair.hit.match.loose,
      label: pair.hit.token.text,
      labelBox: box(pair.hit.token),
      amountBox: box(pair.amount.token),
      ocrConf,
    };
    if (item.value === null) {
      item.value = Math.abs(value);
      item.confidence = pair.score;
      item.minOcrConf = ocrConf;
    } else {
      // 集計項目（残業関連・その他手当）は複数行を合算する
      item.value += Math.abs(value);
      item.confidence = Math.min(item.confidence, pair.score);
      item.minOcrConf = Math.min(item.minOcrConf, ocrConf);
    }
    item.evidence.push(part);
    item.status = statusFor(item.confidence, item.minOcrConf);
  }

  // 採用しなかった候補は「別候補」としてUIに出す
  for (const pair of rejected) {
    const item = items[pair.hit.match.key];
    if (!item || item.alternatives.length >= 3) continue;
    if (item.evidence.some((e) => e.amountBox.text === pair.amount.token.text)) continue;
    item.alternatives.push({
      value: Math.abs(pair.amount.parsed.value),
      score: Number(pair.score.toFixed(3)),
      label: pair.hit.token.text,
      relation: pair.relation,
    });
  }
  return items;
}

function collectTotals(accepted) {
  const totals = { gross: null, deduction: null, evidence: {} };
  for (const pair of accepted) {
    if (pair.hit.kindOfTotal === 'gross_total' && totals.gross === null) {
      totals.gross = Math.abs(pair.amount.parsed.value);
      totals.evidence.gross = box(pair.amount.token);
    }
    if (pair.hit.kindOfTotal === 'deduction_total' && totals.deduction === null) {
      totals.deduction = Math.abs(pair.amount.parsed.value);
      totals.evidence.deduction = box(pair.amount.token);
    }
  }
  return totals;
}

/** 支給合計・控除合計・差引支給額の整合検算。 */
function reconcile(items, totals, otherDeductionSum) {
  const checks = [];
  const v = (k) => (items[k].value === null ? null : items[k].value);

  const basic = v('basic_pay');
  const overtime = v('overtime');
  const other = v('other_allowance');
  const deductions = ['health_insurance', 'pension', 'employment_insurance', 'income_tax', 'resident_tax'].map(v);
  const knownDeductionSum = deductions.every((d) => d !== null)
    ? deductions.reduce((s, d) => s + d, 0)
    : null;

  if (totals.gross !== null && basic !== null && overtime !== null && other !== null) {
    const delta = totals.gross - (basic + overtime + other);
    checks.push({
      id: 'pay_total',
      ok: delta === 0,
      delta,
      detail: `支給合計 ${totals.gross} と 基本給+残業+その他 ${basic + overtime + other} の差 ${delta}`,
    });
  }

  if (totals.deduction !== null && knownDeductionSum !== null) {
    const delta = totals.deduction - (knownDeductionSum + otherDeductionSum);
    checks.push({
      id: 'deduction_total',
      ok: delta === 0,
      delta,
      detail: `控除合計 ${totals.deduction} と 控除項目合計 ${knownDeductionSum + otherDeductionSum} の差 ${delta}`,
    });
  }

  if (totals.gross !== null && totals.deduction !== null) {
    const derived = totals.gross - totals.deduction;
    const net = v('net_pay');
    checks.push({
      id: 'net_pay',
      ok: net !== null && net === derived,
      derived,
      delta: net === null ? null : net - derived,
      detail: net === null
        ? `差引支給額は未検出。支給合計-控除合計=${derived} を候補にできる`
        : `差引支給額 ${net} と 支給合計-控除合計 ${derived} の差 ${net - derived}`,
    });
  }
  return checks;
}

const AGGREGATE_KEYS = ['overtime', 'other_allowance'];
const DEDUCTION_KEYS = ['health_insurance', 'pension', 'employment_insurance', 'income_tax', 'resident_tax'];

function termFor(items, key, sign) {
  const item = items[key];
  const parts = item.evidence || [];
  return {
    key,
    value: item.value,
    sign,
    correctable: !item.derived,
    ocrConf: item.minOcrConf ?? 1,
    candidateValues: parts.length > 1 ? aggregateCandidates(parts) : undefined,
  };
}

function applyCorrections(items, totals, solution, blockId, log) {
  for (const c of solution.corrections) {
    if (c.key === '__gross') {
      log.push({ block: blockId, target: '支給合計', from: totals.gross, to: c.to, kind: c.kind });
      totals.gross = c.to;
      totals.grossCorrected = true;
      continue;
    }
    if (c.key === '__deduction') {
      log.push({ block: blockId, target: '控除合計', from: totals.deduction, to: c.to, kind: c.kind });
      totals.deduction = c.to;
      totals.deductionCorrected = true;
      continue;
    }
    const item = items[c.key];
    if (!item || item.value === null) continue;
    item.alternatives.unshift({ value: c.from, score: 0, label: 'OCR読み取り値', relation: 'ocr_raw' });
    item.value = c.to;
    item.corrected = true;
    item.status = STATUS.NEEDS_REVIEW;
    item.reasons.push(`合計との整合から桁誤りを補正（${c.from}→${c.to}）。要確認`);
    log.push({ block: blockId, target: item.label, from: c.from, to: c.to, kind: c.kind });
  }
}

/**
 * OCR経路のみ: 合計と1桁違いで合わない場合に桁誤り補正を試みる。
 * PDF直接抽出は文字が正確なため補正しない（誤った書き換えを避ける）。
 */
function repairWithTotals(items, totals, otherDeductionSum, route, repairedBlocks) {
  const log = [];
  if (route === 'pdf_text') return log;

  const hasAll = (keys) => keys.every((k) => items[k].value !== null);
  const tryApply = (solution, blockId) => {
    if (!solution || !solution.corrections.length) return;
    if (solution.ambiguous) {
      log.push({ block: blockId, skipped: true, reason: '同等の補正候補が複数あるため補正しない' });
      repairedBlocks.add(blockId);
      return;
    }
    repairedBlocks.add(blockId);
    applyCorrections(items, totals, solution, blockId, log);
  };

  // 1) まず合計同士（支給合計 - 控除合計 = 差引支給額）で「基準になる合計」を確かめる。
  //    合計が誤読されたまま各項目を検算すると、正しい項目の方を書き換えてしまうため。
  if (totals.gross !== null && totals.deduction !== null && items.net_pay.value !== null) {
    const terms = [
      { key: '__gross', value: totals.gross, sign: 1, correctable: true, ocrConf: 0.8 },
      { key: '__deduction', value: totals.deduction, sign: -1, correctable: true, ocrConf: 0.8 },
      termFor(items, 'net_pay', -1),
    ];
    tryApply(solveDigitErrors(terms, { maxCorrections: 2 }), 'net_pay');
  }

  // 2) 確かめた支給合計を基準に、支給側の各項目を検算する。
  if (totals.gross !== null && hasAll(['basic_pay', 'overtime', 'other_allowance'])) {
    const terms = [
      termFor(items, 'basic_pay', 1),
      termFor(items, 'overtime', 1),
      termFor(items, 'other_allowance', 1),
      { key: '__gross', value: totals.gross, sign: -1, correctable: !totals.grossCorrected, ocrConf: 0.8 },
    ];
    tryApply(solveDigitErrors(terms), 'pay_total');
  }

  // 3) 同様に控除側。
  if (totals.deduction !== null && hasAll(DEDUCTION_KEYS)) {
    const terms = [
      ...DEDUCTION_KEYS.map((k) => termFor(items, k, 1)),
      { key: '__other_deduction', value: otherDeductionSum, sign: 1, correctable: false, ocrConf: 1 },
      { key: '__deduction', value: totals.deduction, sign: -1, correctable: !totals.deductionCorrected, ocrConf: 0.8 },
    ];
    tryApply(solveDigitErrors(terms), 'deduction_total');
  }
  return log;
}

/** 検算結果を候補の状態へ反映する。 */
function applyChecks(items, checks, totals, repairedBlocks = new Set()) {
  const upgrade = (key, reason) => {
    const item = items[key];
    if (item.value === null) return;
    if (item.corrected || item.derived) {
      // 推測で作った値は検算が合っても確定候補にしない
      item.reasons.push(reason);
      return;
    }
    if (item.status === STATUS.NEEDS_REVIEW && item.confidence >= REVIEW_THRESHOLD && (item.minOcrConf ?? 1) >= LOW_OCR_CONF) {
      item.status = STATUS.CONFIRMED_CANDIDATE;
    }
    item.reasons.push(reason);
  };
  const downgrade = (key, reason) => {
    const item = items[key];
    if (item.value === null) return;
    if (item.status === STATUS.CONFIRMED_CANDIDATE) item.status = STATUS.NEEDS_REVIEW;
    item.reasons.push(reason);
  };

  for (const check of checks) {
    // 桁誤り補正を行った（または補正候補が曖昧だった）ブロックは、検算が通っても裏付けにしない
    const repaired = repairedBlocks.has(check.id);
    if (repaired && check.ok) {
      const keys = check.id === 'pay_total'
        ? ['basic_pay', 'overtime', 'other_allowance']
        : check.id === 'deduction_total' ? DEDUCTION_KEYS : ['net_pay'];
      keys.forEach((k) => {
        const item = items[k];
        if (item.value === null) return;
        if (item.status === STATUS.CONFIRMED_CANDIDATE) item.status = STATUS.NEEDS_REVIEW;
        item.reasons.push('同ブロックで桁誤りの補正・判断保留があったため要確認');
      });
      continue;
    }
    if (check.id === 'pay_total') {
      const keys = ['basic_pay', 'overtime', 'other_allowance'];
      if (check.ok) keys.forEach((k) => upgrade(k, '支給合計と一致'));
      else keys.forEach((k) => downgrade(k, `支給合計と不一致(差 ${check.delta})`));
    }
    if (check.id === 'deduction_total') {
      const keys = ['health_insurance', 'pension', 'employment_insurance', 'income_tax', 'resident_tax'];
      if (check.ok) keys.forEach((k) => upgrade(k, '控除合計と一致'));
      else keys.forEach((k) => downgrade(k, `控除合計と不一致(差 ${check.delta})`));
    }
    if (check.id === 'net_pay') {
      const item = items.net_pay;
      if (check.ok) upgrade('net_pay', '支給合計-控除合計と一致');
      else if (item.value === null && Number.isFinite(check.derived) && check.derived > 0) {
        item.value = check.derived;
        item.status = STATUS.NEEDS_REVIEW;
        item.confidence = 0.5;
        item.derived = true;
        item.reasons.push('支給合計-控除合計から算出した候補（要確認）');
      } else if (item.value !== null) {
        downgrade('net_pay', `支給合計-控除合計と不一致(差 ${check.delta})`);
      }
    }
  }

  // その他手当が見つからない場合、支給合計からの差分を要確認候補として提示する
  const other = items.other_allowance;
  if (other.value === null && totals.gross !== null &&
      items.basic_pay.value !== null && items.overtime.value !== null) {
    const derived = totals.gross - items.basic_pay.value - items.overtime.value;
    if (derived > 0) {
      other.value = derived;
      other.status = STATUS.NEEDS_REVIEW;
      other.confidence = 0.45;
      other.derived = true;
      other.reasons.push('支給合計から基本給・残業を引いた差分（要確認）');
    }
  }
}

/**
 * 給与明細トークン列から9項目候補を抽出する。
 * @param {Array} rawTokens {text,x,y,w,h,conf?} の配列
 * @param {{route?:string}} [options]
 */
export function extractPayslip(rawTokens, options = {}) {
  const startedAt = Date.now();
  const route = options.route || 'unknown';

  if (rawTokens != null && !Array.isArray(rawTokens)) {
    return {
      ok: false,
      error: 'invalid_input',
      message: 'トークン配列を渡してください',
      route,
      items: emptyItems(),
      totals: { gross: null, deduction: null, evidence: {} },
      checks: [],
      stats: { tokenCount: 0, elapsedMs: 0 },
    };
  }

  const layout = buildLayout(rawTokens || []);
  if (!layout.tokens.length) {
    return {
      ok: false,
      error: 'no_text_detected',
      message: '文字を検出できませんでした。撮り直すか、PDFを選び直してください。',
      route,
      items: emptyItems(),
      totals: { gross: null, deduction: null, evidence: {} },
      checks: [],
      stats: { tokenCount: 0, elapsedMs: Date.now() - startedAt },
    };
  }

  const { labelHits, amountRefs, totalHits, otherDeductionHits } = scanRows(layout);
  const columns = detectAmountColumns(amountRefs, layout.medianHeight);

  const totalHitsAsLabels = totalHits.map((h) => ({
    ...h,
    kindOfTotal: h.match.key,
    match: { key: `__total_${h.match.key}`, score: h.match.score, kind: 'single', group: 'total' },
  }));
  const otherDeductionAsLabels = otherDeductionHits.map((h) => ({
    ...h,
    kindOfTotal: null,
    isOtherDeduction: true,
    match: { key: '__other_deduction', score: 0.8, kind: 'aggregate', group: 'deduct' },
  }));

  const allHits = [...labelHits, ...totalHitsAsLabels, ...otherDeductionAsLabels];
  const profile = rowProfile(layout, amountRefs, allHits);
  const pairs = buildPairs(allHits, layout, profile, columns, layout.medianHeight);
  const { accepted, rejected } = assignPairs(pairs);

  const itemPairs = accepted.filter((p) => !p.hit.kindOfTotal && !p.hit.isOtherDeduction);
  const items = collectItems(
    itemPairs,
    rejected.filter((p) => !p.hit.kindOfTotal && !p.hit.isOtherDeduction),
  );
  const totals = collectTotals(accepted.filter((p) => p.hit.kindOfTotal));
  const otherDeductionSum = accepted
    .filter((p) => p.hit.isOtherDeduction)
    .reduce((s, p) => s + Math.abs(p.amount.parsed.value), 0);

  const repairedBlocks = new Set();
  const repairs = repairWithTotals(items, totals, otherDeductionSum, route, repairedBlocks);
  const checks = reconcile(items, totals, otherDeductionSum);
  applyChecks(items, checks, totals, repairedBlocks);

  const summary = { confident: 0, needsReview: 0, notFound: 0 };
  for (const key of ITEM_KEYS) {
    const st = items[key].status;
    if (st === STATUS.CONFIRMED_CANDIDATE) summary.confident += 1;
    else if (st === STATUS.NEEDS_REVIEW) summary.needsReview += 1;
    else summary.notFound += 1;
  }

  // 検算の裏付けが取れた項目だけを「確定候補」にする。
  // PDF直接抽出でも、フォント埋め込みの不備で文字が化けることがあるため経路を問わず適用する。
  const supported = new Set();
  for (const check of checks) {
    if (!check.ok) continue;
    if (check.id === 'pay_total') ['basic_pay', 'overtime', 'other_allowance'].forEach((k) => supported.add(k));
    if (check.id === 'deduction_total') DEDUCTION_KEYS.forEach((k) => supported.add(k));
    if (check.id === 'net_pay') supported.add('net_pay');
  }
  for (const key of ITEM_KEYS) {
    const item = items[key];
    if (item.status === STATUS.CONFIRMED_CANDIDATE && !supported.has(key)) {
      item.status = STATUS.NEEDS_REVIEW;
      item.reasons.push('合計検算の裏付けが無いため要確認');
      continue;
    }
    if (item.status === STATUS.CONFIRMED_CANDIDATE && route !== 'pdf_text' &&
        (item.minOcrConf ?? 1) < OCR_CONFIDENT_MIN) {
      item.status = STATUS.NEEDS_REVIEW;
      item.reasons.push('読み取り信頼度が低いため要確認（合計が合っていても確定にしない）');
      continue;
    }
    // 残業関連とその他手当は「支給合計が合う」だけでは切り分けられない（互いに振り替えても合計は同じ）。
    // 項目名が完全一致していない構成要素がある場合は確定候補にしない。
    if (item.status === STATUS.CONFIRMED_CANDIDATE &&
        AGGREGATE_KEYS.includes(key) &&
        item.evidence.some((e) => !e.exactLabel)) {
      item.status = STATUS.NEEDS_REVIEW;
      item.reasons.push('項目名が完全一致でない手当を含むため要確認（振替の可能性）');
    }
  }

  return {
    ok: true,
    route,
    items,
    totals,
    checks,
    repairs,
    summary,
    stats: {
      tokenCount: layout.tokens.length,
      rowCount: layout.rows.length,
      skewSlope: Number(layout.slope.toFixed(4)),
      otherDeductionSum,
      elapsedMs: Date.now() - startedAt,
    },
  };
}

/**
 * 解析結果の自己評価スコア（正解を知らずに「どれくらい筋が通っているか」を測る）。
 * 検算が通っているほど、未検出が少ないほど高い。
 */
export function selfAssessment(result) {
  if (!result || !result.ok) return -Infinity;
  const checksOk = result.checks.filter((c) => c.ok).length;
  const repairs = (result.repairs || []).length;
  return (
    3 * checksOk +
    1.0 * result.summary.confident +
    0.4 * result.summary.needsReview -
    0.8 * result.summary.notFound -
    0.5 * repairs
  );
}

/**
 * 複数の読み取り結果（OCR設定違いなど）から最も筋の通る解析結果を選ぶ。
 * @param {Array<{name:string, tokens:Array}>} variants
 */
export function extractPayslipBest(variants, options = {}) {
  const list = (variants || []).filter((v) => v && Array.isArray(v.tokens));
  if (!list.length) return extractPayslip([], options);
  let best = null;
  const attempts = [];
  const results = [];
  for (const variant of list) {
    const result = extractPayslip(variant.tokens, options);
    const score = selfAssessment(result);
    attempts.push({ variant: variant.name, score: Number.isFinite(score) ? Number(score.toFixed(2)) : null });
    results.push({ name: variant.name, result });
    if (!best || score > best.score) best = { score, result, variant: variant.name };
  }

  // 別条件の読み取りと値が食い違う項目は確定候補にしない。
  // 「合計は合うが実は誤読」を、独立した2回目の読み取りで落とすための安全弁。
  const disagreements = [];
  for (const key of ITEM_KEYS) {
    const item = best.result.items[key];
    if (!item || item.value === null) continue;
    for (const other of results) {
      if (other.name === best.variant) continue;
      const otherValue = other.result.ok ? other.result.items[key].value : null;
      if (otherValue === null || otherValue === item.value) continue;
      disagreements.push({ key, chosen: item.value, other: otherValue, variant: other.name });
      if (item.status === STATUS.CONFIRMED_CANDIDATE) item.status = STATUS.NEEDS_REVIEW;
      item.reasons.push(`別条件の読み取りでは ${otherValue} と読めたため要確認`);
      if (!item.alternatives.some((a) => a.value === otherValue)) {
        item.alternatives.unshift({ value: otherValue, score: 0, label: `別の読み取り(${other.name})`, relation: 'variant' });
      }
      break;
    }
  }

  return { ...best.result, variant: best.variant, variantScores: attempts, disagreements };
}
