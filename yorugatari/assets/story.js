document.documentElement.classList.add('js');

const mainContent = document.querySelector('main');
const progress = document.querySelector('.progress');
const slug = document.body.dataset.slug || '';
const storyTitle = (document.querySelector('.story-hero h1') || {}).textContent || '';
const storyCategory = (document.querySelector('.story-hero .badge') || {}).textContent || '怖い話';
const headerMeta = document.querySelectorAll('.story-hero .meta span');
const completedStorageKey = 'yorugatari-completed-stories';
const lastReadingStorageKey = 'yorugatari-last-reading';
const favoritesStorageKey = 'yorugatari-favorites';

if (mainContent) {
  if (!mainContent.id) mainContent.id = 'story-content';
  if (!mainContent.hasAttribute('tabindex')) mainContent.setAttribute('tabindex', '-1');
  if (!document.querySelector('.skip-link')) {
    const skipLink = document.createElement('a');
    skipLink.className = 'skip-link';
    skipLink.href = '#' + mainContent.id;
    skipLink.textContent = '本文へ移動';
    document.body.insertAdjacentElement('afterbegin', skipLink);
  }
}

if (progress) progress.setAttribute('aria-hidden', 'true');
addEventListener('scroll', function () {
  const documentElement = document.documentElement;
  const max = documentElement.scrollHeight - documentElement.clientHeight;
  if (progress) progress.style.width = (max ? documentElement.scrollTop / max * 100 : 0) + '%';
}, { passive: true });

const mainNav = document.querySelector('.site-header .nav');
if (mainNav) {
  mainNav.setAttribute('aria-label', '主要メニュー');
  const rankingLink = mainNav.querySelector('a[href*="#ranking"]');
  if (rankingLink) rankingLink.textContent = 'おすすめ';
}

document.querySelectorAll('.rank-item').forEach(function (item) {
  const detail = item.querySelector('small');
  const marker = item.querySelector('.rank-num');
  if (detail) detail.textContent = detail.textContent.replace(/約\d+分/, '約5分');
  if (marker) marker.setAttribute('aria-hidden', 'true');
});

const fear = document.querySelector('.story-side .fear');
if (fear) {
  const fearLevel = (fear.textContent.match(/●/g) || []).length;
  fear.setAttribute('aria-label', '怖さ ' + fearLevel + '/5');
}

function ensurePropertyMeta(property, content) {
  let element = document.querySelector('meta[property="' + property + '"]');
  if (!element) {
    element = document.createElement('meta');
    element.setAttribute('property', property);
    document.head.appendChild(element);
  }
  element.setAttribute('content', content);
}

function ensurePreconnect() {
  if (document.querySelector('link[rel="preconnect"][href="https://page-views-api.ratneshc.com"]')) return;
  const link = document.createElement('link');
  link.rel = 'preconnect';
  link.href = 'https://page-views-api.ratneshc.com';
  link.crossOrigin = 'anonymous';
  const canonical = document.querySelector('link[rel="canonical"]');
  document.head.insertBefore(link, canonical || document.head.firstChild);
}

function ensureVisibleBreadcrumb() {
  const storyHeroContent = document.querySelector('.story-hero .wrap');
  if (!storyHeroContent || storyHeroContent.querySelector('.breadcrumb')) return;
  const breadcrumb = document.createElement('nav');
  breadcrumb.className = 'breadcrumb';
  breadcrumb.setAttribute('aria-label', 'パンくずリスト');
  breadcrumb.innerHTML =
    '<a href="../index.html">夜語り</a>' +
    '<span aria-hidden="true">›</span>' +
    '<a href="../archive.html">全100話</a>' +
    '<span aria-hidden="true">›</span>' +
    '<a href="../archive.html#' + encodeURIComponent(storyCategory) + '">' + storyCategory + '</a>';
  storyHeroContent.insertAdjacentElement('afterbegin', breadcrumb);
}

