const test = require('node:test');
const assert = require('node:assert/strict');

const {
  generateOcrAwareQuestions,
  repairOcrText
} = require('../.tmp-regression/src/services/ocrAwareQuestionGenerator.js');

test('mobile OCR repair joins Japanese words and extracts insurance facts', () => {
  const source = `継 続 入院 所 得 保障 保険 ( 無 解約 返還 金 )2025
支払 事由 14 日 以上 継続 入院
メン タル 疾病 で の 14 日 以上 楼 続 入院
支払 限 度 各 10 回
パッ ケー ジ 契 約 : 給 付 金 月 額 3 万
単品 : 給 付 金 月 額 10 万
契約 年 齢 1575 歳
法人 契約 取扱 う ( 被 保険 者 を 従業 員 、 受 取 人 を 法人 と する )`;

  const repaired = repairOcrText(source);
  const cards = generateOcrAwareQuestions(source, 20, 'qa', 'normal');
  const serialized = JSON.stringify(cards);

  assert.match(repaired, /継続入院所得保障保険/);
  assert.match(serialized, /14日以上継続入院/);
  assert.match(serialized, /各10回/);
  assert.match(serialized, /3万円/);
  assert.match(serialized, /10万円/);
  assert.match(serialized, /15～75歳/);
  assert.match(serialized, /2025年/);
  assert.match(serialized, /被保険者は従業員、受取人は法人/);
});

test('mobile generator does not duplicate the same question', () => {
  const source = `現生人類が登場したとされるのは約30万年前である。
現生人類が登場したとされるのは約30万年前である。`;
  const cards = generateOcrAwareQuestions(source, 20, 'mix', 'normal');
  const questions = cards.map((card) => card.question.replace(/\s+/g, ''));

  assert.equal(new Set(questions).size, questions.length);
  assert.equal(cards.filter((card) => card.answer.includes('30万年前')).length, 1);
});

test('mobile generator leaves unsupported material empty', () => {
  const cards = generateOcrAwareQuestions(
    'これは短い見出しです。確認可能な数値や定義はありません。',
    20,
    'mix',
    'normal'
  );
  assert.equal(cards.length, 0);
});
