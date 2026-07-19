document.documentElement.classList.add('js');

const readingMinutes = {
  'last-elevator': 5,
  'neighbor-wifi': 5,
  'kind-manager': 5,
  'family-photo': 5,
  'three-knocks': 5,
  'read-receipt': 5,
  'night-bus': 5,
  'delivery-box': 5,
  'voice-memo': 5,
  'missing-floor': 5,
  'good-night': 5,
  'window-reflection': 5
};

const mainContent = document.querySelector('main');
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

const progress = document.querySelector('.progress');
if (progress) progress.setAttribute('aria-hidden', 'true');
addEventListener('scroll', function () {
  const documentElement = document.documentElement;
  const max = documentElement.scrollHeight - documentElement.clientHeight;
  if (progress) progress.style.width = (max ? documentElement.scrollTop / max * 100 : 0) + '%';
}, { passive: true });

const slug = document.body.dataset.slug;
const completedStorageKey = 'yorugatari-completed-stories';
const lastReadingStorageKey = 'yorugatari-last-reading';
let completedStories = [];
try {
  const storedCompleted = JSON.parse(localStorage.getItem(completedStorageKey) || '[]');
  completedStories = Array.isArray(storedCompleted) ? storedCompleted : [];
} catch (error) {
  completedStories = [];
}

function saveCompletedStories() {
  try { localStorage.setItem(completedStorageKey, JSON.stringify(completedStories)); } catch (error) {}
}

function isCompleted() {
  return Boolean(slug && completedStories.includes(slug));
}

const storyTitle = (document.querySelector('.story-hero h1') || {}).textContent || '';
const storyCategory = (document.querySelector('.story-hero .badge') || {}).textContent || '怖い話';
const storyHeroContent = document.querySelector('.story-hero .wrap');
if (storyHeroContent && !storyHeroContent.querySelector('.breadcrumb')) {
  const breadcrumb = document.createElement('nav');
  breadcrumb.className = 'breadcrumb';
  breadcrumb.setAttribute('aria-label', 'パンくずリスト');
  breadcrumb.innerHTML = '<a href="../index.html">夜語り</a><span aria-hidden="true">›</span><a href="../archive.html">全100話</a><span aria-hidden="true">›</span><a href="../archive.html#' + encodeURIComponent(storyCategory) + '">' + storyCategory + '</a>';
  storyHeroContent.insertAdjacentElement('afterbegin', breadcrumb);
}
const currentMinutes = readingMinutes[slug];
const headerMeta = document.querySelectorAll('.story-hero .meta span');
if (currentMinutes && headerMeta.length) {
  headerMeta[headerMeta.length - 1].textContent = '約' + currentMinutes + '分';
}