function ensureBreadcrumbStructuredData(story) {
  const canonical = document.querySelector('link[rel="canonical"]');
  const pageUrl = canonical ? canonical.href : location.href.split('#')[0];
  const category = story && story.category ? story.category : storyCategory;
  const title = story && story.title ? story.title : storyTitle;
  const data = {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: [
      { '@type': 'ListItem', position: 1, name: '夜語り', item: 'https://allsunday1122.github.io/yorugatari/' },
      { '@type': 'ListItem', position: 2, name: '全100話', item: 'https://allsunday1122.github.io/yorugatari/archive.html' },
      { '@type': 'ListItem', position: 3, name: category, item: 'https://allsunday1122.github.io/yorugatari/archive.html#' + encodeURIComponent(category) },
      { '@type': 'ListItem', position: 4, name: title, item: pageUrl }
    ]
  };
  let target = null;
  document.querySelectorAll('script[type="application/ld+json"]').forEach(function (script) {
    try {
      const parsed = JSON.parse(script.textContent);
      if (parsed && parsed['@type'] === 'BreadcrumbList') target = script;
    } catch (error) {}
  });
  if (!target) {
    target = document.createElement('script');
    target.type = 'application/ld+json';
    document.head.appendChild(target);
  }
  target.textContent = JSON.stringify(data);
}

function ensureFooterLinks() {
  const footerInner = document.querySelector('.site-footer .footer-inner');
  if (!footerInner) return;
  let footerNav = footerInner.querySelector('.footer-links');
  if (!footerNav) {
    footerNav = document.createElement('nav');
    footerNav.className = 'footer-links';
    footerInner.appendChild(footerNav);
  }
  footerNav.setAttribute('aria-label', '運営情報');
  [
    ['../archive.html', '全100話一覧'],
    ['../about.html', '運営・編集方針'],
    ['../privacy.html', 'プライバシー'],
    ['../terms.html', '利用規約'],
    ['../contact.html', 'お問い合わせ']
  ].forEach(function (entry) {
    if (footerNav.querySelector('a[href="' + entry[0] + '"]')) return;
    const link = document.createElement('a');
    link.href = entry[0];
    link.textContent = entry[1];
    footerNav.appendChild(link);
  });
}

function normalizeBasicPage() {
  ensurePreconnect();
  ensurePropertyMeta('og:image:width', '2048');
  ensurePropertyMeta('og:image:height', '683');
  ensurePropertyMeta('og:image:alt', '月明かりと提灯が照らす夜の町並み');
  ensureVisibleBreadcrumb();
  ensureBreadcrumbStructuredData(null);
  ensureFooterLinks();
  if (progress) progress.setAttribute('aria-hidden', 'true');
  if (headerMeta.length) headerMeta[headerMeta.length - 1].textContent = '約5分';
}

normalizeBasicPage();

const explanationButton = document.querySelector('#explainBtn');
const explanation = document.querySelector('#explanation');
if (explanationButton) explanationButton.setAttribute('type', 'button');
if (explanationButton && explanation) {
  if (!explanation.id) explanation.id = 'explanation';
  explanationButton.setAttribute('aria-controls', explanation.id);
  explanationButton.setAttribute('aria-expanded', 'false');
  explanation.hidden = true;
  explanation.classList.remove('open');
  explanationButton.addEventListener('click', function () {
    const isOpen = explanation.hidden;
    explanation.hidden = !isOpen;
    explanation.classList.toggle('open', isOpen);
    explanationButton.setAttribute('aria-expanded', String(isOpen));
    explanationButton.textContent = isOpen ? '解説を閉じる' : '解説を見る';
  });
}

const storyInfoBox = document.querySelector('.story-side .side-box, .story-side .story-info, .story-side, .story-info');
let favorites = [];
try {
  const stored = JSON.parse(localStorage.getItem(favoritesStorageKey) || '[]');
  favorites = Array.isArray(stored) ? stored : [];
} catch (error) {}

let favoriteButton = document.querySelector('#favoriteBtn');
if (!favoriteButton && storyInfoBox && slug) {
  favoriteButton = document.createElement('button');
  favoriteButton.id = 'favoriteBtn';
  favoriteButton.className = 'btn favorite';
  storyInfoBox.insertAdjacentElement('afterbegin', favoriteButton);
}
if (favoriteButton) favoriteButton.setAttribute('type', 'button');

function drawFavorite() {
  if (!favoriteButton) return;
  const selected = favorites.includes(slug);
  favoriteButton.classList.toggle('active', selected);
  favoriteButton.setAttribute('aria-pressed', String(selected));
  favoriteButton.textContent = selected ? '★ お気に入り済み' : '☆ お気に入り';
}

if (favoriteButton) {
  favoriteButton.addEventListener('click', function () {
    favorites = favorites.includes(slug)
      ? favorites.filter(function (item) { return item !== slug; })
      : favorites.concat(slug);
    try { localStorage.setItem(favoritesStorageKey, JSON.stringify(favorites)); } catch (error) {}
    drawFavorite();
  });
}
drawFavorite();

