'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const IOS_DIR = __dirname;
const REPO_ROOT = path.resolve(IOS_DIR, '..', '..');
const WEB = path.join(REPO_ROOT, 'apps', 'sanitary-manager-2');

global.window = { Q_PARTS: [] };
global.localStorage = { getItem: () => null, setItem: () => {} };

const scripts = [
  'q1.js','q2.js','q3.js','q4.js','q5.js','q6.js','q7.js','q8.js','q9.js',
  'audit-patch-v2.js','audit-fixes.js','question-order-v1.js'
];
for (const file of scripts) {
  const full = path.join(WEB, file);
  if (!fs.existsSync(full)) throw new Error(`Missing release input: ${file}`);
  vm.runInThisContext(fs.readFileSync(full, 'utf8'), { filename: full });
}

const questions = window.Q_PARTS;
if (questions.length !== 90) throw new Error(`Expected 90 questions, got ${questions.length}`);

const examRound = {'令和8年4月':1,'令和7年10月':2,'令和7年4月':3};
const subjects = ['関係法令','労働衛生','労働生理'];
const groups = new Map();
for (const q of questions) {
  const key = `${q.examSet}|${q.subject}`;
  if (!groups.has(key)) groups.set(key, []);
  groups.get(key).push(q);
}
if (groups.size !== 9) throw new Error(`Expected 9 exam/subject groups, got ${groups.size}`);

for (const [key, qs] of groups) {
  if (qs.length !== 10) throw new Error(`${key}: expected 10 questions, got ${qs.length}`);
  const positions = [0,0,0,0,0];
  for (const q of qs) {
    if (!Array.isArray(q.choices) || q.choices.length !== 5) throw new Error(`${q.id}: choices must be 5`);
    if (!Number.isInteger(q.answer) || q.answer < 1 || q.answer > 5) throw new Error(`${q.id}: invalid answer ${q.answer}`);
    positions[q.answer - 1]++;
  }
  if (!positions.every(n => n === 2)) throw new Error(`${key}: answer positions are biased: ${positions.join(',')}`);
}

const required = ['id','examSet','subject','topic','question','choices','answer','quick','explanation','basis','sourceUrl','baselineDate','originType','rightsBasis'];
for (const q of questions) {
  for (const field of required) {
    const value = q[field];
    if (value === undefined || value === null || value === '' || (Array.isArray(value) && value.length === 0)) {
      throw new Error(`${q.id || '?'}: missing ${field}`);
    }
  }
  if (!examRound[q.examSet]) throw new Error(`${q.id}: unknown examSet ${q.examSet}`);
  if (!subjects.includes(q.subject)) throw new Error(`${q.id}: unknown subject ${q.subject}`);
}

const out = questions.map(q => ({
  id: q.id,
  round: examRound[q.examSet],
  exam_set: q.examSet,
  subject: q.subject,
  topic: q.topic,
  question: q.question,
  choices: q.choices,
  correct_index: q.answer - 1,
  quick: q.quick,
  explanation: q.explanation,
  primary_basis: q.basis,
  source_url: q.sourceUrl,
  baseline_date: q.baselineDate,
  origin_type: q.originType,
  rights_basis: q.rightsBasis
}));

const outPath = path.join(IOS_DIR, 'release-questions.json');
fs.writeFileSync(outPath, JSON.stringify(out, null, 2) + '\n');
console.log(`Exported ${out.length} audited questions to ${outPath}`);
console.log('PASS: 9 groups x 10 questions, 5 choices each, answer positions 1-5 each exactly twice per group.');
