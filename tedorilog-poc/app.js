// PoC UI（画面A/B/C）。解析は engine/ を直接読み込み、評価ハーネスと同じロジックを使う。
// 外部への通信は行わない。pdf.js も同梱物を読み込む。

import { extractPayslip, extractPayslipBest, STATUS } from './engine/extract.js';
import { ITEM_KEYS, ITEM_LABELS } from './engine/lexicon.js';
import { buildSaveDraft } from './engine/save_guard.js';
import { parseAmount } from './engine/normalize.js';
import { extractPdfTokens, renderFirstPage } from './engine/pdf_tokens.js';

const $ = (id) => document.getElementById(id);
const state = {
  source: null, // {kind, name, buffer|caseId}
  result: null,
  confirmations: {},
  preview: null, // {type:'canvas'|'image', scale, width}
  startedAt: 0,
  elapsedMs: 0,
  editCount: 0,
  manualCount: 0,
  manifest: null,
};

const STATUS_TEXT = {
  [STATUS.CONFIRMED_CANDIDATE]: ['確定候補', 'confident'],
  [STATUS.NEEDS_REVIEW]: ['要確認', 'review'],
  [STATUS.NOT_FOUND]: ['未検出', 'missing'],
};

function showScreen(name) {
  for (const s of ['a', 'b', 'c']) {
    $(`screen-${s}`).hidden = s !== name;
  }
  document.querySelectorAll('.step').forEach((el) => {
    el.classList.toggle('active', el.dataset.step === name);
  });
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

function setError(id, message) {
  const el = $(id);
  el.hidden = !message;
  el.textContent = message || '';
}

// ---------------------------------------------------------------- 画面A

async function loadManifest() {
  try {
    const res = await fetch('./fixtures/manifest.json');
    if (!res.ok) throw new Error(String(res.status));
    state.manifest = await res.json();
  } catch (err) {
    state.manifest = { cases: [] };
    return;
  }
  const select = $('corpus-select');
  for (const c of state.manifest.cases) {
    const option = document.createElement('option');
    option.value = c.id;
    option.textContent = `${c.id}｜${c.title}`;
    select.appendChild(option);
  }
}

function selectFile(kind, input) {
  const file = input.files && input.files[0];
  if (!file) return;
  state.source = { kind, name: file.name, file };
  $('selected-file').textContent = `選択中: ${file.name}`;
  $('btn-start').disabled = false;
  setError('input-error', '');
}

$('file-pdf').addEventListener('change', (e) => selectFile('pdf', e.target));
$('file-photo').addEventListener('change', (e) => selectFile('photo', e.target));
$('file-shot').addEventListener('change', (e) => selectFile('screenshot', e.target));

$('btn-start').addEventListener('click', () => {
  if (!state.source) return;
  if (state.source.kind === 'pdf') runPdf(state.source.file);
  else runImageFile(state.source.file);
});

$('btn-corpus').addEventListener('click', () => {
  const id = $('corpus-select').value;
  if (id) runCorpusCase(id);
});

async function runPdf(file) {
  setError('input-error', '');
  state.startedAt = performance.now();
  try {
    const buffer = await file.arrayBuffer();
    const { tokens, doc } = await extractPdfTokens(buffer);
    if (tokens.length < 8) {
      // テキストを持たないPDF（スキャンPDF）。本番は端末内OCRへフォールバックする。
      setError(
        'input-error',
        'このPDFは文字情報を持っていません（スキャンPDF）。本番アプリでは端末内OCRへ切り替えます。'
        + 'ブラウザPoCではOCRを積んでいないため、固定コーパスのスキャンPDF例（case10）で挙動を確認してください。',
      );
      return;
    }
    const result = extractPayslip(tokens, { route: 'pdf_text' });
    await showPdfPreview(doc);
    finishAnalysis(result);
  } catch (err) {
    setError('input-error', `PDFを読み込めませんでした: ${err && err.message ? err.message : err}`);
  }
}

function runImageFile(file) {
  setError(
    'input-error',
    '画像の文字認識は端末内OCR（本番: Apple Vision）で行う想定です。ブラウザPoCにはOCRエンジンを積んでいないため、'
    + '画像ファイルの解析はできません。固定コーパス（スクリーンショット・写真の例）で挙動を確認してください。',
  );
  const url = URL.createObjectURL(file);
  const img = $('preview-image');
  img.src = url;
  img.hidden = false;
}

async function runCorpusCase(caseId) {
  setError('input-error', '');
  state.startedAt = performance.now();
  try {
    const meta = state.manifest.cases.find((c) => c.id === caseId);
    const res = await fetch(`./fixtures/cases/${caseId}.tokens.json`);
    if (!res.ok) throw new Error(`fixture ${caseId} を読み込めません`);
    const data = await res.json();
    state.source = { kind: meta.kind, name: `${caseId}｜${meta.title}`, caseId };
    $('selected-file').textContent = `選択中: ${state.source.name}`;

    let result;
    if (data.route === 'pdf_text' && meta.kind === 'text_pdf') {
      // PDFはこの場で実際に解析する
      const pdfRes = await fetch(`./fixtures/${meta.file}`);
      const buffer = await pdfRes.arrayBuffer();
      const { tokens, doc } = await extractPdfTokens(buffer);
      result = extractPayslip(tokens, { route: 'pdf_text' });
      await showPdfPreview(doc);
    } else {
      result = extractPayslipBest(data.variants, { route: data.route });
      await showImagePreview(`./fixtures/${meta.ocr_source || meta.file}`, meta.scale || 1);
    }
    finishAnalysis(result);
  } catch (err) {
    setError('input-error', `サンプルを読み込めませんでした: ${err && err.message ? err.message : err}`);
  }
}

// ---------------------------------------------------------------- 原文プレビュー

async function showPdfPreview(doc) {
  const canvas = $('preview-canvas');
  const img = $('preview-image');
  img.hidden = true;
  canvas.hidden = false;
  const { scale } = await renderFirstPage(doc, canvas, 1.4);
  state.preview = { type: 'canvas', scale, el: canvas };
}

function showImagePreview(url, caseScale) {
  return new Promise((resolve) => {
    const img = $('preview-image');
    const canvas = $('preview-canvas');
    canvas.hidden = true;
    img.hidden = false;
    img.onload = () => {
      state.preview = { type: 'image', scale: caseScale, el: img };
      resolve();
    };
    img.onerror = () => {
      state.preview = null;
      resolve();
    };
    img.src = url;
  });
}

function highlight(item) {
  const overlay = $('preview-overlay');
  overlay.innerHTML = '';
  if (!state.preview || !item.evidence.length) {
    $('preview-note').textContent = item.value === null
      ? 'この項目は読み取り元が特定できていません（未検出、または合計から算出した候補です）。'
      : 'この項目の読み取り位置は表示できません。';
    return;
  }
  const el = state.preview.el;
  const displayed = el.getBoundingClientRect();
  const natural = state.preview.type === 'canvas'
    ? { w: el.width, h: el.height }
    : { w: el.naturalWidth, h: el.naturalHeight };
  // トークン座標(pt) → 元画像/描画ピクセル → 表示ピクセル
  const toPx = state.preview.scale;
  const ratio = displayed.width / natural.w;

  for (const part of item.evidence) {
    for (const [box, kind] of [[part.labelBox, 'label'], [part.amountBox, 'amount']]) {
      if (!box) continue;
      const div = document.createElement('div');
      div.className = `hl ${kind}`;
      div.style.left = `${box.x * toPx * ratio}px`;
      div.style.top = `${box.y * toPx * ratio}px`;
      div.style.width = `${Math.max(6, box.w * toPx * ratio)}px`;
      div.style.height = `${Math.max(6, box.h * toPx * ratio)}px`;
      overlay.appendChild(div);
    }
  }
  $('preview-note').textContent = `${item.label}: 青枠が項目名、黄枠が読み取った金額です。`;
}

// ---------------------------------------------------------------- 画面B

function finishAnalysis(result) {
  state.elapsedMs = Math.round(performance.now() - state.startedAt);
  state.result = result;
  state.confirmations = {};
  state.editCount = 0;
  state.manualCount = 0;

  for (const key of ITEM_KEYS) {
    const item = result.items[key];
    state.confirmations[key] = { value: item.value, confirmed: false, edited: false };
  }
  renderItems();
  renderBanner();
  setError('save-error', '');
  showScreen('b');
}

function renderBanner() {
  const r = state.result;
  const route = r.route === 'pdf_text' ? 'PDF直接解析' : `OCR${r.variant ? `（${r.variant}）` : ''}`;
  const parts = [
    `入力経路: ${route}`,
    `確定候補 ${r.summary.confident} / 要確認 ${r.summary.needsReview} / 未検出 ${r.summary.notFound}`,
    `処理時間 ${state.elapsedMs}ms`,
  ];
  if (!r.ok) parts.unshift(r.message || '解析できませんでした');
  const failed = r.checks.filter((c) => !c.ok);
  if (failed.length) parts.push(`検算の不一致: ${failed.map((c) => c.id).join(', ')}`);
  $('review-banner').textContent = `${parts.join(' ／ ')}。保存する前に各項目を確認してください。`;
}

function renderItems() {
  const box = $('items');
  box.innerHTML = '';
  for (const key of ITEM_KEYS) {
    const item = state.result.items[key];
    const conf = state.confirmations[key];
    const [statusLabel, statusClass] = STATUS_TEXT[item.status];

    const wrap = document.createElement('div');
    wrap.className = `item${conf.confirmed ? ' is-confirmed' : ''}`;

    const head = document.createElement('div');
    head.className = 'item-head';
    const label = document.createElement('span');
    label.className = 'item-label';
    label.textContent = ITEM_LABELS[key];
    label.addEventListener('click', () => highlight(item));
    const badge = document.createElement('span');
    badge.className = `badge ${statusClass}`;
    badge.textContent = statusLabel;
    head.append(label, badge);
    if (item.derived) head.append(tag('合計から算出'));
    if (item.corrected) head.append(tag('桁誤りを補正'));
    wrap.appendChild(head);

    const row = document.createElement('div');
    row.className = 'item-row';
    const input = document.createElement('input');
    input.type = 'text';
    input.inputMode = 'numeric';
    input.value = conf.value === null ? '' : conf.value.toLocaleString('ja-JP');
    input.addEventListener('change', () => {
      const raw = input.value.trim();
      if (raw === '') {
        conf.value = null;
      } else {
        const parsed = parseAmount(raw);
        if (!parsed) {
          setError('save-error', `${ITEM_LABELS[key]}: 金額として読み取れません`);
          input.value = conf.value === null ? '' : conf.value.toLocaleString('ja-JP');
          return;
        }
        conf.value = Math.abs(parsed.value);
        input.value = conf.value.toLocaleString('ja-JP');
      }
      setError('save-error', '');
      const changed = conf.value !== item.value;
      if (changed && !conf.edited) {
        conf.edited = true;
        if (item.value === null) state.manualCount += 1;
        else state.editCount += 1;
      }
      conf.confirmed = true;
      renderItems();
    });

    const clear = document.createElement('button');
    clear.type = 'button';
    clear.textContent = '未設定に戻す';
    clear.addEventListener('click', () => {
      conf.value = null;
      conf.confirmed = true;
      conf.edited = item.value !== null;
      renderItems();
    });

    const confirmLabel = document.createElement('label');
    confirmLabel.className = 'confirm';
    const check = document.createElement('input');
    check.type = 'checkbox';
    check.checked = conf.confirmed;
    check.addEventListener('change', () => {
      conf.confirmed = check.checked;
      renderItems();
    });
    confirmLabel.append(check, document.createTextNode('確認した'));

    row.append(input, clear, confirmLabel);
    wrap.appendChild(row);

    if (item.alternatives && item.alternatives.length) {
      const alts = document.createElement('div');
      alts.className = 'alts';
      for (const alt of item.alternatives.slice(0, 3)) {
        const btn = document.createElement('button');
        btn.type = 'button';
        btn.className = 'alt';
        btn.textContent = `別候補 ${alt.value.toLocaleString('ja-JP')}${alt.label ? `（${alt.label}）` : ''}`;
        btn.addEventListener('click', () => {
          if (conf.value !== alt.value) {
            conf.value = alt.value;
            conf.edited = true;
            state.editCount += 1;
          }
          conf.confirmed = true;
          renderItems();
        });
        alts.appendChild(btn);
      }
      wrap.appendChild(alts);
    }

    if (item.reasons && item.reasons.length) {
      const reason = document.createElement('p');
      reason.className = 'item-reason';
      reason.textContent = item.reasons.join(' / ');
      wrap.appendChild(reason);
    }
    box.appendChild(wrap);
  }
}

function tag(text) {
  const el = document.createElement('span');
  el.className = 'badge review';
  el.textContent = text;
  return el;
}

$('btn-confirm-all').addEventListener('click', () => {
  for (const key of ITEM_KEYS) state.confirmations[key].confirmed = true;
  renderItems();
});

$('btn-back').addEventListener('click', () => showScreen('a'));

$('btn-save').addEventListener('click', () => {
  const draft = buildSaveDraft(state.result, state.confirmations);
  if (!draft.ok) {
    setError(
      'save-error',
      `保存できません。未確認の項目があります: ${draft.blocked.map((b) => b.label).join('、')}`,
    );
    return;
  }
  setError('save-error', '');
  renderResult(draft.payload);
  showScreen('c');
});

// ---------------------------------------------------------------- 画面C

function renderResult(payload) {
  const values = Object.values(payload.items);
  const confirmedAsIs = values.filter((v) => v.source === 'user_confirmed').length;
  const edited = values.filter((v) => v.source === 'user_edited').length;
  const empty = values.filter((v) => v.source === 'empty').length;
  const route = state.result.route === 'pdf_text' ? 'PDF直接解析' : 'OCR';

  const dl = $('result-summary');
  dl.innerHTML = '';
  const rows = [
    ['入力', state.source ? state.source.name : '-'],
    ['入力経路', route + (state.result.variant ? `（${state.result.variant}）` : '')],
    ['認識成功項目数', `${confirmedAsIs} 項目（提示された候補をそのまま確認）`],
    ['要修正項目数', `${edited} 項目（修正操作 ${state.editCount + state.manualCount} 回）`],
    ['未検出・未入力', `${empty} 項目`],
    ['処理時間', `${state.elapsedMs} ms`],
    ['外部送信', 'なし（端末内で完結）'],
  ];
  for (const [k, v] of rows) {
    const dt = document.createElement('dt');
    dt.textContent = k;
    const dd = document.createElement('dd');
    dd.textContent = v;
    dl.append(dt, dd);
  }
  $('result-json').textContent = JSON.stringify(payload, null, 2);
}

$('btn-restart').addEventListener('click', () => {
  state.source = null;
  state.result = null;
  $('selected-file').textContent = '';
  $('btn-start').disabled = true;
  $('preview-overlay').innerHTML = '';
  showScreen('a');
});

showScreen('a');
loadManifest();
