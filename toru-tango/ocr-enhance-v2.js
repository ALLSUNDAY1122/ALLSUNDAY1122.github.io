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
    <p class="muted small">2種類の画像補正を比較し、文字量・日本語率・認識信頼度が高い結果を自動採用します。</p>`;
  originalRunButton.insertAdjacentElement('beforebegin', controls);

  const runButton = originalRunButton.cloneNode(true);
  runButton.textContent = '高精度で文字を読む';
  originalRunButton.replaceWith(runButton);

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
  });
  rotateRight.addEventListener('click', () => {
    sourceRotation = normalizeRotation(sourceRotation + 90);
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

    for (let index = 0, pixel = 0; index < data.length; index += 4, pixel += 1) {
      let value = (grays[pixel] - low) * 255 / (high - low);
      value = Math.max(0, Math.min(255, value));
      if (variant === 'binary') value = value < threshold ? 0 : 255;
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
    const noise = (text.match(/[|_=<>\\^]{1}/g) || []).length;
    const meaningfulLines = text.split(/\n/).filter((line) =>
      (line.match(/[\u3040-\u30ff\u3400-\u9fff0-9A-Za-z]/g) || []).length >= 4
    ).length;
    return japanese * 3 + digits * 1.2 + latin * 0.45 + meaningfulLines * 18 + Number(confidence || 0) * 2 - noise * 4;
  }

  function passPlan(type) {
    if (type === 'table') {
      return [
        { label: '表向け白黒補正', variant: 'binary', psm: '6' },
        { label: 'まばらな文字向け', variant: 'balanced', psm: '11' }
      ];
    }
    if (type === 'faint') {
      return [
        { label: '薄文字強調', variant: 'faint', psm: '6' },
        { label: '白黒補正', variant: 'binary', psm: '11' }
      ];
    }
    return [
      { label: '本文向け補正', variant: 'balanced', psm: '6' },
      { label: '原画像', variant: 'original', psm: '3' }
    ];
  }

  runButton.addEventListener('click', async () => {
    if (!sourceImage) {
      setStatus('先に写真を撮るか選択してください。', 'error');
      return;
    }

    runButton.disabled = true;
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

      candidates.sort((left, right) => right.score - left.score);
      const best = candidates[0];
      if (!best || best.text.length < 10) {
        throw new Error('文字を十分に認識できませんでした。教材を平らに置き、影を避け、文字が画面いっぱいになる距離で撮り直してください。');
      }
      sourceText.value = best.text;
      const confidenceLabel = best.confidence >= 75 ? '良好' : best.confidence >= 55 ? '要確認' : '低め';
      setStatus(`文字認識が完了しました。「${best.label}」を採用しました。認識信頼度は${Math.round(best.confidence)}（${confidenceLabel}）です。本文を必ず確認してください。`, best.confidence >= 55 ? 'success' : 'error');
      sourceText.scrollIntoView({ behavior: 'smooth', block: 'center' });
    } catch (error) {
      setStatus(error instanceof Error ? error.message : '文字認識に失敗しました。', 'error');
    } finally {
      if (worker) await worker.terminate().catch(() => {});
      runButton.disabled = false;
    }
  });
})();
