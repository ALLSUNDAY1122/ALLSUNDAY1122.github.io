import test from 'node:test';
import assert from 'node:assert/strict';
import { extractPayslip, extractPayslipBest, STATUS } from '../engine/extract.js';

/** 行・列を指定して簡易にトークンを組み立てる。 */
function tok(text, x, y, { w, h = 10, conf = 1 } = {}) {
  return { text, x, y, w: w ?? text.length * 6, h, conf };
}

function simpleSlip(overrides = {}) {
  const rows = [
    ['基本給', '250,000'],
    ['残業手当', '30,000'],
    ['通勤手当', '10,000'],
    ['支給合計', '290,000'],
    ['健康保険料', '14,000'],
    ['厚生年金保険料', '26,000'],
    ['雇用保険料', '1,740'],
    ['所得税', '5,000'],
    ['住民税', '12,000'],
    ['控除合計', '58,740'],
    ['差引支給額', '231,260'],
  ];
  const tokens = [];
  rows.forEach(([label, amount], i) => {
    const y = 100 + i * 20;
    tokens.push(tok(overrides[label]?.label ?? label, 50, y));
    tokens.push(tok(overrides[label]?.amount ?? amount, 300, y, { w: 50 }));
  });
  return tokens;
}

test('同一行・右隣の金額を項目に割り当てる', () => {
  const result = extractPayslip(simpleSlip(), { route: 'pdf_text' });
  assert.equal(result.ok, true);
  assert.equal(result.items.basic_pay.value, 250000);
  assert.equal(result.items.overtime.value, 30000);
  assert.equal(result.items.other_allowance.value, 10000);
  assert.equal(result.items.health_insurance.value, 14000);
  assert.equal(result.items.net_pay.value, 231260);
});

test('項目の間に別ラベルがある場合、境界を越えて金額を取らない', () => {
  const tokens = [
    tok('基本給', 50, 100),
    tok('250,000', 200, 100, { w: 50 }),
    tok('健康保険料', 300, 100),
    tok('14,000', 450, 100, { w: 50 }),
  ];
  const result = extractPayslip(tokens, { route: 'pdf_text' });
  assert.equal(result.items.basic_pay.value, 250000);
  assert.equal(result.items.health_insurance.value, 14000);
});

test('残業関連・その他手当は複数行を合算する', () => {
  const tokens = [
    tok('基本給', 50, 100), tok('250,000', 300, 100, { w: 50 }),
    tok('時間外手当', 50, 120), tok('20,000', 300, 120, { w: 50 }),
    tok('深夜手当', 50, 140), tok('5,000', 300, 140, { w: 50 }),
    tok('通勤手当', 50, 160), tok('8,000', 300, 160, { w: 50 }),
    tok('住宅手当', 50, 180), tok('12,000', 300, 180, { w: 50 }),
  ];
  const result = extractPayslip(tokens, { route: 'pdf_text' });
  assert.equal(result.items.overtime.value, 25000);
  assert.equal(result.items.other_allowance.value, 20000);
});

test('ラベルの真下にある金額（列ヘッダ型）を対応付ける', () => {
  const tokens = [
    tok('本給', 60, 100, { w: 20 }), tok('時間外', 160, 100, { w: 30 }), tok('通勤費', 260, 100, { w: 30 }),
    tok('295,000', 55, 130, { w: 45 }), tok('51,200', 160, 130, { w: 40 }), tok('10,500', 260, 130, { w: 40 }),
  ];
  const result = extractPayslip(tokens, { route: 'pdf_text' });
  assert.equal(result.items.basic_pay.value, 295000);
  assert.equal(result.items.overtime.value, 51200);
  assert.equal(result.items.other_allowance.value, 10500);
});

test('支給・控除・差引の整合検算が行われる', () => {
  const result = extractPayslip(simpleSlip(), { route: 'pdf_text' });
  const byId = Object.fromEntries(result.checks.map((c) => [c.id, c]));
  assert.equal(byId.pay_total.ok, true);
  assert.equal(byId.deduction_total.ok, true);
  assert.equal(byId.net_pay.ok, true);
  assert.equal(result.items.net_pay.status, STATUS.CONFIRMED_CANDIDATE);
});

test('検算が合わない項目は確定候補にしない', () => {
  const tokens = simpleSlip({ 基本給: { amount: '260,000' } }); // 支給合計と不整合
  const result = extractPayslip(tokens, { route: 'pdf_text' });
  const byId = Object.fromEntries(result.checks.map((c) => [c.id, c]));
  assert.equal(byId.pay_total.ok, false);
  assert.equal(result.items.basic_pay.status, STATUS.NEEDS_REVIEW);
});

