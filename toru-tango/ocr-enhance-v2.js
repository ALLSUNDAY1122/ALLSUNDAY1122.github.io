(() => {
  'use strict';

  const photoInput = document.querySelector('#photoInput');
  const rotateLeft = document.querySelector('#rotateLeft');
  const rotateRight = document.querySelector('#rotateRight');
  const originalRunButton = document.querySelector('#runOcr');
  const sourceText = document.querySelector('#sourceText');
  const status = document.querySelector('#ocrStatus');

  if (!photoInput || !rotateLeft || !rotateRight || !originalRunButton || !sourceText || !status) return;

  let sourceImage = null;
  let sourceRotation = 0;

  const normalizeRotation = (value) => ((value % 360) + 360) % 360;
  const setStatus = (message, type = '') => {
    status.className = `status${type ? ` ${type}` : ''}`;
    status.textContent = message;
  };

  const controls = document.createElement('div');
  controls.id = 'ocrEnhanceControls';
  controls.className = 'hidden';
  controls.innerHTML = `
    <label class="label" for="ocrDocumentType">教材の種類</label>
    <select id="ocrDocumentType">
      <option value="text" selected>教科書・文章</option>
      <option value="table">表・箇条書き・資料</option>
      <option value="faint">薄い文字・影がある写真</option>
    </select>
    <p class="muted small">同じ写真の「補正なし」と「教材向け補正」を比較し、文字量・日本語率・認識信頼度が高い結果を自動採用します。認識後に結果を見比べて選び直せます。</p>`;
  originalRunButton.insertAdjacentElement('beforebegin', controls);

  const runButton = originalRunButton.cloneNode(true);
  runButton.textContent = '高精度で文字を読む';
  originalRunButton.replaceWith(runButton);

  const comparisonStyle = document.createElement('style');
  comparisonStyle.textContent = `
    #ocrComparison{margin-top:12px}
    #ocrComparison h3{font-size:16px;margin:0 0 4px}
    #ocrComparison>.muted{margin:0 0 10px}
    .ocrCompareGrid{display:grid;gap:10px}
    .ocrCompareCard{background:#f8f9fc;border:1px solid #dce2ec;border-radius:15px;padding:12px}
    .ocrCompareCard.isSelected{background:#f1f5ff;border-color:#3456d1;box-shadow:0 0 0 1px #3456d1}
    .ocrCompareHeader{align-items:flex-start;display:flex;gap:8px;justify-content:space-between}
    .ocrCompareHeader strong{font-size:14px;line-height:1.4}
    .ocrCompareBadge{background:#3456d1;border-radius:999px;color:#fff;font-size:11px;font-weight:700;padding:3px 8px;white-space:nowrap}
    .ocrCompareBadge:empty{display:none}
    .ocrCompareMeta{color:#667085;font-size:12px;line-height:1.5;margin:4px 0 8px}
    .ocrCompareText{background:#fff;border:1px solid #dce2ec;border-radius:10px;color:#172033;font-size:13px;line-height:1.55;margin:0 0 10px;max-height:210px;min-height:96px;overflow:auto;padding:10px;white-space:pre-wrap}
    .ocrCompareCard button{width:100%}
  `;
  document.head.appendChild(comparisonStyle);

  const comparison = document.createElement('section');
  comparison.id = 'ocrComparison';
  comparison.className = 'hidden';
  comparison.setAttribute('aria-live', 'polite');
  status.insertAdjacentElement('afterend', comparison);

  function clearComparison() {
    comparison.replaceChildren();
    comparison.classList.add('hidden');
  }

  function confidenceLabel(confidence) {
    if (confidence >= 75) return '良好';
    if (confidence >= 55) return '要確認';
    return '低め';
  }

  function useCandidate(candidate, cards) {
    if (!candidate.text) return;
    sourceText.value = candidate.text;
    cards.forEach((card) => {
      const isSelected = card.dataset.candidateLabel === candidate.label;
      card.classList.toggle('isSelected', isSelected);
      const badge = card.querySelector('.ocrCompareBadge');
      if (badge) badge.textContent = isSelected ? '本文に使用中' : '';
      const button = card.querySelector('button');
      if (button) button.textContent = isSelected ? 'この結果を使用中' : 'この結果を本文に使う';
    });
    setStatus(`「${candidate.label}」を本文に使います。内容を確認し、誤りがあれば修正してください。`, 'success');
    sourceText.scrollIntoView({ behavior: 'smooth', block: 'center' });
  }

  function renderComparison(candidates, selected) {
    clearComparison();

    const heading = document.createElement('h3');
    heading.textContent = 'OCR結果を比較';
    const description = document.createElement('p');
    description.className = 'muted small';
    description.textContent = '同じ写真の結果です。全文を見比べ、読み取りが正確な方を本文に使ってください。';
    const grid = document.createElement('div');
    grid.className = 'ocrCompareGrid';

    const cards = candidates.map((candidate) => {
      const card = document.createElement('article');
      card.className = `ocrCompareCard${candidate === selected ? ' isSelected' : ''}`;
      card.dataset.candidateLabel = candidate.label;

      const header = document.createElement('div');
      header.className = 'ocrCompareHeader';
      const title = document.createElement('strong');
      title.textContent = candidate.label;
      const badge = document.createElement('span');
      badge.className = 'ocrCompareBadge';
      badge.textContent = candidate === selected ? '自動採用' : '';
      header.append(title, badge);

      const meta = document.createElement('p');
      meta.className = 'ocrCompareMeta';
      const lineCount = candidate.text ? candidate.text.split(/\n/).filter(Boolean).length : 0;
      meta.textContent = `認識信頼度 ${Math.round(candidate.confidence)}（${confidenceLabel(candidate.confidence)}）・${candidate.text.length}文字・${lineCount}行`;

      const text = document.createElement('pre');
      text.className = 'ocrCompareText';
      text.textContent = candidate.text || '文字を認識できませんでした。';

      const button = document.createElement('button');
      button.className = 'btn';
      button.type = 'button';
      button.disabled = !candidate.text;
      button.textContent = candidate === selected ? 'この結果を使用中' : 'この結果を本文に使う';
      button.addEventListener('click', () => useCandidate(candidate, cards));

      card.append(header, meta, text, button);
      grid.appendChild(card);
      return card;
    });

    comparison.append(heading, description, grid);
    comparison.classList.remove('hidden');
  }

  function loadImage(file) {
    return new Promise((resolve, reject) => {
      const url = URL.createObjectURL(file);
      const image = new Image();
      image.onload = () => {
        URL.revokeObjectURL(url);
        resolve(image);
      };
      image.onerror = () => {
        URL.revokeObjectURL(url);
        reject(new Error('高精度OCR用の画像を読み込めませんでした。'));
      };
      image.src = url;
    });
  }

  photoInput.addEventListener('change', async (event) => {
    const file = event.target.files?.[0] || null;
    sourceImage = null;
    sourceRotation = 0;
    clearComparison();
    controls.classList.toggle('hidden', !file);
    if (!file) return;
    try {
      sourceImage = await loadImage(file);
    } catch (error) {
      setStatus(error instanceof Error ? error.message : '画像を読み込めませんでした。', 'error');
    }
  });

  rotateLeft.addEventListener('click', () => {
    sourceRotation = normalizeRotation(sourceRotation - 90);
    clearComparison();
  });
  rotateRight.addEventListener('click', () => {
    sourceRotation = normalizeRotation(sourceRotation + 90);
    clearComparison();
  });

  async function loadTesseract() {
    if (window.Tesseract?.createWorker) return;
    await new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = 'https://cdn.jsdelivr.net/npm/tesseract.js@5.1.1/dist/tesseract.min.js';
      script.onload = resolve;
      script.onerror = () => reject(new Error('文字認識機能を読み込めませんでした。通信状態を確認してください。'));
      document.head.appendChild(script);
    });
  }

  function percentile(histogram, total, ratio) {
    let count = 0;
    const target = total * ratio;
    for (let value = 0; value < 256; value += 1) {
      count += histogram[value];
      if (count >= target) return value;
    }
    return 255;
  }

  function otsuThreshold(histogram, total) {
    let sum = 0;
    for (let value = 0; value < 256; value += 1) sum += value * histogram[value];
    let backgroundWeight = 0;
    let backgroundSum = 0;
    let bestVariance = -1;
    let bestThreshold = 160;
    for (let value = 0; value < 256; value += 1) {
      backgroundWeight += histogram[value];
      if (!backgroundWeight) continue;
      const foregroundWeight = total - backgroundWeight;
      if (!foregroundWeight) break;
      backgroundSum += value * histogram[value];
      const backgroundMean = backgroundSum / backgroundWeight;
      const foregroundMean = (sum - backgroundSum) / foregroundWeight;
      const variance = backgroundWeight * foregroundWeight * (backgroundMean - foregroundMean) ** 2;
      if (variance > bestVariance) {
        bestVariance = variance;
        bestThreshold = value;
      }
    }
    return Math.max(95, Math.min(215, bestThreshold));
  }

  function createOcrCanvas(variant, maxSide = 3200) {
    if (!sourceImage) throw new Error('画像が選択されていません。');
    const sourceWidth = sourceImage.naturalWidth || sourceImage.width;
    const sourceHeight = sourceImage.naturalHeight || sourceImage.height;
    const rotation = normalizeRotation(sourceRotation);
    const swap = rotation === 90 || rotation === 270;
    const rotatedWidth = swap ? sourceHeight : sourceWidth;
    const rotatedHeight = swap ? sourceWidth : sourceHeight;
    const scale = Math.min(2.4, Math.max(0.55, maxSide / Math.max(rotatedWidth, rotatedHeight)));
    const canvas = document.createElement('canvas');
    canvas.width = Math.max(1, Math.round(rotatedWidth * scale));
    canvas.height = Math.max(1, Math.round(rotatedHeight * scale));
    const context = canvas.getContext('2d', { willReadFrequently: true });
    context.imageSmoothingEnabled = true;
    context.imageSmoothingQuality = 'high';
    context.fillStyle = '#fff';
    context.fillRect(0, 0, canvas.width, canvas.height);
    context.save();
    context.translate(canvas.width / 2, canvas.height / 2);
    context.rotate(rotation * Math.PI / 180);
    context.drawImage(sourceImage, -sourceWidth * scale / 2, -sourceHeight * scale / 2, sourceWidth * scale, sourceHeight * scale);
    context.restore();

    if (variant === 'original') return canvas;

    const imageData = context.getImageData(0, 0, canvas.width, canvas.height);
    const data = imageData.data;
    const histogram = new Uint32Array(256);
    const grays = new Uint8Array(canvas.width * canvas.height);
    for (let index = 0, pixel = 0; index < data.length; index += 4, pixel += 1) {
      const gray = Math.round(data[index] * 0.299 + data[index + 1] * 0.587 + data[index + 2] * 0.114);
      grays[pixel] = gray;
      histogram[gray] += 1;
    }

    const total = grays.length;
    const low = percentile(histogram, total, variant === 'faint' ? 0.04 : 0.015);
    const high = Math.max(low + 25, percentile(histogram, total, variant === 'faint' ? 0.97 : 0.992));
    const threshold = otsuThreshold(histogram, total);
    const stretchedThreshold = Math.max(0, Math.min(255, (threshold - low) * 255 / (high - low)));

    for (let index = 0, pixel = 0; index < data.length; index += 4, pixel += 1) {
      let value = (grays[pixel] - low) * 255 / (high - low);
      value = Math.max(0, Math.min(255, value));
      if (variant === 'binary') value = value < stretchedThreshold ? 0 : 255;
      if (variant === 'faint') value = Math.max(0, Math.min(255, (value - 145) * 1.55 + 145));
      data[index] = value;
      data[index + 1] = value;
      data[index + 2] = value;
      data[index + 3] = 255;
    }
    context.putImageData(imageData, 0, 0);
    return canvas;
  }

  function repairText(value) {
    const raw = String(value || '').trim();
    return window.ToruTangoGeneratorV2?.repairOcrText
      ? window.ToruTangoGeneratorV2.repairOcrText(raw)
      : raw;
  }

  function scoreText(text, confidence) {
    const japanese = (text.match(/[\u3040-\u30ff\u3400-\u9fff々]/g) || []).length;
    const digits = (text.match(/[0-9]/g) || []).length;
    const latin = (text.match(/[A-Za-z]/g) || []).length;
    const noise = (text.match(/[|_=<>\\^\uFFFD]/g) || []).length;
    const lineLengths = text.split(/\n/)
      .map((line) => (line.match(/[\u3040-\u30ff\u3400-\u9fff0-9A-Za-z]/g) || []).length)
      .filter((length) => length > 0);
    const meaningfulLines = lineLengths.filter((length) => length >= 6).length;
    const shortFragments = lineLengths.filter((length) => length <= 4).length;
    return japanese * 3
      + digits * 1.2
      + latin * 0.45
      + meaningfulLines * 18
      + Number(confidence || 0) * 2.5
      - noise * 6
      - shortFragments * 10;
  }

  function passPlan(type) {
    if (type === 'table') {
      return [
        { label: '補正なし（比較基準）', variant: 'original', psm: '3' },
        { label: '表向け白黒補正', variant: 'binary', psm: '6' }
      ];
    }
    if (type === 'faint') {
      return [
        { label: '補正なし（比較基準）', variant: 'original', psm: '3' },
        { label: '薄文字強調', variant: 'faint', psm: '6' }
      ];
    }
    return [
      { label: '補正なし（比較基準）', variant: 'original', psm: '3' },
      { label: '本文向け補正', variant: 'balanced', psm: '6' }
    ];
  }

  runButton.addEventListener('click', async () => {
    if (!sourceImage) {
      setStatus('先に写真を撮るか選択してください。', 'error');
      return;
    }

    runButton.disabled = true;
    clearComparison();
    const type = document.querySelector('#ocrDocumentType')?.value || 'text';
    let worker = null;
    try {
      setStatus('高精度文字認識を準備しています。初回は少し時間がかかります。');
      await loadTesseract();
      let currentPass = 0;
      const plan = passPlan(type);
      worker = await window.Tesseract.createWorker('jpn+eng', 1, {
        logger: (message) => {
          if (typeof message.progress === 'number') {
            setStatus(`${plan[currentPass]?.label || '文字認識'} ${Math.round(message.progress * 100)}%`);
          }
        }
      });

      const candidates = [];
      for (currentPass = 0; currentPass < plan.length; currentPass += 1) {
        const pass = plan[currentPass];
        setStatus(`${pass.label}で認識しています（${currentPass + 1}/${plan.length}）。`);
        await worker.setParameters({
          tessedit_pageseg_mode: pass.psm,
          preserve_interword_spaces: '1',
          user_defined_dpi: '300'
        });
        const result = await worker.recognize(createOcrCanvas(pass.variant));
        const text = repairText(result?.data?.text || '');
        const confidence = Number(result?.data?.confidence || 0);
        candidates.push({ text, confidence, score: scoreText(text, confidence), label: pass.label });
      }

      const best = [...candidates].sort((left, right) => right.score - left.score)[0];
      if (!best || best.text.length < 10) {
        throw new Error('文字を十分に認識できませんでした。教材を平らに置き、影を避け、文字が画面いっぱいになる距離で撮り直してください。');
      }
      sourceText.value = best.text;
      renderComparison(candidates, best);
      setStatus(`文字認識が完了しました。「${best.label}」を自動採用しました。2つの結果を比較してから本文を確認してください。`, best.confidence >= 55 ? 'success' : 'error');
      comparison.scrollIntoView({ behavior: 'smooth', block: 'start' });
    } catch (error) {
      setStatus(error instanceof Error ? error.message : '文字認識に失敗しました。', 'error');
    } finally {
      if (worker) await worker.terminate().catch(() => {});
      runButton.disabled = false;
    }
  });
})();