let completedStories = [];
try {
  const stored = JSON.parse(localStorage.getItem(completedStorageKey) || '[]');
  completedStories = Array.isArray(stored) ? stored : [];
} catch (error) {}

function saveCompletedStories() {
  try { localStorage.setItem(completedStorageKey, JSON.stringify(completedStories)); } catch (error) {}
}

function isCompleted() {
  return Boolean(slug && completedStories.includes(slug));
}

let completedButton = null;
let completedStatus = null;
if (storyInfoBox && slug && !storyInfoBox.querySelector('.reading-status')) {
  const readingStatus = document.createElement('div');
  readingStatus.className = 'reading-status';
  readingStatus.innerHTML =
    '<p class="view-count" aria-live="polite">閲覧数 <strong>—</strong></p>' +
    '<button class="btn completed-toggle" type="button"></button>' +
    '<p class="completed-note" aria-live="polite"></p>';
  const actions = storyInfoBox.querySelector('.hero-actions');
  storyInfoBox.insertBefore(readingStatus, actions || null);
  completedButton = readingStatus.querySelector('.completed-toggle');
  completedStatus = readingStatus.querySelector('.completed-note');
} else if (storyInfoBox) {
  completedButton = storyInfoBox.querySelector('.completed-toggle');
  completedStatus = storyInfoBox.querySelector('.completed-note');
}

function drawCompleted(automatic) {
  if (!completedButton || !completedStatus) return;
  const completed = isCompleted();
  completedButton.classList.toggle('active', completed);
  completedButton.setAttribute('aria-pressed', String(completed));
  completedButton.textContent = completed ? '✓ 読了済み' : '○ 読了にする';
  completedStatus.textContent = completed
    ? (automatic ? '本文の最後まで読んだため、読了にしました。' : 'この端末の読了リストに保存されています。')
    : '読了状況はこの端末だけに保存されます。';
}

function setCompleted(completed, automatic) {
  if (!slug) return;
  completedStories = completed
    ? Array.from(new Set(completedStories.concat(slug)))
    : completedStories.filter(function (item) { return item !== slug; });
  saveCompletedStories();
  if (completed) {
    try {
      const last = JSON.parse(localStorage.getItem(lastReadingStorageKey) || 'null');
      if (last && last.slug === slug) localStorage.removeItem(lastReadingStorageKey);
    } catch (error) {}
  }
  drawCompleted(automatic);
}

if (completedButton) {
  completedButton.addEventListener('click', function () {
    setCompleted(!isCompleted(), false);
  });
}
drawCompleted(false);

const storyBody = document.querySelector('.story-body');
const openedAt = Date.now();
let lastPositionSavedAt = 0;

function saveReadingPosition(force) {
  if (!slug || !storyBody || isCompleted()) return;
  if (!force && Date.now() - lastPositionSavedAt < 1000) return;
  const documentElement = document.documentElement;
  const max = documentElement.scrollHeight - documentElement.clientHeight;
  const readingProgress = Math.max(0, Math.min(99, Math.round((max ? documentElement.scrollTop / max : 0) * 100)));
  try {
    localStorage.setItem(lastReadingStorageKey, JSON.stringify({
      slug: slug,
      progress: readingProgress,
      updatedAt: Date.now()
    }));
    lastPositionSavedAt = Date.now();
  } catch (error) {}
}

if (location.hash === '#resume') {
  try {
    const savedReading = JSON.parse(localStorage.getItem(lastReadingStorageKey) || 'null');
    if (savedReading && savedReading.slug === slug && Number(savedReading.progress) > 0) {
      requestAnimationFrame(function () {
        const max = document.documentElement.scrollHeight - document.documentElement.clientHeight;
        scrollTo({
          top: max * Number(savedReading.progress) / 100,
          behavior: 'smooth'
        });
      });
    }
  } catch (error) {}
}

function markCompletedAtEnd() {
  if (!storyBody || isCompleted() || Date.now() - openedAt < 15000) return;
  const rect = storyBody.getBoundingClientRect();
  if (rect.bottom <= window.innerHeight + 80) setCompleted(true, true);
}

addEventListener('scroll', markCompletedAtEnd, { passive: true });
addEventListener('scroll', function () { saveReadingPosition(false); }, { passive: true });
addEventListener('pagehide', function () { saveReadingPosition(true); });
saveReadingPosition(true);
setTimeout(markCompletedAtEnd, 15000);

