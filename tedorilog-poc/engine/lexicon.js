// 9項目の表記ゆれ辞書。
// variants は正規化済み（normalizeLabel を通した形）で書く。

import { normalizeLabel, fuzzyContains } from './normalize.js';

export const ITEM_KEYS = [
  'basic_pay',
  'overtime',
  'other_allowance',
  'health_insurance',
  'pension',
  'employment_insurance',
  'income_tax',
  'resident_tax',
  'net_pay',
];

export const ITEM_LABELS = {
  basic_pay: '基本給',
  overtime: '残業関連',
  other_allowance: 'その他手当',
  health_insurance: '健康保険',
  pension: '厚生年金',
  employment_insurance: '雇用保険',
  income_tax: '所得税',
  resident_tax: '住民税',
  net_pay: '差引支給額',
};

/**
 * kind:
 *   single    … 1明細に1つ
 *   aggregate … 複数行の合計で1項目を作る
 * group: pay(支給) / deduct(控除) / net(差引) / total(合計行)
 */
export const LEXICON = [
  {
    key: 'basic_pay',
    kind: 'single',
    group: 'pay',
    variants: ['基本給額', '基本給料', '基本給', '基準内賃金', '基準給', '本給', '月額基本給'],
    deny: ['基本給控除', '基本給単価'],
  },
  {
    key: 'overtime',
    kind: 'aggregate',
    group: 'pay',
    variants: [
      '時間外勤務手当', '時間外労働手当', '超過勤務手当', '普通残業手当', '残業手当', '時間外手当',
      '所定外手当', '法定外残業', '深夜勤務手当', '深夜残業手当', '休日出勤手当', '休日労働手当',
      '休日勤務手当', '時間外割増', '深夜割増', '休日割増', '残業代', '時間外', '所定外', '深夜手当',
      '深夜残業', '休日出勤', '休日手当', '超過勤務', '残業',
    ],
    deny: ['時間外時間', '残業時間', '時間外労働時間', '所定外時間'],
  },
  {
    key: 'other_allowance',
    kind: 'aggregate',
    group: 'pay',
    variants: [
      '通勤手当', '通勤費', '交通費', '住宅手当', '家族手当', '扶養手当', '役職手当', '職務手当',
      '資格手当', '技能手当', '皆勤手当', '精勤手当', '食事手当', '現場手当', '出張手当', '地域手当',
      '特別手当', '調整手当', 'その他手当', 'その他支給', '諸手当',
    ],
    // 末尾が「手当」で他項目に該当しないものを拾うためのゆるい規則
    loosePattern: /(手当|手富|季当)$/,
    deny: ['残業手当', '時間外手当', '深夜手当', '休日手当', '超過勤務手当', '割増手当'],
  },
  {
    key: 'health_insurance',
    kind: 'single',
    group: 'deduct',
    variants: ['健康保険料', '健康保険', '健保料', '健保'],
    deny: ['介護保険', '健康保険基金'],
  },
  {
    key: 'pension',
    kind: 'single',
    group: 'deduct',
    variants: ['厚生年金保険料', '厚生年金基金', '厚生年金', '厚年保険料', '厚年料', '厚年'],
    deny: ['国民年金'],
  },
  {
    key: 'employment_insurance',
    kind: 'single',
    group: 'deduct',
    variants: ['雇用保険料', '雇用保険', '雇保料', '雇保'],
    deny: [],
  },
  {
    key: 'income_tax',
    kind: 'single',
    group: 'deduct',
    variants: ['源泉所得税', '所得税額', '所得税', '源泉税', '源泉徴収税額'],
    deny: ['課税対象額', '所得税調整'],
  },
  {
    key: 'resident_tax',
    kind: 'single',
    group: 'deduct',
    variants: ['市県民税', '市民税県民税', '住民税', '市民税', '県民税', '地方税', '特別徴収住民税'],
    deny: [],
  },
  {
    key: 'net_pay',
    kind: 'single',
    group: 'net',
    variants: [
      '差引支給額', '差引支払額', '差引支給', '銀行振込額', '振込支給額', '口座振込額', '差引額',
      '手取り額', '手取額', '手取り', '手取', '振込額', '支払額', 'お振込額', '差引合計額', 'net',
    ],
    deny: ['総支給額', '支給額合計', '支給合計', '課税支給額', '差引支給額累計'],
  },
];

/** 合計行（項目ではないが検算に使う） */
export const TOTAL_LEXICON = [
  {
    key: 'gross_total',
    variants: ['支給額合計', '総支給額', '支給合計', '支給額計', '支給計', '総支給', '支給総額', '合計支給額'],
    deny: ['差引'],
  },
  {
    key: 'deduction_total',
    variants: ['控除額合計', '控除合計', '控除額計', '控除計', '控除総額', '総控除額'],
    deny: [],
  },
];

/** 控除項目だが9項目に含まれないもの（合計の差分説明に使う） */
export const OTHER_DEDUCTION_VARIANTS = [
  '介護保険料', '介護保険', '財形貯蓄', '組合費', '社宅費', '生命保険料', '互助会費', '親睦会費',
  '積立金', '前払金', '貸付金返済', '欠勤控除',
];

function bestVariantScore(text, entry) {
  for (const d of entry.deny || []) {
    if (text.includes(d)) return null;
  }
  let best = null;
  for (const v of entry.variants) {
    const nv = normalizeLabel(v);
    const s = fuzzyContains(text, nv);
    if (!s) continue;
    // 長い表記ほど確実（「基本給」より「基本給額」を優先）
    const specificity = nv.length / Math.max(text.length, nv.length);
    const score = s * (0.65 + 0.35 * specificity);
    if (!best || score > best.score) best = { score, variant: v, exact: s === 1 };
  }
  return best;
}

/**
 * ラベル文字列から該当項目を判定する。
 * @returns {{key:string, score:number, variant:string, kind:string, group:string, loose?:boolean}|null}
 */
export function matchItemLabel(rawText) {
  const text = normalizeLabel(rawText);
  if (!text || text.length > 24) return null;

  let best = null;
  for (const entry of LEXICON) {
    const m = bestVariantScore(text, entry);
    if (!m) continue;
    const cand = { key: entry.key, score: m.score, variant: m.variant, kind: entry.kind, group: entry.group, exact: m.exact };
    if (!best || cand.score > best.score) best = cand;
  }
  if (best) return best;

  // どの辞書にも無い「〜手当」はその他手当としてゆるく拾う
  const other = LEXICON.find((e) => e.key === 'other_allowance');
  if (other.loosePattern.test(text) && !(other.deny || []).some((d) => text.includes(d))) {
    return { key: 'other_allowance', score: 0.55, variant: text, kind: 'aggregate', group: 'pay', loose: true };
  }
  return null;
}

/** 合計行（支給合計 / 控除合計）の判定。 */
export function matchTotalLabel(rawText) {
  const text = normalizeLabel(rawText);
  if (!text) return null;
  let best = null;
  for (const entry of TOTAL_LEXICON) {
    const m = bestVariantScore(text, entry);
    if (!m) continue;
    if (!best || m.score > best.score) best = { key: entry.key, score: m.score, variant: m.variant };
  }
  return best;
}

/** 9項目外の控除項目か。 */
export function isOtherDeduction(rawText) {
  const text = normalizeLabel(rawText);
  return OTHER_DEDUCTION_VARIANTS.some((v) => fuzzyContains(text, normalizeLabel(v)) > 0);
}
