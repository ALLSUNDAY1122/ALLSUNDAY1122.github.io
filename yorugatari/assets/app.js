const grid = document.querySelector('#storyGrid');
const search = document.querySelector('#searchInput');
const chips = Array.prototype.slice.call(document.querySelectorAll('.chip'));
const empty = document.querySelector('#emptyState');
const count = document.querySelector('#count');
const coreStories = Array.isArray(window.STORIES) ? window.STORIES : [];
const notionStories = Array.isArray(window.NOTION_STORIES) ? window.NOTION_STORIES : [];
const stories = Array.from(
  new Map(coreStories.concat(notionStories).map((story) => [story.slug, story])).values()
);
const completedStorageKey = 'yorugatari-completed-stories';
const favoritesStorageKey = 'yorugatari-favorites';
const lastReadingStorageKey = 'yorugatari-last-reading';
const initialCardCount = 18;
const cardBatchSize = 18;
let completedStories = [];
let favoriteStories = [];
let lastReading = null;
let renderGeneration = 0;

try {
  const storedCompleted = JSON.parse(localStorage.getItem(completedStorageKey) || '[]');
  completedStories = Array.isArray(storedCompleted) ? storedCompleted : [];
} catch (error) {
  completedStories = [];
}
try {
  const storedFavorites = JSON.parse(localStorage.getItem(favoritesStorageKey) || '[]');
  favoriteStories = Array.isArray(storedFavorites) ? storedFavorites : [];
} catch (error) {
  favoriteStories = [];
}
try {
  lastReading = JSON.parse(localStorage.getItem(lastReadingStorageKey) || 'null');
} catch (error) {
  lastReading = null;
}

let activeCategory = 'すべて';
let activeReadingStatus = 'all';

if (count) count.setAttribute('aria-live', 'polite');
if (empty) empty.setAttribute('role', 'status');
if (grid) grid.setAttribute('aria-busy', 'true');

function storyHref(story) {
  return story.href || `stories/${story.slug}.html`;
}

function card(story) {
  const fear = '●'.repeat(story.fear) + '○'.repeat(5 - story.fear);
  const tags = Array.isArray(story.tags) ? story.tags : [];
  const completed = completedStories.includes(story.slug);
  return `<a class="card${completed ? ' completed' : ''}" href="${storyHref(story)}" data-title="${story.title}" data-category="${story.category}" data-tags="${tags.join(' ')}"${completed ? ' aria-label="' + story.title + '（読了済み）"' : ''}>
    <div class="meta"><span class="badge">${story.category}</span><span>${story.length}</span><span>約${story.minutes}分</span>${completed ? '<span class="read-badge">✓ 読了</span>' : ''}</div>
    <h3>${story.title}</h3><p>${story.summary}</p>
    <div class="card-foot"><span class="fear" aria-label="怖さ ${story.fear}/5">${fear}</span><span>${story.series || 'オリジナル作品'}</span></div>
  </a>`;
}

function scheduleBatch(callback) {
  if ('requestIdleCallback' in window) {
    requestIdleCallback(callback, { timeout: 700 });
  } else {
    setTimeout(callback, 16);
  }
}

function filteredStories() {
  const query = (search ? search.value : '').trim().toLowerCase();
  return stories.filter(function (story) {
    const categoryMatches = activeCategory === 'すべて' || story.category === activeCategory || story.series === activeCategory;
    const statusMatches = activeReadingStatus === 'all'
      || (activeReadingStatus === 'unread' && !completedStories.includes(story.slug))
      || (activeReadingStatus === 'completed' && completedStories.includes(story.slug))
      || (activeReadingStatus === 'favorite' && favoriteStories.includes(story.slug));
    const tags = Array.isArray(story.tags) ? story.tags : [];
    const text = `${story.title} ${story.summary} ${story.category} ${story.series || ''} ${tags.join(' ')}`.toLowerCase();
    return categoryMatches && statusMatches && (!query || text.includes(query));
  });
}

function render(options) {
  if (!grid || !empty || !count) return;

  const progressive = Boolean(options && options.progressive);
  const filtered = filteredStories();
  const generation = ++renderGeneration;
  const completedCount = stories.filter(function (story) { return completedStories.includes(story.slug); }).length;

  empty.style.display = filtered.length ? 'none' : 'block';
  count.textContent = `表示${filtered.length}話・この端末で${completedCount}話読了`;

  if (!progressive || filtered.length <= initialCardCount) {
    grid.innerHTML = filtered.map(card).join('');
    grid.setAttribute('aria-busy', 'false');
    return;
  }

  grid.setAttribute('aria-busy', 'true');
  grid.innerHTML = filtered.slice(0, initialCardCount).map(card).join('');
  let nextIndex = initialCardCount;

  function appendNextBatch() {
    if (generation !== renderGeneration) return;
    const endIndex = Math.min(nextIndex + cardBatchSize, filtered.length);
    grid.insertAdjacentHTML('beforeend', filtered.slice(nextIndex, endIndex).map(card).join(''));
    nextIndex = endIndex;
    if (nextIndex < filtered.length) {
      scheduleBatch(appendNextBatch);
    } else {
      grid.setAttribute('aria-busy', 'false');
    }
  }

  scheduleBatch(appendNextBatch);
}

