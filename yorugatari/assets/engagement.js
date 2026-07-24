(function () {
  'use strict';

  const SITE_ID = 'allsunday1122.github.io';
  const API_BASE = 'https://page-views-api.ratneshc.com/api/v1';
  const SOURCE_KEY = 'yorugatari-source-tracked';
  const CAMPAIGN_KEY_PREFIX = 'yorugatari-campaign-tracked:';
  const canonical = document.querySelector('link[rel="canonical"]');
  const canonicalUrl = canonical ? canonical.href : location.href.split('#')[0];
  const actualPath = location.pathname.replace(/\/{2,}/g, '/').replace(/\/$/, '') || '/';
  const isYorugatari = actualPath === '/yorugatari' || actualPath.startsWith('/yorugatari/');
  const viewCount = document.querySelector('.view-count strong');
  const query = new URLSearchParams(location.search);
  const knownCampaigns = new Map([
    ['x|launch_20260723|top_100', 'launch-20260723-x-top-100'],
    ['x|launch_20260723|last_elevator', 'launch-20260723-x-last-elevator'],
    ['threads|launch_20260723|spare_key', 'launch-20260723-threads-spare-key'],
    ['line|launch_20260723|hired_experience', 'launch-20260723-line-hired-experience']
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

  function taggedShareUrl() {
    const url = new URL(canonicalUrl);
    url.searchParams.set('utm_source', 'web_share');
    url.searchParams.set('utm_medium', 'social');
    url.searchParams.set('utm_campaign', 'onsite_share');
    return url.href;
  }

  const source = sourceChannel();
  const campaign = campaignId();
  const automated = isAutomatedRequest();
  const state = {
    path: actualPath,
    trackingPath: actualPath,
    source,
    campaign,
    automated,
    tracked: false,
    sourceTracked: false,
    campaignTracked: false,
    views: null,
    shareReady: false,
    shareUrl: taggedShareUrl(),
    relatedReady: document.querySelectorAll('.related a').length >= 2,
    error: null,
    sourceError: null,
    campaignError: null
  };
  window.YORUGATARI_ENGAGEMENT = state;

  function endpoint(name, targetPath) {
    return API_BASE + '/' + name + '?site=' + encodeURIComponent(SITE_ID) + '&path=' + encodeURIComponent(targetPath || actualPath);
  }

  async function request(url, options, attempts) {
    let lastError = null;
    for (let attempt = 1; attempt <= attempts; attempt += 1) {
      try {
        const response = await fetch(url, options);
        if (response.ok) return response;
        lastError = new Error('HTTP ' + response.status);
        if (response.status < 500 && response.status !== 429) break;
      } catch (error) {
        lastError = error;
      }
      if (attempt < attempts) await new Promise(function (resolve) { setTimeout(resolve, attempt * 400); });
    }
    throw lastError || new Error('Request failed');
  }

  function requestOptions(keepalive) {
    return {
      method: 'GET',
      credentials: 'omit',
      cache: 'no-store',
      keepalive: Boolean(keepalive),
      referrerPolicy: 'no-referrer'
    };
  }

  async function trackPageView() {
    if (!isYorugatari || automated) return;
    await request(endpoint('track'), requestOptions(true), 2);
    state.tracked = true;
  }

  async function trackSource() {
    if (!isYorugatari || automated || source === 'internal') return;
    let alreadyTracked = false;
    try { alreadyTracked = sessionStorage.getItem(SOURCE_KEY) === '1'; } catch (error) {}
    if (alreadyTracked) return;
    await request(endpoint('track', '/yorugatari/__source/' + source), requestOptions(true), 2);
    state.sourceTracked = true;
    try { sessionStorage.setItem(SOURCE_KEY, '1'); } catch (error) {}
  }

  async function trackCampaign() {
    if (!isYorugatari || automated || !campaign) return;
    const storageKey = CAMPAIGN_KEY_PREFIX + campaign;
    let alreadyTracked = false;
    try { alreadyTracked = sessionStorage.getItem(storageKey) === '1'; } catch (error) {}
    if (alreadyTracked) return;
    await request(endpoint('track', '/yorugatari/__campaign/' + campaign), requestOptions(true), 2);
    state.campaignTracked = true;
    try { sessionStorage.setItem(storageKey, '1'); } catch (error) {}
  }

  async function loadViewCount() {
    if (!viewCount || !isYorugatari) return;
    const response = await request(endpoint('views'), requestOptions(false), 3);
    const data = await response.json();
    const views = Number(data && data.views);
    if (!Number.isFinite(views) || views < 0) throw new Error('Invalid view count');
    state.views = views;
    viewCount.textContent = new Intl.NumberFormat('ja-JP').format(views);
    viewCount.closest('.view-count')?.setAttribute('aria-label', '閲覧数 ' + views + '回');
  }

  async function startAnalytics() {
    try { await trackPageView(); } catch (error) { state.error = error && error.message ? error.message : String(error); }
    try { await trackSource(); } catch (error) { state.sourceError = error && error.message ? error.message : String(error); }
    try { await trackCampaign(); } catch (error) { state.campaignError = error && error.message ? error.message : String(error); }
    try {
      await loadViewCount();
    } catch (error) {
      state.error = error && error.message ? error.message : String(error);
      if (viewCount) viewCount.textContent = '—';
    }
  }

  function copyText(text) {
    if (navigator.clipboard && navigator.clipboard.writeText) return navigator.clipboard.writeText(text);
    return new Promise(function (resolve, reject) {
      const textarea = document.createElement('textarea');
      textarea.value = text;
      textarea.setAttribute('readonly', '');
      textarea.style.position = 'fixed';
      textarea.style.opacity = '0';
      document.body.appendChild(textarea);
      textarea.select();
      try {
        const copied = document.execCommand('copy');
        textarea.remove();
        copied ? resolve() : reject(new Error('Copy failed'));
      } catch (error) {
        textarea.remove();
        reject(error);
      }
    });
  }

  function storyInfoBox() {
    return document.querySelector('.story-side .story-info, .story-side .side-box, .story-side, .story-info');
  }

  function installShareControl() {
    const slug = document.body && document.body.dataset.slug;
    const infoBox = storyInfoBox();
    const heading = document.querySelector('.story-hero h1');
    if (!slug || !infoBox || !heading || infoBox.querySelector('#shareButton')) return;

    const wrapper = document.createElement('div');
    wrapper.className = 'share-control';
    wrapper.style.display = 'grid';
    wrapper.style.gap = '.5rem';
    wrapper.style.marginTop = '1rem';
    wrapper.innerHTML = '<button class="btn" id="shareButton" type="button">共有する</button><p class="share-status" aria-live="polite" style="min-height:1.5em;margin:0;font-size:.85rem"></p>';
    const readingStatus = infoBox.querySelector('.reading-status');
    if (readingStatus) readingStatus.insertAdjacentElement('afterend', wrapper);
    else infoBox.insertAdjacentElement('afterbegin', wrapper);

    const button = wrapper.querySelector('#shareButton');
    const status = wrapper.querySelector('.share-status');
    const title = heading.textContent.trim() + '｜夜語り';
    const text = '約5分で読めるオリジナル怖い話「' + heading.textContent.trim() + '」';
    const shareUrl = state.shareUrl;

    button.addEventListener('click', async function () {
      button.disabled = true;
      try {
        if (navigator.share) {
          await navigator.share({ title, text, url: shareUrl });
          status.textContent = '共有画面を開きました。';
        } else {
          await copyText(shareUrl);
          status.textContent = '計測用の作品URLをコピーしました。';
        }
      } catch (error) {
        if (error && error.name === 'AbortError') status.textContent = '';
        else status.textContent = '共有できませんでした。URLをアドレス欄からコピーしてください。';
      } finally {
        button.disabled = false;
      }
    });
    state.shareReady = true;
  }

  function scheduleAnalytics() {
    if ('requestIdleCallback' in window) {
      requestIdleCallback(function () { startAnalytics(); }, { timeout: 1200 });
    } else {
      setTimeout(startAnalytics, 0);
    }
  }

  installShareControl();
  scheduleAnalytics();
})();
