import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const site = path.join(root, 'yorugatari');
const quizVersion = '20260724-001';
const quizPath = path.join(site, 'horror-quiz.html');
const runtimePath = path.join(site, 'assets', 'horror-quiz.js');

if (!fs.existsSync(quizPath)) throw new Error('Missing horror-quiz.html');
if (!fs.existsSync(runtimePath)) throw new Error('Missing assets/horror-quiz.js');

const targets = [
  { file: 'index.html', prefix: '', hero: true, chips: 'category-page-links' },
  { file: 'archive.html', prefix: '', hero: false, chips: 'archive-jump' },
  { file: '5min-horror.html', prefix: '', hero: true },
  { file: 'bedtime-horror.html', prefix: '', hero: true },
  ...fs.readdirSync(path.join(site, 'categories'))
    .filter((file) => file.endsWith('.html'))
    .sort()
    .map((file) => ({ file: `categories/${file}`, prefix: '../', hero: false, chips: 'category-nav' }))
];

function stripQuizLinks(value) {
  return value.replace(/<a\b[^>]*href=["'][^"']*horror-quiz\.html["'][^>]*>[\s\S]*?<\/a>/gi, '');
}

function ensureContainer(html, pattern, anchor, label) {
  let matched = false;
  const next = html.replace(pattern, (whole, open, inner, close) => {
    matched = true;
    const clean = stripQuizLinks(inner);
    return `${open}${clean}${anchor}${close}`;
  });
  if (!matched) throw new Error(`Missing ${label} container`);
  return next;
}

function updateTarget(target) {
  const filePath = path.join(site, target.file);
  const before = fs.readFileSync(filePath, 'utf8');
  const href = `${target.prefix}horror-quiz.html`;
  let after = stripQuizLinks(before);

  after = ensureContainer(
    after,
    /(<nav class="nav"[^>]*>)([\s\S]*?)(<\/nav>)/i,
    `<a href="${href}">怖さ診断</a>`,
    `${target.file} header navigation`
  );

  after = ensureContainer(
    after,
    /(<nav class="footer-links"[^>]*>)([\s\S]*?)(<\/nav>)/i,
    `<a href="${href}">怖さ診断</a>`,
    `${target.file} footer navigation`
  );

  if (target.hero) {
    after = ensureContainer(
      after,
      /(<div class="hero-actions">)([\s\S]*?)(<\/div>)/i,
      `<a class="btn" href="${href}">怖さ診断</a>`,
      `${target.file} hero actions`
    );
  }

  if (target.chips === 'category-page-links') {
    after = ensureContainer(
      after,
      /(<nav class="chips category-page-links"[^>]*>)([\s\S]*?)(<\/nav>)/i,
      `<a class="chip" href="${href}">怖さ診断</a>`,
      `${target.file} category links`
    );
  } else if (target.chips === 'archive-jump') {
    after = ensureContainer(
      after,
      /(<nav class="archive-jump" aria-label="カテゴリ別ページ">)([\s\S]*?)(<\/nav>)/i,
      `<a class="chip" href="${href}">怖さ診断</a>`,
      `${target.file} archive links`
    );
  } else if (target.chips === 'category-nav') {
    after = ensureContainer(
      after,
      /(<nav class="chips category-nav"[^>]*>)([\s\S]*?)(<\/nav>)/i,
      `<a class="chip" href="${href}">怖さ診断</a>`,
      `${target.file} category navigation`
    );
  }

  const quizLinks = (after.match(/href=["'][^"']*horror-quiz\.html["']/gi) || []).length;
  const minimum = target.hero && target.chips ? 4 : target.hero || target.chips ? 3 : 2;
  if (quizLinks < minimum) throw new Error(`Expected at least ${minimum} quiz links in ${target.file}, found ${quizLinks}`);

  if (after !== before) fs.writeFileSync(filePath, after, 'utf8');
  return { file: target.file, changed: after !== before, quizLinks };
}

const results = targets.map(updateTarget);
const quiz = fs.readFileSync(quizPath, 'utf8');
if (!quiz.includes(`assets/horror-quiz.js?v=${quizVersion}`)) throw new Error('Quiz runtime version mismatch');
if ((quiz.match(/<fieldset\b/gi) || []).length !== 3) throw new Error('Quiz must contain three questions');
if ((quiz.match(/href="stories\//g) || []).length !== 0) {
  throw new Error('Quiz recommendations must be rendered by the runtime, not duplicated in HTML');
}

console.log(JSON.stringify({ version: quizVersion, targets: results.length, changed: results.filter((row) => row.changed).length, results }));
