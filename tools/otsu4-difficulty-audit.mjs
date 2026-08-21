import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, '..');
const bankPath = path.join(repo, 'kikenbutsu-otsu4-sprint', 'questions.generated.json');
const bank = JSON.parse(fs.readFileSync(bankPath, 'utf8'));
const questions = bank.questions || [];

const SUBJECTS = ['法令', '物理・化学', '性質・消火'];
const absurdPatterns = [
  /酸素になる/,
  /質量が0になる/,
  /必ず0(?:になる)?/,
  /燃料を(?:追加|増や)す/,
  /酸素を(?:追加|増や)す/,
  /温度を上げる/,
  /圧力だけ上げる/,
  /一切問題にならない/,
  /火災に関係しない/,
  /確認する必要はない/,
  /全く同じ挙動/,
  /会社規程だけ/,
  /任意基準だけ/,
  /手続不要/,
  /許可不要/,
  /警察への口頭連絡だけ/,
  /税務署への申告/,
  /道路ならどこでもよい/,
  /工場敷地ならどこでもよい/,
  /無許可倉庫/
];
const cloneMarkers = [
  '本番で同じ知識を使う場面を想定する。',
  '条件を取り違えないように判断する。',
  '基本事項を応用して答える。',
  '誤りやすい選択肢に注意して答える。'
];

const answerText = q => String(q.choices?.[q.answer] ?? '');
const wrongChoices = q => (q.choices || []).filter((_, i) => i !== q.answer);
const absurd = s => absurdPatterns.some(re => re.test(String(s)));
const normalize = s => String(s)
  .replace(/^(本番で同じ知識を使う場面を想定する。|条件を取り違えないように判断する。|基本事項を応用して答える。|誤りやすい選択肢に注意して答える。)/, '')
  .replace(/[\s　]+/g, '')
  .trim();

const errors = [];
const warnings = [];
const fail = msg => errors.push(msg);

if (!Array.isArray(questions) || questions.length < 1) fail('question bank is empty');

const difficultyValues = new Set(questions.map(q => q.difficulty));
if (difficultyValues.size < 2) {
  fail(`difficulty is not calibrated: only ${[...difficultyValues].join(',') || 'none'}`);
}

const trivial = [];
for (const q of questions) {
  const bad = wrongChoices(q).filter(absurd);
  if (bad.length >= 2) trivial.push({ id: q.id, subject: q.subject, topic: q.topic, bad });
  const text = `${q.question} ${q.point} ${q.detail}`;
  if (cloneMarkers.some(m => text.includes(m))) fail(`${q.id}: generic clone marker detected`);
}
if (trivial.length) {
  fail(`knowledge-free elimination risk: ${trivial.length} questions have >=2 obviously implausible distractors`);
}

const normalized = new Map();
for (const q of questions) {
  const key = normalize(q.question);
  if (normalized.has(key)) fail(`${q.id}: normalized stem duplicates ${normalized.get(key)}`);
  else normalized.set(key, q.id);
}

const answerLengthOutliers = [];
for (const q of questions) {
  const lengths = q.choices.map(x => String(x).length);
  const a = lengths[q.answer];
  const other = lengths.filter((_, i) => i !== q.answer).sort((x, y) => x - y);
  const median = (other[1] + other[2]) / 2;
  if (a >= Math.max(18, median * 2.4)) answerLengthOutliers.push(q.id);
}
if (answerLengthOutliers.length > Math.ceil(questions.length * 0.05)) {
  fail(`answer-length cue risk: ${answerLengthOutliers.length} questions`);
}

function style(q) {
  if (/計算|倍数|密度|熱量|気体|燃焼範囲/.test(q.topic)) return 'calculation';
  if (/組合せ|該当しない|誤っている|誤り/.test(q.question)) return 'negative-or-combination';
  if (/正しい説明|適切なもの|区分|分類|指定数量/.test(`${q.question} ${q.topic}`)) return 'knowledge-selection';
  return 'rule-or-scenario';
}

function mockSet(set) {
  const law = questions.filter(q => q.subject === '法令').slice((set - 1) * 15, (set - 1) * 15 + 15);
  const phy = questions.filter(q => q.subject === '物理・化学').slice((set - 1) * 10, (set - 1) * 10 + 10);
  const prop = questions.filter(q => q.subject === '性質・消火').slice((set - 1) * 10, (set - 1) * 10 + 10);
  return { law, phy, prop };
}

for (let set = 1; set <= Math.min(3, Math.floor(questions.filter(q => q.subject === '法令').length / 15)); set++) {
  const m = mockSet(set);
  for (const [name, group] of Object.entries(m)) {
    const styles = new Set(group.map(style));
    if (styles.size < 3) fail(`mock${set}/${name}: style diversity ${styles.size} < 3 (${[...styles].join(',')})`);
    const hard = group.filter(q => q.difficulty >= 3).length;
    if (hard < Math.max(2, Math.floor(group.length * 0.2))) fail(`mock${set}/${name}: too few difficulty-3 items (${hard}/${group.length})`);
  }
}

const subjectSummary = {};
for (const s of SUBJECTS) {
  const group = questions.filter(q => q.subject === s);
  subjectSummary[s] = {
    total: group.length,
    difficulty: Object.fromEntries([...new Set(group.map(q => q.difficulty))].sort().map(d => [d, group.filter(q => q.difficulty === d).length])),
    trivialRisk: trivial.filter(x => x.subject === s).length,
    styles: Object.fromEntries([...new Set(group.map(style))].map(st => [st, group.filter(q => style(q) === st).length]))
  };
}

const report = {
  ok: errors.length === 0,
  baseline: {
    format: '乙種・五肢択一式',
    mockComposition: '法令15 / 物理化学10 / 性質消火10',
    passRule: '各科目60%以上',
    policy: '公開過去問の難易度・選択肢競合度を参照し、本文は転載しない'
  },
  total: questions.length,
  difficultyValues: [...difficultyValues].sort(),
  knowledgeFreeEliminationRiskCount: trivial.length,
  answerLengthCueRiskCount: answerLengthOutliers.length,
  subjectSummary,
  sampleTrivialFindings: trivial.slice(0, 25),
  errors,
  warnings
};

console.log(JSON.stringify(report, null, 2));
if (errors.length) process.exit(1);
