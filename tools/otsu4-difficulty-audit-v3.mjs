import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, '..');
const bankPath = path.join(repo, 'kikenbutsu-otsu4-sprint', 'questions.generated.json');
execFileSync(process.execPath, [path.join(here, 'otsu4-difficulty-audit.mjs')], { cwd: repo, stdio: 'inherit' });

const bank = JSON.parse(fs.readFileSync(bankPath, 'utf8'));
const questions = bank.questions || [];
const errors = [];
const fail = msg => errors.push(msg);
const mechanismTopics = new Set(['冷却消火','窒息消火','除去消火','抑制消火','泡消火','二酸化炭素消火','粉末消火','静電気','接地']);
function stableRank(text, salt) { let hash = 1469598103934665603n; for (const byte of new TextEncoder().encode(`${salt}|${text}`)) { hash ^= BigInt(byte); hash = BigInt.asUintN(64, hash * 1099511628211n); } return hash; }
function ordered(pool, salt) { return [...pool].sort((a, b) => stableRank(a.id, salt) < stableRank(b.id, salt) ? -1 : 1); }
function take(pool, set, count, salt) { const sorted = ordered(pool, salt); const start = (set - 1) * count; return sorted.length >= start + count ? sorted.slice(start, start + count) : null; }
function style(q) {
  const text = `${q.topic} ${q.question}`;
  if (/組合せ|該当しない|誤っている|誤り/.test(text)) return 'negative-or-combination';
  if (q.subject === '法令') { if (/計算|倍数合算|指定数量判定/.test(q.topic)) return 'calculation'; if (q.topic.includes('指定数量')) return 'knowledge-selection'; return 'rule-or-facility'; }
  if (q.subject === '物理・化学') { if (/計算|燃焼範囲判定/.test(q.topic)) return 'calculation'; if ([...mechanismTopics].some(t => q.topic.includes(t))) return 'mechanism-or-control'; return 'concept-knowledge'; }
  if (/品名分類|石油類区分/.test(q.topic)) return 'classification';
  if (/指定数量応用|比較応用/.test(q.topic)) return 'quantity-or-comparison';
  return 'property-or-response';
}
function mockSet(set) {
  const law = questions.filter(q => q.subject === '法令');
  const lawParts = [take(law.filter(q => q.difficulty >= 3), set, 5, 'law-hard'), take(law.filter(q => q.difficulty < 3 && q.topic.includes('指定数量')), set, 2, 'law-knowledge'), take(law.filter(q => q.difficulty < 3 && !q.topic.includes('指定数量')), set, 8, 'law-rule')];
  const phy = questions.filter(q => q.subject === '物理・化学');
  const phyParts = [take(phy.filter(q => q.difficulty >= 3), set, 3, 'physics-hard'), take(phy.filter(q => q.difficulty < 3 && !mechanismTopics.has(q.topic)), set, 5, 'physics-concept'), take(phy.filter(q => q.difficulty < 3 && mechanismTopics.has(q.topic)), set, 2, 'physics-mechanism')];
  const prop = questions.filter(q => q.subject === '性質・消火');
  const propParts = [take(prop.filter(q => q.difficulty >= 3 && q.topic === '石油類区分'), set, 1, 'properties-hard-classification'), take(prop.filter(q => q.difficulty >= 3 && (q.topic === '指定数量応用' || q.topic === '比較応用')), set, 2, 'properties-hard-application'), take(prop.filter(q => q.difficulty < 3 && q.topic === '品名分類'), set, 2, 'properties-normal-classification'), take(prop.filter(q => q.difficulty < 3 && q.topic !== '品名分類'), set, 5, 'properties-response')];
  if ([...lawParts, ...phyParts, ...propParts].some(x => !x)) return null;
  return { law: ordered(lawParts.flat(), `law-set-${set}`), phy: ordered(phyParts.flat(), `physics-set-${set}`), prop: ordered(propParts.flat(), `properties-set-${set}`) };
}
if (questions.length !== 720) fail(`total ${questions.length} != 720`);
const expectedCounts = { '法令': 288, '物理・化学': 192, '性質・消火': 240 };
for (const [s, n] of Object.entries(expectedCounts)) { const actual = questions.filter(q => q.subject === s).length; if (actual !== n) fail(`${s} ${actual} != ${n}`); }
const summaries = [], ids = [];
for (let set = 1; set <= 6; set++) {
  const m = mockSet(set); if (!m) { fail(`mock ${set}: could not build`); continue; }
  for (const [name, rows] of Object.entries(m)) {
    const expectedTotal = name === 'law' ? 15 : 10, expectedHard = name === 'law' ? 5 : 3, hard = rows.filter(q => q.difficulty >= 3).length, styles = [...new Set(rows.map(style))];
    if (rows.length !== expectedTotal) fail(`mock ${set}/${name}: total ${rows.length}`);
    if (hard !== expectedHard) fail(`mock ${set}/${name}: hard ${hard} != ${expectedHard}`);
    if (styles.length < 3) fail(`mock ${set}/${name}: styles ${styles.length} < 3`);
    summaries.push({ set, subject: name, total: rows.length, hard, styles, ids: rows.map(q => q.id) }); ids.push(...rows.map(q => q.id));
  }
}
if (ids.length !== 210) fail(`mock ids ${ids.length} != 210`);
if (new Set(ids).size !== ids.length) fail('six mock sets overlap');
const free = { law: questions.filter(q => q.subject === '法令').slice(0, 29), phy: questions.filter(q => q.subject === '物理・化学').slice(0, 19), prop: questions.filter(q => q.subject === '性質・消火').slice(0, 24) };
if (free.law.length < 15 || free.phy.length < 10 || free.prop.length < 10) fail('free round 1 cannot build 15/10/10');
const report = { ok: errors.length === 0, total: questions.length, mockSetCount: 6, mockQuestionCount: ids.length, mockUniqueQuestionCount: new Set(ids).size, freeRound1: '15/10/10 available', summaries, errors };
console.log(JSON.stringify(report, null, 2));
if (errors.length) process.exit(1);
