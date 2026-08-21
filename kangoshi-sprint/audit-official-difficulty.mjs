import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(here, 'product-content');
const errors = [];
const expected = {
  115: { raw: 'raw/set1-raw.json', year: 2026 },
  114: { raw: 'raw/set2-raw.json', year: 2025 },
  113: { raw: 'raw/set3-raw.json', year: 2024 },
};
const categoryFiles = {
  '必修': 'required.json',
  '一般': 'general.json',
  '状況設定': 'situation.json',
};
const expectedCategoryCounts = { '必修': 50, '一般': 130, '状況設定': 60 };
const placeholder = /髪型|好きな色|好物|靴のサイズ|誕生月|爪の長さ|髪の長さ|テレビ番組|明らかに誤り|ダミー|仮問題|常識で分かる/;

function readJson(rel) {
  const full = path.join(root, rel);
  if (!fs.existsSync(full)) {
    errors.push(`missing file: ${rel}`);
    return null;
  }
  return JSON.parse(fs.readFileSync(full, 'utf8'));
}

function norm(s) {
  return String(s ?? '')
    .normalize('NFKC')
    .replace(/\s+/g, '')
    .replace(/[。、・,.!?！？「」『』（）()［］\[\]〈〉<>]/g, '');
}

function levenshtein(a, b) {
  if (a === b) return 0;
  if (!a.length) return b.length;
  if (!b.length) return a.length;
  let prev = Array.from({length: b.length + 1}, (_, i) => i);
  for (let i = 1; i <= a.length; i++) {
    const cur = [i];
    for (let j = 1; j <= b.length; j++) {
      cur[j] = Math.min(
        cur[j - 1] + 1,
        prev[j] + 1,
        prev[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1),
      );
    }
    prev = cur;
  }
  return prev[b.length];
}

function similarity(a, b) {
  a = norm(a); b = norm(b);
  if (!a && !b) return 1;
  const max = Math.max(a.length, b.length);
  return max ? 1 - levenshtein(a, b) / max : 1;
}

const manifest = readJson('manifest.json');
if (!manifest) process.exit(1);
const correctionDoc = readJson('required-150/text-corrections.json');
const officialPdfCorrections = new Map((correctionDoc?.corrections || []).map(x => [x.id, x]));
if (correctionDoc && !String(correctionDoc.verifiedAgainst || '').includes('厚生労働省')) {
  errors.push('required text corrections must remain verified against MHLW official PDFs');
}

if (manifest.targetQuestions !== 720) errors.push('manifest targetQuestions must be 720');
if (manifest.setCount !== 3 || manifest.questionsPerSet !== 240) errors.push('manifest must be 3 x 240');
if (JSON.stringify(manifest.compositionPerSet) !== JSON.stringify(expectedCategoryCounts)) {
  errors.push(`manifest composition must be ${JSON.stringify(expectedCategoryCounts)}`);
}

const manifestExams = new Map((manifest.sets || []).map(s => [Number(s.sourceExam), s]));
for (const exam of Object.keys(expected).map(Number)) {
  const set = manifestExams.get(exam);
  if (!set) {
    errors.push(`manifest missing exam ${exam}`);
    continue;
  }
  if (set.sourceYear !== expected[exam].year) errors.push(`exam ${exam}: sourceYear mismatch`);
  if (set.questionCount !== 240 || set.sourceQuestionCount !== 240 || set.runtimeEligibleCount !== 240) {
    errors.push(`exam ${exam}: counts must remain 240`);
  }
}
if ([...manifestExams.keys()].some(x => !expected[x])) errors.push('manifest contains a non-official extra exam set');