document.querySelectorAll('.rank-item').forEach(function (item) {
  const href = item.getAttribute('href') || '';
  const relatedSlug = href.replace(/^.*\//, '').replace(/\.html(?:#.*)?$/, '');
  const minutes = readingMinutes[relatedSlug];
  const detail = item.querySelector('small');
  const marker = item.querySelector('.rank-num');
  if (minutes && detail) detail.textContent = detail.textContent.replace(/約\d+分/, '約' + minutes + '分');
  if (marker) marker.setAttribute('aria-hidden', 'true');
});

const mainNav = document.querySelector('.site-header .nav');
if (mainNav) {
  mainNav.setAttribute('aria-label', '主要メニュー');
  const rankingLink = mainNav.querySelector('a[href*="#ranking"]');
  if (rankingLink) rankingLink.textContent = 'おすすめ';
}

const fear = document.querySelector('.story-side .fear');
if (fear) {
  const fearLevel = (fear.textContent.match(/●/g) || []).length;
  fear.setAttribute('aria-label', '怖さ ' + fearLevel + '/5');
}

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

const storyInfoBox = document.querySelector('.story-side .side-box, .story-side .story-info, .story-side');
let favoriteButton = document.querySelector('#favoriteBtn');
if (!favoriteButton && storyInfoBox && slug) {
  favoriteButton = document.createElement('button');
  favoriteButton.id = 'favoriteBtn';
  favoriteButton.className = 'btn favorite';
  storyInfoBox.insertAdjacentElement('afterbegin', favoriteButton);
}
if (favoriteButton) favoriteButton.setAttribute('type', 'button');
const storageKey = 'yorugatari-favorites';
let favorites = [];
try {
  const stored = JSON.parse(localStorage.getItem(storageKey) || '[]');
  favorites = Array.isArray(stored) ? stored : [];
} catch (error) {
  favorites = [];
}

function drawFavorite() {
  if (!favoriteButton) return;
  const selected = favorites.includes(slug);
  favoriteButton.classList.toggle('active', selected);
  favoriteButton.setAttribute('aria-pressed', String(selected));
  favoriteButton.textContent = selected ? '★ お気に入り済み' : '☆ お気に入り';
}

if (favoriteButton) {
  favoriteButton.addEventListener('click', function () {
    favorites = favorites.includes(slug) ? favorites.filter(function (item) { return item !== slug; }) : favorites.concat(slug);
    try { localStorage.setItem(storageKey, JSON.stringify(favorites)); } catch (error) {}
    drawFavorite();
  });
}
drawFavorite();

let completedButton = null;
let completedStatus = null;
let viewCount = null;

if (storyInfoBox && slug) {
  const readingStatus = document.createElement('div');
  readingStatus.className = 'reading-status';
  readingStatus.innerHTML = '<p class="view-count" aria-live="polite">閲覧数 <strong>—</strong></p><button class="btn completed-toggle" type="button"></button><p class="completed-note" aria-live="polite"></p>';
  const actions = storyInfoBox.querySelector('.hero-actions');
  storyInfoBox.insertBefore(readingStatus, actions || null);
  completedButton = readingStatus.querySelector('.completed-toggle');
  completedStatus = readingStatus.querySelector('.completed-note');
  viewCount = readingStatus.querySelector('.view-count strong');
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
    localStorage.setItem(lastReadingStorageKey, JSON.stringify({ slug: slug, progress: readingProgress, updatedAt: Date.now() }));
    lastPositionSavedAt = Date.now();
  } catch (error) {}
}

