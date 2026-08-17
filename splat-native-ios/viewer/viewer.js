const API = 'https://gybchnyqlqwmajwkhsly.supabase.co/functions/v1/scanlab-public';
const params = new URLSearchParams(location.search);
const id = params.get('id');
const token = params.get('token');
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
  document.title = pageTitle;
  setMeta('meta[name="description"]', description);
  setMeta('meta[property="og:title"]', pageTitle);
  setMeta('meta[property="og:description"]', description);
  setMeta('meta[property="og:url"]', location.href);
  setMeta('meta[name="twitter:title"]', pageTitle);
  setMeta('meta[name="twitter:description"]', description);
  if (item.previewUrl) {
    setMeta('meta[property="og:image"]', item.previewUrl);
    setMeta('meta[name="twitter:image"]', item.previewUrl);
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

share.addEventListener('click', async () => {
  try {
    const shareData = { title: document.title, text: caption.textContent || undefined, url: location.href };
    if (navigator.share) {
      await navigator.share(shareData);
    } else if (navigator.clipboard) {
      await navigator.clipboard.writeText(location.href);
      share.textContent = 'URLをコピーしました';
      setTimeout(() => { share.textContent = '共有'; }, 1600);
    }
  } catch (error) {
    if (error?.name !== 'AbortError') console.error(error);
  }
});

main();
