(function () {
  'use strict';

  const RUNTIME_VERSION = '20260724-002';
  const API_BASE = 'https://page-views-api.ratneshc.com/api/v1/track';
  const SITE_ID = 'allsunday1122.github.io';
  const path = location.pathname.replace(/\/{2,}/g, '/').replace(/\/$/, '');
  const configs = {
    '/yorugatari/5min-horror.html': {
      title: '5分で読める怖い話｜夜語り',
      text: '約5分で読める一話完結の怖い話12選。無料・登録不要です。',
      content: 'five_minute_12',
      startId: 'five-minute'
    },
    '/yorugatari/bedtime-horror.html': {
      title: '寝る前に読む怖い話｜夜語り',
      text: '寝る前に一話だけ読みたい人向けの、静かに怖い短編8選です。',
      content: 'bedtime_8',
      startId: 'bedtime'
    }
  };
  const config = configs[path];
  const shareButton = document.querySelector('#landingShareButton');
  const copyButton = document.querySelector('#landingCopyButton');
  const status = document.querySelector('#landingShareStatus');
  if (!config || !shareButton || !copyButton || !status) return;

  const canonical = document.querySelector('link[rel="canonical"]')?.href || location.href.split('?')[0];
  const trackedUrl = new URL(canonical);
  trackedUrl.searchParams.set('utm_source', 'web_share');
  trackedUrl.searchParams.set('utm_medium', 'social');
  trackedUrl.searchParams.set('utm_campaign', 'onsite_share');
  trackedUrl.searchParams.set('utm_content', config.content);

  const storyStartPath = '/yorugatari/__landing-start/' + config.startId;
  const storyStartKey = 'yorugatari-landing-start:' + config.startId;
  const state = {
    runtimeVersion: RUNTIME_VERSION,
    title: config.title,
    text: config.text,
    url: trackedUrl.href,
    storyStartPath,
    storyStartAttempted: false,
    storyStartTracked: false,
    storyStartError: null,
    lastAction: null,
    error: null
  };
  window.YORUGATARI_LANDING_SHARE = state;

  function announce(message) {
    status.textContent = message;
  }

  function trackingEndpoint(trackingPath) {
    return API_BASE + '?site=' + encodeURIComponent(SITE_ID) + '&path=' + encodeURIComponent(trackingPath);
  }

  function trackStoryStart() {
    let alreadyTracked = false;
    try { alreadyTracked = sessionStorage.getItem(storyStartKey) === '1'; } catch (error) {}
    if (alreadyTracked) return;

    state.storyStartAttempted = true;
    try { sessionStorage.setItem(storyStartKey, '1'); } catch (error) {}
    fetch(trackingEndpoint(storyStartPath), {
      method: 'GET',
      credentials: 'omit',
      cache: 'no-store',
      keepalive: true,
      referrerPolicy: 'no-referrer'
    }).then(function (response) {
      if (!response.ok) throw new Error('HTTP ' + response.status);
      state.storyStartTracked = true;
      state.storyStartError = null;
    }).catch(function (error) {
      state.storyStartError = error && error.message ? error.message : String(error);
    });
  }

  async function copyLink() {
    try {
      await navigator.clipboard.writeText(state.url);
      state.lastAction = 'copy';
      state.error = null;
      announce('共有用リンクをコピーしました。');
      return true;
    } catch (error) {
      state.error = error && error.message ? error.message : String(error);
      announce('リンクをコピーできませんでした。');
      return false;
    }
  }

  shareButton.addEventListener('click', async function () {
    if (typeof navigator.share !== 'function') {
      await copyLink();
      return;
    }
    try {
      await navigator.share({ title: state.title, text: state.text, url: state.url });
      state.lastAction = 'share';
      state.error = null;
      announce('共有画面を開きました。');
    } catch (error) {
      if (error && error.name === 'AbortError') {
        state.lastAction = 'cancel';
        announce('共有をキャンセルしました。');
        return;
      }
      state.error = error && error.message ? error.message : String(error);
      announce('共有画面を開けませんでした。');
    }
  });

  copyButton.addEventListener('click', copyLink);
  document.querySelectorAll('a[href^="stories/"]').forEach(function (link) {
    link.addEventListener('click', trackStoryStart);
  });
})();
