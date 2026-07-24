(function () {
  'use strict';

  const SITE_ID = 'allsunday1122.github.io';
  const API_BASE = 'https://page-views-api.ratneshc.com/api/v1/track';
  const path = location.pathname.replace(/\/{2,}/g, '/').replace(/\/$/, '') || '/';
  const isYorugatari = path === '/yorugatari' || path.startsWith('/yorugatari/');
  const trackingPath = document.body?.dataset.pageType === '404' ? '/yorugatari/404' : path;
  const sourceKey = 'yorugatari-source-tracked';
  const campaignKeyPrefix = 'yorugatari-campaign-tracked:';
  const query = new URLSearchParams(location.search);
  const knownCampaigns = new Map([
    ['x|launch_20260723|top_100', 'launch-20260723-x-top-100'],
    ['x|launch_20260723|last_elevator', 'launch-20260723-x-last-elevator'],
    ['threads|launch_20260723|spare_key', 'launch-20260723-threads-spare-key'],
    ['line|launch_20260723|hired_experience', 'launch-20260723-line-hired-experience'],
    ['x|launch_20260724|five_minute_12', 'launch-20260724-x-five-minute'],
    ['threads|launch_20260724|five_minute_12', 'launch-20260724-threads-five-minute'],
    ['x|launch_20260724|bedtime_8', 'launch-20260724-x-bedtime'],
    ['threads|launch_20260724|bedtime_8', 'launch-20260724-threads-bedtime']
  ]);

  function isAutomatedRequest() {
    const userAgent = String(navigator.userAgent || '');
    const automatedUserAgent = /(HeadlessChrome|Chrome-Lighthouse|Lighthouse|Yorugatari[-/ ].*(?:Audit|Check|Test)|Yorugatari-Live-Check)/i.test(userAgent);
    const automatedQuery = Array.from(query.keys()).some(function (key) {
      return /(?:^|[-_])(audit|verify|release|performance|lighthouse|accessibility|a11y|ui)(?:$|[-_])/i.test(key);
    });
    return Boolean(navigator.webdriver || window.__YORUGATARI_AUTOMATION__ === true || automatedUserAgent || automatedQuery);
  }

  function sourceChannel() {
    const source = (query.get('utm_source') || '').toLowerCase();
    if (source) {
      if (/^(google|bing|yahoo|duckduckgo|baidu|yandex)$/.test(source)) return 'search';
      if (/^(x|twitter|facebook|instagram|threads|line|tiktok|web_share)$/.test(source)) return 'social';
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

  function campaignId() {
    const source = (query.get('utm_source') || '').toLowerCase();
    const campaign = (query.get('utm_campaign') || '').toLowerCase();
    const content = (query.get('utm_content') || '').toLowerCase();
    if (source === 'web_share' && campaign === 'onsite_share') return 'onsite-share';
    return knownCampaigns.get([source, campaign, content].join('|')) || null;
  }

  const source = sourceChannel();
  const campaign = campaignId();
  const automated = isAutomatedRequest();
  const state = {
    path,
    trackingPath,
    source,
    campaign,
    automated,
    tracked: false,
    sourceTracked: false,
    campaignTracked: false,
    error: null,
    sourceError: null,
    campaignError: null
  };
  window.YORUGATARI_ANALYTICS = state;

  if (!isYorugatari || automated) return;

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

  async function trackPage() {
    try {
      await send(trackingPath);
      state.tracked = true;
    } catch (error) {
      state.error = error && error.message ? error.message : String(error);
    }
  }

  async function trackSource() {
    if (source === 'internal') return;
    let alreadyTracked = false;
    try { alreadyTracked = sessionStorage.getItem(sourceKey) === '1'; } catch (error) {}
    if (alreadyTracked) return;
    try {
      await send('/yorugatari/__source/' + source);
      state.sourceTracked = true;
      try { sessionStorage.setItem(sourceKey, '1'); } catch (error) {}
    } catch (error) {
      state.sourceError = error && error.message ? error.message : String(error);
    }
  }

  async function trackCampaign() {
    if (!campaign) return;
    const storageKey = campaignKeyPrefix + campaign;
    let alreadyTracked = false;
    try { alreadyTracked = sessionStorage.getItem(storageKey) === '1'; } catch (error) {}
    if (alreadyTracked) return;
    try {
      await send('/yorugatari/__campaign/' + campaign);
      state.campaignTracked = true;
      try { sessionStorage.setItem(storageKey, '1'); } catch (error) {}
    } catch (error) {
      state.campaignError = error && error.message ? error.message : String(error);
    }
  }

  async function track() {
    await trackPage();
    await trackSource();
    await trackCampaign();
  }

  function schedule() {
    if ('requestIdleCallback' in window) requestIdleCallback(track, { timeout: 3000 });
    else setTimeout(track, 1200);
  }

  if (document.readyState === 'complete') schedule();
  else addEventListener('load', schedule, { once: true });
})();
