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
  if (/計算|倍数|密度計算|熱量計算|気体計算|燃焼範囲判定/.test(q.topic)) return 'calculation';
  if (q.subject === '法令' && !/指定数量/.test(q.topic)) return 'rule-or-facility';
  if (q.subject === '物理・化学' && /冷却消火|窒息消火|除去消火|抑制消火|泡消火|二酸化炭素消火|粉末消火|静電気|接地/.test(q.topic)) return 'mechanism-or-control';
  if (q.subject === '物理・化学') return 'concept-knowledge';
  if (q.subject === '性質・消火' && /性質・火災予防|水溶性|低所蒸気|静電気|水面拡大|耐アルコール泡|隣接冷却|燃料遮断|再着火|ミスト|高温面|油布発熱|流出封じ|濃度測定|防爆換気|消火剤適応|事故通報/.test(q.topic)) return 'property-or-response';
  if (/区分|分類|指定数量|比較応用/.test(text)) return 'knowledge-selection';
  return 'rule-or-scenario';
}

// Must match Otsu4ContentStore.stableRank / balancedMockSlice.
function stableRank(text, salt) {
  let hash = 1469598103934665603n;
  const bytes = new TextEncoder().encode(`${salt}|${text}`);
  for (const byte of bytes) {
    hash ^= BigInt(byte);
    hash = BigInt.asUintN(64, hash * 1099511628211n);
  }
  return hash;
}

function balancedMockSlice(pool, set, count, hardCount, salt) {
  const normalCount = count - hardCount;
  const hard = pool
    .filter(q => q.difficulty >= 3)
    .sort((a, b) => stableRank(a.id, `${salt}-hard`) < stableRank(b.id, `${salt}-hard`) ? -1 : 1);
  const normal = pool
    .filter(q => q.difficulty < 3)
    .sort((a, b) => stableRank(a.id, `${salt}-normal`) < stableRank(b.id, `${salt}-normal`) ? -1 : 1);
  const hardStart = (set - 1) * hardCount;
  const normalStart = (set - 1) * normalCount;
  if (hard.length < hardStart + hardCount || normal.length < normalStart + normalCount) return null;
  return [
    ...hard.slice(hardStart, hardStart + hardCount),
    ...normal.slice(normalStart, normalStart + normalCount)
  ].sort((a, b) => stableRank(a.id, `${salt}-set-${set}`) < stableRank(b.id, `${salt}-set-${set}`) ? -1 : 1);
}

function mockSet(set) {
  const law = balancedMockSlice(questions.filter(q => q.subject === '法令'), set, 15, 5, 'law');
  const phy = balancedMockSlice(questions.filter(q => q.subject === '物理・化学'), set, 10, 3, 'physics');
  const prop = balancedMockSlice(questions.filter(q => q.subject === '性質・消火'), set, 10, 3, 'properties');
  return { law, phy, prop };
}

const mockSummaries = [];
for (let set = 1; set <= 3; set++) {
  const m = mockSet(set);
  for (const [name, group] of Object.entries(m)) {
    if (!group) {
      fail(`mock${set}/${name}: balanced selection could not be built`);
      continue;
    }
    const styles = new Set(group.map(style));
    const minStyles = name === 'phy' ? 2 : 3;
    if (styles.size < minStyles) fail(`mock${set}/${name}: style diversity ${styles.size} < ${minStyles} (${[...styles].join(',')})`);
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
