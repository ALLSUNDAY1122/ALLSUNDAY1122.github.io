import fs from 'node:fs';
import path from 'node:path';

const ROOT = process.cwd();
const SITE_ROOT = path.join(ROOT, 'yorugatari');
const STORIES_ROOT = path.join(SITE_ROOT, 'stories');
const SCRIPT_VERSION = '20260723-001';
const SHARE_IMAGE = 'https://allsunday1122.github.io/yorugatari/assets/yorugatari-share.png';
const SHARE_WIDTH = '2172';
const SHARE_HEIGHT = '724';
const SHARE_ALT = '月明かりと提灯が照らす夜の町並み';
const STATIC_PAGES = ['index.html', 'archive.html', 'about.html', 'privacy.html', 'terms.html', 'contact.html'];

function escapeAttribute(value) {
  return String(value).replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function metaContent(html, pattern, label) {
  const match = html.match(pattern);
  if (!match || !match[1].trim()) throw new Error(`Missing ${label}`);
  return match[1].trim();
}

function upsertMeta(html, key, value, attribute = 'property') {
  const escapedKey = key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const pattern = new RegExp(`<meta\\s+${attribute}=["']${escapedKey}["']\\s+content=["'][^"']*["']\\s*\\/?>(?:\\s*)`, 'i');
  const tag = `<meta ${attribute}="${key}" content="${escapeAttribute(value)}">\n  `;
  if (pattern.test(html)) return html.replace(pattern, tag);
  return html.replace('</head>', `  ${tag}</head>`);
}

function ensureSocialMetadata(html) {
  const title = metaContent(html, /<title>([\s\S]*?)<\/title>/i, 'title').replace(/<[^>]+>/g, '');
  const description = metaContent(html, /<meta\s+name=["']description["']\s+content=["']([^"']+)["']/i, 'description');
  const canonical = metaContent(html, /<link\s+rel=["']canonical["']\s+href=["']([^"']+)["']/i, 'canonical');

  html = upsertMeta(html, 'og:locale', 'ja_JP');
  html = upsertMeta(html, 'og:type', canonical.includes('/stories/') ? 'article' : 'website');
  html = upsertMeta(html, 'og:url', canonical);
  html = upsertMeta(html, 'og:site_name', '夜語り');
  html = upsertMeta(html, 'og:title', title);
  html = upsertMeta(html, 'og:description', description);
  html = upsertMeta(html, 'og:image', SHARE_IMAGE);
  html = upsertMeta(html, 'og:image:width', SHARE_WIDTH);
  html = upsertMeta(html, 'og:image:height', SHARE_HEIGHT);
  html = upsertMeta(html, 'og:image:alt', SHARE_ALT);
  html = upsertMeta(html, 'twitter:card', 'summary_large_image', 'name');
  html = upsertMeta(html, 'twitter:image', SHARE_IMAGE, 'name');
  html = upsertMeta(html, 'twitter:image:alt', SHARE_ALT, 'name');
  return html;
}

function ensureEngagementScript(html, src) {
  const versioned = `${src}?v=${SCRIPT_VERSION}`;
  const existing = /<script\s+src=["'][^"']*engagement\.js(?:\?v=[^"']*)?["']\s*><\/script>/i;
  if (existing.test(html)) return html.replace(existing, `<script src="${versioned}"></script>`);
  return html.replace('</body>', `  <script src="${versioned}"></script>\n</body>`);
}

function normalizeStaticPage(filename) {
  const filePath = path.join(SITE_ROOT, filename);
  let html = fs.readFileSync(filePath, 'utf8');
  html = ensureSocialMetadata(html);
  html = ensureEngagementScript(html, 'assets/engagement.js');

  if (filename === 'privacy.html') {
    html = html.replace(
      '当サイトでは、作品ごとの閲覧数を表示するため、Page Views APIを利用しています。広告配信、会員登録、問い合わせフォームは導入していません。',
      '当サイトでは、主要ページと作品ごとの閲覧数、およびページが見つからなかったアクセスの合計を把握するため、Page Views APIを利用しています。広告配信、会員登録、問い合わせフォームは導入していません。'
    );
    html = html.replace('<h2>作品の閲覧数</h2>', '<h2>アクセス数の集計</h2>');
    html = html.replace(
      'Page Views APIは、作品ページの閲覧数を30分単位で重複を除いて集計します。重複判定のためにIPアドレスとブラウザ情報から短期間有効なハッシュを生成しますが、IPアドレスそのもの、Cookie、当サイトの読了履歴は保存しません。',
      'Page Views APIは、ページごとの閲覧数を30分単位で重複を除いて集計します。送信する内容はサイト識別子とページのパスです。重複判定のためにIPアドレスとブラウザ情報から短期間有効なハッシュを生成しますが、IPアドレスそのもの、Cookie、参照元URL、当サイトの読了履歴は保存しません。'
    );
    html = html.replace(/制定・最終更新：\d{4}年\d{1,2}月\d{1,2}日/, '制定・最終更新：2026年7月23日');
  }

  fs.writeFileSync(filePath, html, 'utf8');
}

function normalizeStoryPage(filename) {
  const filePath = path.join(STORIES_ROOT, filename);
  let html = fs.readFileSync(filePath, 'utf8');
  html = ensureSocialMetadata(html);
  html = ensureEngagementScript(html, '../assets/engagement.js');
  fs.writeFileSync(filePath, html, 'utf8');
}

function normalize404() {
  const filePath = path.join(ROOT, '404.html');
  let html = fs.readFileSync(filePath, 'utf8');
  html = html.replace('<body>', '<body data-page-type="404">');
  if (!html.includes('href="/yorugatari/archive.html"')) {
    html = html.replace(
      '<a class="btn btn-primary" href="/yorugatari/">夜語りへ戻る</a>',
      '<a class="btn btn-primary" href="/yorugatari/">夜語りへ戻る</a><a class="btn" href="/yorugatari/archive.html">全100話から探す</a>'
    );
  }
  html = ensureEngagementScript(html, '/yorugatari/assets/engagement.js');
  fs.writeFileSync(filePath, html, 'utf8');
}

STATIC_PAGES.forEach(normalizeStaticPage);
fs.readdirSync(STORIES_ROOT)
  .filter((filename) => filename.endsWith('.html'))
  .sort()
  .forEach(normalizeStoryPage);
normalize404();

console.log(`Normalized engagement for ${STATIC_PAGES.length} static pages and ${fs.readdirSync(STORIES_ROOT).filter((name) => name.endsWith('.html')).length} stories.`);
