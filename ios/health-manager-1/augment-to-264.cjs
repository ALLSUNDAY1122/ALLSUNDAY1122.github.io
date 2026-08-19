'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const IOS_DIR = __dirname;
const REPO_ROOT = path.resolve(IOS_DIR, '..', '..');
const HM1 = path.join(IOS_DIR, 'Resources', 'questions.json');
const HM2_WEB = path.join(REPO_ROOT, 'apps', 'sanitary-manager-2');

const base = JSON.parse(fs.readFileSync(HM1, 'utf8'));
if (base.length !== 132) throw new Error(`Expected HM1 base=132, got ${base.length}`);

const scripts = [
  'q1.js','q2.js','q3.js','q4.js','q5.js','q6.js','q7.js','q8.js','q9.js','q10.js','q11.js','q12.js',
  'audit-patch-v2.js','audit-patch-v3.js','audit-patch-v4.js','audit-fixes.js','question-order-v1.js'
];
global.window = { Q_PARTS: [] };
global.localStorage = { getItem: () => null, setItem: () => {} };
for (const file of scripts) {
  const full = path.join(HM2_WEB, file);
  if (!fs.existsSync(full)) throw new Error(`Missing HM2 audited input: ${file}`);
  vm.runInThisContext(fs.readFileSync(full, 'utf8'), { filename: full });
}
const source = window.Q_PARTS;
if (source.length !== 300) throw new Error(`Expected audited HM2=300, got ${source.length}`);

const clean = s => String(s || '')
  .normalize('NFKC')
  .replace(/次の記述のうち/g, '')
  .replace(/次のうち/g, '')
  .replace(/法令上/g, '')
  .replace(/正しいものはどれか/g, '')
  .replace(/誤っているものはどれか/g, '')
  .replace(/[\s\p{P}\p{S}]/gu, '')
  .toLowerCase();
const grams = s => {
  const t = clean(s);
  const out = new Set();
  for (let i=0;i<Math.max(0,t.length-2);i++) out.add(t.slice(i,i+3));
  return out;
};
const similarity = (a,b) => {
  const A=grams(a), B=grams(b);
  if (!A.size || !B.size) return 0;
  let inter=0; for (const x of A) if (B.has(x)) inter++;
  return inter / (A.size + B.size - inter);
};

const existingStems = base.map(q => q.stem);
const acceptedStems = [];
const subjects = ['関係法令','労働衛生','労働生理'];
const pools = Object.fromEntries(subjects.map(s => [s, []]));

for (const q of source) {
  if (!q.fiveYearExpansion) continue;
  if (q.publicationStatus !== '公開候補') continue;
  if (q.lawRelated && q.auditStatus !== '一次資料照合済') continue;
  if (!q.lawRelated && q.auditStatus !== '内容監査済') continue;
  if (!subjects.includes(q.subject)) continue;
  if (!Array.isArray(q.choices) || q.choices.length !== 5) continue;
  if (!Number.isInteger(q.answer) || q.answer < 1 || q.answer > 5) continue;
  const tooClose = [...existingStems, ...acceptedStems].some(stem => similarity(stem, q.question) >= 0.58);
  if (tooClose) continue;
  pools[q.subject].push(q);
  acceptedStems.push(q.question);
}

for (const s of subjects) {
  if (pools[s].length < 44) throw new Error(`${s}: only ${pools[s].length} unique audited expansion questions available`);
  pools[s] = pools[s].slice(0,44);
}

const layouts = [
  {id:'practice-A', title:'追加演習A', counts:{'関係法令':15,'労働衛生':15,'労働生理':14}},
  {id:'practice-B', title:'追加演習B', counts:{'関係法令':15,'労働衛生':14,'労働生理':15}},
  {id:'practice-C', title:'追加演習C', counts:{'関係法令':14,'労働衛生':15,'労働生理':15}},
];
const cursor = {'関係法令':0,'労働衛生':0,'労働生理':0};
const added = [];
for (const round of layouts) {
  let n = 1;
  for (const subject of subjects) {
    const count = round.counts[subject];
    const chunk = pools[subject].slice(cursor[subject], cursor[subject] + count);
    cursor[subject] += count;
    for (const q of chunk) {
      added.push({
        id: `${round.id}-Q${String(n).padStart(2,'0')}`,
        round: round.id,
        roundTitle: `${round.title}（監査済み共通範囲）`,
        period: '第一種衛生管理者・共通出題範囲の追加演習',
        officialTopicQuestionNo: null,
        label: q.subject,
        conceptKey: `hm2:${q.id}:${q.topic}`,
        stem: q.question,
        choices: q.choices,
        ans: q.answer - 1,
        short: q.quick,
        key: q.topic,
        detail: q.explanation,
        sourceType: q.originType || 'audited-original-practice',
        sourceRef: q.sourceUrl || q.basis,
        sourcePublishedAt: q.baselineDate || q.legalChecked || '2026-08-18',
        lawVersion: q.legalChecked || q.baselineDate || '2026-08-18',
        lawAsOf: q.legalChecked || q.baselineDate || '2026-08-18',
        auditDate: q.baselineDate || q.legalChecked || '2026-08-18',
        auditStatus: q.auditStatus,
        auditSourceURL: q.sourceUrl || '',
        semanticIndependence: 'independent',
        originalExpression: true,
        officialRecurrence: false,
        recurrenceFamily: null,
        independenceReason: '第二種衛生管理者で一次資料・内容監査済みのうち、第一種衛生管理者にも共通する出題範囲から、既存132問との高類似を除外して追加演習として採用。'
      });
      n++;
    }
  }
  if (n !== 45) throw new Error(`${round.id}: expected 44 questions, got ${n-1}`);
}

const all = [...base, ...added];
if (all.length !== 264) throw new Error(`Expected total=264, got ${all.length}`);
if (new Set(all.map(q=>q.id)).size !== 264) throw new Error('Duplicate ids in HM1 264 bank');
if (new Set(all.map(q=>clean(q.stem))).size !== 264) throw new Error('Duplicate normalized stems in HM1 264 bank');

const counts = {};
for (const q of all) {
  counts[q.round] = counts[q.round] || {total:0,'関係法令':0,'労働衛生':0,'労働生理':0};
  counts[q.round].total++;
  counts[q.round][q.label]++;
}
for (const r of ['2026-04','2025-10','2025-04','practice-A','practice-B','practice-C']) {
  if (!counts[r] || counts[r].total !== 44) throw new Error(`${r}: invalid round total`);
}

fs.writeFileSync(HM1, JSON.stringify(all, null, 2) + '\n');
const audit = {
  generatedAt: '2026-08-19',
  baseQuestions: base.length,
  addedQuestions: added.length,
  totalQuestions: all.length,
  sourceAuditedBank: 300,
  sourceExpansionCandidates: source.filter(q=>q.fiveYearExpansion).length,
  similarityThreshold: 0.58,
  subjectAddedCounts: Object.fromEntries(subjects.map(s=>[s, pools[s].length])),
  roundCounts: counts,
  sourcePolicy: 'Only HM2 fiveYearExpansion questions already marked 公開候補 and audited are eligible; high-similarity stems against HM1 base/selected additions are excluded.'
};
fs.writeFileSync(path.join(IOS_DIR,'audit','APP2_005_264_EXPANSION_2026-08-19.json'), JSON.stringify(audit,null,2)+'\n');
console.log(JSON.stringify(audit,null,2));
console.log('PASS: HealthManager1 expanded from 132 to 264 audited questions.');
