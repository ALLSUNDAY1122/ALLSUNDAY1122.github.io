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

const favoriteButton = document.querySelector('#favoriteBtn');
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

const shareButton = document.querySelector('#shareBtn');
if (shareButton) shareButton.setAttribute('type', 'button');
if (shareButton) {
  shareButton.addEventListener('click', async function () {
    const description = document.querySelector('meta[name="description"]');
    const data = { title: document.title, text: description ? description.content : '', url: location.href };
    try {
      if (navigator.share) { await navigator.share(data); return; }
      if (navigator.clipboard && navigator.clipboard.writeText) {
        await navigator.clipboard.writeText(location.href);
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