(function () {
  const FOLDER_KEY = 'toru-tango-folders-v1';
  let folders = JSON.parse(localStorage.getItem(FOLDER_KEY) || '["メイン"]');
  if (!Array.isArray(folders) || !folders.length) folders = ['メイン'];
  folders = [...new Set(folders.filter(Boolean).map(String))];
  const saveFolders = () => localStorage.setItem(FOLDER_KEY, JSON.stringify(folders));
  const folderOf = (card) => card.folder || card.deckName || 'メイン';
  const listCard = document.querySelector('#list .card');
  const itemHost = document.querySelector('#items');
  const listFilter = document.querySelector('#listFilter');
  if (!listCard || !itemHost || !listFilter) return;

  const folderCard = document.createElement('div');
  folderCard.className = 'card';
  folderCard.innerHTML = '<h2>フォルダ分類</h2><p class="muted">単語カードをフォルダごとに整理できます。</p><div class="row"><input id="folderName" class="input" style="flex:1;min-width:180px" placeholder="例：英単語、試験対策"><button id="addFolder" class="btn">新規フォルダ追加</button></div><label class="label" for="folderFilter">表示するフォルダ</label><select id="folderFilter"><option value="all">全フォルダ</option></select>';
  listCard.parentNode.insertBefore(folderCard, listCard);
  const folderFilter = folderCard.querySelector('#folderFilter');
  const escText = (value) => String(value).replace(/[&<>"']/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]));
  const renderFolderOptions = () => {
    folderFilter.innerHTML = '<option value="all">全フォルダ</option>' + folders.map((name) => `<option value="${escText(name)}">${escText(name)}</option>`).join('');
  };
  const renderFolderList = () => {
    const mode = listFilter.value;
    const selected = folderFilter.value;
    const rows = cards.map((card, index) => ({ card, index })).filter(({ card }) => {
      if (mode === 'weak' && !isWeak(card)) return false;
      if (mode === 'unseen' && (card.correct + card.wrong !== 0)) return false;
      return selected === 'all' || folderOf(card) === selected;
    });
    document.querySelector('#count').textContent = rows.length;
    itemHost.innerHTML = rows.length ? rows.map(({ card, index }) => `<div class="item"><div class="qa"><b>${escText(card.q)}</b><span>${escText(card.a)}</span><small class="badge">フォルダ：${escText(folderOf(card))} ・ 正解 ${card.correct} ・ 弱点 ${card.wrong}</small></div><div><select class="folder-move" data-index="${index}">${folders.map((name) => `<option value="${escText(name)}" ${folderOf(card) === name ? 'selected' : ''}>${escText(name)}へ移動</option>`).join('')}</select><button class="btn secondary" onclick="editCard(${index})">編集</button><button class="btn secondary" onclick="delCard(${index})">削除</button></div></div>`).join('') : '<div class="empty">該当するカードがありません。</div>';
    itemHost.querySelectorAll('.folder-move').forEach((select) => select.addEventListener('change', (event) => {
      const target = event.currentTarget;
      cards[Number(target.dataset.index)].folder = target.value;
      persist();
      renderFolderOptions();
      folderFilter.value = selected;
      renderFolderList();
    }));
  };
  folderCard.querySelector('#addFolder').onclick = () => {
    const input = folderCard.querySelector('#folderName');
    const name = input.value.trim();
    if (!name) return alert('フォルダ名を入力してください。');
    if (folders.includes(name)) return alert('同じ名前のフォルダがあります。');
    folders.push(name);
    saveFolders();
    input.value = '';
    renderFolderOptions();
    renderFolderList();
  };
  listFilter.onchange = renderFolderList;
  folderFilter.onchange = renderFolderList;
  renderFolderOptions();
  renderFolderList();
})();
