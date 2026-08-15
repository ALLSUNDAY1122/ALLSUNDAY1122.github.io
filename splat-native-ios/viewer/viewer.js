import * as GaussianSplats3D from '@mkkellogg/gaussian-splats-3d';

const API = 'https://gybchnyqlqwmajwkhsly.supabase.co/functions/v1/scanlab-public';
const params = new URLSearchParams(location.search);
const id = params.get('id');
const token = params.get('token');
const status = document.querySelector('#status');
const statusText = document.querySelector('#status-text');
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
    document.title = `${item.title} | Scan Lab`;
    title.textContent = item.title;
    author.textContent = item.author?.displayName ? `@${item.author.handle} · ${item.author.displayName}` : 'Scan Lab';
    caption.textContent = item.caption || '';
    caption.hidden = !item.caption;
    locationText.textContent = item.location?.label ? `場所: ${item.location.label}` : '';
    locationText.hidden = !item.location?.label;
    likes.textContent = `♡ ${Number(item.likeCount || 0).toLocaleString('ja-JP')}`;
    card.hidden = false;

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
    if (navigator.share) {
      await navigator.share({ title: document.title, url: location.href });
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
