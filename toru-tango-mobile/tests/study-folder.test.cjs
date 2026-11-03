const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require('typescript');

const source = fs.readFileSync('app/(tabs)/study.tsx', 'utf8');
const start = source.indexOf('function shuffle<T>');
const end = source.indexOf('export default function StudyScreen()');
assert.ok(start >= 0 && end > start, 'Must locate production study queue implementation');

const isolated = source.slice(start, end) + '\nmodule.exports = { buildStudyQueue };';
const js = ts.transpileModule(isolated, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText;
const moduleRef = { exports: {} };
vm.runInNewContext(js, {
  module: moduleRef,
  Math,
  getCardReviewStage: (card) => card.reviewStage || 'review',
  isReviewDue: (card) => (card.reviewStage || 'review') === 'review' && !card.nextReviewAt
}, { timeout: 1000 });
const { buildStudyQueue } = moduleRef.exports;

const cards = [
  { id: 'en1', deckName: '英語', isHidden: false, correct: 0, wrong: 0, reviewStage: 'review', nextReviewAt: null },
  { id: 'en2', deckName: '英語', isHidden: true, correct: 0, wrong: 0, reviewStage: 'review', nextReviewAt: null },
  { id: 'en3', deckName: '英語', isHidden: false, correct: 0, wrong: 2, reviewStage: 'weak' },
  { id: 'hist1', deckName: '日本史', isHidden: false, correct: 1, wrong: 0, reviewStage: 'mastered' },
  { id: 'legacy', isHidden: false, correct: 0, wrong: 0, reviewStage: 'review', nextReviewAt: null }
];
const ids = (items) => Array.from(items, (card) => card.id);

test('all folders remains the default and includes legacy cards', () => {
  assert.deepEqual(ids(buildStudyQueue(cards, 'all', 'normal', 'all', null)),
    ['en1', 'en2', 'en3', 'hist1', 'legacy']);
});

test('a selected folder never mixes in cards from other folders', () => {
  assert.deepEqual(ids(buildStudyQueue(cards, 'all', 'normal', 'all', '英語')),
    ['en1', 'en2', 'en3']);
  assert.deepEqual(ids(buildStudyQueue(cards, 'all', 'normal', 'all', '日本史')),
    ['hist1']);
});

test('the existing visible-only setting still applies after choosing a folder', () => {
  assert.deepEqual(ids(buildStudyQueue(cards, 'all', 'normal', 'visible', '英語')),
    ['en1', 'en3']);
});

test('existing learning modes continue to intersect with the folder filter', () => {
  assert.deepEqual(ids(buildStudyQueue(cards, 'weak', 'normal', 'all', '英語')), ['en3']);
  assert.deepEqual(ids(buildStudyQueue(cards, 'unseen', 'normal', 'all', '英語')), ['en1', 'en2']);
  assert.deepEqual(ids(buildStudyQueue(cards, 'mastered', 'normal', 'all', '英語')), []);
  assert.deepEqual(ids(buildStudyQueue(cards, 'review', 'normal', 'all', '英語')), ['en1', 'en2']);
});

test('legacy cards without deckName belong only to the メイン folder', () => {
  assert.deepEqual(ids(buildStudyQueue(cards, 'all', 'normal', 'all', 'メイン')), ['legacy']);
  assert.deepEqual(ids(buildStudyQueue(cards, 'all', 'normal', 'all', '英語')), ['en1', 'en2', 'en3']);
});

test('empty folders return zero eligible cards and cannot enter another folder', () => {
  assert.equal(buildStudyQueue(cards, 'all', 'normal', 'all', '未作成のフォルダ').length, 0);
});

test('the Study screen keeps the folder selector and zero-card start guard', () => {
  assert.match(source, /<Section title="学習するフォルダ">/);
  assert.match(source, /disabled=\{!eligibleCount\}/);
  assert.match(source, /setSessionDeck\(activeDeck\)/);
  assert.match(source, /const activeDeck = selectedDeck !== null && deckCounts\.has\(selectedDeck\)/);
});
