import { normalizeShareURL, parseShareKey } from './share-url.js';

const API = 'https://gybchnyqlqwmajwkhsly.supabase.co/functions/v1/scanlab-public';
const { id, token, legacyToken, fragmentToken } = parseShareKey(location.href);
const status = document.querySelector('#status');
const statusText = document.querySelector('#status-text');
const statusPreview = document.querySelector('#status-preview');
const card = document.querySelector('#card');
const title = document.querySelector('#title');
const author = document.querySelector('#author');
const caption = document.querySelector('#caption');
const locationText = document.querySelector('#location');
const likes = document.querySelector('#likes');
const share = document.querySelector('#share');

const shareURL = normalizeShareURL(location.href, { id, token });
if (legacyToken && !fragmentToken) {
  // Backward compatibility for previously issued ?token= links while removing the
  // capability token from the HTTP-visible query string as soon as the page executes.
  history.replaceState(null, '', shareURL);
}

function fail(message) {
  status.classList.add('error');
  statusText.textContent = message;
}

function setMeta(selector, value, attribute = 'content') {
  const element = document.querySelector(selector);
  if (element && value) element.setAttribute(attribute, value);
}

function applyShareMetadata(item) {
  const pageTitle = item.title ? `${item.title} | Scan Lab` : 'Scan Lab 3D Viewer';
  const description = item.caption || 'Scan Labで公開された3D Gaussian Splatをブラウザで閲覧します。';
  const canonicalURL = id ? shareURL : `${location.origin}${location.pathname}`;
  const previewAlt = item.title ? `${item.title} の3Dプレビュー` : 'Scan Lab 3Dプレビュー';
  document.title = pageTitle;
  setMeta('meta[name="description"]', description);
  setMeta('meta[property="og:title"]', pageTitle);
  setMeta('meta[property="og:description"]', description);
  setMeta('meta[property="og:url"]', canonicalURL);
  setMeta('meta[name="twitter:title"]', pageTitle);
  setMeta('meta[name="twitter:description"]', description);
  setMeta('link[rel="canonical"]', canonicalURL, 'href');
  if (item.previewUrl) {
    setMeta('meta[property="og:image"]', item.previewUrl);
    setMeta('meta[property="og:image:alt"]', previewAlt);
    setMeta('meta[name="twitter:image"]', item.previewUrl);
    setMeta('meta[name="twitter:image:alt"]', previewAlt);
  }
}

function revealPreview(item) {
  if (!item.previewUrl) return;
  statusPreview.src = item.previewUrl;
  statusPreview.alt = item.title ? `${item.title} のプレビュー` : '3Dプレビュー';
  statusPreview.hidden = false;
  status.classList.add('has-preview');
}

function renderMetadataCard(item) {
  title.textContent = item.title || '名称未設定';
  const handle = item.author?.handle ? `@${item.author.handle}` : '';
  const displayName = item.author?.displayName || '';
  author.textContent = [handle, displayName].filter(Boolean).join(' · ') || 'Scan Lab';
  caption.textContent = item.caption || '';
  caption.hidden = !item.caption;
  locationText.textContent = item.location?.label ? `場所: ${item.location.label}` : '';
  locationText.hidden = !item.location?.label;
  likes.textContent = `♡ ${Number(item.likeCount || 0).toLocaleString('ja-JP')}`;
  card.hidden = false;
}

async function loadMetadata() {
  if (!id && !token) throw new Error('共有URLが正しくありません。');
  const query = new URLSearchParams({ mode: 'share' });
  if (token) query.set('token', token); else query.set('id', id);
  const response = await fetch(`${API}?${query.toString()}`, { headers: { Accept: 'application/json' } });
  if (response.status === 404) throw new Error('この3Dは非公開化または削除されています。');
  if (!response.ok) throw new Error('共有3Dを取得できませんでした。');
  const body = await response.json();
  if (!body?.item?.modelUrl) throw new Error('3Dデータを利用できません。');
  return body.item;
}

async function main() {
  try {
    const item = await loadMetadata();

    // Metadata and preview are intentionally rendered before loading the heavy 3D runtime.
    // A CDN/GPU/runtime failure must not erase the recipient's title/description/preview context.
    applyShareMetadata(item);
    renderMetadataCard(item);
    revealPreview(item);
    statusText.textContent = '3Dを読み込んでいます';

    const GaussianSplats3D = await import('@mkkellogg/gaussian-splats-3d');
    const rootElement = document.querySelector('#viewer');
    const viewer = new GaussianSplats3D.Viewer({
      rootElement,
      cameraUp: [0, 1, 0],
      initialCameraPosition: [0, 0, 4],
      initialCameraLookAt: [0, 0, 0],
      sharedMemoryForWorkers: false,
      gpuAcceleratedSort: false,
      enableSIMDInSort: true,
      halfPrecisionCovariancesOnGPU: true,
      dynamicScene: false,
      sphericalHarmonicsDegree: 0,
      showLoadingUI: true
    });
    await viewer.addSplatScene(item.modelUrl, {
      splatAlphaRemovalThreshold: 1,
      showLoadingUI: true,
      progressiveLoad: true
    });
    viewer.start();
    status.classList.add('hidden');
  } catch (error) {
    console.error(error);
    fail(error?.message || '3Dを表示できませんでした。');
  }
}

async function copyShareURL() {
  if (navigator.clipboard?.writeText) {
    try {
      await navigator.clipboard.writeText(shareURL);
      return true;
    } catch {
      // Fall through to the legacy DOM copy path for restricted clipboard contexts.
    }
  }

  const textarea = document.createElement('textarea');
  textarea.value = shareURL;
  textarea.setAttribute('readonly', '');
  textarea.setAttribute('aria-hidden', 'true');
  textarea.style.position = 'fixed';
  textarea.style.opacity = '0';
  textarea.style.pointerEvents = 'none';
  document.body.appendChild(textarea);
  textarea.select();
  textarea.setSelectionRange(0, textarea.value.length);
  let copied = false;
  try {
    copied = document.execCommand('copy');
  } catch {
    copied = false;
  } finally {
    textarea.remove();
  }
  return copied;
}

function showCopiedFeedback() {
  share.textContent = 'URLをコピーしました';
  setTimeout(() => { share.textContent = '共有'; }, 1600);
}

share.addEventListener('click', async () => {
  const shareData = { title: document.title, text: caption.textContent || undefined, url: shareURL };
  if (navigator.share) {
    try {
      await navigator.share(shareData);
      return;
    } catch (error) {
      if (error?.name === 'AbortError') return;
      console.error(error);
    }
  }

  if (await copyShareURL()) {
    showCopiedFeedback();
    return;
  }

  // Last-resort manual path: only invoked after a user gesture and when browser copy APIs fail.
  window.prompt('共有URLをコピーしてください', shareURL);
});

main();
