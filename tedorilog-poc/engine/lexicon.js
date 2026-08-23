// 9項目の判定辞書。
//
// 方針: 語をひとつずつ列挙するのではなく「語の作られ方」で判定する。
//   例) 残業関連 = (時間外|残業|超勤|所定外|法定外|深夜|休日) を含む支給項目
// 未知の明細では見たことのない言い回しが必ず出るため、列挙だけでは追従できない。
// 列挙リスト（canonical）はOCRで字が化けたときのあいまい一致用に残す。

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

// 勤怠欄など「金額ではない行」を項目として拾わないための共通除外
const TIME_LIKE = [/時間$/, /時間数/, /日数$/, /回数$/, /単価$/, /率$/];

export const LEXICON = [
  {
    key: 'basic_pay',
    kind: 'single',
    group: 'pay',
    patterns: [/基本給/, /^本給$/, /本俸/, /月例給/, /基準内(給与|賃金|給)/, /^基準給$/, /^標準給与$/],
    canonical: ['基本給', '基本給額', '本給', '本俸', '月例給', '基準内賃金', '基準内給与', '基準給'],
    deny: [/控除/, ...TIME_LIKE],
  },
  {
    key: 'overtime',
    kind: 'aggregate',
    group: 'pay',
    patterns: [/時間外/, /残業/, /超勤/, /超過勤務/, /所定外/, /法定外/, /深夜/, /休日/, /割増/],
    canonical: ['時間外手当', '残業手当', '時間外勤務手当', '超過勤務手当', '深夜手当', '休日出勤手当', '残業代'],
    deny: TIME_LIKE,
  },
  {
    key: 'other_allowance',
    kind: 'aggregate',
    group: 'pay',
    patterns: [
      /通勤(手当|費)/, /交通費/, /住宅(手当|補助)/, /家族手当/, /扶養手当/, /役職手当/, /職務手当/,
      /資格手当/, /技能手当/, /皆勤手当/, /精勤手当/, /食事(手当|補助)/, /在宅(勤務)?手当/,
      /地域手当/, /調整手当/, /現場手当/, /営業手当/, /単身赴任手当/, /特殊(作業)?手当/, /諸手当/,
      /その他(手当|支給)/,
    ],
    // 上のどれにも当たらない「〜手当」を拾うゆるい規則
    loosePattern: /(手当|手富|季当)$/,
    canonical: ['通勤手当', '住宅手当', '家族手当', '役職手当', '資格手当', '皆勤手当', '職務手当'],
    deny: [/残業/, /時間外/, /深夜/, /休日/, /超勤/, /所定外/, /割増/, ...TIME_LIKE],
  },
  {
    key: 'health_insurance',
    kind: 'single',
    group: 'deduct',
    patterns: [/健康保険/, /^健保/],
    canonical: ['健康保険料', '健康保険', '健保料', '健保'],
    deny: [/介護/, /基金/, ...TIME_LIKE],
  },
  {
    key: 'pension',
    kind: 'single',
    group: 'deduct',
    patterns: [/厚生年金/, /^厚年/],
    canonical: ['厚生年金保険料', '厚生年金', '厚年保険料', '厚年'],
    deny: [/国民年金/, /基金/, ...TIME_LIKE],
  },
  {
    key: 'employment_insurance',
    kind: 'single',
    group: 'deduct',
    patterns: [/雇用保険/, /^雇保/],
    canonical: ['雇用保険料', '雇用保険', '雇保'],
    deny: TIME_LIKE,
  },
  {
    key: 'income_tax',
    kind: 'single',
    group: 'deduct',
    patterns: [/所得税/, /源泉/],
    canonical: ['所得税', '源泉所得税', '源泉税', '所得税額'],
    deny: [/住民/, /市県民/, /市町村/, /調整$/, /課税対象/, ...TIME_LIKE],
  },
  {
    key: 'resident_tax',
    kind: 'single',
    group: 'deduct',
    patterns: [/住民税/, /市県民税/, /市民税/, /県民税/, /市町村民税/, /地方税/, /特別徴収/],
    canonical: ['住民税', '市県民税', '市民税', '地方税', '特別徴収住民税'],
    deny: TIME_LIKE,
  },
  {
    key: 'net_pay',
    kind: 'single',
    group: 'net',
    patterns: [/差引(支給|支払|合計|額)/, /手取/, /振込(額|金額)/, /^支払額$/, /^支給額$/],
    canonical: ['差引支給額', '差引支払額', '差引支給', '手取額', '振込額', '銀行振込額', '差引合計'],
    deny: [/総支給/, /支給合計/, /支給額合計/, /支給額計/, /課税/, /累計/, ...TIME_LIKE],
  },
];

