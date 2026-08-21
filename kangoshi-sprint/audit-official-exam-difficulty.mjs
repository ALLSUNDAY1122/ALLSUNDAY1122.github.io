import fs from 'node:fs';

const text = fs.readFileSync(new URL('./questions-runtime.js', import.meta.url), 'utf8');
const marker = 'const ALL=';
const start = text.indexOf(marker);
if (start < 0) throw new Error('questions-runtime.js: const ALL not found');
let i = start + marker.length;
while (/\s/.test(text[i] || '')) i++;
if (text[i] !== '[') throw new Error('questions-runtime.js: ALL is not an array');
let depth = 0, inString = false, escaped = false, end = -1;
for (let p = i; p < text.length; p++) {
  const ch = text[p];
  if (inString) {
    if (escaped) escaped = false;
    else if (ch === '\\') escaped = true;
    else if (ch === '"') inString = false;
    continue;
  }
  if (ch === '"') { inString = true; continue; }
  if (ch === '[') depth++;
  else if (ch === ']') {
    depth--;
    if (depth === 0) { end = p + 1; break; }
  }
}
if (end < 0) throw new Error('questions-runtime.js: ALL array is unterminated');
const questions = JSON.parse(text.slice(i, end));
const errors = [];
const expectedExams = [113, 114, 115];
const expectedSessions = ['AM', 'PM'];

if (questions.length !== 720) errors.push(`expected 720 official questions, got ${questions.length}`);

for (const exam of expectedExams) {
  const examQs = questions.filter(q => q.sourceExam === exam);
  if (examQs.length !== 240) errors.push(`exam ${exam}: expected 240, got ${examQs.length}`);
  const cats = Object.fromEntries(['必修','一般','状況設定'].map(k => [k, examQs.filter(q => q.category === k).length]));
  if (cats['必修'] !== 50 || cats['一般'] !== 130 || cats['状況設定'] !== 60) {
    errors.push(`exam ${exam}: category composition must be 50/130/60, got ${JSON.stringify(cats)}`);
  }
  for (const session of expectedSessions) {
    const sessionQs = examQs.filter(q => q.session === session);
    if (sessionQs.length !== 120) errors.push(`exam ${exam} ${session}: expected 120, got ${sessionQs.length}`);
    const numbers = new Set(sessionQs.map(q => q.questionNo));
    for (let n = 1; n <= 120; n++) if (!numbers.has(n)) errors.push(`exam ${exam} ${session}: missing official slot ${n}`);
  }
}

for (const q of questions) {
  if (!expectedExams.includes(q.sourceExam)) errors.push(`${q.id}: unsupported sourceExam ${q.sourceExam}`);
  if (!expectedSessions.includes(q.session)) errors.push(`${q.id}: invalid session ${q.session}`);
  const expectedId = `K${q.sourceExam}-${q.session}${String(q.questionNo).padStart(3, '0')}`;
  if (q.id !== expectedId) errors.push(`${q.id}: official-slot id mismatch, expected ${expectedId}`);
  if (!Array.isArray(q.officialAcceptedAnswers)) errors.push(`${q.id}: officialAcceptedAnswers missing`);
  if (!q.officialScoringStatus) errors.push(`${q.id}: officialScoringStatus missing`);
  if (q.releaseEligible !== true) errors.push(`${q.id}: releaseEligible must be true`);
}

if (errors.length) {
  console.error(errors.slice(0, 100).join('\n'));
  if (errors.length > 100) console.error(`...and ${errors.length - 100} more`);
  process.exit(1);
}

console.log('PASS: difficulty provenance locked to 720 real exam slots (115/114/113), 240 each, official scoring metadata present; no synthetic filler slots.');