if (location.hash === '#resume') {
  try {
    const savedReading = JSON.parse(localStorage.getItem(lastReadingStorageKey) || 'null');
    if (savedReading && savedReading.slug === slug && Number(savedReading.progress) > 0) {
      requestAnimationFrame(function () {
        const max = document.documentElement.scrollHeight - document.documentElement.clientHeight;
        scrollTo({ top: max * Number(savedReading.progress) / 100, behavior: 'smooth' });
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
  return new Promise(function (resolve, reject) {
    const script = document.createElement('script');
    script.src = '../assets/' + source + '?v=20260719-100';
    script.async = false;
    script.onload = resolve;
    script.onerror = reject;
    document.head.appendChild(script);
  });
}

function recommendationLink(story, className) {
  const link = document.createElement('a');
  link.className = className;
  link.href = story.slug + '.html';
  const title = document.createElement('strong');
  title.textContent = story.title;
  const detail = document.createElement('span');
  detail.textContent = story.category + '・約' + story.minutes + '分' + (completedStories.includes(story.slug) ? '・読了済み' : '');
  link.appendChild(title);
  link.appendChild(detail);
  return link;
}

async function buildNextStoryGuide() {
  if (!storyBody || !slug || storyBody.querySelector('.story-next')) return;
  try {
    window.STORIES = [];
    await Promise.all(catalogSources.map(loadCatalogScript));
    const catalog = Array.from(
      new Map((Array.isArray(window.STORIES) ? window.STORIES : []).map((story) => [story.slug, story])).values()
    );
    const currentIndex = catalog.findIndex(function (story) { return story.slug === slug; });
    if (currentIndex < 0) return;

    const orderedAfterCurrent = catalog.slice(currentIndex + 1).concat(catalog.slice(0, currentIndex));
    const nextUnread = orderedAfterCurrent.find(function (story) { return !completedStories.includes(story.slug); }) || orderedAfterCurrent[0];
    const sameFear = orderedAfterCurrent.filter(function (story) {
      return story.category === storyCategory && story.slug !== (nextUnread && nextUnread.slug);
    }).sort(function (a, b) {
      return Number(completedStories.includes(a.slug)) - Number(completedStories.includes(b.slug));
    }).slice(0, 2);
    if (!nextUnread) return;

    const guide = document.createElement('section');
    guide.className = 'story-next';
    guide.setAttribute('data-nosnippet', '');
    const eyebrow = document.createElement('span');
    eyebrow.className = 'eyebrow';
    eyebrow.textContent = 'One more story';
    const heading = document.createElement('h2');
    heading.textContent = 'まだ眠れませんか？';
    const copy = document.createElement('p');
    copy.textContent = '読了していない作品から、次の一話を選びました。';
    guide.appendChild(eyebrow);
    guide.appendChild(heading);
    guide.appendChild(copy);
    guide.appendChild(recommendationLink(nextUnread, 'next-primary'));
    if (sameFear.length) {
      const subheading = document.createElement('h3');
      subheading.textContent = '同じ「' + storyCategory + '」を読む';
      const related = document.createElement('div');
      related.className = 'next-related';
      sameFear.forEach(function (story) { related.appendChild(recommendationLink(story, 'next-related__item')); });
      guide.appendChild(subheading);
      guide.appendChild(related);
    }
    storyBody.appendChild(guide);
  } catch (error) {}
}

buildNextStoryGuide();

async function updateViewCount() {
  if (!viewCount || !slug) return;
  const productionHost = 'allsunday1122.github.io';
  const productionPath = '/yorugatari/stories/' + slug + '.html';
  const base = 'https://page-views-api.ratneshc.com/api/v1/';
  const query = '?site=' + encodeURIComponent(productionHost) + '&path=' + encodeURIComponent(productionPath);
  try {
    if (location.hostname === productionHost) {
      const tracked = await fetch(base + 'track' + query, { keepalive: true });
      if (!tracked.ok) throw new Error('view tracking request failed');
    }
    const response = await fetch(base + 'views' + query);
    if (!response.ok) throw new Error('view count request failed');
    const data = await response.json();
    const views = Number(data.views);
    viewCount.textContent = Number.isFinite(views) ? views.toLocaleString('ja-JP') + '回' : '—';
  } catch (error) {
    viewCount.textContent = '取得できませんでした';
  }
}
updateViewCount();

const shareButton = document.querySelector('#shareBtn');
if (shareButton) shareButton.setAttribute('type', 'button');
if (shareButton) {
  shareButton.addEventListener('click', async function () {
    const shareText = '「' + storyTitle + '」を読みました。\n#夜語り #怖い話';
    const data = { title: document.title, text: shareText, url: location.href };
    try {
      if (navigator.share) { await navigator.share(data); return; }
      if (navigator.clipboard && navigator.clipboard.writeText) {
        await navigator.clipboard.writeText(shareText + '\n' + location.href);
        const original = shareButton.textContent;
        shareButton.textContent = 'URLをコピーしました';
        setTimeout(function () { shareButton.textContent = original; }, 1800);
        return;
      }
      window.prompt('このURLをコピーしてください', location.href);
    } catch (error) {
      if (!error || error.name !== 'AbortError') {
        shareButton.textContent = '共有できませんでした';
        setTimeout(function () { shareButton.textContent = '共有'; }, 1800);
      }
    }
  });
}

const footer = document.querySelector('.footer-inner');
if (footer && !footer.querySelector('.footer-links')) {
  const links = document.createElement('nav');
  links.className = 'footer-links';
  links.setAttribute('aria-label', '運営情報');
  links.innerHTML = '<a href="../about.html">運営・編集方針</a><a href="../privacy.html">プライバシー</a><a href="../terms.html">利用規約</a><a href="../contact.html">お問い合わせ</a>';
  footer.appendChild(links);
}
