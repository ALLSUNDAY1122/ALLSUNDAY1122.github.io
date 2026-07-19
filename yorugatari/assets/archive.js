const archiveStories = Array.from(
  new Map((Array.isArray(window.STORIES) ? window.STORIES : []).map((story) => [story.slug, story])).values()
);
const archiveCategories = ['心霊', '人怖', '意味怖', 'ネット怪談', '都市伝説風', '後味悪い'];
const archiveSections = document.querySelector('#archiveSections');
const archiveJump = document.querySelector('#archiveJump');
const archiveTotal = document.querySelector('#archiveTotal');
const archiveBreakdown = document.querySelector('#archiveBreakdown');
const completedStorageKey = 'yorugatari-completed-stories';
const favoritesStorageKey = 'yorugatari-favorites';
let completedStories = [];
let favoriteStories = [];
let activeReadingStatus = 'all';
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

function archiveHref(story) {
  return story.href || `stories/${story.slug}.html`;
}

function archiveItem(story, index) {
  const completed = completedStories.includes(story.slug);
  return `<a class="archive-item${completed ? ' completed' : ''}" href="${archiveHref(story)}">
    <span class="archive-no">${String(index + 1).padStart(3, '0')}</span>
    <span class="archive-copy"><strong>${story.title}${completed ? '<span class="read-badge">✓ 読了</span>' : ''}</strong><small>${story.summary}</small></span>
  </a>`;
}

function readingStatusMatches(story) {
  return activeReadingStatus === 'all'
    || (activeReadingStatus === 'unread' && !completedStories.includes(story.slug))
    || (activeReadingStatus === 'completed' && completedStories.includes(story.slug))
    || (activeReadingStatus === 'favorite' && favoriteStories.includes(story.slug));
}

function renderArchive() {
  if (!archiveSections || !archiveJump) return;
  const completedCount = archiveStories.filter(function (story) { return completedStories.includes(story.slug); }).length;
  archiveTotal.textContent = `${archiveStories.length}話中 ${completedCount}話読了`;
  archiveBreakdown.textContent = archiveCategories.map(function (category) {
    return `${category}${archiveStories.filter(function (story) { return story.category === category; }).length}話`;
  }).join('・');

  archiveJump.innerHTML = archiveCategories.map(function (category) {
    const count = archiveStories.filter(function (story) { return story.category === category && readingStatusMatches(story); }).length;
    return `<a href="#${category}">${category}（${count}）</a>`;
  }).join('');

  archiveSections.innerHTML = archiveCategories.map(function (category) {
    const items = archiveStories.filter(function (story) { return story.category === category && readingStatusMatches(story); });
    if (!items.length) return '';
    return `<section class="archive-section" id="${category}">
      <div class="section-head"><div><div class="eyebrow">Category</div><h2>${category}</h2></div><div class="section-note">${items.length}話</div></div>
      <div class="archive-list">${items.map(function (story) { return archiveItem(story, archiveStories.indexOf(story)); }).join('')}</div>
    </section>`;
  }).join('');
}

if (archiveSections && archiveJump) {
  const summary = document.querySelector('.archive-summary');
  if (summary) {
    const filters = document.createElement('div');
    filters.className = 'reading-filters archive-reading-filters';
    filters.setAttribute('aria-label', '読書状況で絞り込む');
    filters.innerHTML = '<span>読書状況</span><button class="chip active" data-reading-status="all" type="button">すべて</button><button class="chip" data-reading-status="unread" type="button">未読のみ</button><button class="chip" data-reading-status="completed" type="button">読了済み</button><button class="chip" data-reading-status="favorite" type="button">お気に入り</button>';
    summary.appendChild(filters);
    filters.querySelectorAll('[data-reading-status]').forEach(function (button) {
      button.setAttribute('aria-pressed', String(button.classList.contains('active')));
      button.addEventListener('click', function () {
        filters.querySelectorAll('[data-reading-status]').forEach(function (item) {
          item.classList.remove('active');
          item.setAttribute('aria-pressed', 'false');
        });
        button.classList.add('active');
        button.setAttribute('aria-pressed', 'true');
        activeReadingStatus = button.dataset.readingStatus;
        renderArchive();
      });
    });
  }
  renderArchive();
}
