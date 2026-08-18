import * as GaussianSplats3D from '@mkkellogg/gaussian-splats-3d';

const API = 'https://gybchnyqlqwmajwkhsly.supabase.co/functions/v1/scanlab-public';
const METADATA_TIMEOUT_MS = 12000;
const SCENE_TIMEOUT_MS = 60000;
const AUTO_RETRY_DELAYS_MS = [0, 700];

const params = new URLSearchParams(location.search);
const id = params.get('id');
const token = params.get('token');
const status = document.querySelector('#status');
const statusText = document.querySelector('#status-text');
const statusDetail = document.querySelector('#status-detail');
const retry = document.querySelector('#retry');
const card = document.querySelector('#card');
const title = document.querySelector('#title');
const author = document.querySelector('#author');
const caption = document.querySelector('#caption');
const locationText = document.querySelector('#location');
const likes = document.querySelector('#likes');
const share = document.querySelector('#share');
const rootElement = document.querySelector('#viewer');

let currentViewer = null;
let loadGeneration = 0;
let loading = false;

class ViewerLoadError extends Error {
  constructor(message, { retryable = true, detail = '', code = 'unknown' } = {}) {
    super(message);
    this.name = 'ViewerLoadError';
    this.retryable = retryable;
    this.detail = detail;
    this.code = code;
  }
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function setStatus(mode, message, detail = '') {
  status.classList.remove('hidden', 'error', 'offline');
  if (mode === 'error') status.classList.add('error');
  if (mode === 'offline') status.classList.add('offline');
  status.setAttribute('aria-busy', mode === 'loading' ? 'true' : 'false');
  statusText.textContent = message;
  statusDetail.textContent = detail;
  statusDetail.hidden = !detail;
  retry.hidden = mode === 'loading';
  retry.disabled = mode === 'loading';
}

function hideStatus() {
  status.classList.add('hidden');
  status.setAttribute('aria-busy', 'false');
}

function cleanupViewer() {
  const viewer = currentViewer;
  currentViewer = null;
  if (!viewer) return;
  try { viewer.stop?.(); } catch (error) { console.warn('viewer.stop failed', error); }
  try { viewer.dispose?.(); } catch (error) { console.warn('viewer.dispose failed', error); }
  rootElement.replaceChildren();
}

function timeoutPromise(ms, error) {
  return new Promise((_, reject) => setTimeout(() => reject(error), ms));
}

function validateModelUrl(value) {
  let url;
  try {
    url = new URL(value, location.href);
  } catch {
    throw new ViewerLoadError('3DデータのURLが壊れています。', {
      retryable: false,
      code: 'invalid_model_url'
    });
  }
  const localDevelopment = location.hostname === 'localhost' || location.hostname === '127.0.0.1';
  if (url.protocol !== 'https:' && !(localDevelopment && url.protocol === 'http:')) {
    throw new ViewerLoadError('安全でない3DデータURLは読み込めません。', {
      retryable: false,
      code: 'unsafe_model_url'
    });
  }
  return url.href;
}

async function fetchMetadataOnce() {
  if (!id && !token) {
    throw new ViewerLoadError('共有URLが正しくありません。', {
      retryable: false,
      code: 'missing_share_key'
    });
  }
  if (navigator.onLine === false) {
    throw new ViewerLoadError('インターネットに接続されていません。', {
      retryable: true,
      detail: '接続を確認してから、もう一度試してください。',
      code: 'offline'
    });
  }

  const query = new URLSearchParams({ mode: 'share' });
  if (token) query.set('token', token); else query.set('id', id);
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), METADATA_TIMEOUT_MS);

  let response;
  try {
    response = await fetch(`${API}?${query.toString()}`, {
      headers: { Accept: 'application/json' },
      cache: 'no-store',
      signal: controller.signal
    });
  } catch (error) {
    if (error?.name === 'AbortError') {
      throw new ViewerLoadError('共有情報の取得に時間がかかっています。', {
        retryable: true,
        detail: '通信状態を確認して再試行してください。',
        code: 'metadata_timeout'
      });
    }
    throw new ViewerLoadError('共有3Dへ接続できませんでした。', {
      retryable: true,
      detail: 'ネットワークまたはサーバーの一時的な問題の可能性があります。',
      code: 'metadata_network'
    });
  } finally {
    clearTimeout(timer);
  }

  if (response.status === 404 || response.status === 410) {
    throw new ViewerLoadError('この3Dは非公開化または削除されています。', {
      retryable: false,
      code: 'not_available'
    });
  }
  if (response.status === 401 || response.status === 403) {
    throw new ViewerLoadError('この3Dを表示する権限がありません。', {
      retryable: false,
      code: 'forbidden'
    });
  }
  if (response.status === 429) {
    throw new ViewerLoadError('アクセスが集中しています。', {
      retryable: true,
      detail: '少し時間をおいてから再試行してください。',
      code: 'rate_limited'
    });
  }
  if (!response.ok) {
    throw new ViewerLoadError('共有3Dを取得できませんでした。', {
      retryable: response.status >= 500,
      detail: `サーバー応答: ${response.status}`,
      code: `metadata_http_${response.status}`
    });
  }

  let body;
  try {
    body = await response.json();
  } catch {
    throw new ViewerLoadError('共有情報の形式が正しくありません。', {
      retryable: true,
      code: 'invalid_metadata_json'
    });
  }
  if (!body?.item?.modelUrl) {
    throw new ViewerLoadError('3Dデータを利用できません。', {
      retryable: false,
      code: 'missing_model_url'
    });
  }
  return { ...body.item, modelUrl: validateModelUrl(body.item.modelUrl) };
}

