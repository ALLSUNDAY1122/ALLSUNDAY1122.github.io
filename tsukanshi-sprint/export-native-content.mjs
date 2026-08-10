import fs from 'node:fs';
import vm from 'node:vm';

const files = [
  'questions.js','sources-v02.js','questions-v02-tb.js','questions-v02-ks1.js','questions-v02-ks2.js','questions-v02-ks3.js','questions-v02-ks4.js',
  'questions-v02-jm1.js','questions-v02-jm2.js','questions-v02-jm3.js','questions-v02-jm4.js','sources-v03.js','questions-v03-tb.js',
  'questions-v03-audit1.js','questions-v03-audit1-order.js','questions-v03-audit1-polish.js','questions-editorial-audit2-7.js','questions-editorial-final-polish.js'
];

const context = vm.createContext({console});
for (const file of files) {
  const source = fs.readFileSync(new URL(`./${file}`, import.meta.url), 'utf8');
  vm.runInContext(source, context, {filename:file});
}
vm.runInContext(`
  this.__QUESTIONS = TSUKANSHI_QUESTIONS;
  this.__VERSION = TSUKANSHI_CONTENT_VERSION;
  this.__BASELINE = TSUKANSHI_LAW_BASELINE;
  this.__SOURCES = typeof TSUKANSHI_SOURCE_CATALOG_V02 !== 'undefined' ? TSUKANSHI_SOURCE_CATALOG_V02 : {};
`, context);

const Q = context.__QUESTIONS || [];
const version = context.__VERSION;
const baseline = context.__BASELINE;
const sources = context.__SOURCES || {};
if (Q.length !== 492) throw new Error(`expected 492 total questions, got ${Q.length}`);
if (Q.filter(q => q.answerType !== 'declaration').length !== 480) throw new Error('study count must be 480');
if (Q.filter(q => q.answerType === 'declaration').length !== 12) throw new Error('declaration count must be 12');
if (!version || !baseline) throw new Error('missing content version or law baseline');

const allowedRights = new Set(['original','allowed','licensed']);
let numericSeen = 0;
const normalize = q => {
  if (q.auditStatus !== 'approved') throw new Error(`unapproved question: ${q.id}`);
  if (!allowedRights.has(q.rightsStatus)) throw new Error(`unsafe rights status: ${q.id} / ${q.rightsStatus}`);

  const refs = Array.isArray(q.sourceRefs) ? q.sourceRefs : [];
  const primary = refs.map(ref => sources[ref]).find(Boolean);
  const type = q.answerType;
  let premium = false;
  if (type === 'numeric') {
    numericSeen += 1;
    premium = numericSeen > 12;
  } else if (type === 'declaration') {
    premium = true;
  }
  const blanks = (q.blanks || []).map((b, index) => ({
    key: String(b.key || b.label || `blank-${index+1}`),
    label: String(b.label || `空欄${index+1}`),
    options: (b.options || []).map(String),
    correctValue: String(b.answer ?? '')
  }));
  const declarationFields = (q.declarationFields || []).map(f => ({
    key: String(f.key),
    label: String(f.label),
    correctValue: String(f.answer),
    aliases: Array.isArray(f.aliases) ? f.aliases.map(String) : []
  }));
  const correctIndices = type === 'singleChoice'
    ? [q.answer]
    : type === 'multiChoice' ? (q.answers || []) : [];
  const checkedAt = q.sourceCheckedAt || primary?.checkedAt || q.auditedAt || q.editorialAuditDate || q.auditDate || '2026-08-09';
  const sourceTitle = q.sourceTitle || primary?.title || null;
  const sourceURL = q.sourceUrl || q.sourceURL || primary?.url || null;
  const rightsBasis = [
    q.rightsStatus,
    q.sourceType,
    q.transformationNote,
    q.rightsBasis
  ].filter(Boolean).map(String).join(' | ') || null;

  return {
    id: String(q.id),
    subject: String(q.subject),
    topic: String(q.topic),
    answerType: type,
    prompt: String(q.question),
    choices: (q.choices || []).map(String),
    correctIndices,
    correctNumber: Number.isFinite(q.correctNumber) ? q.correctNumber : null,
    acceptedRange: Number.isFinite(q.acceptedRange) ? q.acceptedRange : null,
    unit: q.unit ? String(q.unit) : null,
    roundingRule: q.roundingRule ? String(q.roundingRule) : null,
    blanks,
    declarationFields,
    sourceText: q.sourceText ? String(q.sourceText) : null,
    memoryPoint: String(q.point),
    explanation: String(q.detail),
    sourceTitle,
    sourceURL,
    sourceRefs: refs,
    sourceCheckedAt: checkedAt,
    lawBaselineDate: String(q.lawBaseline || baseline),
    contentVersion: version,
    premium,
    examRound: q.examRound ? String(q.examRound) : null,
    questionNumber: q.questionNo ? String(q.questionNo) : null,
    rightsBasis
  };
};

const questions = Q.map(normalize);
const ids = new Set();
const promptMap = new Map();
for (const q of questions) {
  if (!q.id || ids.has(q.id)) throw new Error(`duplicate or empty id: ${q.id}`);
  ids.add(q.id);
  const signature = q.prompt.replace(/\s+/g, '').trim();
  if (promptMap.has(signature)) throw new Error(`duplicate prompt: ${q.id} / ${promptMap.get(signature)}`);
  promptMap.set(signature, q.id);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(q.sourceCheckedAt)) throw new Error(`invalid sourceCheckedAt: ${q.id}`);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(q.lawBaselineDate)) throw new Error(`invalid lawBaselineDate: ${q.id}`);
  if (!q.rightsBasis) throw new Error(`missing rights basis: ${q.id}`);
  if (q.answerType === 'numeric' && !q.roundingRule) throw new Error(`numeric roundingRule missing: ${q.id}`);
}

const output = {
  schemaVersion: 1,
  contentVersion: version,
  lawBaselineDate: baseline,
  exportedAt: new Date().toISOString(),
  studyQuestionCount: 480,
  declarationCount: 12,
  freeNumericCount: questions.filter(q => q.answerType === 'numeric' && !q.premium).length,
  questions
};

const outputPath = process.argv[2] || new URL('./native-ios/Resources/tsukanshi-questions.json', import.meta.url);
const path = outputPath instanceof URL ? outputPath : new URL(outputPath, `file://${process.cwd()}/`);
fs.mkdirSync(new URL('.', path), {recursive:true});
fs.writeFileSync(path, JSON.stringify(output, null, 2) + '\n');
console.log(`PASS: exported ${questions.length} audited questions to ${path.pathname}`);
console.log(`contentVersion=${version} lawBaseline=${baseline} freeNumeric=${output.freeNumericCount}`);
