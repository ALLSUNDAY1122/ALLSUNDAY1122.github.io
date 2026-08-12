// トークン列 → 行・列構造への整形。
// PDF直接抽出とOCRで粒度が違う（OCRは単語が細かく割れる）ため、
// 一度ここで「行」「連結トークン」へ揃えてから解析する。

import { parseAmount, toHalfWidth } from './normalize.js';

const clone = (t) => ({ ...t });

function tokenRight(t) {
  return t.x + (t.w || 0);
}

function tokenCenterY(t) {
  return t.y + (t.h || 0) / 2;
}

function tokenCenterX(t) {
  return t.x + (t.w || 0) / 2;
}

export function medianOf(values) {
  if (!values.length) return 0;
  const s = [...values].sort((a, b) => a - b);
  return s[Math.floor(s.length / 2)];
}

/** 与えられた傾き slope のもとで行キーを計算する（左上原点、slopeは dy/dx）。 */
function rowKey(t, slope) {
  return tokenCenterY(t) - slope * tokenCenterX(t);
}

function clusterRows(tokens, slope, tolerance) {
  const sorted = [...tokens].sort((a, b) => rowKey(a, slope) - rowKey(b, slope));
  const rows = [];
  let current = [];
  let anchor = null;
  for (const t of sorted) {
    const k = rowKey(t, slope);
    if (anchor === null || Math.abs(k - anchor) <= tolerance) {
      if (anchor === null) anchor = k;
      current.push(t);
      anchor = (anchor * (current.length - 1) + k) / current.length;
    } else {
      rows.push(current);
      current = [t];
      anchor = k;
    }
  }
  if (current.length) rows.push(current);
  return rows;
}

/**
 * 紙写真の傾きを推定する。行クラスタ数と行内のばらつきが最小になる傾きを選ぶ。
 * @returns {number} slope (dy/dx)
 */
export function estimateSkew(tokens, medianHeight) {
  if (tokens.length < 6) return 0;
  const tolerance = Math.max(2, medianHeight * 0.5);
  let best = { slope: 0, cost: Infinity };
  for (let slope = -0.08; slope <= 0.0801; slope += 0.0025) {
    const rows = clusterRows(tokens, slope, tolerance);
    let spread = 0;
    for (const row of rows) {
      const keys = row.map((t) => rowKey(t, slope));
      spread += Math.max(...keys) - Math.min(...keys);
    }
    const cost = rows.length * tolerance + spread;
    if (cost < best.cost - 1e-9) best = { slope, cost };
  }
  return Math.abs(best.slope) < 0.0026 ? 0 : best.slope;
}

const NUM_TAIL = /[\d,.]$/;
const NUM_HEAD = /^[\d,.]/;

function isCJK(ch) {
  return /[　-ヿ一-鿿＀-￯]/.test(ch);
}

/** 同一行内で近接するトークンを連結する（OCRの単語分割を戻す）。 */
function mergeRowTokens(row, medianHeight) {
  const sorted = [...row].sort((a, b) => a.x - b.x);
  const out = [];
  for (const raw of sorted) {
    const t = clone(raw);
    const prev = out[out.length - 1];
    if (!prev) {
      out.push(t);
      continue;
    }
    const gap = t.x - tokenRight(prev);
    const numericJoin = NUM_TAIL.test(prev.text) && NUM_HEAD.test(t.text);
    const cjkJoin = isCJK(prev.text[prev.text.length - 1]) && isCJK(t.text[0]);
    // OCRは1語を細かく割るため、日本語同士は文字高の0.8倍まで詰めて連結する
    const limit = numericJoin ? medianHeight * 0.9 : medianHeight * 0.8;
    if (gap >= -medianHeight * 0.3 && gap <= limit && (numericJoin || cjkJoin)) {
      prev.text += t.text;
      prev.w = tokenRight(t) - prev.x;
      prev.h = Math.max(prev.h || 0, t.h || 0);
      prev.conf = Math.min(prev.conf ?? 1, t.conf ?? 1);
      prev.merged = true;
    } else {
      out.push(t);
    }
  }
  return out;
}

const LABEL_AMOUNT = /^([^\d０-９]*[^\d０-９\s])[\s]*([-+−▲△¥￥(（]?[\d０-９][\d０-９,.\s]*[)）]?円?)$/;

/** 「基本給252,000」のようにラベルと金額がくっついたトークンを分割する。 */
function splitLabelAmount(token) {
  const text = token.text.trim();
  if (text.length < 3) return [token];
  const m = text.match(LABEL_AMOUNT);
  if (!m) return [token];
  const [, labelPart, amountPart] = m;
  if (!labelPart || labelPart.length < 2) return [token];
  if (!parseAmount(amountPart)) return [token];
  // 「2026年3月分」のような日付混じりは分割しない
  if (/[年月日]$/.test(labelPart)) return [token];
  const total = text.length;
  const w = token.w || 0;
  const labelW = (w * labelPart.length) / total;
  return [
    { ...token, text: labelPart, w: labelW, split: true },
    { ...token, text: amountPart, x: token.x + labelW, w: w - labelW, split: true },
  ];
}

/**
 * トークンを解析しやすい形へ整える。
 * @returns {{rows: Array<{index:number, tokens:Array, key:number}>, tokens:Array, slope:number, medianHeight:number}}
 */
export function buildLayout(rawTokens) {
  const tokens = (rawTokens || [])
    .filter((t) => t && typeof t.text === 'string' && t.text.trim() !== '')
    .map((t) => ({
      text: toHalfWidth(t.text).trim(),
      x: Number(t.x) || 0,
      y: Number(t.y) || 0,
      w: Number(t.w) || 0,
      h: Number(t.h) || 0,
      conf: t.conf === undefined ? 1 : Number(t.conf),
      page: t.page || 1,
    }))
    .filter((t) => t.text !== '');

  if (!tokens.length) {
    return { rows: [], tokens: [], slope: 0, medianHeight: 0 };
  }

  const medianHeight = medianOf(tokens.map((t) => t.h).filter((h) => h > 0)) || 10;
  const slope = estimateSkew(tokens, medianHeight);
  const tolerance = Math.max(2, medianHeight * 0.55);

  const grouped = clusterRows(tokens, slope, tolerance);
  const rows = [];
  for (const group of grouped) {
    const merged = mergeRowTokens(group, medianHeight).flatMap(splitLabelAmount);
    merged.sort((a, b) => a.x - b.x);
    rows.push({ tokens: merged, key: medianOf(merged.map((t) => rowKey(t, slope))) });
  }
  rows.sort((a, b) => a.key - b.key);
  rows.forEach((r, i) => {
    r.index = i;
    r.tokens.forEach((t) => {
      t.row = i;
    });
  });

  return {
    rows,
    tokens: rows.flatMap((r) => r.tokens),
    slope,
    medianHeight,
  };
}

/** 金額トークンの右端x座標から「金額列」を推定する。 */
export function detectAmountColumns(amountTokens, medianHeight) {
  const edges = amountTokens.map((a) => tokenRight(a.token)).sort((x, y) => x - y);
  const columns = [];
  const tol = Math.max(6, medianHeight * 1.2);
  for (const e of edges) {
    const last = columns[columns.length - 1];
    if (last && e - last.center <= tol) {
      last.members.push(e);
      last.center = last.members.reduce((s, v) => s + v, 0) / last.members.length;
    } else {
      columns.push({ center: e, members: [e] });
    }
  }
  return columns.filter((c) => c.members.length >= 2);
}

export { tokenRight, tokenCenterX, tokenCenterY };
