const MAP_URL = 'https://raw.githubusercontent.com/geolonia/japanese-prefectures/master/map-full.svg';
const PREFECTURES = [
  ['01','北海道'],['02','青森県'],['03','岩手県'],['04','宮城県'],['05','秋田県'],['06','山形県'],['07','福島県'],
  ['08','茨城県'],['09','栃木県'],['10','群馬県'],['11','埼玉県'],['12','千葉県'],['13','東京都'],['14','神奈川県'],
  ['15','新潟県'],['16','富山県'],['17','石川県'],['18','福井県'],['19','山梨県'],['20','長野県'],['21','岐阜県'],
  ['22','静岡県'],['23','愛知県'],['24','三重県'],['25','滋賀県'],['26','京都府'],['27','大阪府'],['28','兵庫県'],
  ['29','奈良県'],['30','和歌山県'],['31','鳥取県'],['32','島根県'],['33','岡山県'],['34','広島県'],['35','山口県'],
  ['36','徳島県'],['37','香川県'],['38','愛媛県'],['39','高知県'],['40','福岡県'],['41','佐賀県'],['42','長崎県'],
  ['43','熊本県'],['44','大分県'],['45','宮崎県'],['46','鹿児島県'],['47','沖縄県']
];
const DEFAULT_SELECTION = ['13123', '12203', '12227'];
const MAX_SELECTIONS = 3;

const state = {
  municipalities: [],
  selectedCodes: [...DEFAULT_SELECTION],
  activePrefectureCode: '13',
  childAge: 2
};

const elements = {
  map: document.querySelector('#japan-map'),
  municipalityList: document.querySelector('#municipality-list'),
  prefectureHeading: document.querySelector('#selected-prefecture-heading'),
  prefectureMessage: document.querySelector('#prefecture-message'),
  selectionBar: document.querySelector('#selection-bar'),
  comparison: document.querySelector('#comparison'),
  searchInput: document.querySelector('#municipality-search'),
  searchButton: document.querySelector('#search-button'),
  searchResults: document.querySelector('#search-results'),
  childAge: document.querySelector('#child-age'),
  shareButton: document.querySelector('#share-comparison'),
  shareStatus: document.querySelector('#share-status')
};

async function boot() {
  try {
    const response = await fetch('./data/municipalities.json', { cache: 'no-store' });
    if (!response.ok) throw new Error(`自治体データの読み込みに失敗しました: ${response.status}`);
    const data = await response.json();
    if (!Array.isArray(data.municipalities)) throw new Error('自治体データの形式が正しくありません。');

    state.municipalities = data.municipalities;
    hydrateStateFromUrl();
    elements.childAge.value = String(state.childAge);

    await renderMap();
    renderMunicipalities(state.activePrefectureCode);
    renderSelection();
    renderComparison();
    bindControls();
    updateUrl();
  } catch (error) {
    console.error(error);
    elements.map.innerHTML = '<div class="load-error"><strong>サイトデータを読み込めませんでした。</strong><p>通信状態を確認してページを再読み込みしてください。</p></div>';
    elements.comparison.className = 'comparison-empty';
    elements.comparison.textContent = '比較データを読み込めませんでした。';
  }
}

function hydrateStateFromUrl() {
  const params = new URLSearchParams(window.location.search);
  const requestedCodes = (params.get('compare') ?? '')
    .split(',')
    .map((code) => code.trim())
    .filter(Boolean);
  const validCodes = [...new Set(requestedCodes)]
    .filter((code) => state.municipalities.some((item) => item.code === code))
    .slice(0, MAX_SELECTIONS);

  if (validCodes.length) state.selectedCodes = validCodes;

  const requestedAge = Number(params.get('age'));
  if (Number.isInteger(requestedAge) && requestedAge >= 0 && requestedAge <= 18) {
    state.childAge = requestedAge;
  }

  const requestedPrefecture = params.get('pref');
  if (PREFECTURES.some(([code]) => code === requestedPrefecture)) {
    state.activePrefectureCode = requestedPrefecture;
  } else {
    const firstSelected = state.municipalities.find((item) => item.code === state.selectedCodes[0]);
    if (firstSelected) state.activePrefectureCode = firstSelected.prefectureCode;
  }
}

async function renderMap() {
  try {
    const response = await fetch(MAP_URL);
    if (!response.ok) throw new Error('map unavailable');
    const svgText = await response.text();
    elements.map.innerHTML = svgText;
    elements.map.querySelectorAll('.prefecture').forEach((node) => {
      const code = String(node.dataset.code).padStart(2, '0');
      node.setAttribute('tabindex', '0');
      node.setAttribute('role', 'button');
      node.setAttribute('aria-label', `${prefectureName(code)}を選択`);
      const select = () => selectPrefecture(code);
      node.addEventListener('click', select);
      node.addEventListener('keydown', (event) => {
        if (event.key === 'Enter' || event.key === ' ') {
          event.preventDefault();
          select();
        }
      });
    });
    highlightPrefecture();
  } catch (error) {
    console.warn('SVG map fallback:', error);
    renderPrefectureFallback();
  }
}

