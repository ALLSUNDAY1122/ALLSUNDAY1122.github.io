(() => {
  'use strict';

  const DATA_URL = '../content-loop/questions.generated.json';
  const STORAGE_KEY = 'shoshi-learning-sprint-v1';
  const SUBJECT_ORDER = ['憲法','民法','刑法','商法・会社法','民事訴訟法','民事保全法','民事執行法','司法書士法','供託法','不動産登記法','商業登記法'];
  const YEAR_LABEL = {2023:'令和5', 2024:'令和6', 2025:'令和7'};
  const FONT_SCALE = {small:0.94, medium:1, large:1.12};

  const $ = (id) => document.getElementById(id);
  const els = {};
  let questions = [];
  let currentView = 'home';
  let quiz = null;

  const defaultState = () => ({
    version: 1,
    attempts: {},
    dailyGoal: 8,
    fontSize: 'medium',
    examDate: '',
    activeYear: 2025,
    studyDays: {}
  });

  let state = loadState();

  function cacheEls() {
    [
      'main','topHeader','headerHome','bottomNav','homeView','mockView','recordView','settingsView','quizView','resultView','errorView',
      'progressRing','progressRingText','dailyHeadline','dailyMeta','startDaily','dailyGoalLabel','examPaceCard','daysLeft','paceText','yearTabs','subjectGrid',
      'mockGrid','accuracyDonut','accuracyText','attemptCount','correctCount','subjectBars','heatmap','weakList',
      'fontSizeControl','goalControl','examDate','exportData','importData','clearData','offlineStatus',
      'quizCounter','quizSource','sectionPreamble','questionTopic','questionText','answerChoices','gradingMark','feedbackCard','feedbackTitle','feedbackExplanation','memoryLine','sourceDetailsText','nextQuestion',
      'resultTitle','resultScore','resultMessage','backHome','errorMessage','retryLoad'
    ].forEach(id => { els[id] = $(id); });
  }

  function loadState() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) return defaultState();
      const parsed = JSON.parse(raw);
      return {...defaultState(), ...parsed, attempts: parsed.attempts || {}, studyDays: parsed.studyDays || {}};
    } catch (_) {
      return defaultState();
    }
  }

  function saveState() {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  }

  function todayKey(date = new Date()) {
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, '0');
    const d = String(date.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  }

  function getStat(id) {
    return state.attempts[id] || {attempts:0, correct:0, wrong:0, consecutiveCorrect:0, weak:false, lastAnsweredAt:null};
  }

  function setStat(id, value) {
    state.attempts[id] = value;
  }

  function shuffle(items) {
    const out = [...items];
    for (let i = out.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [out[i], out[j]] = [out[j], out[i]];
    }
    return out;
  }

  async function loadQuestions() {
    try {
      const res = await fetch(DATA_URL, {cache:'no-cache'});
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      if (!Array.isArray(data) || data.length !== 210) throw new Error(`問題数が210ではありません（${Array.isArray(data) ? data.length : 'invalid'}）`);
      const ids = new Set(data.map(q => q.id));
      if (ids.size !== 210) throw new Error('問題IDに重複があります');
      questions = data;
      state.activeYear = data.some(q => q.source_year === Number(state.activeYear)) ? Number(state.activeYear) : Math.max(...data.map(q => q.source_year));
      saveState();
      renderAll();
      showView('home');
    } catch (err) {
      els.errorMessage.textContent = `${err.message}。通信状態を確認して再度お試しください。`;
      showView('error');
    }
  }

  function showView(name) {
    currentView = name;
    document.querySelectorAll('.view').forEach(v => v.classList.toggle('active', v.dataset.view === name));
    const inFlow = name === 'quiz' || name === 'result' || name === 'error';
    els.bottomNav.classList.toggle('hidden', inFlow);
    els.headerHome.classList.toggle('hidden', !inFlow);
    document.querySelectorAll('#bottomNav button').forEach(b => b.classList.toggle('active', b.dataset.nav === name));
    if (name === 'home') renderHome();
    if (name === 'mock') renderMock();
    if (name === 'record') renderRecord();
    if (name === 'settings') renderSettings();
    window.scrollTo({top:0, behavior:'instant'});
    els.main.focus({preventScroll:true});
  }

  function renderAll() {
    applyFontSize();
    renderHome();
    renderMock();
    renderRecord();
    renderSettings();
  }

  function renderHome() {
    if (!questions.length) return;
    const today = state.studyDays[todayKey()] || 0;
    const pct = Math.min(100, Math.round((today / state.dailyGoal) * 100));
    els.progressRing.style.background = `conic-gradient(var(--vermilion) ${pct * 3.6}deg,#e5dfd2 0deg)`;
    els.progressRingText.textContent = `${pct}%`;
    els.progressRing.setAttribute('aria-label', `今日の進捗 ${pct}パーセント`);
    els.dailyGoalLabel.textContent = `${state.dailyGoal}問`;
    els.dailyHeadline.textContent = today >= state.dailyGoal ? '今日の目標、達成。' : `${state.dailyGoal}問だけ、積み上げる。`;
    els.dailyMeta.textContent = today ? `今日は${today}問回答済み。出題当時の基準で続けます。` : '210問を出題当時の基準で正確に周回します。';

    renderExamPace();
    renderYearTabs();
    renderSubjectGrid();
  }

  function renderExamPace() {
    if (!state.examDate) {
      els.examPaceCard.classList.add('hidden');
      return;
    }
    const end = new Date(`${state.examDate}T00:00:00`);
    const now = new Date();
    now.setHours(0,0,0,0);
    const days = Math.ceil((end - now) / 86400000);
    if (!Number.isFinite(days) || days < 0) {
      els.examPaceCard.classList.add('hidden');
      return;
    }
    const unanswered = questions.filter(q => getStat(q.id).attempts === 0).length;
    const pace = days > 0 ? Math.max(1, Math.ceil(unanswered / days)) : unanswered;
    els.daysLeft.textContent = days === 0 ? '今日' : `${days}日`;
    els.paceText.textContent = unanswered === 0 ? '210問すべてに回答済みです。' : `未回答${unanswered}問。1日${pace}問で一巡できます。`;
    els.examPaceCard.classList.remove('hidden');
  }

  function renderYearTabs() {
    const years = [...new Set(questions.map(q => q.source_year))].sort((a,b) => b-a);
    els.yearTabs.replaceChildren(...years.map(year => {
      const b = document.createElement('button');
      b.type = 'button';
      b.textContent = YEAR_LABEL[year] || year;
      b.className = Number(state.activeYear) === year ? 'active' : '';
      b.setAttribute('role','tab');
      b.setAttribute('aria-selected', Number(state.activeYear) === year ? 'true' : 'false');
      b.addEventListener('click', () => { state.activeYear = year; saveState(); renderYearTabs(); renderSubjectGrid(); });
      return b;
    }));
  }

  function categoryStats(list) {
    const stats = list.map(q => getStat(q.id));
    const answered = stats.filter(s => s.attempts > 0).length;
    const completionCount = stats.length ? Math.min(...stats.map(s => s.attempts)) : 0;
    const totalAttempts = stats.reduce((n,s) => n + s.attempts, 0);
    const correct = stats.reduce((n,s) => n + s.correct, 0);
    const accuracy = totalAttempts ? Math.round(correct / totalAttempts * 100) : null;
    return {answered, completionCount, totalAttempts, accuracy};
  }

  function renderSubjectGrid() {
    const year = Number(state.activeYear);
    els.subjectGrid.replaceChildren(...SUBJECT_ORDER.map(subject => {
      const list = questions.filter(q => q.source_year === year && q.subject === subject);
      if (!list.length) return document.createDocumentFragment();
      const st = categoryStats(list);
      const b = document.createElement('button');
      b.type = 'button';
      b.className = 'subject-card';
      b.setAttribute('aria-label', `${YEAR_LABEL[year]}年度 ${subject} ${list.length}問`);
      const strong = document.createElement('strong'); strong.textContent = subject;
      const stats = document.createElement('div'); stats.className = 'stats';
      const answered = document.createElement('span'); answered.textContent = `${st.answered}/${list.length}回答`;
      const completion = document.createElement('span'); completion.className = 'completion'; completion.textContent = `完答${st.completionCount}回`;
      const accuracy = document.createElement('span'); accuracy.textContent = st.accuracy === null ? '正答率—' : `正答率${st.accuracy}%`;
      stats.append(answered, completion, accuracy);
      b.append(strong, stats);
      b.addEventListener('click', () => startQuiz(shuffle(list), `${YEAR_LABEL[year]}・${subject}`));
      return b;
    }));
  }

  function pickDailyQuestions(count) {
    const ranked = questions.map(q => {
      const s = getStat(q.id);
      const rank = s.weak ? 0 : s.attempts === 0 ? 1 : 2;
      return {q, rank, rnd:Math.random()};
    }).sort((a,b) => a.rank - b.rank || a.rnd - b.rnd);
    return ranked.slice(0, Math.min(count, ranked.length)).map(x => x.q);
  }

  function renderMock() {
    if (!questions.length) return;
    const cards = [];
    [...new Set(questions.map(q => q.source_year))].sort((a,b) => b-a).forEach(year => {
      ['AM','PM'].forEach(session => {
        const list = questions.filter(q => q.source_year === year && q.session === session).sort((a,b) => a.source_question_no - b.source_question_no);
        const st = categoryStats(list);
        const b = document.createElement('button');
        b.type = 'button'; b.className = 'mock-card';
        const copy = document.createElement('div');
        const title = document.createElement('strong'); title.textContent = `${YEAR_LABEL[year]}年度 ${session === 'AM' ? '午前' : '午後'}`;
        const stats = document.createElement('div'); stats.className = 'stats'; stats.textContent = `35問・完答${st.completionCount}回${st.accuracy === null ? '' : `・正答率${st.accuracy}%`}`;
        copy.append(title, stats);
        const badge = document.createElement('span'); badge.className = 'session-badge'; badge.textContent = session === 'AM' ? '午前35' : '午後35';
        b.append(copy, badge);
        b.addEventListener('click', () => startQuiz(list, `${YEAR_LABEL[year]}年度 ${session === 'AM' ? '午前' : '午後'}模試`));
        cards.push(b);
      });
    });
    els.mockGrid.replaceChildren(...cards);
  }

  function startQuiz(list, label) {
    if (!list.length) return;
    quiz = {items:list, index:0, correct:0, label, answered:false};
    showView('quiz');
    renderQuestion();
  }

  function renderQuestion() {
    const q = quiz.items[quiz.index];
    quiz.answered = false;
    els.quizCounter.textContent = `${quiz.index + 1} / ${quiz.items.length}`;
    els.quizSource.textContent = `${YEAR_LABEL[q.source_year]} ${q.session === 'AM' ? '午前' : '午後'}${q.source_question_no}`;
    els.questionTopic.textContent = `${q.subject}｜${q.topic || '過去問'}`;
    els.questionText.textContent = q.question;
    if (q.section_preamble) {
      els.sectionPreamble.textContent = q.section_preamble;
      els.sectionPreamble.classList.remove('hidden');
    } else {
      els.sectionPreamble.textContent = '';
      els.sectionPreamble.classList.add('hidden');
    }
    els.feedbackCard.classList.add('hidden');
    els.gradingMark.classList.add('hidden');
    els.gradingMark.textContent = '';
    els.answerChoices.replaceChildren(...[1,2,3,4,5].map(n => {
      const b = document.createElement('button');
      b.type = 'button'; b.className = 'answer-choice'; b.textContent = String(n); b.setAttribute('aria-label', `選択肢${n}`);
      b.addEventListener('click', () => submitAnswer(n, b));
      return b;
    }));
  }

  function submitAnswer(choice, button) {
    if (quiz.answered) return;
    quiz.answered = true;
    const q = quiz.items[quiz.index];
    const allCorrect = q.scoring_status === 'all_correct';
    const isCorrect = allCorrect || Number(q.official_answer_no) === choice;
    if (isCorrect) quiz.correct += 1;

    document.querySelectorAll('.answer-choice').forEach(b => { b.disabled = true; });
    button.classList.add('selected');
    updateLearningState(q, isCorrect);

    els.gradingMark.textContent = isCorrect ? '○' : '×';
    els.gradingMark.classList.remove('hidden');
    if (allCorrect) {
      els.feedbackTitle.textContent = '公式の全員正答問題';
      els.feedbackExplanation.textContent = q.short_explanation || '法務省の公式採点上、全員正答として扱われた問題です。';
    } else if (isCorrect) {
      els.feedbackTitle.textContent = `正解。公式正答は${q.official_answer_no}。`;
      els.feedbackExplanation.textContent = q.short_explanation || '出題年度の公式正答に一致しました。';
    } else {
      els.feedbackTitle.textContent = `不正解。公式正答は${q.official_answer_no}。`;
      els.feedbackExplanation.textContent = q.short_explanation || '出題年度の公式正答を確認してください。';
    }
    els.memoryLine.textContent = q.memory_line || `${q.topic || q.subject}：公式正答を確認する。`;
    els.sourceDetailsText.textContent = `${q.primary_basis || '法務省公式問題・正答'}／法令基準日 ${q.law_baseline || '—'}／状態 ${q.current_law_status || 'historical'}。法務省公開問題をアプリ向けに整形して表示。`;
    els.nextQuestion.textContent = quiz.index === quiz.items.length - 1 ? '結果を見る' : '次の問題';
    els.feedbackCard.classList.remove('hidden');
    els.feedbackCard.scrollIntoView({behavior:'smooth', block:'nearest'});
  }

  function updateLearningState(q, isCorrect) {
    const prev = getStat(q.id);
    const next = {...prev};
    next.attempts += 1;
    next.lastAnsweredAt = new Date().toISOString();
    if (isCorrect) {
      next.correct += 1;
      next.consecutiveCorrect += 1;
      if (next.consecutiveCorrect >= 3) next.weak = false;
    } else {
      next.wrong += 1;
      next.consecutiveCorrect = 0;
      next.weak = true;
    }
    setStat(q.id, next);
    const key = todayKey();
    state.studyDays[key] = (state.studyDays[key] || 0) + 1;
    saveState();
  }

  function finishQuiz() {
    const total = quiz.items.length;
    const score = quiz.correct;
    els.resultTitle.textContent = `${total}問、完了。`;
    els.resultScore.textContent = `${score} / ${total}`;
    const pct = Math.round(score / total * 100);
    els.resultMessage.textContent = pct >= 80 ? '精度を保てています。3連続正解した苦手問題は自動で苦手から外れます。' : pct >= 60 ? '間違えた問題を苦手として残しました。次の8問で優先的に出題します。' : '正答率より、誤答を次の周回につなげることを優先します。';
    quiz = null;
    showView('result');
  }

  function renderRecord() {
    if (!questions.length) return;
    const stats = Object.values(state.attempts);
    const attempts = stats.reduce((n,s) => n + (s.attempts || 0), 0);
    const correct = stats.reduce((n,s) => n + (s.correct || 0), 0);
    const accuracy = attempts ? Math.round(correct / attempts * 100) : 0;
    els.attemptCount.textContent = `${attempts}問`;
    els.correctCount.textContent = `正解 ${correct}問`;
    els.accuracyText.textContent = attempts ? `${accuracy}%` : '—';
    els.accuracyDonut.style.background = `conic-gradient(var(--green) ${accuracy * 3.6}deg,#e4dfd4 0deg)`;

    els.subjectBars.replaceChildren(...SUBJECT_ORDER.map(subject => {
      const list = questions.filter(q => q.subject === subject);
      const subjectStats = list.map(q => getStat(q.id));
      const a = subjectStats.reduce((n,s) => n + s.attempts, 0);
      const c = subjectStats.reduce((n,s) => n + s.correct, 0);
      const pct = a ? Math.round(c / a * 100) : 0;
      const row = document.createElement('div'); row.className = 'bar-row';
      const label = document.createElement('span'); label.textContent = subject;
      const track = document.createElement('div'); track.className = 'bar-track';
      const fill = document.createElement('div'); fill.className = 'bar-fill'; fill.style.width = `${pct}%`; track.append(fill);
      const value = document.createElement('span'); value.textContent = a ? `${pct}%` : '—';
      row.append(label, track, value); return row;
    }));

    const cells = [];
    for (let i = 34; i >= 0; i--) {
      const d = new Date(); d.setHours(12,0,0,0); d.setDate(d.getDate() - i);
      const count = state.studyDays[todayKey(d)] || 0;
      const cell = document.createElement('div');
      const level = count === 0 ? 0 : count <= 4 ? 1 : count <= 8 ? 2 : count <= 16 ? 3 : 4;
      cell.className = `heat-cell${level ? ` lv${level}` : ''}`;
      cell.title = `${todayKey(d)}：${count}問`;
      cell.setAttribute('aria-label', `${todayKey(d)} ${count}問`);
      cells.push(cell);
    }
    els.heatmap.replaceChildren(...cells);

    const weak = questions.filter(q => getStat(q.id).weak).sort((a,b) => {
      const sa = getStat(a.id), sb = getStat(b.id);
      return (sb.wrong - sa.wrong) || String(sb.lastAnsweredAt || '').localeCompare(String(sa.lastAnsweredAt || ''));
    });
    if (!weak.length) {
      const empty = document.createElement('p'); empty.className = 'muted'; empty.textContent = '苦手問題はまだありません。誤答した問題がここに残ります。';
      els.weakList.replaceChildren(empty);
    } else {
      els.weakList.replaceChildren(...weak.slice(0,12).map(q => {
        const item = document.createElement('button'); item.type = 'button'; item.className = 'weak-item';
        const s = getStat(q.id); item.textContent = `${YEAR_LABEL[q.source_year]} ${q.session === 'AM' ? '午前' : '午後'}${q.source_question_no}｜${q.topic}（連続正解${s.consecutiveCorrect}/3）`;
        item.addEventListener('click', () => startQuiz([q], '苦手1問'));
        return item;
      }));
    }
  }

  function renderSettings() {
    applyFontSize();
    els.examDate.value = state.examDate || '';
    document.querySelectorAll('[data-font]').forEach(b => b.classList.toggle('active', b.dataset.font === state.fontSize));
    document.querySelectorAll('[data-goal]').forEach(b => b.classList.toggle('active', Number(b.dataset.goal) === Number(state.dailyGoal)));
  }

  function applyFontSize() {
    document.documentElement.style.setProperty('--font-scale', FONT_SCALE[state.fontSize] || 1);
  }

  function exportData() {
    const payload = {app:'司法書士試験・択一式｜学びスプリント', exportedAt:new Date().toISOString(), state};
    const blob = new Blob([JSON.stringify(payload,null,2)], {type:'application/json'});
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob); a.download = `shoshi-sprint-${todayKey()}.json`; a.click();
    setTimeout(() => URL.revokeObjectURL(a.href), 1000);
  }

  async function importData(file) {
    if (!file) return;
    try {
      const parsed = JSON.parse(await file.text());
      const incoming = parsed.state || parsed;
      if (!incoming || typeof incoming !== 'object' || !incoming.attempts) throw new Error('学習データ形式ではありません');
      state = {...defaultState(), ...incoming, attempts:incoming.attempts || {}, studyDays:incoming.studyDays || {}};
      saveState(); renderAll(); showView('home');
    } catch (err) {
      alert(`読み込みに失敗しました：${err.message}`);
    } finally {
      els.importData.value = '';
    }
  }

  function bindEvents() {
    els.startDaily.addEventListener('click', () => startQuiz(pickDailyQuestions(state.dailyGoal), `今日の${state.dailyGoal}問`));
    els.nextQuestion.addEventListener('click', () => {
      if (!quiz || !quiz.answered) return;
      if (quiz.index >= quiz.items.length - 1) finishQuiz();
      else { quiz.index += 1; renderQuestion(); window.scrollTo({top:0, behavior:'smooth'}); }
    });
    els.backHome.addEventListener('click', () => showView('home'));
    els.headerHome.addEventListener('click', () => { quiz = null; showView('home'); });
    els.retryLoad.addEventListener('click', loadQuestions);
    document.querySelectorAll('#bottomNav button').forEach(b => b.addEventListener('click', () => showView(b.dataset.nav)));
    document.querySelectorAll('[data-font]').forEach(b => b.addEventListener('click', () => { state.fontSize = b.dataset.font; saveState(); renderSettings(); }));
    document.querySelectorAll('[data-goal]').forEach(b => b.addEventListener('click', () => { state.dailyGoal = Number(b.dataset.goal); saveState(); renderSettings(); renderHome(); }));
    els.examDate.addEventListener('change', () => { state.examDate = els.examDate.value; saveState(); renderExamPace(); });
    els.exportData.addEventListener('click', exportData);
    els.importData.addEventListener('change', () => importData(els.importData.files[0]));
    els.clearData.addEventListener('click', () => {
      if (!confirm('学習履歴をすべて初期化しますか？設定も初期値に戻ります。')) return;
      state = defaultState(); saveState(); renderAll(); showView('home');
    });
    window.addEventListener('online', updateOfflineStatus);
    window.addEventListener('offline', updateOfflineStatus);
  }

  function updateOfflineStatus() {
    els.offlineStatus.textContent = navigator.onLine ? 'オンライン。初回読込後は画面と問題データを端末にキャッシュします。' : 'オフラインです。キャッシュ済みデータで学習を続けます。';
  }

  function setupServiceWorker() {
    if (!('serviceWorker' in navigator)) {
      els.offlineStatus.textContent = 'このブラウザではService Workerを利用できません。';
      return;
    }
    window.addEventListener('load', () => navigator.serviceWorker.register('./sw.js').catch(() => {
      els.offlineStatus.textContent = 'オフラインキャッシュの登録に失敗しました。オンラインでは利用できます。';
    }));
  }

  function init() {
    cacheEls();
    bindEvents();
    updateOfflineStatus();
    setupServiceWorker();
    renderSettings();
    loadQuestions();
  }

  document.addEventListener('DOMContentLoaded', init);
})();
