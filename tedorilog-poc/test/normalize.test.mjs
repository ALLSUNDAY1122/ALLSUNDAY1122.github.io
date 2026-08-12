import test from 'node:test';
import assert from 'node:assert/strict';
import { parseAmount, normalizeLabel, toHalfWidth, fuzzyContains } from '../engine/normalize.js';

test('金額正規化: 一般的な表記', () => {
  assert.equal(parseAmount('1,234').value, 1234);
  assert.equal(parseAmount('¥1,234').value, 1234);
  assert.equal(parseAmount('￥1,234').value, 1234);
  assert.equal(parseAmount('1 234').value, 1234);
  assert.equal(parseAmount('1234円').value, 1234);
  assert.equal(parseAmount('280,000').value, 280000);
  assert.equal(parseAmount('０').value, 0);
});

test('金額正規化: 全角数字', () => {
  assert.equal(parseAmount('１２３，４５６').value, 123456);
  assert.equal(parseAmount('￥９８７').value, 987);
});

test('金額正規化: マイナス表記', () => {
  assert.equal(parseAmount('-1,234').value, -1234);
  assert.equal(parseAmount('△1,234').value, -1234);
  assert.equal(parseAmount('▲1,234').value, -1234);
  assert.equal(parseAmount('(1,234)').value, -1234);
  assert.equal(parseAmount('（1,234）').value, -1234);
  assert.equal(parseAmount('(¥19,220)').value, -19220);
  assert.equal(parseAmount('△1,234').negative, true);
});

test('金額正規化: OCRのゆれ', () => {
  assert.equal(parseAmount('13,7 00').value, 13700);
  assert.equal(parseAmount('67.736').value, 67736, 'カンマを点と誤読しても桁区切りとして扱う');
  assert.equal(parseAmount('A18,900').value, -18900, '△をAと誤読した場合も符号として扱う');
  assert.equal(parseAmount('1,234.00').value, 1234, '小数2桁は円未満として切り捨て');
  const noisy = parseAmount('12,3,45');
  assert.equal(noisy.value, 12345);
  assert.ok(noisy.confidence < 1, '桁区切り位置が不正なら信頼度を下げる');
});

test('金額正規化: 金額でないものを弾く', () => {
  assert.equal(parseAmount('2026年3月'), null);
  assert.equal(parseAmount('2026-03'), null);
  assert.equal(parseAmount('2026/03/25'), null);
  assert.equal(parseAmount('8:30'), null);
  assert.equal(parseAmount('20.5時間'), null);
  assert.equal(parseAmount('15%'), null);
  assert.equal(parseAmount('基本給'), null);
  assert.equal(parseAmount(''), null);
  assert.equal(parseAmount(null), null);
  assert.equal(parseAmount('---'), null);
});

test('ラベル正規化', () => {
  assert.equal(normalizeLabel('【支給】'), '支給');
  assert.equal(normalizeLabel('差引 支給額'), '差引支給額');
  assert.equal(normalizeLabel('健康保険料　'), '健康保険料');
  assert.equal(toHalfWidth('ＰＡＹ１２３'), 'PAY123');
});

test('あいまい一致は1文字違いまで許容する', () => {
  assert.equal(fuzzyContains('差引支給額', '差引支給額'), 1);
  assert.ok(fuzzyContains('差引支給客', '差引支給額') > 0, 'OCRの1文字誤りを吸収する');
  assert.equal(fuzzyContains('通勤手当', '基本給'), 0);
  assert.equal(fuzzyContains('所得', '住民税'), 0);
});
