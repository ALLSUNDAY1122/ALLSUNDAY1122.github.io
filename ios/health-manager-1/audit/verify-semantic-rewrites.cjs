'use strict';
// Fail-closed release assertion for three independently redesigned HM1 exercise items.
// Run immediately AFTER augment-to-264.cjs writes Resources/questions.json.
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const read = p => JSON.parse(fs.readFileSync(path.join(root, p), 'utf8'));
const generated = read('Resources/questions.json');
if (!Array.isArray(generated) || generated.length !== 264 ||
    new Set(generated.map(q => q.id)).size !== 264) {
  throw new Error('HM1 semantic gate: expected 264 unique generated questions');
}
const a = read('audit/practice_a_fixes_01_10.json').questions;
const b = read('content-overrides-b-20261110.json');
const selected = new Map([
  ['practice-A-Q13', a['practice-A-Q13']],
  ['practice-A-Q38', a['practice-A-Q38']],
  ['practice-B-Q13', b.find(e => e.id === 'practice-B-Q13')?.replacement]
]);
for (const [id, patch] of selected) {
  const q = generated.find(x => x.id === id);
  if (!q || !patch) throw new Error(id + ': missing generated item or source patch');
  for (const field of ['stem', 'choices', 'ans', 'detail', 'key', 'sourceRef', 'auditSourceURL']) {
    if (JSON.stringify(q[field]) !== JSON.stringify(patch[field])) {
      throw new Error(id + ': generated ' + field + ' differs from source patch');
    }
  }
  if (!Array.isArray(q.choices) || q.choices.length !== 5 ||
      new Set(q.choices).size !== 5 || !Number.isInteger(q.ans) ||
      q.ans < 0 || q.ans > 4 ||
      q.short !== '正解は「' + q.choices[q.ans] + '」です。') {
    // Practice B has a source-provided short answer text; the generator retains it,
    // so the string check above applies to A only.
    if (!id.startsWith('practice-B-') ||
        !Array.isArray(q.choices) || q.choices.length !== 5 ||
        new Set(q.choices).size !== 5 || !Number.isInteger(q.ans) ||
        q.ans < 0 || q.ans > 4 ||
        !q.short || !q.short.includes(q.choices[q.ans])) {
      throw new Error(id + ': invalid answer or short explanation');
    }
  }
}
const distribution = [0, 0, 0, 0, 0];
for (const q of generated) {
  if (!Array.isArray(q.choices) || q.choices.length !== 5 ||
      !Number.isInteger(q.ans) || q.ans < 0 || q.ans > 4)
    throw new Error(q.id + ': invalid 5-choice answer structure');
  distribution[q.ans]++;
}
if (JSON.stringify(distribution) !== JSON.stringify([53, 53, 53, 53, 52])) {
  throw new Error('HM1 semantic gate: answer distribution drift: ' + distribution);
}
console.log('PASS: 3 redesigned HM1 exercise items match generated 264-question bank; answer positions 53/53/53/53/52');