chips.forEach(function (chip) {
  chip.setAttribute('aria-pressed', String(chip.classList.contains('active')));
  chip.addEventListener('click', function () {
    chips.forEach(function (item) {
      item.classList.remove('active');
      item.setAttribute('aria-pressed', 'false');
    });
    chip.classList.add('active');
    chip.setAttribute('aria-pressed', 'true');
    activeCategory = chip.dataset.category;
    render();
  });
});

if (search) search.addEventListener('input', render);

const categoryChips = document.querySelector('.chips');
if (categoryChips) {
  const readingFilters = document.createElement('div');
  readingFilters.className = 'reading-filters';
  readingFilters.setAttribute('aria-label', '読書状況で絞り込む');
  readingFilters.innerHTML = '<span>読書状況</span><button class="chip active" data-reading-status="all" type="button">すべて</button><button class="chip" data-reading-status="unread" type="button">未読のみ</button><button class="chip" data-reading-status="completed" type="button">読了済み</button><button class="chip" data-reading-status="favorite" type="button">お気に入り</button>';
  categoryChips.insertAdjacentElement('afterend', readingFilters);
  readingFilters.querySelectorAll('[data-reading-status]').forEach(function (button) {
    button.setAttribute('aria-pressed', String(button.classList.contains('active')));
    button.addEventListener('click', function () {
      readingFilters.querySelectorAll('[data-reading-status]').forEach(function (item) {
        item.classList.remove('active');
        item.setAttribute('aria-pressed', 'false');
      });
      button.classList.add('active');
      button.setAttribute('aria-pressed', 'true');
      activeReadingStatus = button.dataset.readingStatus;
      render();
    });
  });
}

const randomButton = document.querySelector('#randomBtn');
if (randomButton) {
  randomButton.addEventListener('click', function () {
    if (!stories.length) return;
    const story = stories[Math.floor(Math.random() * stories.length)];
    location.href = storyHref(story);
  });
}

function buildReaderPanel() {
  const hero = document.querySelector('.hero .wrap');
  if (!hero || !stories.length) return;

  const completedCount = stories.filter(function (story) { return completedStories.includes(story.slug); }).length;
  const percent = Math.round(completedCount / stories.length * 100);
  const unread = stories.filter(function (story) { return !completedStories.includes(story.slug); });
  const lastStory = lastReading && stories.find(function (story) { return story.slug === lastReading.slug; });
  const dayNumber = Math.floor(Date.UTC(new Date().getFullYear(), new Date().getMonth(), new Date().getDate()) / 86400000);
  const tonightStory = stories[dayNumber % stories.length];
  const nextUnread = unread[0];
  const message = completedCount === stories.length
    ? '全話読了。今夜はお気に入りをもう一度。'
    : completedCount
      ? '読了の印はこの端末に残ります。今夜も一話だけ。'
      : '読み終えると作品カードの色が変わります。';

  let primaryAction = '';
  if (lastStory && !completedStories.includes(lastStory.slug)) {
    primaryAction = '<a class="btn btn-primary" href="' + storyHref(lastStory) + (Number(lastReading.progress) > 8 ? '#resume' : '') + '">「' + lastStory.title + '」の続き</a>';
  } else if (nextUnread) {
    primaryAction = '<a class="btn btn-primary" href="' + storyHref(nextUnread) + '">次の未読を読む</a>';
  }

  let panel = document.querySelector('#readerPanel');
  if (!panel) {
    panel = document.createElement('aside');
    panel.id = 'readerPanel';
    hero.appendChild(panel);
  }
  panel.className = 'reader-panel';
  panel.setAttribute('aria-label', 'あなたの読書状況');
  panel.setAttribute('aria-busy', 'false');
  panel.innerHTML = '<div class="reader-panel__head"><div><span class="eyebrow">Your night log</span><strong>' + completedCount + ' / ' + stories.length + '話 読了</strong></div><span>' + percent + '%</span></div><div class="reader-meter" role="progressbar" aria-label="読了率" aria-valuemin="0" aria-valuemax="100" aria-valuenow="' + percent + '"><span style="width:' + percent + '%"></span></div><p>' + message + '</p><div class="reader-panel__actions">' + primaryAction + '<a class="btn" href="' + storyHref(tonightStory) + '" aria-label="今夜の一話「' + tonightStory.title + '」を読む">今夜の一話</a></div>';
}

buildReaderPanel();

const mainNav = document.querySelector('.site-header .nav');
if (mainNav && !mainNav.querySelector('a[href="archive.html"]')) {
  const archiveLink = document.createElement('a');
  archiveLink.href = 'archive.html';
  archiveLink.textContent = '全100話';
  const aboutLink = mainNav.querySelector('a[href="about.html"]');
  mainNav.insertBefore(archiveLink, aboutLink || null);
}

const footerNav = document.querySelector('.site-footer .footer-links');
if (footerNav && !footerNav.querySelector('a[href="archive.html"]')) {
  const archiveLink = document.createElement('a');
  archiveLink.href = 'archive.html';
  archiveLink.textContent = '全100話一覧';
  footerNav.insertBefore(archiveLink, footerNav.firstChild);
}

render({ progressive: true });