function renderPrefectureFallback() {
  const grid = document.createElement('div');
  grid.className = 'prefecture-grid';
  PREFECTURES.forEach(([code, name]) => {
    const button = document.createElement('button');
    button.type = 'button';
    button.textContent = name;
    button.classList.toggle('is-active', code === state.activePrefectureCode);
    button.addEventListener('click', () => selectPrefecture(code));
    grid.append(button);
  });
  elements.map.replaceChildren(grid);
}

function selectPrefecture(code) {
  state.activePrefectureCode = code;
  highlightPrefecture();
  renderMunicipalities(code);
  updateUrl();
}

function highlightPrefecture() {
  elements.map.querySelectorAll('.prefecture').forEach((node) => {
    const code = String(node.dataset.code).padStart(2, '0');
    node.classList.toggle('is-active', code === state.activePrefectureCode);
  });
  elements.map.querySelectorAll('.prefecture-grid button').forEach((button, index) => {
    button.classList.toggle('is-active', PREFECTURES[index]?.[0] === state.activePrefectureCode);
  });
}

function renderMunicipalities(prefectureCode) {
  const list = state.municipalities.filter((item) => item.prefectureCode === prefectureCode);
  elements.prefectureHeading.textContent = prefectureName(prefectureCode);
  elements.prefectureMessage.textContent = list.length
    ? `${list.length}自治体の詳細データを掲載しています。`
    : '公式リンク・比較データは順次追加します。';
  elements.municipalityList.replaceChildren();

  if (!list.length) {
    const empty = document.createElement('p');
    empty.textContent = '現在、この都道府県の詳細データは未登録です。';
    elements.municipalityList.append(empty);
    return;
  }

  list.forEach((municipality) => elements.municipalityList.append(createMunicipalityCard(municipality)));
}

function createMunicipalityCard(municipality) {
  const card = document.createElement('article');
  card.className = 'municipality-card';
  card.classList.toggle('is-selected', state.selectedCodes.includes(municipality.code));

  const title = document.createElement('h4');
  title.textContent = municipality.name;
  const summary = document.createElement('p');
  summary.textContent = municipality.summary;
  const actions = document.createElement('div');
  actions.className = 'card-actions';

  const selectButton = document.createElement('button');
  selectButton.type = 'button';
  const selected = state.selectedCodes.includes(municipality.code);
  selectButton.textContent = selected ? '比較から外す' : '比較に追加';
  selectButton.classList.toggle('remove', selected);
  selectButton.addEventListener('click', () => toggleMunicipality(municipality.code));

  const official = document.createElement('a');
  official.href = municipality.officialUrl;
  official.target = '_blank';
  official.rel = 'noopener noreferrer';
  official.textContent = '公式サイト';

  actions.append(selectButton, official);
  card.append(title, summary, actions);
  return card;
}

function toggleMunicipality(code) {
  const index = state.selectedCodes.indexOf(code);
  if (index >= 0) {
    state.selectedCodes.splice(index, 1);
  } else if (state.selectedCodes.length < MAX_SELECTIONS) {
    state.selectedCodes.push(code);
  } else {
    window.alert(`比較できる自治体は最大${MAX_SELECTIONS}件です。`);
    return;
  }
  renderMunicipalities(state.activePrefectureCode);
  renderSelection();
  renderComparison();
  updateUrl();
}

function renderSelection() {
  elements.selectionBar.replaceChildren();
  if (!state.selectedCodes.length) {
    elements.selectionBar.textContent = '比較対象は選択されていません。';
    return;
  }
  selectedMunicipalities().forEach((municipality) => {
    const chip = document.createElement('span');
    chip.className = 'selection-chip';
    chip.append(document.createTextNode(`${municipality.prefecture} ${municipality.name}`));
    const remove = document.createElement('button');
    remove.type = 'button';
    remove.setAttribute('aria-label', `${municipality.name}を比較から外す`);
    remove.textContent = '×';
    remove.addEventListener('click', () => toggleMunicipality(municipality.code));
    chip.append(remove);
    elements.selectionBar.append(chip);
  });
}

function renderComparison() {
  const selected = selectedMunicipalities();
  if (!selected.length) {
    elements.comparison.className = 'comparison-empty';
    elements.comparison.textContent = '地図または検索結果から自治体を選択してください。';
    return;
  }

  const rows = [
    {
      label: '公式サイト',
      render: (m) => `<a href="${escapeHtml(m.officialUrl)}" target="_blank" rel="noopener noreferrer">${escapeHtml(m.name)}公式サイト</a>`
    },
    {
      label: '子ども医療費',
      render: (m) => eligibilityCell(
        state.childAge <= m.childMedical.maxAge,
        m.childMedical.target,
        `${m.childMedical.copay}／所得制限：${m.childMedical.incomeLimit}`,
        m.childMedical.sourceUrl,
        m.childMedical.checkedAt
      )
    },
    {
      label: '病児・病後児保育',
      render: (m) => eligibilityCell(
        isSickChildEligible(m.sickChildCare, state.childAge),
        m.sickChildCare.target,
        `${m.sickChildCare.facilityCount}施設掲載／${m.sickChildCare.fee}`,
        m.sickChildCare.sourceUrl,
        m.sickChildCare.checkedAt
      )
    },
    {
      label: '住宅支援',
      render: (m) => researchingCell(m.housing.summary)
    },
    {
      label: '公共サービス',
      render: (m) => researchingCell(m.publicServices.summary)
    }
  ];

  const head = selected.map((m) => `<th scope="col">${escapeHtml(m.name)}</th>`).join('');
  const body = rows.map((row) => `<tr><th scope="row">${escapeHtml(row.label)}</th>${selected.map((m) => `<td>${row.render(m)}</td>`).join('')}</tr>`).join('');

  elements.comparison.className = 'comparison-wrap';
  elements.comparison.innerHTML = `<table class="comparison-table"><thead><tr><th scope="col">比較項目</th>${head}</tr></thead><tbody>${body}</tbody></table>`;
}

