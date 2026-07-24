const MAP_URL = 'https://raw.githubusercontent.com/geolonia/japanese-prefectures/master/map-full.svg';
const MUNICIPALITIES_URL = './data/generated/municipalities.json';
const DEFINITIONS_URL = './data/service-definitions.json';
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
const WORK_STATUS_PRESENTATION = {
  todo: { label: '未着手', detail: '公式情報の調査を開始していません。' },
  researching: { label: '調査中', detail: '公式情報を確認して追加します。' },
  needs_medium_review: { label: '要詳細確認', detail: '条件が複雑なため、詳細確認を行っています。' },
  needs_revision: { label: '修正中', detail: '内容を再確認し、修正しています。' },
  needs_coordinator: { label: '統括確認中', detail: '全国統括による確認待ちです。' },
  blocked: { label: '確認停止中', detail: '確認上の問題が解消するまで更新を停止しています。' },
  pr_open: { label: '審査中', detail: '更新内容を審査しています。' },
  merged: { label: '統合済み', detail: 'データ更新は統合済みですが、確認済み制度としては表示しません。' }
};
const state = {
  municipalities: [],
  serviceDefinitions: [],
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
    const [municipalitiesResponse, definitionsResponse] = await Promise.all([
      fetch(MUNICIPALITIES_URL, { cache: 'no-store' }),
      fetch(DEFINITIONS_URL, { cache: 'no-store' })
    ]);
    if (!municipalitiesResponse.ok) {
      throw new Error(`自治体データの読み込みに失敗しました: ${municipalitiesResponse.status}`);
    }
    if (!definitionsResponse.ok) {
      throw new Error(`制度定義の読み込みに失敗しました: ${definitionsResponse.status}`);
    }
    const [municipalitiesData, definitionsData] = await Promise.all([
      municipalitiesResponse.json(),
      definitionsResponse.json()
    ]);
    if (!Array.isArray(municipalitiesData.municipalities)) {
      throw new Error('自治体データの形式が正しくありません。');
    }
    if (!Array.isArray(definitionsData.services)) {
      throw new Error('制度定義の形式が正しくありません。');
    }
    state.municipalities = municipalitiesData.municipalities;
    state.serviceDefinitions = definitionsData.services;
    state.selectedCodes = state.selectedCodes.filter((code) => state.municipalities.some((item) => item.code === code));
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
  const ageParam = params.get('age');
  const requestedAge = ageParam === null ? NaN : Number(ageParam);
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
    elements.map.innerHTML = await response.text();
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
    : '自治体データの読み込み状態を確認してください。';
  elements.municipalityList.replaceChildren();
  if (!list.length) {
    const empty = document.createElement('p');
    empty.textContent = 'この都道府県の自治体データを読み込めませんでした。';
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
  const detail = document.createElement('a');
  detail.href = `./municipality/${encodeURIComponent(municipality.code)}/`;
  detail.textContent = '制度詳細';
  const official = document.createElement('a');
  official.href = municipality.officialUrl;
  official.target = '_blank';
  official.rel = 'noopener noreferrer';
  official.textContent = '公式サイト';
  actions.append(selectButton, detail, official);
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
      render: (municipality) => `<a href="${escapeHtml(municipality.officialUrl)}" target="_blank" rel="noopener noreferrer">${escapeHtml(municipality.name)}公式サイト</a>`
    },
    ...state.serviceDefinitions.map((definition) => ({
      label: definition.label,
      render: (municipality) => renderServiceCell(municipality, definition)
    }))
  ];
  const head = selected.map((municipality) => `<th scope="col"><a href="./municipality/${escapeHtml(municipality.code)}/">${escapeHtml(municipality.name)}</a></th>`).join('');
  const body = rows
    .map((row) => `<tr><th scope="row">${escapeHtml(row.label)}</th>${selected.map((municipality) => `<td>${row.render(municipality)}</td>`).join('')}</tr>`)
    .join('');
  elements.comparison.className = 'comparison-wrap';
  elements.comparison.innerHTML = `<table class="comparison-table"><thead><tr><th scope="col">比較項目</th>${head}</tr></thead><tbody>${body}</tbody></table>`;
}
function renderServiceCell(municipality, definition) {
  const service = municipality.services?.[definition.id];
  if (!service) return workStatusCell('todo', 'データ未登録');
  if (service.status === 'verified') return verifiedServiceCell(service, definition);
  if (service.status === 'unavailable') return unavailableCell(service.summary, service.source);
  return workStatusCell(service.status, service.summary, service.source);
}
function verifiedServiceCell(service, definition) {
  const eligibility = evaluateEligibility(definition.eligibilityRule, service.eligibility);
  const details = formatServiceDetails(service, definition.detailFields);
  return `${eligibilityBadge(eligibility)}<span class="cell-main">${escapeHtml(service.summary)}</span>${details ? `<span class="cell-detail">${escapeHtml(details)}</span>` : ''}${sourceLink(service.source)}`;
}
function workStatusCell(status, summary, source = {}) {
  const presentation = WORK_STATUS_PRESENTATION[status] ?? {
    label: '状態不明',
    detail: '表示状態を確認しています。'
  };
  return `<span class="status">${escapeHtml(presentation.label)}</span><span class="cell-main">${escapeHtml(summary || '内容未登録')}</span><span class="cell-detail">${escapeHtml(presentation.detail)}</span>${sourceLink(source)}`;
}
function unavailableCell(summary, source = {}) {
  return `<span class="status review">公式情報で詳細未確認</span><span class="cell-main">${escapeHtml(summary)}</span><span class="cell-detail">制度がないとは限りません。現行条件は自治体の公式サイトまたは担当窓口で確認してください。</span>${sourceLink(source)}`;
}
function sourceLink(source = {}) {
  if (!source.url) return '';
  return `<a class="source-link" href="${escapeHtml(source.url)}" target="_blank" rel="noopener noreferrer">公式情報（確認日 ${escapeHtml(source.checkedAt ?? '未記録')}）</a>`;
}
function evaluateEligibility(rule, eligibility = {}) {
  if (rule !== 'ageRange') return { kind: 'verified', label: '確認済み' };
  const ageYears = state.childAge;
  const ageStartMonths = ageYears * 12;
  const ageEndMonths = ageStartMonths + 11;
  const minAgeMonths = Number.isInteger(eligibility.minAgeMonths) ? eligibility.minAgeMonths : 0;
  const maxAgeYears = Number.isInteger(eligibility.maxAgeYears) ? eligibility.maxAgeYears : 120;
  if (ageYears > maxAgeYears || ageEndMonths < minAgeMonths) {
    return { kind: 'ineligible', label: '年齢条件外の可能性' };
  }
  if (ageStartMonths < minAgeMonths && ageEndMonths >= minAgeMonths) {
    return { kind: 'review', label: '月齢の確認が必要' };
  }
  return { kind: 'eligible', label: '年齢条件の対象候補' };
}
function eligibilityBadge(result) {
  const className = result.kind === 'eligible'
    ? 'status ok'
    : result.kind === 'ineligible'
      ? 'status no'
      : 'status';
  return `<span class="${className}">${escapeHtml(result.label)}</span>`;
}
function formatServiceDetails(service, fields = []) {
  return fields
    .map((field) => {
      const value = valueAtPath(service, field.path);
      if (value === undefined || value === null || value === '') return null;
      return `${field.label}：${value}${field.suffix ?? ''}`;
    })
    .filter(Boolean)
    .join('／');
}
function valueAtPath(object, path) {
  return String(path).split('.').reduce((value, key) => value?.[key], object);
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
  const results = state.municipalities.filter((municipality) => `${municipality.prefecture}${municipality.name}`.toLowerCase().includes(query));
  if (!results.length) {
    elements.searchResults.textContent = '入力内容に一致する自治体が見つかりませんでした。';
    return;
  }
  results.forEach((municipality) => {
    const row = document.createElement('div');
    row.className = 'search-result';
    row.append(document.createTextNode(`${municipality.prefecture} ${municipality.name}`));
    const button = document.createElement('button');
    button.type = 'button';
    button.textContent = state.selectedCodes.includes(municipality.code) ? '選択済み' : '比較に追加';
    button.disabled = state.selectedCodes.includes(municipality.code);
    button.addEventListener('click', () => {
      state.activePrefectureCode = municipality.prefectureCode;
      toggleMunicipality(municipality.code);
      renderMunicipalities(municipality.prefectureCode);
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
  if (state.selectedCodes.length) url.searchParams.set('compare', state.selectedCodes.join(','));
  else url.searchParams.delete('compare');
  url.searchParams.set('age', String(state.childAge));
  url.searchParams.set('pref', state.activePrefectureCode);
  window.history.replaceState(null, '', url);
}
function selectedMunicipalities() {
  return state.selectedCodes
    .map((code) => state.municipalities.find((municipality) => municipality.code === code))
    .filter(Boolean);
}
function prefectureName(code) {
  return PREFECTURES.find(([prefectureCode]) => prefectureCode === code)?.[1] ?? '都道府県';
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
