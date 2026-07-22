(function () {
  'use strict';

  const SITE_ID = 'allsunday1122.github.io';
  const API_BASE = 'https://page-views-api.ratneshc.com/api/v1/track';
  const path = location.pathname.replace(/\/{2,}/g, '/').replace(/\/$/, '') || '/';
  const isYorugatari = path === '/yorugatari' || path.startsWith('/yorugatari/');
  const trackingPath = document.body?.dataset.pageType === '404' ? '/yorugatari/404' : path;
  const sourceKey = 'yorugatari-source-tracked';

  function sourceChannel() {
    const campaign = new URLSearchParams(location.search).get('utm_source') || '';
    const source = campaign.toLowerCase();
    if (source) {
      if (/google|bing|yahoo|duckduckgo|baidu|yandex/.test(source)) return 'search';
      if (/x|twitter|facebook|instagram|threads|line|tiktok/.test(source)) return 'social';
      return 'campaign';
    }
    if (!document.referrer) return 'direct';
    try {
      const host = new URL(document.referrer).hostname.toLowerCase();
      if (host === location.hostname) return 'internal';
      if (/google\.|bing\.|search\.yahoo\.|duckduckgo\.|baidu\.|yandex\./.test(host)) return 'search';
      if (/(^|\.)x\.com$|twitter\.com$|facebook\.com$|instagram\.com$|threads\.net$|line\.me$|tiktok\.com$/.test(host)) return 'social';
      return 'referral';
    } catch (error) {
      return 'referral';
    }
  }

  const source = sourceChannel();
  const state = { path, trackingPath, source, tracked: false, sourceTracked: false, error: null };
  window.YORUGATARI_ANALYTICS = state;

  if (!isYorugatari || navigator.webdriver) return;

  function endpoint(targetPath) {
    return API_BASE + '?site=' + encodeURIComponent(SITE_ID) + '&path=' + encodeURIComponent(targetPath);
  }

  function send(targetPath) {
    return fetch(endpoint(targetPath), {
      method: 'GET',
      credentials: 'omit',
      cache: 'no-store',
      keepalive: true,
      referrerPolicy: 'no-referrer'
    }).then(function (response) {
      if (!response.ok) throw new Error('HTTP ' + response.status);
    });
  }

  async function track() {
    try {
      await send(trackingPath);
      state.tracked = true;

      let sourceAlreadyTracked = false;
      try { sourceAlreadyTracked = sessionStorage.getItem(sourceKey) === '1'; } catch (error) {}
      if (source !== 'internal' && !sourceAlreadyTracked) {
        await send('/yorugatari/__source/' + source);
        state.sourceTracked = true;
        try { sessionStorage.setItem(sourceKey, '1'); } catch (error) {}
      }
    } catch (error) {
      state.error = error && error.message ? error.message : String(error);
    }
  }

  function schedule() {
    if ('requestIdleCallback' in window) requestIdleCallback(track, { timeout: 3000 });
    else setTimeout(track, 1200);
  }

  if (document.readyState === 'complete') schedule();
  else addEventListener('load', schedule, { once: true });
})();
