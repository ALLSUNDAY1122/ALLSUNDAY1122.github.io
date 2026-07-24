import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const site = path.join(root, 'yorugatari');
const version = '20260724-001';
const files = ['5min-horror.html', 'bedtime-horror.html'];
const shareSection = `    <section class="section landing-share" aria-labelledby="landing-share-title"><div class="wrap"><div class="section-head"><div><div class="eyebrow">Share</div><h2 id="landing-share-title">この特集を共有する</h2></div></div><p class="landing-intro">共有用リンクには作品名や個人情報を含めず、この特集から再訪問があったことだけを匿名で集計します。</p><div class="hero-actions"><button class="btn btn-primary" id="landingShareButton" type="button">共有する</button><button class="btn" id="landingCopyButton" type="button">リンクをコピー</button></div><p class="share-status" id="landingShareStatus" role="status" aria-live="polite"></p></div></section>\n\n`;

function ensureShareSection(html) {
  if (html.includes('id="landingShareButton"')) return html;
  const faq = '    <section class="section"><div class="wrap"><div class="section-head"><div><div class="eyebrow">FAQ</div>';
  if (!html.includes(faq)) throw new Error('FAQ insertion point was not found');
  return html.replace(faq, shareSection + faq);
}

function ensureShareScript(html) {
  html = html.replace(/\s*<script\s+src=["']assets\/landing-share\.js(?:\?v=[^"']*)?["']\s*><\/script>\s*/gi, '\n');
  const analytics = /  <script src="assets\/analytics\.js\?v=[^"]+"><\/script>/;
  if (!analytics.test(html)) throw new Error('Analytics script insertion point was not found');
  return html.replace(analytics, `  <script src="assets/landing-share.js?v=${version}"></script>\n$&`);
}

let changed = 0;
for (const filename of files) {
  const filePath = path.join(site, filename);
  const before = fs.readFileSync(filePath, 'utf8');
  let after = ensureShareSection(before);
  after = ensureShareScript(after);
  if (after !== before) {
    fs.writeFileSync(filePath, after, 'utf8');
    changed += 1;
  }
}

console.log(`Ensured curated landing sharing on ${files.length} pages; changed ${changed}.`);
