import fs from 'node:fs';
import vm from 'node:vm';

const source = fs.readFileSync(new URL('./questions.js', import.meta.url), 'utf8');
const context = vm.createContext({});
vm.runInContext(`${source}\nthis.__QUESTIONS = TSUKANSHI_QUESTIONS; this.__VERSION = TSUKANSHI_CONTENT_VERSION; this.__BASELINE = TSUKANSHI_LAW_BASELINE;`, context);

const questions = context.__QUESTIONS;
const version = context.__VERSION;
const baseline = context.__BASELINE;
const errors = [];
const warnings = [];
const ids = new Set();
const questionText = new Map();

const fail = (id, message) => errors.push(`${id || 'GLOBAL'}: ${message}`);
const warn = (id, message) => warnings.push(`${id || 'GLOBAL'}: ${message}`);

if (!Array.isArray(questions) || questions.length === 0) fail(null, 'questions is empty');
if (!version) fail(null, 'content version is missing');
if (!/^\d{4}-\d{2}-\d{2}$/.test(baseline || '')) fail(null, 'law baseline must be YYYY-MM-DD');

for (const q of questions || []) {
  const id = q.id || 'NO_ID';
  if (!q.id) fail(id, 'id is required');
  if (ids.has(q.id)) fail(id, 'duplicate id');
  ids.add(q.id);

  for (const key of ['subject', 'topic', 'answerType', 'question', 'point', 'detail', 'lawBaseline', 'auditStatus']) {
    if (q[key] === undefined || q[key] === null || String(q[key]).trim() === '') fail(id, `${key} is required`);
  }

  if (q.auditStatus !== 'approved') warn(id, 'not approved; must not be exposed in production UI');
  if (q.lawBaseline !== baseline) warn(id, `law baseline ${q.lawBaseline} differs from active ${baseline}`);

  const normalized = String(q.question || '').replace(/\s+/g, ' ').trim();
  if (normalized) {
    if (questionText.has(normalized)) fail(id, `duplicate question text with ${questionText.get(normalized)}`);
    questionText.set(normalized, id);
  }

  switch (q.answerType) {
    case 'singleChoice': {
      if (!Array.isArray(q.choices) || q.choices.length < 2) fail(id, 'singleChoice requires choices');
      if (!Number.isInteger(q.answer) || q.answer < 0 || q.answer >= (q.choices?.length || 0)) fail(id, 'answer index is invalid');
      break;
    }
    case 'multiChoice': {
      if (!Array.isArray(q.choices) || q.choices.length < 2) fail(id, 'multiChoice requires choices');
      if (!Array.isArray(q.answers) || q.answers.length < 2) fail(id, 'multiChoice requires at least two answers');
      if (new Set(q.answers || []).size !== (q.answers || []).length) fail(id, 'answers contains duplicates');
      if ((q.answers || []).some(v => !Number.isInteger(v) || v < 0 || v >= (q.choices?.length || 0))) fail(id, 'multiChoice answer index is invalid');
      if (q.selectionCount !== undefined && q.selectionCount !== q.answers?.length) fail(id, 'selectionCount does not match answers length');
      break;
    }
    case 'blankSelect': {
      if (!Array.isArray(q.blanks) || q.blanks.length === 0) fail(id, 'blankSelect requires blanks');
      for (const b of q.blanks || []) {
        if (!b.label || !Array.isArray(b.options) || !b.options.includes(b.answer)) fail(id, `blank ${b.label || '?'} answer must exist in options`);
      }
      break;
    }
    case 'numeric': {
      if (!Number.isFinite(q.correctNumber)) fail(id, 'numeric correctNumber must be finite');
      if (!q.unit) fail(id, 'numeric unit is required');
      if (q.acceptedRange !== undefined && (!Number.isFinite(q.acceptedRange) || q.acceptedRange < 0)) fail(id, 'acceptedRange must be >= 0');
      break;
    }
    case 'declaration': {
      if (!q.sourceText) fail(id, 'declaration sourceText is required');
      if (!Array.isArray(q.declarationFields) || q.declarationFields.length === 0) fail(id, 'declarationFields is required');
      const keys = new Set();
      for (const f of q.declarationFields || []) {
        if (!f.key || !f.label || !f.answer) fail(id, 'declaration field key/label/answer is required');
        if (keys.has(f.key)) fail(id, `duplicate declaration field key ${f.key}`);
        keys.add(f.key);
      }
      break;
    }
    default:
      fail(id, `unsupported answerType: ${q.answerType}`);
  }
}

console.log(`Content version: ${version}`);
console.log(`Law baseline: ${baseline}`);
console.log(`Questions: ${questions?.length || 0}`);
if (warnings.length) {
  console.log('\nWarnings:');
  warnings.forEach(x => console.log(`- ${x}`));
}
if (errors.length) {
  console.error('\nErrors:');
  errors.forEach(x => console.error(`- ${x}`));
  process.exit(1);
}
console.log('\nContent audit passed.');
