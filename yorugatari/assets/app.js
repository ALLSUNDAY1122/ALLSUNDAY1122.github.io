const grid = document.querySelector('#storyGrid');
const search = document.querySelector('#searchInput');
const chips = Array.prototype.slice.call(document.querySelectorAll('.chip'));
const empty = document.querySelector('#emptyState');
const count = document.querySelector('#count');
const coreStories = Array.isArray(window.STORIES) ? window.STORIES : [];
const notionStories = Array.isArray(window.NOTION_STORIES) ? window.NOTION_STORIES : [];
const stories = coreStories.concat(notionStories);
const completedStorageKey = 'yorugatari-completed-stories';
let completedStories = [];
try {
  const storedCompleted = JSON.parse(localStorage.getItem(completedStorageKey) || '[]');
  completedStories = Array.isArray(storedCompleted) ? storedCompleted : [];
} catch (error) {
  completedStories = [];
}
let activeCategory = 'すべて';

if (count) count.setAttribute('aria-live', 'polite');
if (empty) empty.setAttribute('role', 'status');

function storyHref(story) {
  return story.href || `stories/${story.slug}.html`;
}

function card(story) {
  const fear = '●'.repeat(story.fear) + '○'.repeat(5 - story.fear);
  const tags = Array.isArray(story.tags) ? story.tags : [];
  const completed = completedStories.includes(story.slug);
  return `<a class="card${completed ? ' completed' : ''}" href="${storyHref(story)}" data-title="${story.title}" data-category="${story.category}" data-tags="${tags.join(' ')}">
    <div class="meta"><span class="badge">${story.category}</span><span>${story.length}</span><span>約${story.minutes}分</span>${completed ? '<span class="read-badge">✓ 読了</span>' : ''}</div>
    <h3>${story.title}</h3><p>${story.summary}</p>
    <div class="card-foot"><span class="fear" aria-label="怖さ ${story.fear}/5">${fear}</span><span>${story.series || 'オリジナル作品'}</span></div>
  </a>`;
}

function render() {
  if (!grid || !empty || !count) return;

  const query = (search ? search.value : '').trim().toLowerCase();
  const filtered = stories.filter(function (story) {
    const categoryMatches = activeCategory === 'すべて' || story.category === activeCategory || story.series === activeCategory;
    const tags = Array.isArray(story.tags) ? story.tags : [];
    const text = `${story.title} ${story.summary} ${story.category} ${story.series || ''} ${tags.join(' ')}`.toLowerCase();
    return categoryMatches && (!query || text.includes(query));
  });

  grid.innerHTML = filtered.map(card).join('');
  empty.style.display = filtered.length ? 'none' : 'block';
  const completedCount = stories.filter(function (story) { return completedStories.includes(story.slug); }).length;
  count.textContent = `表示${filtered.length}話・この端末で${completedCount}話読了`;
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

const randomButton = document.querySelector('#randomBtn');
if (randomButton) {
  randomButton.addEventListener('click', function () {
    if (!stories.length) return;
    const story = stories[Math.floor(Math.random() * stories.length)];
    location.href = storyHref(story);
  });
}

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

render();
