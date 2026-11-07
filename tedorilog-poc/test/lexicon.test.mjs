import test from 'node:test';
import assert from 'node:assert/strict';
import { matchItemLabel, matchTotalLabel, isOtherDeduction } from '../engine/lexicon.js';

const expectKey = (text, key) => {
  const m = matchItemLabel(text);
  assert.ok(m, `${text} が辞書に一致しない`);
  assert.equal(m.key, key, `${text} -> ${m.key} (期待 ${key})`);
};

test('表記ゆれ辞書: 基本給', () => {
  ['基本給', '基本給額', '本給', '基準給', '月額基本給'].forEach((t) => expectKey(t, 'basic_pay'));
});

test('表記ゆれ辞書: 残業関連', () => {
  ['残業手当', '時間外手当', '時間外', '超過勤務手当', '所定外', '深夜手当', '休日出勤手当', '残業代']
    .forEach((t) => expectKey(t, 'overtime'));
});

test('表記ゆれ辞書: 社会保険・税', () => {
  ['健康保険', '健保', '健康保険料'].forEach((t) => expectKey(t, 'health_insurance'));
  ['厚生年金', '厚年', '厚生年金保険料', '厚年保険料'].forEach((t) => expectKey(t, 'pension'));
  ['雇用保険', '雇保', '雇用保険料'].forEach((t) => expectKey(t, 'employment_insurance'));
  ['所得税', '源泉所得税', '源泉税'].forEach((t) => expectKey(t, 'income_tax'));
  ['住民税', '市県民税', '市民税', '地方税'].forEach((t) => expectKey(t, 'resident_tax'));
});

test('表記ゆれ辞書: 差引支給額', () => {
  ['差引支給額', '差引支給', '手取額', '手取り', '振込額', '銀行振込額', '差引支給額（振込）']
    .forEach((t) => expectKey(t, 'net_pay'));
});

test('総支給額を差引支給額と取り違えない', () => {
  const gross = matchItemLabel('総支給額');
  assert.ok(!gross || gross.key !== 'net_pay', '総支給額が差引支給額に一致してはいけない');
  assert.equal(matchTotalLabel('総支給額').key, 'gross_total');
  assert.equal(matchTotalLabel('支給合計').key, 'gross_total');
  assert.equal(matchTotalLabel('控除合計').key, 'deduction_total');
  assert.equal(matchTotalLabel('控除額計').key, 'deduction_total');
  assert.equal(matchTotalLabel('差引支給額'), null, '差引支給額は合計行ではない');
});

test('残業系の手当をその他手当に混ぜない', () => {
  expectKey('時間外手当', 'overtime');
  expectKey('深夜手当', 'overtime');
  ['通勤手当', '住宅手当', '家族手当', '役職手当', '資格手当'].forEach((t) => expectKey(t, 'other_allowance'));
  expectKey('特殊作業手当', 'other_allowance'); // 辞書に無い手当はその他手当へ
});

test('介護保険など9項目外の控除を識別する', () => {
  assert.equal(isOtherDeduction('介護保険料'), true);
  assert.equal(isOtherDeduction('組合費'), true);
  assert.equal(isOtherDeduction('健康保険料'), false);
  const kaigo = matchItemLabel('介護保険料');
  assert.ok(!kaigo || kaigo.key !== 'health_insurance', '介護保険を健康保険に取り違えない');
});

test('勤怠の時間項目を金額項目として拾わない', () => {
  const m = matchItemLabel('残業時間');
  assert.ok(!m || m.key !== 'overtime', '残業時間は残業手当ではない');
});
