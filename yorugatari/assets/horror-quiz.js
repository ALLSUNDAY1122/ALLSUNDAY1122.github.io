(function () {
  'use strict';

  const RESULTS = {
    quiet: {
      label: '静かな違和感タイプ',
      summary: '大きな怪物より、消した照明や枕元の音が少しずつ気になってくる怖さが向いています。',
      stories: [
        { title: 'おやすみの順番', href: 'stories/good-night.html', note: '家の中を毎晩同じ挨拶が移動する、静かな後味の悪さ。' },
        { title: '自動保存された音声', href: 'stories/voice-memo.html', note: '覚えのない録音に、本人とは別の呼吸が近づいてくるネット怪談。' },
        { title: '返却期限は明日の朝', href: 'stories/return-by-morning.html', note: '閉館後の図書館で、自分の名前と期限が記された本を受け取る心霊譚。' }
      ]
    },
    human: {
      label: '現実の悪意タイプ',
      summary: '幽霊よりも、制度や善意を装って生活へ入り込む人間の行動に強く怖さを感じるタイプです。',
      stories: [
        { title: '合鍵は返却済み', href: 'stories/spare-key-returned.html', note: '無料防犯診断で複製された鍵が、研修生の実地侵入に使われる人怖。' },
        { title: '宅配ボックスの住人', href: 'stories/delivery-box.html', note: '宅配設備と複製鍵を使い、住人との入れ替わりを狙う元配送員。' },
        { title: '故人はそのように回答しました', href: 'stories/deceased-answered-that-way.html', note: '故人の声を復元するサービスの返答を、人間が契約誘導のため演じていた話。' }
      ]
    },
    digital: {
      label: '記録とネットタイプ',
      summary: '通知、アカウント、位置情報など、便利な仕組みが現実を書き換える怖さに向いています。',
      stories: [
        { title: '隣人のWi-Fi', href: 'stories/neighbor-wifi.html', note: '存在しない部屋のWi-Fiが、壁の中の監視通路を知らせてくる。' },
        { title: '削除済みユーザーから割り当てられました', href: 'stories/assigned-by-deleted-user.html', note: '削除済みの担当者へ返信すると、仕事と責任だけでなく存在まで移る。' },
        { title: '既読がつかない', href: 'stories/read-receipt.html', note: '行方不明者から午前4時に届く返信と、自宅を示す位置情報。' }
      ]
    },
    rules: {
      label: '奇妙なルールタイプ',
      summary: '理由を知らされない手順や、破った後に規則の意味が分かる怪談が向いています。',
      stories: [
        { title: '三回ノック', href: 'stories/three-knocks.html', note: '失くしたものを戻す三回ノック。代わりに自分の存在が名簿から消える。' },
        { title: '存在しない四階', href: 'stories/missing-floor.html', note: '雨の午前零時だけ現れる階で、帰り道と家族が一つずつ失われる。' },
        { title: '余った一合を家族に出さないで', href: 'stories/do-not-serve-the-extra-cup-of-rice.html', note: '余分な米を三度食卓へ出すと、米を研いだ人が次の一合になる。' }
      ]
    }
  };

  const form = document.querySelector('#horrorQuiz');
  const result = document.querySelector('#quizResult');
  const resultTitle = document.querySelector('#quizResultTitle');
  const resultSummary = document.querySelector('#quizResultSummary');
  const resultStories = document.querySelector('#quizResultStories');
  const restartButton = document.querySelector('#quizRestart');
  const shareButton = document.querySelector('#quizShare');
  const copyButton = document.querySelector('#quizCopy');
  const status = document.querySelector('#quizStatus');
  if (!form || !result || !resultTitle || !resultSummary || !resultStories || !restartButton || !shareButton || !copyButton || !status) return;

  const TYPE_ORDER = ['quiet', 'human', 'digital', 'rules'];
  const canonical = document.querySelector('link[rel="canonical"]')?.href || location.href.split(/[?#]/)[0];
  let currentType = null;

  function announce(message) {
    status.textContent = message;
  }

  function scoredType(values) {
    const score = { quiet: 0, human: 0, digital: 0, rules: 0 };
    score[values.scene] += 4;

    if (values.ending === 'linger') { score.quiet += 2; score.rules += 1; }
    if (values.ending === 'twist') { score.digital += 2; score.human += 1; }
    if (values.ending === 'real') { score.human += 2; score.digital += 1; }
    if (values.ending === 'ritual') { score.rules += 2; score.quiet += 1; }

    if (values.intensity === 'low') score.quiet += 2;
    if (values.intensity === 'medium') { score.digital += 1; score.human += 1; score.rules += 1; }
    if (values.intensity === 'high') { score.human += 2; score.rules += 1; }

    return TYPE_ORDER.reduce((best, type) => score[type] > score[best] ? type : best, TYPE_ORDER[0]);
  }

  function render(type, shouldFocus) {
    const data = RESULTS[type];
    if (!data) return;
    currentType = type;
    resultTitle.textContent = data.label;
    resultSummary.textContent = data.summary;
    resultStories.innerHTML = data.stories.map((story, index) => `
      <a class="quiz-story" href="${story.href}">
        <span class="quiz-story__number">${String(index + 1).padStart(2, '0')}</span>
        <span><strong>${story.title}</strong><small>${story.note}</small></span>
      </a>`).join('');
    result.hidden = false;
    result.dataset.type = type;
    history.replaceState(null, '', '#quiz-result');
    announce(`${data.label}のおすすめ3作品を表示しました。`);
    if (shouldFocus) resultTitle.focus();
  }

  function selectedValues() {
    const data = new FormData(form);
    return {
      scene: data.get('scene'),
      ending: data.get('ending'),
      intensity: data.get('intensity')
    };
  }

  form.addEventListener('submit', function (event) {
    event.preventDefault();
    if (!form.reportValidity()) return;
    render(scoredType(selectedValues()), true);
  });

  restartButton.addEventListener('click', function () {
    form.reset();
    currentType = null;
    result.hidden = true;
    result.removeAttribute('data-type');
    history.replaceState(null, '', location.pathname + location.search);
    announce('診断をリセットしました。');
    form.querySelector('input')?.focus();
  });

  function sharePayload() {
    const label = currentType ? RESULTS[currentType].label : '怖い話診断';
    const url = new URL(canonical);
    url.searchParams.set('utm_source', 'web_share');
    url.searchParams.set('utm_medium', 'social');
    url.searchParams.set('utm_campaign', 'onsite_share');
    url.searchParams.set('utm_content', 'horror_quiz');
    return {
      title: 'あなたに合う怖い話診断｜夜語り',
      text: currentType ? `私の診断結果は「${label}」。3問でおすすめの怖い話が分かります。` : '3問で、今夜読む怖い話を選べます。',
      url: url.href
    };
  }

  async function copyShare() {
    const payload = sharePayload();
    try {
      await navigator.clipboard.writeText(`${payload.text}\n${payload.url}`);
      announce('診断ページの共有文をコピーしました。');
    } catch (error) {
      announce('共有文をコピーできませんでした。');
    }
  }

  shareButton.addEventListener('click', async function () {
    const payload = sharePayload();
    if (typeof navigator.share !== 'function') {
      await copyShare();
      return;
    }
    try {
      await navigator.share(payload);
      announce('共有画面を開きました。');
    } catch (error) {
      if (error && error.name === 'AbortError') announce('共有をキャンセルしました。');
      else announce('共有画面を開けませんでした。');
    }
  });

  copyButton.addEventListener('click', copyShare);
})();
