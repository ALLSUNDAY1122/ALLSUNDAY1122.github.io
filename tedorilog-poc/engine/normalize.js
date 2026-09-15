// 文字列・金額の正規化。
// OCR/PDFのどちらの経路でも同じ関数を通す。

const FULLWIDTH_OFFSET = 0xfee0;

/** 全角英数字・記号を半角へ。全角スペースは半角スペースへ。 */
export function toHalfWidth(s) {
  return String(s)
    .replace(/[！-～]/g, (c) => String.fromCharCode(c.charCodeAt(0) - FULLWIDTH_OFFSET))
    .replace(/　/g, ' ')
    .replace(/[，､]/g, ',')
    .replace(/[．｡]/g, '.');
}

/** ラベル比較用の正規化。空白・記号・装飾を落とす。 */
export function normalizeLabel(s) {
  return toHalfWidth(s)
    .replace(/\s+/g, '')
    .replace(/[【】\[\]()（）:：|｜<>＜＞*＊#・、。,.]/g, '')
    .trim();
}

const DIGITS = '0123456789';

/** 全角数字を半角へ寄せる（OCRの全角混入対策）。 */
function digitsToHalf(s) {
  return s.replace(/[０-９]/g, (c) => DIGITS[c.charCodeAt(0) - 0xff10]);
}

// 金額として扱ってはいけない文脈（日付・時刻・時間数・率など）
const NON_AMOUNT_PATTERNS = [
  /\d{4}\s*[-/年]\s*\d{1,2}/, // 2026-03 / 2026年3月
  /\d{1,2}\s*[-/]\s*\d{1,2}\s*[-/]/, // 03/25/
  /\d{1,2}\s*月/,
  /\d{1,2}\s*日(?!当)/,
  /\d{1,2}\s*:\s*\d{2}/, // 時刻
  /\d\s*[%％]/,
  /\d\s*(時間|Ｈ|h|hr|回|名|人|才|歳)/i,
];

const AMOUNT_CHARS = /^[-+−▲△Δ¥￥円()（）\d,.\s]+$/;

/**
 * 金額文字列を数値へ正規化する。
 * 対応: 1,234 / ¥1,234 / 1 234 / -1,234 / △1,234 / ▲1,234 / (1,234) / 1234円 / １２３４
 * OCR由来のゆれ: "1,23 4" / "1.234"(カンマ誤認) / "12,3 45"
 * @returns {{value:number, negative:boolean, confidence:number, raw:string}|null}
 */
export function parseAmount(raw) {
  if (raw == null) return null;
  const original = String(raw);
  let s = digitsToHalf(toHalfWidth(original)).trim();
  if (!s) return null;
  if (!/\d/.test(s)) return null;

  for (const p of NON_AMOUNT_PATTERNS) {
    if (p.test(s)) return null;
  }

  let confidence = 1;
  let negative = false;

  // 括弧表記のマイナス
  if (/^\(.*\)$/.test(s.replace(/\s/g, ''))) {
    negative = true;
    s = s.replace(/[()]/g, '');
  }
  // △▲− 記号。OCRは△をA/Δと読むことがあるため数字直前のAも符号として扱う
  if (/^[▲△Δ\-−]/.test(s.trim())) {
    negative = true;
    s = s.replace(/^[▲△Δ\-−]\s*/, '');
  } else if (/^[Aa](?=[\d¥￥])/.test(s.trim())) {
    negative = true;
    confidence -= 0.1;
    s = s.trim().slice(1);
  }
  // 通貨記号・円
  s = s.replace(/[¥￥]/g, '').replace(/円/g, '');
  const cleaned = s.replace(/\s/g, '');
  if (!AMOUNT_CHARS.test(cleaned) || !/\d/.test(cleaned)) return null;

  let body = cleaned;
  // 末尾の小数部（.00 など）は円未満として切り捨てる
  const decimal = body.match(/^(.*)\.(\d{1,2})$/);
  if (decimal && /\d/.test(decimal[1])) {
    body = decimal[1];
    confidence -= 0.05;
  }
  // 桁区切りの点・カンマを除去（OCRはカンマを点として読むことがある）
  const separators = (body.match(/[,.]/g) || []).length;
  body = body.replace(/[,.]/g, '');
  if (!/^\d+$/.test(body)) return null;

  // 桁区切りの位置が3桁刻みでない場合は信頼度を下げる（OCR誤読の兆候）
  if (separators > 0) {
    const groups = cleaned.replace(/\s/g, '').split(/[,.]/);
    const wellFormed = groups.slice(1).every((g) => g.length === 3);
    if (!wellFormed) confidence -= 0.2;
  } else if (body.length > 4) {
    // 桁区切り無しの大きな数値（ドットプリンタ形式）はやや信頼度を落とす
    confidence -= 0.05;
  }
  if (body.length > 9) return null;

  const value = parseInt(body, 10);
  if (!Number.isFinite(value)) return null;
  if (original.replace(/\s/g, '').length > 18) confidence -= 0.1;

  return {
    value: negative ? -value : value,
    negative,
    confidence: Math.max(0.1, confidence),
    raw: original,
  };
}

/** 金額らしさ（給与明細の金額として妥当か）。 */
export function amountPlausibility(value) {
  const v = Math.abs(value);
  if (v === 0) return 0.5;
  if (v < 100) return 0.35; // 日数・回数などの可能性
  if (v < 1000) return 0.8;
  if (v <= 9999999) return 1;
  return 0.3;
}

/** レーベンシュタイン距離（短い文字列専用）。 */
export function levenshtein(a, b) {
  if (a === b) return 0;
  const m = a.length;
  const n = b.length;
  if (!m) return n;
  if (!n) return m;
  let prev = Array.from({ length: n + 1 }, (_, i) => i);
  for (let i = 1; i <= m; i++) {
    const cur = [i];
    for (let j = 1; j <= n; j++) {
      cur[j] = Math.min(
        prev[j] + 1,
        cur[j - 1] + 1,
        prev[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1),
      );
    }
    prev = cur;
  }
  return prev[n];
}

/**
 * text が variant に一致するかを判定する。
 * - 完全に含む場合は 1.0
 * - OCR誤りを想定し、文字列全体が数文字違いの場合のみ部分点
 *
 * 部分文字列に対するあいまい一致は許さない。「特殊作業手当」の中の「作業手当」が
 * 「残業手当」と1文字違い、のような取り違えを防ぐため。
 * @returns {number} 一致スコア 0..1（0は不一致）
 */
export function fuzzyContains(text, variant) {
  if (!variant) return 0;
  if (text.includes(variant)) return 1;
  if (variant.length < 4) return 0;
  const maxDistance = variant.length >= 7 ? 2 : 1;
  if (Math.abs(text.length - variant.length) > maxDistance) return 0;
  const d = levenshtein(text, variant);
  if (d > maxDistance) return 0;
  return d === 1 ? 0.78 : 0.6;
}
