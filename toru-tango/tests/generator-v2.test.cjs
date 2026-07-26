const test = require('node:test');
const assert = require('node:assert/strict');

require('../generator-v2.js');

const generator = globalThis.ToruTangoGeneratorV2;

function parseCard(line) {
  const [front, ...back] = line.split('｜');
  return { front, back: back.join('｜') };
}

test('history material creates concrete date, place, and age cards', () => {
  const source = `人類は、数百万年前にアフリカ大陸で誕生した、とされている。
約540万年前アフリカ大陸で、現在のところ最古の猿人とよばれるアウストラロピテクスが登場した。
エチオピア北東部ハダール村付近では、318万年前のアウストラロピテクス・アファレンシスの化石骨が1974年11月24日に発見され、「ルーシー」と名付けられた。`;
  const cards = generator.generateQuestionsV2(source, 10, 'mix', 'normal').map(parseCard);
  const joined = JSON.stringify(cards);

  assert.ok(cards.length >= 3);
  assert.match(joined, /318万年前/);
  assert.match(joined, /1974年11月24日/);
  assert.doesNotMatch(joined, /本文ではどのように説明されていますか/);
  assert.doesNotMatch(joined, /人類史の/);
});

test('spaced insurance-table OCR is repaired and converted to useful cards', () => {
  const source = `継 続 入院 所 得 保障 保険 ( 無 解約 返還 金 )2025
支払 事由 14 日 以上 継続 入院
メン タル 疾病 で の 14 日 以上 楼 続 入院
支払 限 度 各 10 回
パッ ケー ジ 契 約 : 給 付 金 月 額 3 万
単品 : 給 付 金 月 額 10 万
契約 年 齢 1575 歳
法人 契約 取扱 う ( 被 保険 者 を 従業 員 、 受 取 人 を 法人 と する )`;
  const repaired = generator.repairOcrText(source);
  const cards = generator.generateQuestionsV2(source, 20, 'qa', 'normal').map(parseCard);
  const joined = JSON.stringify(cards);

  assert.match(repaired, /継続入院所得保障保険/);
  assert.match(joined, /14日以上継続入院/);
  assert.match(joined, /各10回/);
  assert.match(joined, /3万円/);
  assert.match(joined, /10万円/);
  assert.match(joined, /15～75歳/);
  assert.match(joined, /2025年/);
  assert.match(joined, /被保険者は従業員、受取人は法人/);
});

test('the same fact repeated in source does not create duplicate cards', () => {
  const sentence = '現生人類が登場したとされるのは約30万年前である。';
  const cards = generator.generateQuestionsV2(`${sentence}\n${sentence}\n${sentence}`, 10, 'mix', 'normal');
  const normalized = cards.map((line) => line.replace(/[\s「」『』（）()、，。・：:！？!?＿＿＿_]/g, ''));

  assert.equal(new Set(normalized).size, normalized.length);
  assert.equal(cards.filter((line) => line.includes('30万年前')).length, 1);
});

test('insufficient material does not invent cards to fill the requested count', () => {
  const cards = generator.generateQuestionsV2('これは短い見出しです。説明や数値はありません。', 20, 'mix', 'normal');
  assert.equal(cards.length, 0);
});

test('generated cards always have non-empty front and back', () => {
  const source = 'アウストラロピテクスが登場したのは約540万年前である。';
  const cards = generator.generateQuestionsV2(source, 10, 'mix', 'normal');
  assert.ok(cards.length > 0);
  for (const line of cards) {
    const card = parseCard(line);
    assert.ok(card.front.trim().length >= 5);
    assert.ok(card.back.trim().length >= 1);
  }
});
