import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, '..');
const baseBuilder = path.join(here, 'otsu4-build-content-v2.mjs');
const bankPath = path.join(repo, 'kikenbutsu-otsu4-sprint', 'questions.generated.json');
const wave3Path = path.join(repo, 'kikenbutsu-otsu4-sprint', 'question-bank-v3-wave3-certified.js');

execFileSync(process.execPath, [baseBuilder], { cwd: repo, stdio: 'inherit' });
const bank = JSON.parse(fs.readFileSync(bankPath, 'utf8'));
if (bank.questions.length !== 600) throw new Error(`wave2 base must be 600, got ${bank.questions.length}`);

const ctx = { QUESTIONS: bank.questions, CONTENT_VERSION: bank.contentVersion, console };
vm.createContext(ctx);
vm.runInContext(fs.readFileSync(wave3Path, 'utf8'), ctx, { timeout: 10000, filename: wave3Path });
const questions = ctx.QUESTIONS;

const expected = { total: 720, subjects: { '法令': 288, '物理・化学': 192, '性質・消火': 240 } };
const errors = [];
const counts = {};
const seen = { id: new Map(), question: new Map(), objective: new Map(), explanation: new Map() };
const fail = (id, msg) => errors.push(`${id}: ${msg}`);
const unique = (kind, key, id) => {
  if (seen[kind].has(key)) fail(id, `${kind} duplicates ${seen[kind].get(key)}`);
  else seen[kind].set(key, id);
};
const expectedRanges = { L: [1, 288], P: [1, 192], S: [1, 240] };
const paddingRe = /反復演習|比較セット\d+|undefined|NaN|本番で同じ知識を使う場面を想定する。|条件を取り違えないように判断する。|基本事項を応用して答える。|誤りやすい選択肢に注意して答える。/;

for (const q of questions) {
  counts[q.subject] = (counts[q.subject] || 0) + 1;
  unique('id', q.id, q.id);
  unique('question', String(q.question).trim(), q.id);
  unique('objective', String(q.learningObjective || '').trim(), q.id);
  unique('explanation', JSON.stringify([q.subject, q.point, q.detail]), q.id);
  if (!/^[LPS]\d{3}$/.test(q.id)) fail(q.id, 'bad stable id');
  if (!(q.subject in expected.subjects)) fail(q.id, `bad subject ${q.subject}`);
  if (!q.topic || !q.question || !q.point || !q.detail || !q.learningObjective) fail(q.id, 'required content missing');
  if (!Array.isArray(q.choices) || q.choices.length !== 5 || new Set(q.choices).size !== 5) fail(q.id, 'five unique choices required');
  if (!Number.isInteger(q.answer) || q.answer < 0 || q.answer > 4) fail(q.id, 'bad answer index');
  if (!q.sourceTitle || !q.sourceURL || !q.sourceCheckedAt || !q.sourceLocator) fail(q.id, 'source metadata missing');
  if (q.sourceCheckedAt !== '2026-08-09') fail(q.id, `sourceCheckedAt=${q.sourceCheckedAt}`);
  if (!Array.isArray(q.sourceRefs) || q.sourceRefs.length < 1 || q.sourceRefs.some(r => !r.title || !r.url || !r.locator)) fail(q.id, 'sourceRefs incomplete');
  if (paddingRe.test(`${q.question} ${q.point} ${q.detail}`)) fail(q.id, 'generic/padding marker detected');
  if (q.contentVersion !== bank.contentVersion) fail(q.id, `contentVersion=${q.contentVersion}`);
  const prefix = q.id[0];
  const number = Number(q.id.slice(1));
  const [min, max] = expectedRanges[prefix] || [0, -1];
  if (number < min || number > max) fail(q.id, `id outside final range ${prefix}${min}-${max}`);
  if (q.subject === '法令' && String(q.sourceURL).includes('laws.e-gov.go.jp')) {
    if (String(q.sourceURL).includes('323AC1000000186') && q.legalEffectiveDate !== '2025-06-01') fail(q.id, 'Fire Service Act effective date mismatch');
    if (String(q.sourceURL).includes('334CO0000000306') && q.legalEffectiveDate !== '2026-04-04') fail(q.id, 'Cabinet Order effective date mismatch');
  }
}
if (questions.length !== expected.total) errors.push(`total ${questions.length} != ${expected.total}`);
for (const [subject, count] of Object.entries(expected.subjects)) if (counts[subject] !== count) errors.push(`${subject} ${counts[subject]} != ${count}`);
const wave3 = questions.filter(q =>
  (q.id.startsWith('L') && Number(q.id.slice(1)) >= 241) ||
  (q.id.startsWith('P') && Number(q.id.slice(1)) >= 161) ||
  (q.id.startsWith('S') && Number(q.id.slice(1)) >= 201)
);
if (wave3.length !== 120) errors.push(`wave3 ${wave3.length} != 120`);
if (wave3.filter(q => q.subject === '法令').length !== 48) errors.push('wave3 law count != 48');
if (wave3.filter(q => q.subject === '物理・化学').length !== 32) errors.push('wave3 physics count != 32');
if (wave3.filter(q => q.subject === '性質・消火').length !== 40) errors.push('wave3 properties count != 40');
const report = { ok: errors.length === 0, stage: 'Wave3 final 720', total: questions.length, counts, exactQuestionDuplicates: questions.length - seen.question.size, duplicateLearningObjectives: questions.length - seen.objective.size, duplicateExplanationPackages: questions.length - seen.explanation.size, wave3Count: wave3.length, errors };
console.log(JSON.stringify(report, null, 2));
if (errors.length) process.exit(1);
if (!process.argv.includes('--check')) fs.writeFileSync(bankPath, JSON.stringify({ ...bank, questions }, null, 2) + '\n');
