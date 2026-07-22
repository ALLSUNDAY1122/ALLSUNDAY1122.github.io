(function () {
  'use strict';

  const path = location.pathname.replace(/\/{2,}/g, '/').replace(/\/$/, '') || '/';
  const isYorugatari = path === '/yorugatari' || path.startsWith('/yorugatari/');
  const trackingPath = document.body?.dataset.pageType === '404' ? '/yorugatari/404' : path;
  const state = { path, trackingPath, tracked: false, error: null };
  window.YORUGATARI_ANALYTICS = state;

  if (!isYorugatari || navigator.webdriver) return;

  function track() {
    const endpoint = 'https://page-views-api.ratneshc.com/api/v1/track?site=' +
      encodeURIComponent('allsunday1122.github.io') + '&path=' + encodeURIComponent(trackingPath);
    fetch(endpoint, {
      method: 'GET',
      credentials: 'omit',
      cache: 'no-store',
      keepalive: true,
      referrerPolicy: 'no-referrer'
    }).then(function (response) {
      if (!response.ok) throw new Error('HTTP ' + response.status);
      state.tracked = true;
    }).catch(function (error) {
      state.error = error && error.message ? error.message : String(error);
    });
  }

  function schedule() {
    if ('requestIdleCallback' in window) requestIdleCallback(track, { timeout: 3000 });
    else setTimeout(track, 1200);
  }

  if (document.readyState === 'complete') schedule();
  else addEventListener('load', schedule, { once: true });
})();