async function loadMetadata() {
  let lastError;
  for (let attempt = 0; attempt < AUTO_RETRY_DELAYS_MS.length; attempt += 1) {
    if (AUTO_RETRY_DELAYS_MS[attempt] > 0) await sleep(AUTO_RETRY_DELAYS_MS[attempt]);
    try {
      return await fetchMetadataOnce();
    } catch (error) {
      lastError = error;
      if (!(error instanceof ViewerLoadError) || !error.retryable) throw error;
    }
  }
  throw lastError;
}

function renderMetadata(item) {
  document.title = `${item.title || '3D Scan'} | Scan Lab`;
  title.textContent = item.title || '3D Scan';
  author.textContent = item.author?.displayName
    ? `@${item.author.handle || 'user'} · ${item.author.displayName}`
    : 'Scan Lab';
  caption.textContent = item.caption || '';
  caption.hidden = !item.caption;
  locationText.textContent = item.location?.label ? `場所: ${item.location.label}` : '';
  locationText.hidden = !item.location?.label;
  likes.textContent = `♡ ${Number(item.likeCount || 0).toLocaleString('ja-JP')}`;
  card.hidden = false;
}

async function loadScene(item, generation) {
  cleanupViewer();
  if (generation !== loadGeneration) return;

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
    showLoadingUI: false
  });
  currentViewer = viewer;

  try {
    await Promise.race([
      viewer.addSplatScene(item.modelUrl, {
        splatAlphaRemovalThreshold: 1,
        showLoadingUI: false,
        progressiveLoad: true
      }),
      timeoutPromise(SCENE_TIMEOUT_MS, new ViewerLoadError('3Dデータの読み込みがタイムアウトしました。', {
        retryable: true,
        detail: '大きな3Dや通信状態によって時間がかかる場合があります。',
        code: 'scene_timeout'
      }))
    ]);
  } catch (error) {
    cleanupViewer();
    if (error instanceof ViewerLoadError) throw error;
    throw new ViewerLoadError('3Dデータを読み込めませんでした。', {
      retryable: true,
      detail: 'データ配信またはブラウザの一時的な問題の可能性があります。',
      code: 'scene_load_failed'
    });
  }

  if (generation !== loadGeneration) {
    cleanupViewer();
    return;
  }
  viewer.start();
}

function presentFailure(error) {
  const known = error instanceof ViewerLoadError;
  const message = known ? error.message : '3Dを表示できませんでした。';
  const detail = known ? error.detail : 'ページを再読み込みするか、もう一度試してください。';
  const offline = known && error.code === 'offline';
  setStatus(offline ? 'offline' : 'error', message, detail);
  retry.hidden = known ? !error.retryable : false;
  console.error(error);
}

async function load() {
  if (loading) return;
  loading = true;
  const generation = ++loadGeneration;
  retry.disabled = true;
  card.hidden = true;
  cleanupViewer();
  setStatus('loading', '共有情報を読み込んでいます');

  try {
    const item = await loadMetadata();
    if (generation !== loadGeneration) return;
    renderMetadata(item);
    setStatus('loading', '3Dデータを読み込んでいます', '大きな3Dでは少し時間がかかることがあります。');
    await loadScene(item, generation);
    if (generation === loadGeneration) hideStatus();
  } catch (error) {
    if (generation === loadGeneration) presentFailure(error);
  } finally {
    if (generation === loadGeneration) {
      loading = false;
      retry.disabled = false;
    }
  }
}

retry.addEventListener('click', () => {
  if (!loading) load();
});

window.addEventListener('offline', () => {
  if (!loading) setStatus('offline', 'インターネット接続が切れました。', '接続が戻ったら、もう一度試してください。');
});

window.addEventListener('online', () => {
  if (!loading && !status.classList.contains('hidden')) {
    statusDetail.textContent = '接続が戻りました。再試行できます。';
    statusDetail.hidden = false;
    retry.hidden = false;
  }
});

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

load();
