(function () {
  'use strict';

  const VERSION = '20260724-001';
  const API = 'https://page-views-api.ratneshc.com/api/v1/track';
  const SITE = 'allsunday1122.github.io';
  const ids = {
    '/yorugatari/5min-horror.html': 'five-minute',
    '/yorugatari/bedtime-horror.html': 'bedtime'
  };
  const trackingPaths = {
    'five-minute': '/yorugatari/__landing-start/five-minute',
    bedtime: '/yorugatari/__landing-start/bedtime'
  };
  const pagePath = location.pathname.replace(/\/{2,}/g, '/').replace(/\/$/, '');
  const id = ids[pagePath];
  if (!id) return;

  const trackingPath = trackingPaths[id];
  const storageKey = 'yorugatari-landing-start:' + id;
  const state = {
    version: VERSION,
    path: trackingPath,
    attempted: false,
    inFlight: false,
    tracked: false,
    error: null
  };
  window.YORUGATARI_LANDING_START = state;

  if (navigator.webdriver && !window.__YORUGATARI_ALLOW_TRACKING_TEST__) return;

  function endpoint() {
    return API + '?site=' + encodeURIComponent(SITE) + '&path=' + encodeURIComponent(trackingPath);
  }

  function send() {
    let alreadyTracked = false;
    try { alreadyTracked = sessionStorage.getItem(storageKey) === '1'; } catch (error) {}
    if (alreadyTracked || state.inFlight) return;

    state.attempted = true;
    state.inFlight = true;
    fetch(endpoint(), {
      method: 'GET',
      credentials: 'omit',
      cache: 'no-store',
      keepalive: true,
      referrerPolicy: 'no-referrer'
    }).then(function (response) {
      if (!response.ok) throw new Error('HTTP ' + response.status);
      try { sessionStorage.setItem(storageKey, '1'); } catch (error) {}
      state.tracked = true;
      state.error = null;
    }).catch(function (error) {
      state.error = error && error.message ? error.message : String(error);
    }).finally(function () {
      state.inFlight = false;
    });
  }

  document.querySelectorAll('a[href^="stories/"]').forEach(function (link) {
    link.addEventListener('click', send);
  });
})();
