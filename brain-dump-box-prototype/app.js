(function () {
  'use strict';

  var STORAGE_KEY = 'brain-dump-box-html-v1';
  var state = {
    items: [],
    tab: 'today',
    query: '',
    showCompleted: false,
    editingId: null,
    undo: null,
    toastTimer: null
  };

  var el = {};

  function byId(id) { return document.getElementById(id); }

  function initElements() {
    el.runtimeStatus = byId('runtimeStatus');
    el.captureInput = byId('captureInput');
    el.saveButton = byId('saveButton');
    el.charCount = byId('charCount');
    el.prediction = byId('prediction');
    el.predictionText = byId('predictionText');
    el.searchInput = byId('searchInput');
    el.showCompleted = byId('showCompleted');
    el.memoList = byId('memoList');
    el.viewTitle = byId('viewTitle');
    el.visibleCount = byId('visibleCount');
    el.countToday = byId('countToday');
    el.countLater = byId('countLater');
    el.countMemo = byId('countMemo');
    el.countAll = byId('countAll');
    el.toast = byId('toast');
    el.toastMessage = byId('toastMessage');
    el.toastAction = byId('toastAction');
    el.editModal = byId('editModal');
    el.infoModal = byId('infoModal');
    el.editInput = byId('editInput');
    el.saveEditButton = byId('saveEditButton');
    el.infoButton = byId('infoButton');
    el.exportButton = byId('exportButton');
    el.importButton = byId('importButton');
    el.importFile = byId('importFile');
    el.clearAllButton = byId('clearAllButton');
  }

  function normalizeText(value) {
    var text = String(value || '');
    if (text.normalize) {
      try { text = text.normalize('NFKC'); } catch (ignore) {}
    }
    return text.replace(/^\s+|\s+$/g, '').toLowerCase();
  }

  function classify(text) {
    var normalized = normalizeText(text);
    var todayWords = ['今日', '本日', '今から', 'すぐ', '至急', '帰ったら', '今夜', 'あとで電話', '締切今日', 'きょう'];
    var laterWords = ['明日', 'あした', '来週', '今度', 'そのうち', '忘れずに', '予約', '買う', '購入', '確認する', '申し込む', '申込', '後日', '週末'];
    var i;
    for (i = 0; i < todayWords.length; i += 1) {
      if (normalized.indexOf(normalizeText(todayWords[i])) !== -1) return 'today';
    }
    for (i = 0; i < laterWords.length; i += 1) {
      if (normalized.indexOf(normalizeText(laterWords[i])) !== -1) return 'later';
    }
    return 'memo';
  }

  function categoryLabel(category) {
    if (category === 'today') return '今日';
    if (category === 'later') return '後で';
    return 'メモ';
  }

  function createId() {
    return 'm_' + Date.now().toString(36) + '_' + Math.random().toString(36).slice(2, 9);
  }

  function safeDate(value) {
    var date = new Date(value);
    if (isNaN(date.getTime())) return new Date();
    return date;
  }

  function formatDate(value) {
    var date = safeDate(value);
    var now = new Date();
    var sameDay = date.getFullYear() === now.getFullYear() && date.getMonth() === now.getMonth() && date.getDate() === now.getDate();
    var hh = ('0' + date.getHours()).slice(-2);
    var mm = ('0' + date.getMinutes()).slice(-2);
    if (sameDay) return '今日 ' + hh + ':' + mm;
    return (date.getMonth() + 1) + '/' + date.getDate() + ' ' + hh + ':' + mm;
  }

  function sanitizeItem(raw) {
    if (!raw || typeof raw !== 'object') return null;
    var text = String(raw.text || '').replace(/^\s+|\s+$/g, '');
    if (!text) return null;
    var category = raw.category;
    if (category !== 'today' && category !== 'later' && category !== 'memo') category = classify(text);
    return {
      id: String(raw.id || createId()),
      text: text.slice(0, 500),
      category: category,
      completed: Boolean(raw.completed),
      createdAt: safeDate(raw.createdAt).toISOString(),
      updatedAt: safeDate(raw.updatedAt || raw.createdAt).toISOString()
    };
  }

  function loadItems() {
    try {
      var stored = localStorage.getItem(STORAGE_KEY);
      if (!stored) return [];
      var parsed = JSON.parse(stored);
      var source = Array.isArray(parsed) ? parsed : parsed.items;
      if (!Array.isArray(source)) return [];
      var result = [];
      var i, item;
      for (i = 0; i < source.length; i += 1) {
        item = sanitizeItem(source[i]);
        if (item) result.push(item);
      }
      return result;
    } catch (error) {
      showToast('保存データを読み込めませんでした', null);
      return [];
    }
  }

  function persist() {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify({ version: 1, items: state.items }));
      return true;
    } catch (error) {
      showToast('端末への保存に失敗しました', null);
      return false;
    }
  }

  function escapeHtml(value) {
    return String(value)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  function updatePrediction() {
    var text = el.captureInput.value;
    var length = text.length;
    el.charCount.textContent = String(length);
    el.saveButton.disabled = normalizeText(text).length === 0;
    if (!normalizeText(text)) {
      el.prediction.className = 'prediction memo';
      el.predictionText.textContent = '入力すると分類を予測します';
      return;
    }
    var category = classify(text);
    el.prediction.className = 'prediction ' + category;
    el.predictionText.textContent = '保存先の予測：' + categoryLabel(category);
  }

  function counts() {
    var result = { today: 0, later: 0, memo: 0, all: state.items.length };
    var i;
    for (i = 0; i < state.items.length; i += 1) result[state.items[i].category] += 1;
    return result;
  }

  function filteredItems() {
    var query = normalizeText(state.query);
    var result = [];
    var i, item;
    for (i = 0; i < state.items.length; i += 1) {
      item = state.items[i];
      if (state.tab !== 'all' && item.category !== state.tab) continue;
      if (!state.showCompleted && item.completed) continue;
      if (query && normalizeText(item.text).indexOf(query) === -1) continue;
      result.push(item);
    }
    result.sort(function (a, b) { return safeDate(b.updatedAt).getTime() - safeDate(a.updatedAt).getTime(); });
    return result;
  }

  function render() {
    var c = counts();
    el.countToday.textContent = c.today + '件';
    el.countLater.textContent = c.later + '件';
    el.countMemo.textContent = c.memo + '件';
    el.countAll.textContent = c.all + '件';

    var tabs = document.querySelectorAll('[data-tab]');
    var i;
    for (i = 0; i < tabs.length; i += 1) tabs[i].setAttribute('aria-selected', tabs[i].getAttribute('data-tab') === state.tab ? 'true' : 'false');

    var titles = { today: '今日やること', later: '後でやること', memo: 'メモ', all: 'すべてのメモ' };
    el.viewTitle.textContent = titles[state.tab];
    var items = filteredItems();
    el.visibleCount.textContent = items.length + '件';

    if (!items.length) {
      var message = state.query ? '検索条件に一致するメモはありません。' : 'ここにはまだメモがありません。\n上の入力欄から追加できます。';
      el.memoList.innerHTML = '<div class="empty">' + escapeHtml(message).replace(/\n/g, '<br>') + '</div>';
      return;
    }

    var html = '';
    var item;
    for (i = 0; i < items.length; i += 1) {
      item = items[i];
      html += '<article class="card' + (item.completed ? ' completed' : '') + '" data-id="' + escapeHtml(item.id) + '">';
      html += '<div class="card-main">';
      html += '<button type="button" class="complete-button" data-action="toggle-complete" aria-label="' + (item.completed ? '未完了に戻す' : '完了にする') + '">✓</button>';
      html += '<div><div class="card-text">' + escapeHtml(item.text) + '</div><div class="card-sub">' + formatDate(item.updatedAt) + '</div></div>';
      html += '</div>';
      html += '<div class="card-actions">';
      html += '<select class="category-select" data-action="change-category" aria-label="分類を変更">';
      html += '<option value="today"' + (item.category === 'today' ? ' selected' : '') + '>今日</option>';
      html += '<option value="later"' + (item.category === 'later' ? ' selected' : '') + '>後で</option>';
      html += '<option value="memo"' + (item.category === 'memo' ? ' selected' : '') + '>メモ</option>';
      html += '</select>';
      html += '<button type="button" class="card-button" data-action="edit">編集</button>';
      html += '<button type="button" class="card-button delete" data-action="delete">削除</button>';
      html += '</div></article>';
    }
    el.memoList.innerHTML = html;
  }

  function addMemo() {
    var text = el.captureInput.value.replace(/^\s+|\s+$/g, '');
    if (!text) return;
    var item = {
      id: createId(), text: text.slice(0, 500), category: classify(text), completed: false,
      createdAt: new Date().toISOString(), updatedAt: new Date().toISOString()
    };
    state.items.push(item);
    if (!persist()) { state.items.pop(); return; }
    el.captureInput.value = '';
    updatePrediction();
    state.tab = item.category;
    render();
    el.captureInput.focus();
    state.undo = { type: 'add', item: item };
    showToast('「' + categoryLabel(item.category) + '」に保存しました', undoLast);
  }

  function findItem(id) {
    var i;
    for (i = 0; i < state.items.length; i += 1) if (state.items[i].id === id) return state.items[i];
    return null;
  }

  function findIndex(id) {
    var i;
    for (i = 0; i < state.items.length; i += 1) if (state.items[i].id === id) return i;
    return -1;
  }

  function toggleComplete(id) {
    var item = findItem(id);
    if (!item) return;
    item.completed = !item.completed;
    item.updatedAt = new Date().toISOString();
    if (!persist()) item.completed = !item.completed;
    render();
  }

  function changeCategory(id, category) {
    var item = findItem(id);
    if (!item) return;
    var previous = item.category;
    item.category = category;
    item.updatedAt = new Date().toISOString();
    if (!persist()) item.category = previous;
    render();
    showToast('「' + categoryLabel(category) + '」へ移動しました', null);
  }

  function openEdit(id) {
    var item = findItem(id);
    if (!item) return;
    state.editingId = id;
    el.editInput.value = item.text;
    openModal(el.editModal);
    setTimeout(function () { el.editInput.focus(); el.editInput.setSelectionRange(el.editInput.value.length, el.editInput.value.length); }, 40);
  }

  function saveEdit() {
    var item = findItem(state.editingId);
    var text = el.editInput.value.replace(/^\s+|\s+$/g, '');
    if (!item || !text) return;
    var previous = item.text;
    item.text = text.slice(0, 500);
    item.updatedAt = new Date().toISOString();
    if (!persist()) { item.text = previous; return; }
    closeModal(el.editModal);
    render();
    showToast('変更を保存しました', null);
  }

  function deleteMemo(id) {
    var index = findIndex(id);
    if (index < 0) return;
    var removed = state.items.splice(index, 1)[0];
    if (!persist()) { state.items.splice(index, 0, removed); return; }
    state.undo = { type: 'delete', item: removed, index: index };
    render();
    showToast('メモを削除しました', undoLast);
  }

  function undoLast() {
    if (!state.undo) return;
    var action = state.undo;
    state.undo = null;
    if (action.type === 'add') {
      var index = findIndex(action.item.id);
      if (index >= 0) state.items.splice(index, 1);
    } else if (action.type === 'delete') {
      state.items.splice(Math.min(action.index, state.items.length), 0, action.item);
    }
    persist();
    render();
    hideToast();
  }

  function showToast(message, action) {
    if (!el.toast) return;
    if (state.toastTimer) clearTimeout(state.toastTimer);
    el.toastMessage.textContent = message;
    el.toastAction.hidden = typeof action !== 'function';
    el.toastAction.onclick = action || null;
    el.toast.classList.add('show');
    state.toastTimer = setTimeout(hideToast, 4200);
  }

  function hideToast() {
    if (!el.toast) return;
    el.toast.classList.remove('show');
    if (state.toastTimer) clearTimeout(state.toastTimer);
    state.toastTimer = null;
  }

  function openModal(modal) {
    modal.classList.add('open');
    document.body.style.overflow = 'hidden';
  }

  function closeModal(modal) {
    modal.classList.remove('open');
    document.body.style.overflow = '';
  }

  function exportBackup() {
    var data = JSON.stringify({ version: 1, exportedAt: new Date().toISOString(), items: state.items }, null, 2);
    try {
      var blob = new Blob([data], { type: 'application/json;charset=utf-8' });
      var url = URL.createObjectURL(blob);
      var link = document.createElement('a');
      link.href = url;
      link.download = 'atama-seiri-memo-backup.json';
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      setTimeout(function () { URL.revokeObjectURL(url); }, 1000);
      showToast('バックアップを書き出しました', null);
    } catch (error) {
      showToast('バックアップを書き出せませんでした', null);
    }
  }

  function importBackup(file) {
    if (!file) return;
    var reader = new FileReader();
    reader.onload = function () {
      try {
        var parsed = JSON.parse(String(reader.result || ''));
        var source = Array.isArray(parsed) ? parsed : parsed.items;
        if (!Array.isArray(source)) throw new Error('invalid');
        var imported = [];
        var i, item;
        for (i = 0; i < source.length; i += 1) {
          item = sanitizeItem(source[i]);
          if (item) imported.push(item);
        }
        if (!imported.length && source.length) throw new Error('empty');
        state.items = imported;
        persist();
        closeModal(el.infoModal);
        render();
        showToast(imported.length + '件を読み込みました', null);
      } catch (error) {
        showToast('バックアップの形式を確認してください', null);
      }
      el.importFile.value = '';
    };
    reader.onerror = function () { showToast('ファイルを読み込めませんでした', null); };
    reader.readAsText(file);
  }

  function clearAll() {
    if (!state.items.length) { showToast('削除するメモがありません', null); return; }
    if (!window.confirm('すべてのメモを削除します。元に戻せません。')) return;
    state.items = [];
    persist();
    closeModal(el.infoModal);
    render();
    showToast('すべてのメモを削除しました', null);
  }

  function bindEvents() {
    el.captureInput.addEventListener('input', updatePrediction);
    el.captureInput.addEventListener('keydown', function (event) {
      if ((event.ctrlKey || event.metaKey) && event.key === 'Enter') { event.preventDefault(); addMemo(); }
    });
    el.saveButton.addEventListener('click', addMemo);
    el.searchInput.addEventListener('input', function () { state.query = el.searchInput.value; render(); });
    el.showCompleted.addEventListener('change', function () { state.showCompleted = el.showCompleted.checked; render(); });
    el.infoButton.addEventListener('click', function () { openModal(el.infoModal); });
    el.saveEditButton.addEventListener('click', saveEdit);
    el.exportButton.addEventListener('click', exportBackup);
    el.importButton.addEventListener('click', function () { el.importFile.click(); });
    el.importFile.addEventListener('change', function () { importBackup(el.importFile.files && el.importFile.files[0]); });
    el.clearAllButton.addEventListener('click', clearAll);

    document.addEventListener('click', function (event) {
      var target = event.target;
      var tab = target.closest ? target.closest('[data-tab]') : null;
      if (tab) { state.tab = tab.getAttribute('data-tab'); render(); return; }
      var close = target.closest ? target.closest('[data-close-modal]') : null;
      if (close) { closeModal(byId(close.getAttribute('data-close-modal'))); return; }
      if (target.classList && target.classList.contains('modal-backdrop')) { closeModal(target); return; }
      var actionTarget = target.closest ? target.closest('[data-action]') : null;
      if (!actionTarget) return;
      var card = actionTarget.closest('.card');
      if (!card) return;
      var id = card.getAttribute('data-id');
      var action = actionTarget.getAttribute('data-action');
      if (action === 'toggle-complete') toggleComplete(id);
      else if (action === 'edit') openEdit(id);
      else if (action === 'delete') deleteMemo(id);
    });

    document.addEventListener('change', function (event) {
      var target = event.target;
      if (!target.getAttribute || target.getAttribute('data-action') !== 'change-category') return;
      var card = target.closest('.card');
      if (card) changeCategory(card.getAttribute('data-id'), target.value);
    });

    document.addEventListener('keydown', function (event) {
      if (event.key === 'Escape') {
        if (el.editModal.classList.contains('open')) closeModal(el.editModal);
        if (el.infoModal.classList.contains('open')) closeModal(el.infoModal);
      }
    });
  }

  function boot() {
    initElements();
    state.items = loadItems();
    bindEvents();
    el.searchInput.value = state.query;
    el.showCompleted.checked = state.showCompleted;
    updatePrediction();
    render();
    el.runtimeStatus.textContent = '操作可能です。すべてのボタン機能を読み込みました。';
    setTimeout(function () { if (el.runtimeStatus) el.runtimeStatus.style.display = 'none'; }, 3600);
    setTimeout(function () { el.captureInput.focus(); }, 50);
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
  else boot();
}());