const allCanonicalIds = new Set();
let grandTotal = 0;
for (const exam of Object.keys(expected).map(Number)) {
  const rawDoc = readJson(expected[exam].raw);
  if (!rawDoc) continue;
  if (rawDoc.sourceExam !== exam || rawDoc.questionCount !== 240 || !Array.isArray(rawDoc.questions) || rawDoc.questions.length !== 240) {
    errors.push(`exam ${exam}: raw official import must be exactly 240 questions`);
    continue;
  }
  const rawById = new Map(rawDoc.questions.map(q => {
    const correction = officialPdfCorrections.get(q.id);
    return [q.id, correction ? {...q, ...correction, id:q.id} : q];
  }));
  const slotSet = new Set(rawDoc.questions.map(q => `${q.session}-${q.questionNo}`));
  if (slotSet.size !== 240) errors.push(`exam ${exam}: raw session/questionNo slots are not unique`);
  for (const session of ['AM', 'PM']) {
    const nums = rawDoc.questions.filter(q => q.session === session).map(q => Number(q.questionNo)).sort((a,b)=>a-b);
    if (nums.length !== 120 || nums.some((n, i) => n !== i + 1)) errors.push(`exam ${exam}: ${session} must be question 1..120 exactly once`);
  }

  const canonical = [];
  for (const [category, file] of Object.entries(categoryFiles)) {
    const doc = readJson(`questions/exam-${exam}/${file}`);
    if (!doc) continue;
    if (doc.sourceExam !== exam || doc.category !== category) errors.push(`exam ${exam}/${file}: metadata mismatch`);
    if (doc.questionCount !== expectedCategoryCounts[category] || !Array.isArray(doc.questions) || doc.questions.length !== expectedCategoryCounts[category]) {
      errors.push(`exam ${exam}/${file}: expected ${expectedCategoryCounts[category]} questions`);
    }
    for (const q of doc.questions || []) canonical.push(q);
  }

  if (canonical.length !== 240) errors.push(`exam ${exam}: canonical total ${canonical.length}, expected 240`);
  grandTotal += canonical.length;
  const canonicalSlots = new Set();
  for (const q of canonical) {
    if (allCanonicalIds.has(q.id)) errors.push(`duplicate canonical id: ${q.id}`);
    allCanonicalIds.add(q.id);
    const expectedId = `K${exam}-${q.session}${String(q.questionNo).padStart(3, '0')}`;
    if (q.id !== expectedId) errors.push(`${q.id}: id does not match official exam/session/questionNo (${expectedId})`);
    if (q.sourceExam !== exam) errors.push(`${q.id}: sourceExam mismatch`);
    if (!['AM','PM'].includes(q.session) || !Number.isInteger(q.questionNo) || q.questionNo < 1 || q.questionNo > 120) {
      errors.push(`${q.id}: invalid official session/questionNo`);
    }
    const slot = `${q.session}-${q.questionNo}`;
    if (canonicalSlots.has(slot)) errors.push(`${q.id}: duplicate official slot ${slot}`);
    canonicalSlots.add(slot);
    if (!Object.hasOwn(expectedCategoryCounts, q.category)) errors.push(`${q.id}: invalid category ${q.category}`);
    if (Array.isArray(q.choices) && q.choices.some(x => placeholder.test(String(x)))) errors.push(`${q.id}: obvious/placeholder distractor detected`);

    const raw = rawById.get(q.id);
    if (!raw) {
      errors.push(`${q.id}: no matching official raw question`);
      continue;
    }
    for (const key of ['sourceExam','session','questionNo','category','answerType']) {
      if (q[key] !== raw[key]) errors.push(`${q.id}: ${key} differs from official raw import`);
    }
    const stemSim = similarity(q.question, raw.question);
    if (stemSim < 0.86) errors.push(`${q.id}: stem diverges too far from official source (${stemSim.toFixed(3)})`);
    if (Array.isArray(raw.choices)) {
      if (!Array.isArray(q.choices) || q.choices.length !== raw.choices.length) {
        errors.push(`${q.id}: choice count differs from official source`);
      } else {
        const choiceSim = q.choices.reduce((sum, x, i) => sum + similarity(x, raw.choices[i]), 0) / q.choices.length;
        if (choiceSim < 0.80) errors.push(`${q.id}: choices diverge too far from official source (${choiceSim.toFixed(3)})`);
      }
    }
    const excluded = String(q.officialScoringStatus || raw.officialScoringStatus || '').includes('excluded');
    const accepted = q.officialAcceptedAnswers ?? raw.officialAcceptedAnswers;
    if (!excluded && (!Array.isArray(accepted) || accepted.length === 0)) errors.push(`${q.id}: official accepted answer metadata missing`);
  }
  if (canonicalSlots.size !== 240) errors.push(`exam ${exam}: canonical official slot coverage ${canonicalSlots.size}/240`);
  for (const rawId of rawById.keys()) if (!allCanonicalIds.has(rawId)) errors.push(`${rawId}: official raw question missing from canonical 720`);
}

if (grandTotal !== 720 || allCanonicalIds.size !== 720) errors.push(`canonical total must be 720 unique official questions; got total=${grandTotal}, unique=${allCanonicalIds.size}`);

if (errors.length) {
  console.error(errors.join('\n'));
  process.exit(1);
}
console.log('PASS: 720 questions map 1:1 to official exams 113-115; verified PDF corrections applied; 240/exam, AM120+PM120, official difficulty preserved, no generated filler slots.');