function eligibilityCell(isEligible, main, detail, sourceUrl, checkedAt) {
  const status = isEligible ? '<span class="status ok">年齢条件の対象候補</span>' : '<span class="status no">年齢条件外の可能性</span>';
  return `${status}<span class="cell-main">${escapeHtml(main)}</span><span class="cell-detail">${escapeHtml(detail)}</span><a class="source-link" href="${escapeHtml(sourceUrl)}" target="_blank" rel="noopener noreferrer">公式情報（確認日 ${escapeHtml(checkedAt)}）</a>`;
}

function researchingCell(summary) {
  return `<span class="status">調査中</span><span class="cell-main">${escapeHtml(summary)}</span><span class="cell-detail">今後、公式情報を確認して追加します。</span>`;
}

function isSickChildEligible(data, ageYears) {
  const ageMonths = ageYears * 12;
  return ageMonths >= data.minAgeMonths && ageYears <= data.maxAge;
}

function bindControls() {
  elements.childAge.addEventListener('change', (event) => {
    state.childAge = Number(event.target.value);
    renderComparison();
    updateUrl();
  });
  elements.searchButton.addEventListener('click', runSearch);
  elements.searchInput.addEventListener('keydown', (event) => {
    if (event.key === 'Enter') runSearch();
  });
  elements.searchInput.addEventListener('input', () => {
    if (!elements.searchInput.value.trim()) elements.searchResults.replaceChildren();
  });
  elements.shareButton.addEventListener('click', shareComparison);
}

function runSearch() {
  const query = elements.searchInput.value.trim().toLowerCase();
  elements.searchResults.replaceChildren();
  if (!query) return;
  const results = state.municipalities.filter((m) => `${m.prefecture}${m.name}`.toLowerCase().includes(query));
  if (!results.length) {
    elements.searchResults.textContent = '詳細データ登録済みの自治体には見つかりませんでした。';
    return;
  }
  results.forEach((m) => {
    const row = document.createElement('div');
    row.className = 'search-result';
    row.append(document.createTextNode(`${m.prefecture} ${m.name}`));
    const button = document.createElement('button');
    button.type = 'button';
    button.textContent = state.selectedCodes.includes(m.code) ? '選択済み' : '比較に追加';
    button.disabled = state.selectedCodes.includes(m.code);
    button.addEventListener('click', () => {
      state.activePrefectureCode = m.prefectureCode;
      toggleMunicipality(m.code);
      renderMunicipalities(m.prefectureCode);
      document.querySelector('#compare-section').scrollIntoView({ behavior: 'smooth' });
    });
    row.append(button);
    elements.searchResults.append(row);
  });
}

async function shareComparison() {
  updateUrl();
  const url = window.location.href;
  const selectedNames = selectedMunicipalities().map((item) => item.name).join('・');
  const shareData = {
    title: '自治体くらべ',
    text: selectedNames ? `${selectedNames}の自治体比較` : '自治体比較',
    url
  };

  try {
    if (navigator.share) {
      await navigator.share(shareData);
      setShareStatus('共有画面を開きました。');
      return;
    }
    await navigator.clipboard.writeText(url);
    setShareStatus('比較URLをコピーしました。');
  } catch (error) {
    if (error?.name === 'AbortError') return;
    console.warn('share unavailable:', error);
    window.prompt('このURLをコピーしてください。', url);
    setShareStatus('比較URLを表示しました。');
  }
}

function setShareStatus(message) {
  elements.shareStatus.textContent = message;
  window.setTimeout(() => {
    if (elements.shareStatus.textContent === message) elements.shareStatus.textContent = '';
  }, 4000);
}

function updateUrl() {
  const url = new URL(window.location.href);
  if (state.selectedCodes.length) {
    url.searchParams.set('compare', state.selectedCodes.join(','));
  } else {
    url.searchParams.delete('compare');
  }
  url.searchParams.set('age', String(state.childAge));
  url.searchParams.set('pref', state.activePrefectureCode);
  window.history.replaceState(null, '', url);
}

function selectedMunicipalities() {
  return state.selectedCodes.map((code) => state.municipalities.find((m) => m.code === code)).filter(Boolean);
}

function prefectureName(code) {
  return PREFECTURES.find(([prefCode]) => prefCode === code)?.[1] ?? '都道府県';
}

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

boot();
