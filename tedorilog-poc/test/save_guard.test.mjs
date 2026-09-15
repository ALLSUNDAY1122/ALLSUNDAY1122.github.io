import test from 'node:test';
import assert from 'node:assert/strict';
import { extractPayslip, STATUS } from '../engine/extract.js';
import { buildSaveDraft } from '../engine/save_guard.js';
import { ITEM_KEYS } from '../engine/lexicon.js';

function sampleResult() {
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
    tokens.push({ text: label, x: 50, y: 100 + i * 20, w: 60, h: 10 });
    tokens.push({ text: amount, x: 300, y: 100 + i * 20, w: 50, h: 10 });
  });
  return extractPayslip(tokens, { route: 'pdf_text' });
}

const confirmAll = (result, patch = {}) => {
  const c = {};
  for (const key of ITEM_KEYS) {
    c[key] = { value: result.items[key].value, confirmed: true, ...(patch[key] || {}) };
  }
  return c;
};

test('確認していない項目があると保存できない', () => {
  const result = sampleResult();
  const draft = buildSaveDraft(result, confirmAll(result, { basic_pay: { confirmed: false } }));
  assert.equal(draft.ok, false);
  assert.equal(draft.payload, null);
  assert.equal(draft.blocked[0].key, 'basic_pay');
});

test('確定候補であってもユーザー確認なしには保存できない', () => {
  const result = sampleResult();
  assert.equal(result.items.net_pay.status, STATUS.CONFIRMED_CANDIDATE);
  const draft = buildSaveDraft(result, {}); // 何も確認していない
  assert.equal(draft.ok, false);
  assert.equal(draft.payload, null);
});

test('全項目を確認すれば保存データを作れる', () => {
  const result = sampleResult();
  const draft = buildSaveDraft(result, confirmAll(result));
  assert.equal(draft.ok, true);
  assert.equal(draft.payload.items.basic_pay.value, 250000);
  assert.equal(draft.payload.items.basic_pay.source, 'user_confirmed');
});

test('ユーザーが修正した値は user_edited として記録される', () => {
  const result = sampleResult();
  const draft = buildSaveDraft(result, confirmAll(result, { income_tax: { value: 5100 } }));
  assert.equal(draft.ok, true);
  assert.equal(draft.payload.items.income_tax.value, 5100);
  assert.equal(draft.payload.items.income_tax.source, 'user_edited');
  assert.equal(draft.payload.items.income_tax.suggested, 5000);
});

test('未検出項目は空欄のまま保存できる', () => {
  const tokens = [
    { text: '基本給', x: 50, y: 100, w: 60, h: 10 },
    { text: '250,000', x: 300, y: 100, w: 50, h: 10 },
  ];
  const result = extractPayslip(tokens, { route: 'pdf_text' });
  assert.equal(result.items.resident_tax.status, STATUS.NOT_FOUND);
  const draft = buildSaveDraft(result, { basic_pay: { value: 250000, confirmed: true } });
  assert.equal(draft.ok, true);
  assert.equal(draft.payload.items.resident_tax.value, null);
  assert.equal(draft.payload.items.resident_tax.source, 'empty');
});

test('誤認識した項目を未設定へ戻して保存できる', () => {
  const result = sampleResult();
  const draft = buildSaveDraft(
    result,
    confirmAll(result, { income_tax: { value: null, confirmed: true } }),
  );
  assert.equal(draft.ok, true);
  assert.equal(draft.payload.items.income_tax.value, null);
});

test('数値でない入力は保存を止める', () => {
  const result = sampleResult();
  const draft = buildSaveDraft(result, confirmAll(result, { pension: { value: Number.NaN } }));
  assert.equal(draft.ok, false);
  assert.equal(draft.blocked[0].key, 'pension');
});

test('保存データに明細の原文・画像は含めない', () => {
  const result = sampleResult();
  const draft = buildSaveDraft(result, confirmAll(result));
  const json = JSON.stringify(draft.payload);
  assert.ok(!json.includes('基本給250'), '原文テキストを保存しない');
  assert.ok(!/tokens/.test(json), 'トークン列を保存しない');
  assert.ok(!/image|dataUrl|base64/i.test(json), '画像データを保存しない');
});
