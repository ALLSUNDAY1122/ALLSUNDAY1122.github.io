import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const site = path.join(root, 'yorugatari');
const normalizationGeneration = '20260724-003';
const shareVersion = '20260724-002';
const startRuntime = 'landing-start-20260724-001.js';
const files = ['5min-horror.html', 'bedtime-horror.html'];
const shareSection = `    <section class="section landing-share" aria-labelledby="landing-share-title"><div class="wrap"><div class="section-head"><div><div class="eyebrow">Share</div><h2 id="landing-share-title">この特集を共有する</h2></div></div><p class="landing-intro">共有用リンクには作品名や個人情報を含めません。特集から作品を開いた回数は、特集単位の合計だけを匿名で集計します。</p><div class="hero-actions"><button class="btn btn-primary" id="landingShareButton" type="button">共有する</button><button class="btn" id="landingCopyButton" type="button">リンクをコピー</button></div><p class="share-status" id="landingShareStatus" role="status" aria-live="polite"></p></div></section>\n\n`;

function ensureShareSection(html) {
  if (html.includes('id="landingShareButton"')) {
    return html.replace(/<section class="section landing-share"[\s\S]*?<\/section>\n\n/, shareSection);
  }
  const faq = '    <section class="section"><div class="wrap"><div class="section-head"><div><div class="eyebrow">FAQ</div>';
  if (!html.includes(faq)) throw new Error('FAQ insertion point was not found');
  return html.replace(faq, shareSection + faq);
}

function ensureRuntimeScripts(html) {
  html = html.replace(/\s*<script\s+src=["']assets\/landing-share\.js(?:\?v=[^"']*)?["']\s*><\/script>\s*/gi, '\n');
  html = html.replace(/\s*<script\s+src=["']assets\/landing-start-[^"']+\.js["']\s*><\/script>\s*/gi, '\n');
  html = html.replace(/\s*<script\s+data-runtime=["']landing-start-[^"']+["'][\s\S]*?<\/script>\s*/gi, '\n');
  const analytics = /  <script src="assets\/analytics\.js\?v=[^"]+"><\/script>/;
  if (!analytics.test(html)) throw new Error('Analytics script insertion point was not found');
  return html.replace(analytics, `  <script src="assets/landing-share.js?v=${shareVersion}"></script>\n  <script src="assets/${startRuntime}"></script>\n$&`);
}

let changed = 0;
for (const filename of files) {
  const filePath = path.join(site, filename);
  const before = fs.readFileSync(filePath, 'utf8');
  let after = ensureShareSection(before);
  after = ensureRuntimeScripts(after);
  const startCount = (after.match(new RegExp(`assets/${startRuntime.replace('.', '\\.')}`, 'g')) || []).length;
  if (startCount !== 1) throw new Error(`Expected one landing start runtime in ${filename}, found ${startCount}`);
  if (after !== before) {
    fs.writeFileSync(filePath, after, 'utf8');
    changed += 1;
  }
}

console.log(`Ensured curated landing sharing and cache-safe start tracking (${normalizationGeneration}) on ${files.length} pages; changed ${changed}.`);
