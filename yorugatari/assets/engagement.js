(function () {
  'use strict';

  const SITE_ID = 'allsunday1122.github.io';
  const API_BASE = 'https://page-views-api.ratneshc.com/api/v1';
  const canonical = document.querySelector('link[rel="canonical"]');
  const canonicalUrl = canonical ? canonical.href : location.href.split('#')[0];
  const actualPath = location.pathname.replace(/\/{2,}/g, '/').replace(/\/$/, '') || '/';
  const isYorugatari = actualPath === '/yorugatari' || actualPath.startsWith('/yorugatari/');
  const isErrorPage = document.body && document.body.dataset.pageType === '404';
  const trackingPath = isErrorPage ? '/yorugatari/404' : actualPath;
  const viewCount = document.querySelector('.view-count strong');
  const state = {
    path: actualPath,
    trackingPath: trackingPath,
    tracked: false,
    views: null,
    shareReady: false,
    relatedReady: false,
    error: null
  };
  window.YORUGATARI_ENGAGEMENT = state;

  function endpoint(name) {
    return API_BASE + '/' + name + '?site=' + encodeURIComponent(SITE_ID) + '&path=' + encodeURIComponent(trackingPath);
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
      if (attempt < attempts) {
        await new Promise(function (resolve) { setTimeout(resolve, attempt * 400); });
      }
    }
    throw lastError || new Error('Request failed');
  }

  async function trackPageView() {
    if (!isYorugatari || navigator.webdriver) return;
    await request(endpoint('track'), {
      method: 'GET',
      credentials: 'omit',
      cache: 'no-store',
      keepalive: true,
      referrerPolicy: 'no-referrer'
    }, 2);
    state.tracked = true;
  }

  async function loadViewCount() {
    if (!viewCount || !isYorugatari || isErrorPage) return;
    const response = await request(endpoint('views'), {
      method: 'GET',
      credentials: 'omit',
      cache: 'no-store',
      referrerPolicy: 'no-referrer'
    }, 3);
    const data = await response.json();
    const views = Number(data && data.views);
    if (!Number.isFinite(views) || views < 0) throw new Error('Invalid view count');
    state.views = views;
    viewCount.textContent = new Intl.NumberFormat('ja-JP').format(views);
    viewCount.closest('.view-count')?.setAttribute('aria-label', '閲覧数 ' + views + '回');
  }

  async function startAnalytics() {
    try {
      await trackPageView();
      await loadViewCount();
    } catch (error) {
      state.error = error && error.message ? error.message : String(error);
      if (viewCount) viewCount.textContent = '—';
    }
  }

  function copyText(text) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      return navigator.clipboard.writeText(text);
    }
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

    button.addEventListener('click', async function () {
      button.disabled = true;
      try {
        if (navigator.share) {
          await navigator.share({ title: title, text: text, url: canonicalUrl });
          status.textContent = '共有画面を開きました。';
        } else {
          await copyText(canonicalUrl);
          status.textContent = '作品URLをコピーしました。';
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

  function storyHref(story) {
    const href = story && story.href ? story.href : ('stories/' + story.slug + '.html');
    return href.replace(/^\.\.\//, '').replace(/^stories\//, '');
  }

  function buildRelatedStories(catalog) {
    const slug = document.body && document.body.dataset.slug;
    const infoBox = storyInfoBox();
    const existing = document.querySelector('.related');
    if (existing && existing.querySelectorAll('a').length >= 2) {
      state.relatedReady = true;
      return true;
    }
    if (!slug || !infoBox || !Array.isArray(catalog) || !catalog.length) return false;

    const stories = Array.from(new Map(catalog.filter(function (story) {
      return story && story.slug && story.title;
    }).map(function (story) {
      return [story.slug, story];
    })).values());
    const currentIndex = stories.findIndex(function (story) { return story.slug === slug; });
    if (currentIndex < 0) return false;
    const current = stories[currentIndex];
    const sameCategory = stories
      .map(function (story, index) { return { story: story, index: index }; })
      .filter(function (entry) { return entry.story.slug !== slug && entry.story.category === current.category; })
      .sort(function (left, right) {
        return Math.abs(left.index - currentIndex) - Math.abs(right.index - currentIndex);
      })
      .map(function (entry) { return entry.story; });
    const fallback = stories.filter(function (story) { return story.slug !== slug; });
    const selected = Array.from(new Map(sameCategory.concat(fallback).map(function (story) {
      return [story.slug, story];
    })).values()).slice(0, 2);
    if (selected.length < 2) return false;

    const container = existing || document.createElement('div');
    container.className = 'related';
    container.innerHTML = '<h2>関連する怖い話</h2>';
    selected.forEach(function (story) {
      const link = document.createElement('a');
      link.href = storyHref(story);
      link.textContent = story.title;
      container.appendChild(link);
    });
    if (!existing) infoBox.appendChild(container);
    state.relatedReady = true;
    return true;
  }

  function installRelatedStories(attempt) {
    const catalog = Array.isArray(window.STORIES) ? window.STORIES : [];
    if (catalog.length >= 100 || attempt >= 30) {
      buildRelatedStories(catalog);
      return;
    }
    setTimeout(function () { installRelatedStories(attempt + 1); }, 200);
  }

  installShareControl();
  installRelatedStories(0);
  startAnalytics();
})();
