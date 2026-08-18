'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const os = require('os');
const crypto = require('crypto');
const { spawnSync } = require('child_process');

const IOS_DIR = __dirname;
const REPO_ROOT = path.resolve(IOS_DIR, '..', '..');
const WEB = path.join(REPO_ROOT, 'apps', 'sanitary-manager-2');

global.window = { Q_PARTS: [] };
global.localStorage = { getItem: () => null, setItem: () => {} };

const scripts = [
  'q1.js','q2.js','q3.js','q4.js','q5.js','q6.js','q7.js','q8.js','q9.js','q10.js','q11.js','q12.js',
  'audit-patch-v2.js','audit-patch-v3.js','audit-fixes.js','question-order-v1.js'
];
for (const file of scripts) {
  const full = path.join(WEB, file);
  if (!fs.existsSync(full)) throw new Error(`Missing release input: ${file}`);
  vm.runInThisContext(fs.readFileSync(full, 'utf8'), { filename: full });
}

const questions = window.Q_PARTS;
if (questions.length !== 300) throw new Error(`Expected 300 questions, got ${questions.length}`);

const sets = [
  '令和8年4月','令和7年10月','令和7年4月',
  '5年分相当｜第4回','5年分相当｜第5回','5年分相当｜第6回','5年分相当｜第7回',
  '5年分相当｜第8回','5年分相当｜第9回','5年分相当｜第10回'
];
const examRound = Object.fromEntries(sets.map((name, i) => [name, i + 1]));
const subjects = ['関係法令','労働衛生','労働生理'];
const groups = new Map();
for (const q of questions) {
  const key = `${q.examSet}|${q.subject}`;
  if (!groups.has(key)) groups.set(key, []);
  groups.get(key).push(q);
}
if (groups.size !== 30) throw new Error(`Expected 30 exam/subject groups, got ${groups.size}`);

for (const set of sets) {
  for (const subject of subjects) {
    const key = `${set}|${subject}`;
    const qs = groups.get(key) || [];
    if (qs.length !== 10) throw new Error(`${key}: expected 10 questions, got ${qs.length}`);
    const positions = [0,0,0,0,0];
    for (const q of qs) {
      if (!Array.isArray(q.choices) || q.choices.length !== 5) throw new Error(`${q.id}: choices must be 5`);
      if (!Number.isInteger(q.answer) || q.answer < 1 || q.answer > 5) throw new Error(`${q.id}: invalid answer ${q.answer}`);
      positions[q.answer - 1]++;
    }
    if (!positions.every(n => n === 2)) throw new Error(`${key}: answer positions are biased: ${positions.join(',')}`);
  }
}

const required = ['id','examSet','subject','topic','question','choices','answer','quick','explanation','basis','sourceUrl','baselineDate','originType','rightsBasis'];
const normalized = s => String(s).replace(/[\s\p{P}\p{S}]/gu, '').toLowerCase();
const bodies = new Map();
for (const q of questions) {
  for (const field of required) {
    const value = q[field];
    if (value === undefined || value === null || value === '' || (Array.isArray(value) && value.length === 0)) {
      throw new Error(`${q.id || '?'}: missing ${field}`);
    }
  }
  if (!examRound[q.examSet]) throw new Error(`${q.id}: unknown examSet ${q.examSet}`);
  if (!subjects.includes(q.subject)) throw new Error(`${q.id}: unknown subject ${q.subject}`);
  if (q.lawRelated && !q.legalChecked) throw new Error(`${q.id}: law-related question missing legalChecked`);
  const body = normalized(q.question);
  if (bodies.has(body)) throw new Error(`${q.id}: exact normalized duplicate of ${bodies.get(body)}`);
  bodies.set(body, q.id);
}

