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
  const text = `${q.topic} ${q.question}`;
  if (/組合せ|該当しない|誤っている|誤り/.test(text)) return 'negative-or-combination';
  if (q.subject === '法令') {
    if (/計算|倍数合算|指定数量判定/.test(q.topic)) return 'calculation';
    if (q.topic.includes('指定数量')) return 'knowledge-selection';
    return 'rule-or-facility';
  }
  if (q.subject === '物理・化学') {
    if (/計算|燃焼範囲判定/.test(q.topic)) return 'calculation';
    if (/冷却消火|窒息消火|除去消火|抑制消火|泡消火|二酸化炭素消火|粉末消火|静電気|接地/.test(q.topic)) return 'mechanism-or-control';
    return 'concept-knowledge';
  }
  if (q.subject === '性質・消火') {
    if (/品名分類|石油類区分/.test(q.topic)) return 'classification';
    if (/指定数量応用|比較応用/.test(q.topic)) return 'quantity-or-comparison';
    return 'property-or-response';
  }
  return 'other';
}

// Must match Otsu4ContentStore.stableRank.
function stableRank(text, salt) {
  let hash = 1469598103934665603n;
  const bytes = new TextEncoder().encode(`${salt}|${text}`);
  for (const byte of bytes) {
    hash ^= BigInt(byte);
    hash = BigInt.asUintN(64, hash * 1099511628211n);
  }
  return hash;
}

function ordered(pool, salt) {
  return [...pool].sort((a, b) => stableRank(a.id, salt) < stableRank(b.id, salt) ? -1 : 1);
}

function take(pool, set, count, salt) {
  const sorted = ordered(pool, salt);
  const start = (set - 1) * count;
  if (sorted.length < start + count) return null;
  return sorted.slice(start, start + count);
}

function lawMockSlice(pool, set) {
  const hard = pool.filter(q => q.difficulty >= 3);
  const knowledge = pool.filter(q => q.difficulty < 3 && q.topic.includes('指定数量'));
  const rule = pool.filter(q => q.difficulty < 3 && !q.topic.includes('指定数量'));
  const parts = [
    take(hard, set, 5, 'law-hard'),
    take(knowledge, set, 2, 'law-knowledge'),
    take(rule, set, 8, 'law-rule')
  ];
  if (parts.some(x => !x)) return null;
  return ordered(parts.flat(), `law-set-${set}`);
}

function physicsMockSlice(pool, set) {
  const mechanismTopics = new Set(['冷却消火','窒息消火','除去消火','抑制消火','泡消火','二酸化炭素消火','粉末消火','静電気','接地']);
  const hard = pool.filter(q => q.difficulty >= 3);
  const mechanism = pool.filter(q => q.difficulty < 3 && mechanismTopics.has(q.topic));
  const concept = pool.filter(q => q.difficulty < 3 && !mechanismTopics.has(q.topic));
  const parts = [
    take(hard, set, 3, 'physics-hard'),
    take(concept, set, 5, 'physics-concept'),
    take(mechanism, set, 2, 'physics-mechanism')
  ];
  if (parts.some(x => !x)) return null;
  return ordered(parts.flat(), `physics-set-${set}`);
}

function propertiesMockSlice(pool, set) {
  const hardClassification = pool.filter(q => q.difficulty >= 3 && q.topic === '石油類区分');
  const hardApplication = pool.filter(q => q.difficulty >= 3 && (q.topic === '指定数量応用' || q.topic === '比較応用'));
  const normalClassification = pool.filter(q => q.difficulty < 3 && q.topic === '品名分類');
  const normalResponse = pool.filter(q => q.difficulty < 3 && q.topic !== '品名分類');
  const parts = [
    take(hardClassification, set, 1, 'properties-hard-classification'),
    take(hardApplication, set, 2, 'properties-hard-application'),
    take(normalClassification, set, 2, 'properties-normal-classification'),
    take(normalResponse, set, 5, 'properties-response')
  ];
  if (parts.some(x => !x)) return null;
  return ordered(parts.flat(), `properties-set-${set}`);
}

function mockSet(set) {
  return {
    law: lawMockSlice(questions.filter(q => q.subject === '法令'), set),
    phy: physicsMockSlice(questions.filter(q => q.subject === '物理・化学'), set),
    prop: propertiesMockSlice(questions.filter(q => q.subject === '性質・消火'), set)
  };
}

const mockSummaries = [];
for (let set = 1; set <= 3; set++) {
  const m = mockSet(set);
  for (const [name, group] of Object.entries(m)) {
    if (!group) {
      fail(`mock${set}/${name}: style-balanced selection could not be built`);
      continue;
    }
    const styles = new Set(group.map(style));
    if (styles.size < 3) fail(`mock${set}/${name}: style diversity ${styles.size} < 3 (${[...styles].join(',')})`);
    const hard = group.filter(q => q.difficulty >= 3).length;
    const expectedHard = name === 'law' ? 5 : 3;
    if (hard !== expectedHard) fail(`mock${set}/${name}: difficulty-3 items ${hard}, expected ${expectedHard}`);
    mockSummaries.push({ set, subject: name, total: group.length, hard, styles: [...styles], ids: group.map(q => q.id) });
  }
}

const mockIds = mockSummaries.flatMap(m => m.ids);
if (mockIds.length !== new Set(mockIds).size) fail('mock sets are not disjoint');

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
  mockSummaries,
  sampleTrivialFindings: trivial.slice(0, 25),
  errors,
  warnings
};

console.log(JSON.stringify(report, null, 2));
if (errors.length) process.exit(1);
