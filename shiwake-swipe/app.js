(() => {
  'use strict';

  const STORAGE_KEY = 'shiwakeSwipeStatsV1';
  const SETTINGS_KEY = 'shiwakeSwipeSettingsV1';
  const MODES = {
    score: { label: 'スコアアタック' },
    time: { label: 'タイムアタック' },
    weak: { label: '苦手出題' },
    daily: { label: 'デイリー10問' },
    unseen: { label: '未出題' },
  };
  const TRACK_LABELS = { '3': '3級', commercial: '2級 商業', industrial: '2級 工業', all: '全範囲' };
  const els = Object.fromEntries([
    'homeScreen','gameScreen','resultScreen','backButton','soundButton','totalAnswers','accuracyRate','bestCombo','streakDays',
    'questionCountBadge','weakCategoryList','resetStatsButton','gameModeTitle','scoreValue','comboValue','limitLabel','limitValue',
    'limitUnit','progressBar','gradeBadge','categoryBadge','transactionText','questionCard','accountText','debitButton','creditButton',
    'feedbackPanel','feedbackTitle','feedbackPoints','feedbackText','journalEntry','nextButton','resultLabel','resultTitle','finalScore',
    'correctCount','resultAccuracy','resultBestCombo','resultMessage','retryButton','homeButton','toast','swipeStage'
  ].map(id => [id, document.getElementById(id)]));

  let allQuestions = [];
  let selectedGrade = '3';
  let settings = loadJson(SETTINGS_KEY, { sound: true, grade: '3' });
  let stats = loadJson(STORAGE_KEY, { questions: {}, total: 0, correct: 0, bestCombo: 0, bestScores: {}, streak: 0, lastStudyDate: null });
  let game = null;
  let dragStartX = null;
  let dragCurrentX = 0;
  let audioContext = null;

  function loadJson(key, fallback) {
    try { const value = localStorage.getItem(key); return value ? { ...fallback, ...JSON.parse(value) } : fallback; }
    catch { return fallback; }
  }
  function saveState() {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(stats));
    localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings));
  }
  function localDate(date = new Date()) {
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, '0');
    const d = String(date.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  }
  function updateStreak() {
    const today = localDate();
    if (stats.lastStudyDate === today) return;
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    stats.streak = stats.lastStudyDate === localDate(yesterday) ? (stats.streak || 0) + 1 : 1;
    stats.lastStudyDate = today;
  }
  function filteredQuestions() {
    if (selectedGrade === 'all') return allQuestions;
    return allQuestions.filter(q => q.track === selectedGrade);
  }
  function shuffle(items, random = Math.random) {
    const result = [...items];
    for (let i = result.length - 1; i > 0; i--) { const j = Math.floor(random() * (i + 1)); [result[i], result[j]] = [result[j], result[i]]; }
    return result;
  }
  function seededRandom(seed) {
    let value = seed >>> 0;
    return () => { value += 0x6D2B79F5; let t = value; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
  }
  function dailySeed() {
    const key = `${localDate()}-${selectedGrade}`;
    return [...key].reduce((sum, char) => (sum * 31 + char.charCodeAt(0)) >>> 0, 2166136261);
  }
  function weaknessScore(question) {
    const record = stats.questions[question.id];
    if (!record?.attempts) return 0;
    return ((record.attempts - record.correct) / record.attempts) * 100 + Math.min(record.attempts, 10);
  }
  function buildQuestionQueue(mode) {
    const pool = filteredQuestions();
    if (mode === 'daily') return shuffle(pool, seededRandom(dailySeed())).slice(0, 10);
    if (mode === 'unseen') return shuffle(pool.filter(q => !(stats.questions[q.id]?.attempts || 0)));
    if (mode === 'weak') {
      const weighted = [...pool].sort((a, b) => weaknessScore(b) - weaknessScore(a));
      const practiced = weighted.filter(q => (stats.questions[q.id]?.attempts || 0) > 0);
      const unseen = shuffle(weighted.filter(q => !(stats.questions[q.id]?.attempts || 0)));
      return [...practiced.slice(0, 7), ...unseen.slice(0, Math.max(0, 10 - practiced.length))].slice(0, 10);
    }
    return shuffle(pool);
  }
  function startGame(mode) {
    const pool = filteredQuestions();
    if (!pool.length) return showToast('この範囲の問題がありません。');
    const queue = buildQuestionQueue(mode);
    if (mode === 'unseen' && !queue.length) return showToast('この範囲はすべて回答済みです。');
    stopTimer();
    game = { mode, queue, index: 0, score: 0, combo: 0, bestCombo: 0, correct: 0, answered: 0, lives: 3, seconds: 60, locked: false, questionStartedAt: performance.now(), timerId: null, lastQuestionId: null };
    showScreen('game');
    els.gameModeTitle.textContent = MODES[mode].label;
    if (mode === 'time') startTimer();
    updateStatus();
    showQuestion();
  }
  function currentQuestion() {
    if (!game) return null;
    if (game.mode === 'score' || game.mode === 'time') {
      if (game.index >= game.queue.length) game.queue = shuffle(filteredQuestions());
    }
    return game.queue[game.index] || null;
  }
  function showQuestion() {
    const question = currentQuestion();
    if (!question) return finishGame();
    game.locked = false;
    game.questionStartedAt = performance.now();
    game.lastQuestionId = question.id;
    els.feedbackPanel.classList.add('is-hidden');
    els.feedbackPanel.classList.remove('is-correct', 'is-wrong');
    els.questionCard.style.transform = '';
    els.questionCard.style.opacity = '1';
    els.questionCard.removeAttribute('data-direction');
    els.gradeBadge.textContent = TRACK_LABELS[question.track] || `${question.grade}級`;
    els.categoryBadge.textContent = question.category;
    els.transactionText.textContent = question.transaction;
    els.accountText.textContent = question.account;
    els.debitButton.disabled = false;
    els.creditButton.disabled = false;
    updateStatus();
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
    game.answered++;
    stats.total++;
    updateStreak();
    const record = stats.questions[question.id] || { attempts: 0, correct: 0, lastAnswered: null };
    record.attempts++;
    record.lastAnswered = new Date().toISOString();
    if (correct) {
      game.correct++; game.combo++; game.bestCombo = Math.max(game.bestCombo, game.combo); stats.correct++; stats.bestCombo = Math.max(stats.bestCombo, game.combo); record.correct++;
      points = 100 + Math.max(0, 50 - Math.floor(elapsed / 100)) + Math.min(game.combo, 20) * 5;
      game.score += points; playTone(true);
    } else { game.combo = 0; if (game.mode === 'score') game.lives--; playTone(false); }
    stats.questions[question.id] = record;
    saveState(); updateStatus(); updateHomeStats(); showFeedback(correct, points, question);
    els.debitButton.disabled = true; els.creditButton.disabled = true;
    if (game.mode === 'time') window.setTimeout(advanceAfterAnswer, 520);
  }
  function showFeedback(correct, points, question) {
    els.feedbackPanel.classList.remove('is-hidden');
    els.feedbackPanel.classList.add(correct ? 'is-correct' : 'is-wrong');
    els.feedbackTitle.textContent = correct ? '正解' : '不正解';
    els.feedbackPoints.textContent = correct ? `+${points}` : '+0';
    els.feedbackText.textContent = question.explanation;
    els.journalEntry.textContent = question.journal;
    els.nextButton.textContent = shouldFinishNow() ? '結果を見る' : '次の問題';
    els.nextButton.classList.toggle('is-hidden', game.mode === 'time');
  }
  function shouldFinishNow() {
    if (!game) return true;
    if (game.mode === 'score') return game.lives <= 0;
    if (['weak','daily','unseen'].includes(game.mode)) return game.index + 1 >= game.queue.length;
    return false;
  }
  function advanceAfterAnswer() {
    if (!game) return;
    if (shouldFinishNow()) return finishGame();
    game.index++;
    showQuestion();
  }
  function updateStatus() {
    if (!game) return;
    els.scoreValue.textContent = game.score.toLocaleString('ja-JP');
    els.comboValue.textContent = game.combo;
    if (game.mode === 'time') { els.limitLabel.textContent = '残り時間'; els.limitValue.textContent = Math.max(0, game.seconds); els.limitUnit.textContent = '秒'; }
    else if (game.mode === 'score') { els.limitLabel.textContent = 'ライフ'; els.limitValue.textContent = `${'♥'.repeat(Math.max(0, game.lives))}${'·'.repeat(Math.max(0, 3 - game.lives))}`; els.limitUnit.textContent = ''; }
    else { els.limitLabel.textContent = '問題'; els.limitValue.textContent = `${Math.min(game.index + 1, game.queue.length)}/${game.queue.length}`; els.limitUnit.textContent = ''; }
  }
  function updateProgress() {
    if (!game) return;
    let ratio = game.mode === 'time' ? game.seconds / 60 : game.mode === 'score' ? game.lives / 3 : game.index / Math.max(1, game.queue.length);
    els.progressBar.style.width = `${Math.max(0, Math.min(1, ratio)) * 100}%`;
  }
  function startTimer() {
    game.timerId = setInterval(() => { if (!game || game.mode !== 'time') return; game.seconds--; updateStatus(); updateProgress(); if (game.seconds <= 0) finishGame(); }, 1000);
  }
  function stopTimer() { if (game?.timerId) clearInterval(game.timerId); if (game) game.timerId = null; }
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
    els.finalScore.textContent = snapshot.score.toLocaleString('ja-JP'); els.correctCount.textContent = snapshot.correct; els.resultAccuracy.textContent = `${accuracy}%`; els.resultBestCombo.textContent = snapshot.bestCombo;
    els.resultLabel.textContent = isBest ? 'NEW BEST' : 'RESULT'; els.resultTitle.textContent = MODES[snapshot.mode].label;
    els.resultMessage.textContent = accuracy >= 90 ? `正答率${accuracy}%、最大${snapshot.bestCombo}連続正解。` : accuracy >= 70 ? '基礎は固まっています。苦手論点を反復しましょう。' : '勘定科目の増減から借方・貸方を判断しましょう。';
    showScreen('result');
  }
  function showScreen(name) {
    els.homeScreen.classList.toggle('is-hidden', name !== 'home'); els.gameScreen.classList.toggle('is-hidden', name !== 'game'); els.resultScreen.classList.toggle('is-hidden', name !== 'result'); els.backButton.classList.toggle('is-hidden', name === 'home'); window.scrollTo({ top: 0, behavior: 'smooth' });
  }
  function goHome() { stopTimer(); game = null; showScreen('home'); updateHomeStats(); renderWeakCategories(); }
  function updateHomeStats() {
    els.totalAnswers.textContent = stats.total || 0;
    els.accuracyRate.textContent = stats.total ? `${Math.round((stats.correct || 0) / stats.total * 100)}%` : '—';
    els.bestCombo.textContent = stats.bestCombo || 0;
    if (els.streakDays) els.streakDays.textContent = stats.streak || 0;
    els.questionCountBadge.textContent = `${filteredQuestions().length}問収録`;
  }
  function renderWeakCategories() {
    const map = new Map();
    filteredQuestions().forEach(q => { const r = stats.questions[q.id]; if (!r?.attempts) return; const v = map.get(q.category) || { attempts: 0, correct: 0 }; v.attempts += r.attempts; v.correct += r.correct; map.set(q.category, v); });
    const rows = [...map.entries()].map(([category,v]) => ({ category, ...v, rate: Math.round(v.correct / v.attempts * 100) })).sort((a,b) => a.rate - b.rate).slice(0,5);
    els.weakCategoryList.innerHTML = rows.length ? rows.map(r => `<div class="weak-row"><strong>${escapeHtml(r.category)}</strong><span>${r.correct}/${r.attempts}問・${r.rate}%</span><div class="weak-bar"><i style="width:${r.rate}%"></i></div></div>`).join('') : '<p class="empty-message">回答すると論点別の正答率が表示されます。</p>';
  }
  function escapeHtml(value) { return String(value).replace(/[&<>'"]/g, c => ({ '&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;' }[c])); }
  function showToast(message) { els.toast.textContent = message; els.toast.classList.remove('is-hidden'); clearTimeout(showToast.timer); showToast.timer = setTimeout(() => els.toast.classList.add('is-hidden'), 2400); }
  function playTone(correct) {
    if (!settings.sound) return;
    try { audioContext ||= new (window.AudioContext || window.webkitAudioContext)(); const o = audioContext.createOscillator(); const g = audioContext.createGain(); o.type = correct ? 'sine' : 'square'; o.frequency.value = correct ? 660 : 180; g.gain.setValueAtTime(0.08, audioContext.currentTime); g.gain.exponentialRampToValueAtTime(0.001, audioContext.currentTime + 0.15); o.connect(g).connect(audioContext.destination); o.start(); o.stop(audioContext.currentTime + 0.15); } catch { settings.sound = false; }
  }
  function setGrade(grade) { selectedGrade = grade; settings.grade = grade; document.querySelectorAll('.grade-button').forEach(b => b.classList.toggle('is-active', b.dataset.grade === grade)); saveState(); updateHomeStats(); renderWeakCategories(); }
  function handlePointerDown(e) { if (!game || game.locked) return; dragStartX = e.clientX; dragCurrentX = 0; els.questionCard.setPointerCapture?.(e.pointerId); els.questionCard.classList.add('is-dragging'); }
  function handlePointerMove(e) { if (dragStartX === null || !game || game.locked) return; dragCurrentX = e.clientX - dragStartX; els.questionCard.style.transform = `translateX(${dragCurrentX}px) rotate(${Math.max(-12, Math.min(12, dragCurrentX / 18))}deg)`; if (Math.abs(dragCurrentX) > 30) els.questionCard.dataset.direction = dragCurrentX < 0 ? 'debit' : 'credit'; else els.questionCard.removeAttribute('data-direction'); }
  function handlePointerUp() { if (dragStartX === null || !game || game.locked) return; const d = dragCurrentX; dragStartX = null; dragCurrentX = 0; els.questionCard.classList.remove('is-dragging'); els.questionCard.style.transform = ''; els.questionCard.removeAttribute('data-direction'); if (d <= -56) answer('debit'); else if (d >= 56) answer('credit'); }
  function bindEvents() {
    document.querySelectorAll('.grade-button').forEach(b => b.addEventListener('click', () => setGrade(b.dataset.grade)));
    document.querySelectorAll('.mode-card').forEach(b => b.addEventListener('click', () => startGame(b.dataset.mode)));
    els.debitButton.addEventListener('click', () => answer('debit')); els.creditButton.addEventListener('click', () => answer('credit')); els.nextButton.addEventListener('click', advanceAfterAnswer);
    els.backButton.addEventListener('click', goHome); els.homeButton.addEventListener('click', goHome); els.retryButton.addEventListener('click', () => game && startGame(game.mode));
    els.soundButton.addEventListener('click', () => { settings.sound = !settings.sound; els.soundButton.setAttribute('aria-pressed', String(settings.sound)); els.soundButton.textContent = settings.sound ? '♪' : '×'; saveState(); });
    els.resetStatsButton.addEventListener('click', () => { if (!confirm('回答履歴・連続学習日数・自己ベストを削除しますか？')) return; stats = { questions: {}, total: 0, correct: 0, bestCombo: 0, bestScores: {}, streak: 0, lastStudyDate: null }; saveState(); updateHomeStats(); renderWeakCategories(); showToast('学習記録をリセットしました。'); });
    els.questionCard.addEventListener('pointerdown', handlePointerDown); els.questionCard.addEventListener('pointermove', handlePointerMove); els.questionCard.addEventListener('pointerup', handlePointerUp); els.questionCard.addEventListener('pointercancel', handlePointerUp);
    window.addEventListener('keydown', e => { if (els.gameScreen.classList.contains('is-hidden')) return; if (e.key === 'ArrowLeft') answer('debit'); if (e.key === 'ArrowRight') answer('credit'); if ((e.key === 'Enter' || e.key === ' ') && !els.feedbackPanel.classList.contains('is-hidden')) advanceAfterAnswer(); });
  }
  async function initialize() {
    bindEvents(); selectedGrade = ['3','commercial','industrial','all'].includes(settings.grade) ? settings.grade : '3'; setGrade(selectedGrade); els.soundButton.setAttribute('aria-pressed', String(settings.sound)); els.soundButton.textContent = settings.sound ? '♪' : '×';
    try {
      const response = await fetch('data/questions.json', { cache: 'no-store' }); if (!response.ok) throw new Error(`HTTP ${response.status}`); const payload = await response.json();
      allQuestions = (payload.transactions || []).flatMap((row, index) => {
        const track = Number(row.g) === 3 ? '3' : row.s === 'industrial' ? 'industrial' : 'commercial';
        const prefix = track === '3' ? 'g3' : track === 'industrial' ? 'i2' : 'c2';
        return [
          { id: `${prefix}-${index}-d`, track, grade: row.g, category: row.c, transaction: row.t, account: row.d, correctSide: 'debit', explanation: row.de, journal: row.j },
          { id: `${prefix}-${index}-c`, track, grade: row.g, category: row.c, transaction: row.t, account: row.k, correctSide: 'credit', explanation: row.ce, journal: row.j }
        ];
      });
      updateHomeStats(); renderWeakCategories();
    } catch (error) { console.error(error); els.questionCountBadge.textContent = '読込失敗'; showToast('問題データを読み込めませんでした。'); }
    if ('serviceWorker' in navigator) window.addEventListener('load', () => navigator.serviceWorker.register('sw.js').catch(() => {}));
  }
  initialize();
})();