/** 合計行（項目ではないが検算に使う） */
export const TOTAL_LEXICON = [
  {
    key: 'gross_total',
    patterns: [/総支給/, /支給(合計|額計|計|総額)/, /^合計支給額$/],
    canonical: ['総支給額', '支給合計', '支給額計', '支給計'],
    deny: [/差引/, /控除/, ...TIME_LIKE],
  },
  {
    key: 'deduction_total',
    patterns: [/控除(合計|額計|計|総額)/, /総控除/],
    canonical: ['控除合計', '控除額計', '控除計', '総控除額'],
    deny: [/支給/, ...TIME_LIKE],
  },
];

/** 控除項目だが9項目に含まれないもの（合計の差分説明に使う） */
export const OTHER_DEDUCTION_PATTERNS = [
  /介護保険/, /組合費/, /財形/, /社宅/, /生命保険/, /互助会/, /親睦会/, /共済/, /積立/,
  /貸付/, /前払/, /欠勤控除/, /遅刻早退/,
];

function denied(text, entry) {
  return (entry.deny || []).some((re) => re.test(text));
}

function patternScore(text, entry) {
  let best = null;
  for (const re of entry.patterns || []) {
    const m = text.match(re);
    if (!m) continue;
    // 一致した部分が長いほど確からしい。ラベル全体に占める割合も見る
    const coverage = m[0].length / Math.max(text.length, 1);
    const score = 0.9 + 0.1 * coverage;
    if (!best || score > best.score) best = { score, matched: m[0], length: m[0].length };
  }
  return best;
}

function fuzzyScore(text, entry) {
  let best = null;
  for (const variant of entry.canonical || []) {
    const s = fuzzyContains(text, normalizeLabel(variant));
    if (!s || s === 1) continue; // 完全包含はpatternで拾えているはず
    const score = s * 0.9;
    if (!best || score > best.score) best = { score, matched: variant, length: variant.length };
  }
  return best;
}

/**
 * ラベル文字列から該当項目を判定する。
 * @returns {{key:string, score:number, matched:string, kind:string, group:string, exact:boolean, loose?:boolean}|null}
 */
export function matchItemLabel(rawText) {
  const text = normalizeLabel(rawText);
  if (!text || text.length > 24) return null;

  let best = null;
  for (const entry of LEXICON) {
    if (denied(text, entry)) continue;
    const hit = patternScore(text, entry);
    if (!hit) continue;
    const cand = {
      key: entry.key, score: hit.score, matched: hit.matched,
      kind: entry.kind, group: entry.group, exact: true, length: hit.length,
    };
    if (!best || cand.score > best.score || (cand.score === best.score && cand.length > best.length)) best = cand;
  }
  if (best) return best;

  // 文字化けした項目名をあいまい一致で拾う
  for (const entry of LEXICON) {
    if (denied(text, entry)) continue;
    const hit = fuzzyScore(text, entry);
    if (!hit) continue;
    const cand = {
      key: entry.key, score: hit.score, matched: hit.matched,
      kind: entry.kind, group: entry.group, exact: false, length: hit.length,
    };
    if (!best || cand.score > best.score) best = cand;
  }
  if (best) return best;

  // どの規則にも当たらない「〜手当」はその他手当として拾う
  const other = LEXICON.find((e) => e.key === 'other_allowance');
  if (other.loosePattern.test(text) && !denied(text, other)) {
    return { key: 'other_allowance', score: 0.55, matched: text, kind: 'aggregate', group: 'pay', exact: false, loose: true };
  }
  return null;
}

/** 合計行（支給合計 / 控除合計）の判定。 */
export function matchTotalLabel(rawText) {
  const text = normalizeLabel(rawText);
  if (!text) return null;
  let best = null;
  for (const entry of TOTAL_LEXICON) {
    if (denied(text, entry)) continue;
    const hit = patternScore(text, entry) || fuzzyScore(text, entry);
    if (!hit) continue;
    if (!best || hit.score > best.score) best = { key: entry.key, score: hit.score, matched: hit.matched };
  }
  return best;
}

/** 9項目外の控除項目か。 */
export function isOtherDeduction(rawText) {
  const text = normalizeLabel(rawText);
  if (!text) return false;
  return OTHER_DEDUCTION_PATTERNS.some((re) => re.test(text));
}