const out = questions.map(q => ({
  id: q.id,
  round: examRound[q.examSet],
  exam_set: q.examSet,
  subject: q.subject,
  topic: q.topic,
  question: q.question,
  choices: q.choices,
  correct_index: q.answer - 1,
  quick: q.quick,
  explanation: q.explanation,
  primary_basis: q.basis,
  source_url: q.sourceUrl,
  baseline_date: q.baselineDate,
  origin_type: q.originType,
  rights_basis: q.rightsBasis,
  law_related: Boolean(q.lawRelated),
  legal_checked: q.legalChecked || null,
  audit_status: q.auditStatus,
  publication_status: q.publicationStatus
}));

const outPath = path.join(IOS_DIR, 'release-questions.json');
fs.writeFileSync(outPath, JSON.stringify(out, null, 2) + '\n');
console.log(`Exported ${out.length} audited questions to ${outPath}`);
console.log('PASS: 10 rounds / 30 groups x 10 questions, 5 choices each, answer positions 1-5 each exactly twice per group.');

// Verify that the interrupted text transport still represents the exact user-approved
// Second-class icon artwork closely enough to use as a lossless-source recovery path.
// This does not trust the filenames or commit messages: it validates the actual decoded
// WebP container and a robust 8x8 grayscale fingerprint sampled from the approved PNG.
const iconPartsDir = path.join(WEB, 'approved-icon');
if (fs.existsSync(iconPartsDir)) {
  const parts = fs.readdirSync(iconPartsDir).filter(n => /^part\d+\.b64$/.test(n)).sort();
  if (parts.length) {
    const encoded = parts.map(n => fs.readFileSync(path.join(iconPartsDir, n), 'utf8').trim()).join('');
    const iconBytes = Buffer.from(encoded, 'base64');
    const tmp = path.join(os.tmpdir(), 'sm2-approved-transfer.webp');
    fs.writeFileSync(tmp, iconBytes);
    const sha = crypto.createHash('sha256').update(iconBytes).digest('hex');
    let expectedBytes = null;
    if (iconBytes.length >= 12 && iconBytes.subarray(0,4).toString() === 'RIFF' && iconBytes.subarray(8,12).toString() === 'WEBP') {
      expectedBytes = iconBytes.readUInt32LE(4) + 8;
    }
    console.log(`ICON_TRANSFER parts=${parts.length} actual_bytes=${iconBytes.length} riff_expected_bytes=${expectedBytes} sha256=${sha}`);
    if (!expectedBytes || expectedBytes !== iconBytes.length) {
      throw new Error(`Approved icon transfer is incomplete: actual=${iconBytes.length} expected=${expectedBytes}`);
    }

    const expectedGray8 = [38,62,53,80,137,64,41,36,59,51,55,138,194,122,89,48,57,76,104,131,101,208,192,50,47,83,121,133,126,196,187,82,164,226,214,224,229,210,229,171,255,255,155,183,177,152,255,255,252,173,159,161,148,140,177,253,142,236,211,199,202,210,235,142];
    const candidates = [
      ['magick', [tmp, '-resize', '8x8!', '-colorspace', 'Gray', '-depth', '8', 'gray:-']],
      ['convert', [tmp, '-resize', '8x8!', '-colorspace', 'Gray', '-depth', '8', 'gray:-']]
    ];
    let gray = null;
    for (const [cmd,args] of candidates) {
      const r = spawnSync(cmd, args, { encoding: null, maxBuffer: 1024 * 1024 });
      if (r.status === 0 && r.stdout && r.stdout.length === 64) { gray = r.stdout; break; }
    }
    if (!gray) throw new Error('Could not decode approved icon transfer with ImageMagick');
    const mae = expectedGray8.reduce((sum,v,i) => sum + Math.abs(v - gray[i]), 0) / 64;
    console.log(`ICON_TRANSFER perceptual_mae=${mae.toFixed(3)} expected_max=4.000`);
    if (mae > 4) throw new Error(`Approved icon transfer does not match approved artwork (MAE ${mae.toFixed(3)})`);
    console.log('PASS: approved Health Manager 2 icon artwork fingerprint matches the user-approved icon.');
  }
}