const catalogSources = [
  'stories.js',
  'stories-016-025.js',
  'stories-026-035.js',
  'stories-036-045.js',
  'stories-046-055.js',
  'stories-056-065.js',
  'stories-066-075.js',
  'stories-076-085.js',
  'stories-086-095.js',
  'stories-096-100.js'
];

function loadCatalogScript(source) {
  return new Promise(function (resolve) {
    const script = document.createElement('script');
    script.src = '../assets/' + source + '?v=20260723-003';
    script.async = false;
    script.onload = function () { resolve(true); };
    script.onerror = function () { resolve(false); };
    document.head.appendChild(script);
  });
}

function storyPageHref(story) {
  const href = story && story.href ? story.href : (story.slug + '.html');
  return href.replace(/^\.\.\//, '').replace(/^stories\//, '');
}

function ensureStoryId(story, currentIndex, completeCatalog) {
  if (!completeCatalog) return;
  const storyInfo = document.querySelector('.story-info');
  if (!storyInfo) return;
  const storyId = 'YGT-' + String(currentIndex + 1).padStart(3, '0');
  if (storyInfo.textContent.includes(storyId)) return;
  const definitionList = storyInfo.querySelector('dl');
  if (definitionList) {
    const term = document.createElement('dt');
    const value = document.createElement('dd');
    term.textContent = '作品ID';
    value.textContent = storyId;
    definitionList.insertBefore(value, definitionList.firstChild);
    definitionList.insertBefore(term, value);
    return;
  }
  const paragraph = document.createElement('p');
  paragraph.textContent = 'ID：' + storyId;
  const heading = storyInfo.querySelector('h2');
  if (heading) heading.insertAdjacentElement('afterend', paragraph);
  else storyInfo.insertAdjacentElement('afterbegin', paragraph);
}

function buildStoryPagination(stories, currentIndex, completeCatalog) {
  if (!slug || document.querySelector('.story-pagination')) return;
  const navigation = document.createElement('nav');
  navigation.className = 'hero-actions story-pagination';
  navigation.setAttribute('aria-label', completeCatalog ? '前後の怖い話' : '作品一覧');

  if (completeCatalog && currentIndex > 0 && stories[currentIndex - 1]) {
    const previousStory = stories[currentIndex - 1];
    const previousLink = document.createElement('a');
    previousLink.className = 'btn';
    previousLink.href = storyPageHref(previousStory);
    previousLink.textContent = '← 前の話「' + previousStory.title + '」';
    navigation.appendChild(previousLink);
  }

  const archiveLink = document.createElement('a');
  archiveLink.className = 'btn';
  archiveLink.href = '../archive.html';
  archiveLink.textContent = '全100話一覧';
  navigation.appendChild(archiveLink);

  if (completeCatalog && currentIndex >= 0 && stories[currentIndex + 1]) {
    const nextStory = stories[currentIndex + 1];
    const nextLink = document.createElement('a');
    nextLink.className = 'btn btn-primary';
    nextLink.href = storyPageHref(nextStory);
    nextLink.textContent = '次の話「' + nextStory.title + '」→';
    navigation.appendChild(nextLink);
  }

  const storyShell = document.querySelector('.story-shell');
  if (storyShell) storyShell.insertAdjacentElement('afterend', navigation);
  else if (mainContent) mainContent.appendChild(navigation);
}

catalogSources.reduce(function (promise, source) {
  return promise.then(function (loadedCount) {
    return loadCatalogScript(source).then(function (loaded) {
      return loadedCount + (loaded ? 1 : 0);
    });
  });
}, Promise.resolve(0)).then(function (loadedCount) {
  const catalog = Array.isArray(window.STORIES) ? window.STORIES : [];
  const stories = Array.from(new Map(catalog.map(function (story) {
    return [story.slug, story];
  })).values());
  const currentIndex = stories.findIndex(function (story) {
    return story.slug === slug;
  });
  const currentStory = currentIndex >= 0 ? stories[currentIndex] : null;
  const completeCatalog = loadedCount === catalogSources.length;

  if (currentStory) {
    ensureBreadcrumbStructuredData(currentStory);
    if (headerMeta.length && currentStory.minutes) {
      headerMeta[headerMeta.length - 1].textContent = '約' + currentStory.minutes + '分';
    }
    ensureStoryId(currentStory, currentIndex, completeCatalog);
  }
  buildStoryPagination(stories, currentIndex, completeCatalog);
});
