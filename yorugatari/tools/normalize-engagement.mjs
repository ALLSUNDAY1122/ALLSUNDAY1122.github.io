import fs from 'node:fs';
import path from 'node:path';

const ROOT = process.cwd();
const SITE_ROOT = path.join(ROOT, 'yorugatari');
const STORIES_ROOT = path.join(SITE_ROOT, 'stories');
const ANALYTICS_VERSION = '20260723-003';
const FIVE_MINUTE_ANALYTICS_VERSION = '20260724-004';
const BEDTIME_ANALYTICS_VERSION = '20260724-005';
const ENGAGEMENT_VERSION = '20260723-003';
const RUNTIME_RELEASE = '20260724-001';
const AUDITED_STORIES = new Set(['last-elevator.html', 'spare-key-returned.html', 'hired-with-your-experience.html']);
const SHARE_IMAGE = 'https://allsunday1122.github.io/yorugatari/assets/yorugatari-share.png';
const SHARE_WIDTH = '2172';
const SHARE_HEIGHT = '724';
const SHARE_ALT = '月明かりと提灯が照らす夜の町並み';
const STATIC_PAGES = ['index.html', '5min-horror.html', 'bedtime-horror.html', 'archive.html', 'about.html', 'privacy.html', 'terms.html', 'contact.html'];

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

function setRuntimeScript(html, src, version, release = null) {
  html = html.replace(/\s*<script\s+src=["'][^"']*\/(?:analytics|engagement)\.js(?:\?v=[^"']*)?["']\s*><\/script>\s*/gi, '\n');
  const query = `?v=${version}${release ? `&r=${release}` : ''}`;
  return html.replace('</body>', `  <script src="${src}${query}"></script>\n</body>`);
}

function ensureStoryCuratedLinks(html) {
  const fiveMinuteLink = '<a href="../5min-horror.html">5分で読める12選</a>';
  const bedtimeLink = '<a href="../bedtime-horror.html">寝る前の8選</a>';
  html = html.replace(/<a href=["']\.\.\/5min-horror\.html["']>[^<]*<\/a>/gi, '');
  html = html.replace(/<a href=["']\.\.\/bedtime-horror\.html["']>[^<]*<\/a>/gi, '');
  const footerNav = /(<nav class=["']footer-links["'][^>]*>)/i;
  if (!footerNav.test(html)) throw new Error('Story footer navigation was not found');
  return html.replace(footerNav, `$1${fiveMinuteLink}${bedtimeLink}`);
}

function normalizeStaticPage(filename) {
  const filePath = path.join(SITE_ROOT, filename);
  let html = fs.readFileSync(filePath, 'utf8');
  html = ensureSocialMetadata(html);
  const analyticsVersion = filename === '5min-horror.html'
    ? FIVE_MINUTE_ANALYTICS_VERSION
    : filename === 'bedtime-horror.html'
      ? BEDTIME_ANALYTICS_VERSION
      : ANALYTICS_VERSION;
  html = setRuntimeScript(html, 'assets/analytics.js', analyticsVersion, RUNTIME_RELEASE);

  if (filename === 'privacy.html') {
    html = html.replace(
      '当サイトでは、作品ごとの閲覧数を表示するため、Page Views APIを利用しています。広告配信、会員登録、問い合わせフォームは導入していません。',
      '当サイトでは、主要ページと作品ごとの閲覧数、およびページが見つからなかったアクセスの合計を把握するため、Page Views APIを利用しています。広告配信、会員登録、問い合わせフォームは導入していません。'
    );
    html = html.replace('<h2>作品の閲覧数</h2>', '<h2>アクセス数の集計</h2>');
    html = html.replace(
      /<h2>アクセス数の集計<\/h2>\s*<p>[^<]*<\/p>/,
      '<h2>アクセス数の集計</h2>\n      <p>Page Views APIは、ページごとの閲覧数を30分単位で重複を除いて集計します。送信する内容はサイト識別子とページのパスです。外部サイトから初めて訪れた場合は、参照元をブラウザ内で「検索」「SNS」「直接」「その他の参照」「キャンペーン」の粗い区分へ変換し、1セッションにつき1回だけ区分を送信します。夜語りが事前に用意した告知リンクでは、媒体と投稿内容の組合せを表す固定キャンペーンコードも送信します。特集ページから作品を開いた場合は、「5分で読める12選」または「寝る前の8選」のどちらから作品閲覧を開始したかを、特集単位で1セッションにつき1回だけ送信します。開いた作品名や作品URLはこの集計へ含めません。自動監査、Lighthouse、ヘッドレスブラウザによる品質確認は閲覧数と作品開始数に含めません。任意に付けられたUTM値は保存せず、登録済みコードに一致しない値は破棄します。参照元URL、検索語、IPアドレスそのもの、Cookie、当サイトの読了履歴は保存しません。</p>'
    );
    html = html.replace(/制定・最終更新：\d{4}年\d{1,2}月\d{1,2}日/, '制定・最終更新：2026年7月24日');
  }

  fs.writeFileSync(filePath, html, 'utf8');
}

function normalizeStoryPage(filename) {
  const filePath = path.join(STORIES_ROOT, filename);
  let html = fs.readFileSync(filePath, 'utf8');
  html = ensureSocialMetadata(html);
  html = ensureStoryCuratedLinks(html);
  html = setRuntimeScript(html, '../assets/engagement.js', ENGAGEMENT_VERSION, AUDITED_STORIES.has(filename) ? RUNTIME_RELEASE : null);
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
  html = setRuntimeScript(html, '/yorugatari/assets/analytics.js', ANALYTICS_VERSION, RUNTIME_RELEASE);
  fs.writeFileSync(filePath, html, 'utf8');
}

STATIC_PAGES.forEach(normalizeStaticPage);
fs.readdirSync(STORIES_ROOT)
  .filter((filename) => filename.endsWith('.html'))
  .sort()
  .forEach(normalizeStoryPage);
normalize404();

console.log(`Normalized audit-filtered analytics for ${STATIC_PAGES.length} static pages, ${AUDITED_STORIES.size} audited stories, shared engagement for the remaining stories, and the 404 page.`);
