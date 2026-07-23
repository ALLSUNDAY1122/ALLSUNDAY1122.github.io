import fs from 'node:fs';
import path from 'node:path';

const SITE = path.resolve(process.cwd(), 'yorugatari');
const CATEGORY_DIR = path.join(SITE, 'categories');

function updateNav(html, navPattern, anchor, addition) {
  return html.replace(navPattern, (nav) => {
    if (nav.includes('bedtime-horror.html')) return nav;
    if (!nav.includes(anchor)) return nav;
    return nav.replace(anchor, `${anchor}${addition}`);
  });
}

function updateFile(relativePath, transform) {
  const filePath = path.join(SITE, relativePath);
  const original = fs.readFileSync(filePath, 'utf8');
  const updated = transform(original);
  if (updated !== original) {
    fs.writeFileSync(filePath, updated, 'utf8');
    return true;
  }
  return false;
}

let changed = 0;

changed += updateFile('index.html', (html) => {
  html = updateNav(
    html,
    /<nav class="nav" aria-label="主要メニュー">[\s\S]*?<\/nav>/,
    '<a href="5min-horror.html">5分で読む</a>',
    '<a href="bedtime-horror.html">寝る前に読む</a>'
  );
  html = updateNav(
    html,
    /<nav class="chips category-page-links"[^>]*>[\s\S]*?<\/nav>/,
    '<a class="chip" href="5min-horror.html">5分で読める12選</a>',
    '<a class="chip" href="bedtime-horror.html">寝る前に読む8選</a>'
  );
  html = updateNav(
    html,
    /<nav class="footer-links"[^>]*>[\s\S]*?<\/nav>/,
    '<a href="5min-horror.html">5分で読める怖い話</a>',
    '<a href="bedtime-horror.html">寝る前に読む怖い話</a>'
  );
  const hero = /<div class="hero-actions">[\s\S]*?<\/div>/;
  html = html.replace(hero, (block) => {
    if (block.includes('bedtime-horror.html')) return block;
    const anchor = '<a class="btn" href="5min-horror.html">5分で読める12選</a>';
    return block.includes(anchor) ? block.replace(anchor, `${anchor}<a class="btn" href="bedtime-horror.html">寝る前の8選</a>`) : block;
  });
  return html;
});

changed += updateFile('archive.html', (html) => {
  html = updateNav(
    html,
    /<nav class="nav" aria-label="主要メニュー">[\s\S]*?<\/nav>/,
    '<a href="5min-horror.html">5分で読む</a>',
    '<a href="bedtime-horror.html">寝る前に読む</a>'
  );
  html = updateNav(
    html,
    /<nav class="archive-jump" aria-label="カテゴリ別ページ">[\s\S]*?<\/nav>/,
    '<a class="chip" href="5min-horror.html">5分で読める12選</a>',
    '<a class="chip" href="bedtime-horror.html">寝る前に読む8選</a>'
  );
  html = updateNav(
    html,
    /<nav class="footer-links"[^>]*>[\s\S]*?<\/nav>/,
    '<a href="5min-horror.html">5分で読める怖い話</a>',
    '<a href="bedtime-horror.html">寝る前に読む怖い話</a>'
  );
  return html;
});

changed += updateFile('5min-horror.html', (html) => {
  html = updateNav(
    html,
    /<nav class="nav" aria-label="主要メニュー">[\s\S]*?<\/nav>/,
    '<a href="archive.html">全100話</a>',
    '<a href="bedtime-horror.html">寝る前に読む</a>'
  );
  html = updateNav(
    html,
    /<nav class="footer-links"[^>]*>[\s\S]*?<\/nav>/,
    '<a href="archive.html">全100話一覧</a>',
    '<a href="bedtime-horror.html">寝る前に読む怖い話</a>'
  );
  const hero = /<div class="hero-actions">[\s\S]*?<\/div>/;
  html = html.replace(hero, (block) => {
    if (block.includes('bedtime-horror.html')) return block;
    const anchor = '<a class="btn" href="archive.html">全100話を見る</a>';
    return block.includes(anchor) ? block.replace(anchor, `<a class="btn" href="bedtime-horror.html">寝る前の8選</a>${anchor}`) : block;
  });
  return html;
});

for (const filename of fs.readdirSync(CATEGORY_DIR).filter((name) => name.endsWith('.html')).sort()) {
  changed += updateFile(path.join('categories', filename), (html) => {
    html = updateNav(
      html,
      /<nav class="nav" aria-label="主要メニュー">[\s\S]*?<\/nav>/,
      '<a href="../5min-horror.html">5分で読む</a>',
      '<a href="../bedtime-horror.html">寝る前に読む</a>'
    );
    html = updateNav(
      html,
      /<nav class="chips category-nav"[^>]*>[\s\S]*?<\/nav>/,
      '<a class="chip" href="../5min-horror.html">5分で読める12選</a>',
      '<a class="chip" href="../bedtime-horror.html">寝る前に読む8選</a>'
    );
    html = updateNav(
      html,
      /<nav class="footer-links"[^>]*>[\s\S]*?<\/nav>/,
      '<a href="../5min-horror.html">5分で読める怖い話</a>',
      '<a href="../bedtime-horror.html">寝る前に読む怖い話</a>'
    );
    return html;
  });
}

console.log(`Ensured bedtime landing links in ${changed} files.`);
