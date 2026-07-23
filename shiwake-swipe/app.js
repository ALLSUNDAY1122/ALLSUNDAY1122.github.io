(() => {
  'use strict';

  const STORAGE_KEY = 'shiwakeSwipeStatsV1';
  const SETTINGS_KEY = 'shiwakeSwipeSettingsV1';
  const MODES = {
    score: { label: 'スコアアタック', length: Infinity },
    time: { label: 'タイムアタック', length: Infinity },
    weak: { label: '苦手出題', length: 10 },
    daily: { label: 'デイリー10問', length: 10 },
  };

  const els = Object.fromEntries([
    'homeScreen','gameScreen','resultScreen','backButton','soundButton','totalAnswers','accuracyRate','bestCombo',
    'questionCountBadge','weakCategoryList','resetStatsButton','gameModeTitle','scoreValue','comboValue','limitLabel',
    'limitValue','limitUnit','progressBar','gradeBadge','categoryBadge','transactionText','questionCard','accountText',
    'debitButton','creditButton','feedbackPanel','feedbackTitle','feedbackPoints','feedbackText','journalEntry','nextButton',
    'resultLabel','resultTitle','finalScore','correctCount','resultAccuracy','resultBestCombo','resultMessage','retryButton',
    'homeButton','toast','swipeStage'
  ].map(id => [id, document.getElementById(id)]));

  let allQuestions = [];
  let selectedGrade = '3';
  let settings = loadJson(SETTINGS_KEY, { sound: true, grade: '3' });
  let stats = loadJson(STORAGE_KEY, { questions: {}, total: 0, correct: 0, bestCombo: 0, bestScores: {} });
  let game = null;
  let dragStartX = null;
  let dragCurrentX = 0;
  let audioContext = null;

  function loadJson(key, fallback) {
    try {
      const value = localStorage.getItem(key);
      return value ? { ...fallback, ...JSON.parse(value) } : fallback;
    } catch {
      return fallback;
    }
  }

  function saveState() {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(stats));
    localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings));
  }

  function filteredQuestions() {
    if (selectedGrade === 'all') return allQuestions;
    return allQuestions.filter(q => String(q.grade) === selectedGrade);
  }

  function shuffle(items, random = Math.random) {
    const result = [...items];
    for (let i = result.length - 1; i > 0; i -= 1) {
      const j = Math.floor(random() * (i + 1));
      [result[i], result[j]] = [result[j], result[i]];
    }
    return result;
  }

  function seededRandom(seed) {
    let value = seed >>> 0;
    return () => {
      value += 0x6D2B79F5;
      let t = value;
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  function dailySeed() {
    const key = `${new Date().toLocaleDateString('sv-SE')}-${selectedGrade}`;
    return [...key].reduce((sum, char) => (sum * 31 + char.charCodeAt(0)) >>> 0, 2166136261);
  }

  function buildQuestionQueue(mode) {
    const pool = filteredQuestions();
    if (mode === 'daily') return shuffle(pool, seededRandom(dailySeed())).slice(0, 10);
    if (mode === 'weak') {
      const weighted = [...pool].sort((a, b) => weaknessScore(b) - weaknessScore(a));
      const practiced = weighted.filter(q => (stats.questions[q.id]?.attempts || 0) > 0);
      const unseen = shuffle(weighted.filter(q => !(stats.questions[q.id]?.attempts || 0)));
      return [...practiced.slice(0, 7), ...unseen.slice(0, Math.max(0, 10 - practiced.length))].slice(0, 10);
    }
    return shuffle(pool);
  }

  function weaknessScore(question) {
    const record = stats.questions[question.id];
    if (!record || !record.attempts) return 0;
    const errors = record.attempts - record.correct;
    return (errors / record.attempts) * 100 + Math.min(record.attempts, 10);
  }

  function startGame(mode) {
    const pool = filteredQuestions();
    if (!pool.length) {
      showToast('この級の問題がありません。');
      return;
    }

    stopTimer();
    game = {
      mode,
      queue: buildQuestionQueue(mode),
      index: 0,
      score: 0,
      combo: 0,
      bestCombo: 0,
      correct: 0,
      answered: 0,
      lives: 3,
      seconds: 60,
      locked: false,
      questionStartedAt: performance.now(),
      timerId: null,
      lastQuestionId: null,
    };

    showScreen('game');
    els.gameModeTitle.textContent = MODES[mode].label;
    if (mode === 'time') startTimer();
    updateStatus();
    showQuestion();
  }

  function nextQuestionFromEndlessQueue() {
    const pool = filteredQuestions();
    let candidate = pool[Math.floor(Math.random() * pool.length)];
    if (pool.length > 1) {
      let attempts = 0;
      while (candidate.id === game.lastQuestionId && attempts < 5) {
        candidate = pool[Math.floor(Math.random() * pool.length)];
        attempts += 1;
      }
    }
    return candidate;
  }

  function currentQuestion() {
    if (!game) return null;
    if (game.mode === 'score' || game.mode === 'time') {
      if (game.index >= game.queue.length) game.queue = shuffle(filteredQuestions());
      return game.queue[game.index] || nextQuestionFromEndlessQueue();
    }
    return game.queue[game.index] || null;
  }

  function showQuestion() {
    if (!game) return;
    const question = currentQuestion();
    if (!question) {
      finishGame();
      return;
    }

    game.locked = false;
    game.questionStartedAt = performance.now();
    game.lastQuestionId = question.id;
    els.feedbackPanel.classList.add('is-hidden');
    els.feedbackPanel.classList.remove('is-correct', 'is-wrong');
    els.questionCard.style.transform = '';
    els.questionCard.style.opacity = '1';
    els.questionCard.removeAttribute('data-direction');
    els.gradeBadge.textContent = `${question.grade}級`;
    els.categoryBadge.textContent = question.category;
    els.transactionText.textContent = question.transaction;
    els.accountText.textContent = question.account;
    els.debitButton.disabled = false;
    els.creditButton.disabled = false;
    updateProgress();
  }

  function answer(side) {
    if (!game || game.locked) return;
    const question = currentQuestion();
    if (!question) return;

    game.locked = true;
    const correct = side === question.correctSide;
    const elapsed = performance.now() - game.questionStartedAt;
    let points = 0;

    game.answered += 1;
    stats.total += 1;
    const record = stats.questions[question.id] || { attempts: 0, correct: 0, lastAnswered: null };
    record.attempts += 1;
    record.lastAnswered = new Date().toISOString();

    if (correct) {
      game.correct += 1;
      game.combo += 1;
      game.bestCombo = Math.max(game.bestCombo, game.combo);
      stats.correct += 1;
      stats.bestCombo = Math.max(stats.bestCombo, game.combo);
      record.correct += 1;
      points = 100 + Math.max(0, 50 - Math.floor(elapsed / 100)) + Math.min(game.combo, 20) * 5;
      game.score += points;
      playTone(true);
    } else {
      game.combo = 0;
      if (game.mode === 'score') game.lives -= 1;
      playTone(false);
    }

    stats.questions[question.id] = record;
    saveState();
    updateStatus();
    updateHomeStats();
    showFeedback(correct, points, question);

    els.debitButton.disabled = true;
    els.creditButton.disabled = true;

    if (game.mode === 'time') window.setTimeout(() => advanceAfterAnswer(), 520);
  }

  function showFeedback(correct, points, question) {
    els.feedbackPanel.classList.remove('is-hidden');
    els.feedbackPanel.classList.add(correct ? 'is-correct' : 'is-wrong');
    els.feedbackTitle.textContent = correct ? '正解' : '不正解';
    els.feedbackPoints.textContent = correct ? `+${points}` : '+0';
    els.feedbackText.textContent = question.explanation;
    els.journalEntry.textContent = question.journal;
    els.nextButton.textContent = shouldFinishNow() ? '結果を見る' : '次の問題';
    if (game.mode === 'time') els.nextButton.classList.add('is-hidden');
    else els.nextButton.classList.remove('is-hidden');
  }

  function shouldFinishNow() {
    if (!game) return true;
    if (game.mode === 'score') return game.lives <= 0;
    if (game.mode === 'weak' || game.mode === 'daily') return game.index + 1 >= game.queue.length;
    return false;
  }

  function advanceAfterAnswer() {
    if (!game) return;
    if (shouldFinishNow()) {
      finishGame();
      return;
    }
    game.index += 1;
    showQuestion();
  }

  function updateStatus() {
    if (!game) return;
    els.scoreValue.textContent = game.score.toLocaleString('ja-JP');
    els.comboValue.textContent = game.combo;
    if (game.mode === 'time') {
      els.limitLabel.textContent = '残り時間';
      els.limitValue.textContent = Math.max(0, game.seconds);
      els.limitUnit.textContent = '秒';
    } else if (game.mode === 'score') {
      els.limitLabel.textContent = 'ライフ';
      els.limitValue.textContent = `${'♥'.repeat(Math.max(0, game.lives))}${'·'.repeat(Math.max(0, 3 - game.lives))}`;
      els.limitUnit.textContent = '';
    } else {
      els.limitLabel.textContent = '問題';
      els.limitValue.textContent = `${Math.min(game.index + 1, game.queue.length)}/${game.queue.length}`;
      els.limitUnit.textContent = '';
    }
  }

  function updateProgress() {
    if (!game) return;
    let ratio = 0;
    if (game.mode === 'time') ratio = game.seconds / 60;
    else if (game.mode === 'score') ratio = Math.max(0, game.lives / 3);
    else ratio = game.index / game.queue.length;
    els.progressBar.style.width = `${Math.max(0, Math.min(1, ratio)) * 100}%`;
  }

  function startTimer() {
    game.timerId = window.setInterval(() => {
      if (!game || game.mode !== 'time') return;
      game.seconds -= 1;
      updateStatus();
      updateProgress();
      if (game.seconds <= 0) finishGame();
    }, 1000);
  }

  function stopTimer() {
    if (game?.timerId) window.clearInterval(game.timerId);
    if (game) game.timerId = null;
  }

  function finishGame() {
    if (!game) return;
    stopTimer();
    const snapshot = { ...game };
    const accuracy = snapshot.answered ? Math.round(snapshot.correct / snapshot.answered * 100) : 0;
    const bestKey = `${snapshot.mode}-${selectedGrade}`;
    const previousBest = stats.bestScores[bestKey] || 0;
    const isBest = snapshot.score > previousBest;
    if (isBest) stats.bestScores[bestKey] = snapshot.score;
    saveState();

    els.finalScore.textContent = snapshot.score.toLocaleString('ja-JP');
    els.correctCount.textContent = snapshot.correct;
    els.resultAccuracy.textContent = `${accuracy}%`;
    els.resultBestCombo.textContent = snapshot.bestCombo;
    els.resultLabel.textContent = isBest ? 'NEW BEST' : 'RESULT';
    els.resultTitle.textContent = MODES[snapshot.mode].label;
    els.resultMessage.textContent = resultMessage(accuracy, snapshot.bestCombo, isBest);
    showScreen('result');
  }

  function resultMessage(accuracy, combo, isBest) {
    if (isBest) return '自己ベストを更新しました。次は正答率を保ったまま、判断速度を上げましょう。';
    if (accuracy >= 90) return `正答率${accuracy}%、最大${combo}連続正解。安定しています。`;
    if (accuracy >= 70) return '基礎は固まっています。苦手出題で誤答した論点を反復しましょう。';
    return '左右の暗記ではなく、資産・負債・純資産・収益・費用の増減から判断しましょう。';
  }

  function showScreen(name) {
    els.homeScreen.classList.toggle('is-hidden', name !== 'home');
    els.gameScreen.classList.toggle('is-hidden', name !== 'game');
    els.resultScreen.classList.toggle('is-hidden', name !== 'result');
    els.backButton.classList.toggle('is-hidden', name === 'home');
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  function goHome() {
    stopTimer();
    game = null;
    showScreen('home');
    updateHomeStats();
    renderWeakCategories();
  }

  function updateHomeStats() {
    els.totalAnswers.textContent = stats.total || 0;
    els.accuracyRate.textContent = stats.total ? `${Math.round((stats.correct || 0) / stats.total * 100)}%` : '—';
    els.bestCombo.textContent = stats.bestCombo || 0;
    els.questionCountBadge.textContent = `${filteredQuestions().length}問収録`;
  }

  function renderWeakCategories() {
    const categoryMap = new Map();
    allQuestions.forEach(question => {
      const record = stats.questions[question.id];
      if (!record?.attempts) return;
      const current = categoryMap.get(question.category) || { attempts: 0, correct: 0 };
      current.attempts += record.attempts;
      current.correct += record.correct;
      categoryMap.set(question.category, current);
    });

    const rows = [...categoryMap.entries()]
      .map(([category, value]) => ({ category, ...value, rate: Math.round(value.correct / value.attempts * 100) }))
      .sort((a, b) => a.rate - b.rate)
      .slice(0, 5);

    if (!rows.length) {
      els.weakCategoryList.innerHTML = '<p class="empty-message">回答すると論点別の正答率が表示されます。</p>';
      return;
    }

    els.weakCategoryList.innerHTML = rows.map(row => `
      <div class="weak-row">
        <strong>${escapeHtml(row.category)}</strong>
        <span>${row.correct}/${row.attempts}問・${row.rate}%</span>
        <div class="weak-bar" aria-label="正答率${row.rate}%"><i style="width:${row.rate}%"></i></div>
      </div>
    `).join('');
  }

  function escapeHtml(value) {
    return String(value).replace(/[&<>'"]/g, char => ({ '&':'&amp;', '<':'&lt;', '>':'&gt;', "'":'&#39;', '"':'&quot;' }[char]));
  }

  function showToast(message) {
    els.toast.textContent = message;
    els.toast.classList.remove('is-hidden');
    window.clearTimeout(showToast.timer);
    showToast.timer = window.setTimeout(() => els.toast.classList.add('is-hidden'), 2200);
  }

  function playTone(correct) {
    if (!settings.sound) return;
    try {
      audioContext ||= new (window.AudioContext || window.webkitAudioContext)();
      const oscillator = audioContext.createOscillator();
      const gain = audioContext.createGain();
      oscillator.type = correct ? 'sine' : 'square';
      oscillator.frequency.value = correct ? 660 : 180;
      gain.gain.setValueAtTime(0.08, audioContext.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.001, audioContext.currentTime + (correct ? 0.12 : 0.18));
      oscillator.connect(gain).connect(audioContext.destination);
      oscillator.start();
      oscillator.stop(audioContext.currentTime + (correct ? 0.12 : 0.18));
    } catch {
      settings.sound = false;
    }
  }

  function setGrade(grade) {
    selectedGrade = grade;
    settings.grade = grade;
    document.querySelectorAll('.grade-button').forEach(button => button.classList.toggle('is-active', button.dataset.grade === grade));
    saveState();
    updateHomeStats();
  }

  function handlePointerDown(event) {
    if (!game || game.locked) return;
    dragStartX = event.clientX;
    dragCurrentX = 0;
    els.questionCard.setPointerCapture?.(event.pointerId);
    els.questionCard.classList.add('is-dragging');
  }

  function handlePointerMove(event) {
    if (dragStartX === null || !game || game.locked) return;
    dragCurrentX = event.clientX - dragStartX;
    const rotation = Math.max(-12, Math.min(12, dragCurrentX / 18));
    els.questionCard.style.transform = `translateX(${dragCurrentX}px) rotate(${rotation}deg)`;
    if (Math.abs(dragCurrentX) > 30) els.questionCard.dataset.direction = dragCurrentX < 0 ? 'debit' : 'credit';
    else els.questionCard.removeAttribute('data-direction');
  }

  function handlePointerUp() {
    if (dragStartX === null || !game || game.locked) return;
    const distance = dragCurrentX;
    dragStartX = null;
    dragCurrentX = 0;
    els.questionCard.classList.remove('is-dragging');
    els.questionCard.style.transform = '';
    els.questionCard.removeAttribute('data-direction');
    if (distance <= -72) answer('debit');
    else if (distance >= 72) answer('credit');
  }

  function bindEvents() {
    document.querySelectorAll('.grade-button').forEach(button => button.addEventListener('click', () => setGrade(button.dataset.grade)));
    document.querySelectorAll('.mode-card').forEach(button => button.addEventListener('click', () => startGame(button.dataset.mode)));
    els.debitButton.addEventListener('click', () => answer('debit'));
    els.creditButton.addEventListener('click', () => answer('credit'));
    els.nextButton.addEventListener('click', advanceAfterAnswer);
    els.backButton.addEventListener('click', goHome);
    els.homeButton.addEventListener('click', goHome);
    els.retryButton.addEventListener('click', () => game && startGame(game.mode));
    els.soundButton.addEventListener('click', () => {
      settings.sound = !settings.sound;
      els.soundButton.setAttribute('aria-pressed', String(settings.sound));
      els.soundButton.textContent = settings.sound ? '♪' : '×';
      saveState();
      showToast(settings.sound ? '効果音をオンにしました。' : '効果音をオフにしました。');
    });
    els.resetStatsButton.addEventListener('click', () => {
      if (!window.confirm('回答履歴と自己ベストを削除しますか？')) return;
      stats = { questions: {}, total: 0, correct: 0, bestCombo: 0, bestScores: {} };
      saveState();
      updateHomeStats();
      renderWeakCategories();
      showToast('学習記録をリセットしました。');
    });
    els.questionCard.addEventListener('pointerdown', handlePointerDown);
    els.questionCard.addEventListener('pointermove', handlePointerMove);
    els.questionCard.addEventListener('pointerup', handlePointerUp);
    els.questionCard.addEventListener('pointercancel', handlePointerUp);
    window.addEventListener('keydown', event => {
      if (els.gameScreen.classList.contains('is-hidden')) return;
      if (event.key === 'ArrowLeft') answer('debit');
      if (event.key === 'ArrowRight') answer('credit');
      if ((event.key === 'Enter' || event.key === ' ') && !els.feedbackPanel.classList.contains('is-hidden')) advanceAfterAnswer();
    });
  }

  async function initialize() {
    bindEvents();
    selectedGrade = ['2','3','all'].includes(settings.grade) ? settings.grade : '3';
    setGrade(selectedGrade);
    els.soundButton.setAttribute('aria-pressed', String(settings.sound));
    els.soundButton.textContent = settings.sound ? '♪' : '×';

    try {
      const response = await fetch('data/questions.json', { cache: 'no-store' });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const payload = await response.json();
      allQuestions = (payload.transactions || []).flatMap((row, index) => [
        { id: `q${String(index * 2 + 1).padStart(3, '0')}`, grade: row.g, category: row.c, transaction: row.t, account: row.d, correctSide: 'debit', explanation: row.de, journal: row.j },
        { id: `q${String(index * 2 + 2).padStart(3, '0')}`, grade: row.g, category: row.c, transaction: row.t, account: row.k, correctSide: 'credit', explanation: row.ce, journal: row.j },
      ]);
      updateHomeStats();
      renderWeakCategories();
    } catch (error) {
      console.error(error);
      els.questionCountBadge.textContent = '読込失敗';
      showToast('問題データを読み込めませんでした。再読み込みしてください。');
    }

    if ('serviceWorker' in navigator) window.addEventListener('load', () => navigator.serviceWorker.register('sw.js').catch(() => {}));
  }

  initialize();
})();