test('差引支給額が未検出なら合計から算出した候補を要確認で出す', () => {
  const tokens = simpleSlip().filter((t) => t.text !== '差引支給額' && t.text !== '231,260');
  const result = extractPayslip(tokens, { route: 'pdf_text' });
  assert.equal(result.items.net_pay.value, 231260);
  assert.equal(result.items.net_pay.status, STATUS.NEEDS_REVIEW);
  assert.equal(result.items.net_pay.derived, true);
});

test('OCR経路では検算の裏付けが無い項目を確定候補にしない', () => {
  const tokens = [
    tok('基本給', 50, 100), tok('250,000', 300, 100, { w: 50, conf: 0.95 }),
    tok('健康保険料', 50, 120), tok('14,000', 300, 120, { w: 50, conf: 0.95 }),
  ];
  const result = extractPayslip(tokens, { route: 'ocr' });
  assert.equal(result.items.basic_pay.value, 250000);
  assert.equal(result.items.basic_pay.status, STATUS.NEEDS_REVIEW);
});

test('OCRの桁誤りを合計から補正し、必ず要確認にする', () => {
  const tokens = simpleSlip({ 基本給: { amount: '250,900' } }).map((t) =>
    t.text === '250,900' ? { ...t, conf: 0.4 } : { ...t, conf: 0.95 });
  const result = extractPayslip(tokens, { route: 'ocr' });
  assert.equal(result.items.basic_pay.value, 250000, '合計と整合する値へ補正する');
  assert.equal(result.items.basic_pay.status, STATUS.NEEDS_REVIEW);
  assert.equal(result.items.basic_pay.corrected, true);
  assert.ok(result.items.basic_pay.alternatives.some((a) => a.value === 250900), '元の読み取り値を残す');
});

test('PDF直接抽出では桁補正を行わない（文字が正確なため）', () => {
  const tokens = simpleSlip({ 基本給: { amount: '250,900' } });
  const result = extractPayslip(tokens, { route: 'pdf_text' });
  assert.equal(result.items.basic_pay.value, 250900);
  assert.ok(!result.items.basic_pay.corrected);
});

test('複数の読み取り結果から検算の通る方を選ぶ', () => {
  const good = simpleSlip();
  const bad = simpleSlip({ 基本給: { label: 'XXX' }, 住民税: { label: 'YYY' }, 差引支給額: { label: 'ZZZ' } });
  const result = extractPayslipBest(
    [{ name: 'bad', tokens: bad }, { name: 'good', tokens: good }],
    { route: 'ocr' },
  );
  assert.equal(result.variant, 'good');
  assert.equal(result.items.basic_pay.value, 250000);
});

test('入力異常でもクラッシュせずエラーを返す', () => {
  const empty = extractPayslip([], { route: 'pdf_text' });
  assert.equal(empty.ok, false);
  assert.equal(empty.error, 'no_text_detected');
  assert.equal(empty.items.basic_pay.status, STATUS.NOT_FOUND);

  const broken = extractPayslip('これは配列ではない', { route: 'ocr' });
  assert.equal(broken.ok, false);
  assert.equal(broken.error, 'invalid_input');

  const nullish = extractPayslip(null, { route: 'ocr' });
  assert.equal(nullish.ok, false);

  const junk = extractPayslip(
    [{ text: '   ', x: 0, y: 0 }, { text: null, x: 1, y: 1 }, { x: 2, y: 2 }],
    { route: 'ocr' },
  );
  assert.equal(junk.ok, false);
  assert.equal(junk.error, 'no_text_detected');

  const noise = extractPayslip([tok('◆◆◆', 10, 10), tok('■', 20, 30)], { route: 'ocr' });
  assert.equal(noise.ok, true);
  assert.equal(noise.summary.notFound, 9);
});

test('傾いた紙でも同じ行として扱える', () => {
  const slope = 0.045; // 約2.6度
  const tokens = simpleSlip().map((t) => ({ ...t, y: t.y + slope * t.x }));
  const result = extractPayslip(tokens, { route: 'ocr' });
  assert.equal(result.items.basic_pay.value, 250000);
  assert.equal(result.items.net_pay.value, 231260);
  assert.ok(Math.abs(result.stats.skewSlope - slope) < 0.01, '傾きを推定できている');
});
