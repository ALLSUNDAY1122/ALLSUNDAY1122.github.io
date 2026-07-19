const archiveStories = Array.isArray(window.STORIES) ? window.STORIES : [];
const archiveCategories = ['心霊', '人怖', '意味怖', 'ネット怪談', '都市伝説風', '後味悪い'];
const archiveSections = document.querySelector('#archiveSections');
const archiveJump = document.querySelector('#archiveJump');
const archiveTotal = document.querySelector('#archiveTotal');
const archiveBreakdown = document.querySelector('#archiveBreakdown');
const completedStorageKey = 'yorugatari-completed-stories';
let completedStories = [];
try {
  const storedCompleted = JSON.parse(localStorage.getItem(completedStorageKey) || '[]');
  completedStories = Array.isArray(storedCompleted) ? storedCompleted : [];
} catch (error) {
  completedStories = [];
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

if (archiveSections && archiveJump) {
  const completedCount = archiveStories.filter(function (story) { return completedStories.includes(story.slug); }).length;
  archiveTotal.textContent = `${archiveStories.length}話中 ${completedCount}話読了`;
  archiveBreakdown.textContent = archiveCategories.map(function (category) {
    return `${category}${archiveStories.filter(function (story) { return story.category === category; }).length}話`;
  }).join('・');

  archiveJump.innerHTML = archiveCategories.map(function (category) {
    const count = archiveStories.filter(function (story) { return story.category === category; }).length;
    return `<a href="#${category}">${category}（${count}）</a>`;
  }).join('');

  archiveSections.innerHTML = archiveCategories.map(function (category) {
    const items = archiveStories.filter(function (story) { return story.category === category; });
    return `<section class="archive-section" id="${category}">
      <div class="section-head"><div><div class="eyebrow">Category</div><h2>${category}</h2></div><div class="section-note">${items.length}話</div></div>
      <div class="archive-list">${items.map(function (story) { return archiveItem(story, archiveStories.indexOf(story)); }).join('')}</div>
    </section>`;
  }).join('');
}
