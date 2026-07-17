const grid = document.querySelector('#storyGrid');
const search = document.querySelector('#searchInput');
const chips = Array.prototype.slice.call(document.querySelectorAll('.chip'));
const empty = document.querySelector('#emptyState');
const count = document.querySelector('#count');
const stories = Array.isArray(window.STORIES) ? window.STORIES : [];
let activeCategory = 'すべて';

if (count) count.setAttribute('aria-live', 'polite');
if (empty) empty.setAttribute('role', 'status');

function card(story) {
  const fear = '●'.repeat(story.fear) + '○'.repeat(5 - story.fear);
  return `<a class="card" href="stories/${story.slug}.html" data-title="${story.title}" data-category="${story.category}" data-tags="${story.tags.join(' ')}">
    <div class="meta"><span class="badge">${story.category}</span><span>${story.length}</span><span>約${story.minutes}分</span></div>
    <h3>${story.title}</h3><p>${story.summary}</p>
    <div class="card-foot"><span class="fear" aria-label="怖さ ${story.fear}/5">${fear}</span><span>オリジナル作品</span></div>
  </a>`;
}

function render() {
  if (!grid || !empty || !count) return;

  const query = (search ? search.value : '').trim().toLowerCase();
  const filtered = stories.filter(function (story) {
    const categoryMatches = activeCategory === 'すべて' || story.category === activeCategory;
    const text = `${story.title} ${story.summary} ${story.tags.join(' ')}`.toLowerCase();
    return categoryMatches && (!query || text.includes(query));
  });

  grid.innerHTML = filtered.map(card).join('');
  empty.style.display = filtered.length ? 'none' : 'block';
  count.textContent = `${filtered.length}話`;
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
    location.href = `stories/${story.slug}.html`;
  });
}

render();
