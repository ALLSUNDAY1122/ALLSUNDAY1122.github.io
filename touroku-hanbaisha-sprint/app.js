'use strict';
(function(){
const LS_KEY='manabiSprint.tourokuHanbaisha.v03';
const LEGACY_KEY='manabiSprint.tourokuHanbaisha.v02';
const SESSION_TODAY='today12';
const SESSION_CH1='chapter:第1章';
const SESSION_WEAK='weakreview';
const app=document.getElementById('app');
const byId=Object.fromEntries(QUESTIONS.map(q=>[q.id,q]));
let SESSION=null;
let VIEW='home';

function freshState(){return{version:3,weak:{},sessionCompletions:{},stats:{totalAnswered:0,totalCorrect:0,history:[]},settings:{fontSize:'normal'},seenIds:{},inProgress:null}}
function migrateLegacy(){
  let s=freshState();
  try{
    const old=JSON.parse(localStorage.getItem(LEGACY_KEY)||'null');
    if(old&&typeof old==='object'){
      s.sessionCompletions[SESSION_TODAY]=Number.isFinite(old.rounds)?old.rounds:0;
      if(Array.isArray(old.wrongIds)) old.wrongIds.forEach(id=>{if(byId[id])s.weak[id]={streak:0}});
    }
  }catch(e){}
  return s;
}
function isPlainObject(v){return !!v&&typeof v==='object'&&!Array.isArray(v)}
function loadState(){
  let s=null;
  try{s=JSON.parse(localStorage.getItem(LS_KEY)||'null')}catch(e){}
  if(!isPlainObject(s))s=migrateLegacy();
  if(!isPlainObject(s.weak))s.weak={};
  if(!isPlainObject(s.sessionCompletions))s.sessionCompletions={};
  if(!isPlainObject(s.stats))s.stats={totalAnswered:0,totalCorrect:0,history:[]};
  s.stats.totalAnswered=Number.isFinite(s.stats.totalAnswered)?Math.max(0,s.stats.totalAnswered):0;
  s.stats.totalCorrect=Number.isFinite(s.stats.totalCorrect)?Math.max(0,Math.min(s.stats.totalCorrect,s.stats.totalAnswered)):0;
  s.stats.history=Array.isArray(s.stats.history)?s.stats.history.filter(x=>isPlainObject(x)&&typeof x.title==='string'&&typeof x.date==='string'&&Number.isFinite(x.correct)&&Number.isFinite(x.total)).slice(0,30):[];
  if(!isPlainObject(s.settings))s.settings={fontSize:'normal'};
  if(!['normal','large','xlarge'].includes(s.settings.fontSize))s.settings.fontSize='normal';
  if(!isPlainObject(s.seenIds))s.seenIds={};
  if(!isPlainObject(s.inProgress)||!Array.isArray(s.inProgress.ids)||!s.inProgress.ids.length||!Number.isInteger(s.inProgress.idx)||s.inProgress.idx<0||s.inProgress.idx>=s.inProgress.ids.length||s.inProgress.ids.some(id=>!byId[id]))s.inProgress=null;
  return s;
}
function saveState(){try{localStorage.setItem(LS_KEY,JSON.stringify(STATE))}catch(e){}}
let STATE=loadState();

function esc(s){return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')}
function shuffle(arr){let a=arr.slice();for(let i=a.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[a[i],a[j]]=[a[j],a[i]]}return a}
function completionCount(key){return STATE.sessionCompletions[key]||0}
function weakList(){return QUESTIONS.filter(q=>STATE.weak[q.id]&&STATE.weak[q.id].streak<3)}
function applyFont(){document.documentElement.classList.remove('fs-large','fs-xlarge');if(STATE.settings.fontSize==='large')document.documentElement.classList.add('fs-large');if(STATE.settings.fontSize==='xlarge')document.documentElement.classList.add('fs-xlarge')}
function formatDate(iso){const d=new Date(iso);return `${d.getMonth()+1}/${d.getDate()} ${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}`}
function ring(count,accent='var(--ch1)'){const pct=Math.min(5,count)/5*100;return `<div class="ring" data-filled="${count>0?1:0}" style="--pct:${pct}%;--ch-accent:${accent}"><span>${count}</span></div>`}

function tabbar(active){return `<nav class="tabbar" aria-label="メインナビゲーション">
  <button data-tab="home" class="${active==='home'?'active':''}"><span class="ic">⌂</span>ホーム</button>
  <button data-tab="record" class="${active==='record'?'active':''}"><span class="ic">▥</span>学習記録</button>
  <button data-tab="settings" class="${active==='settings'?'active':''}"><span class="ic">⚙</span>設定</button>
</nav>`}
function bindTabs(){app.querySelectorAll('[data-tab]').forEach(b=>b.onclick=()=>go(b.dataset.tab))}
function go(screen){VIEW=screen;render();window.scrollTo(0,0)}

function render(){if(VIEW==='home')return renderHome();if(VIEW==='quiz')return renderQuiz();if(VIEW==='result')return renderResult();if(VIEW==='record')return renderRecord();if(VIEW==='settings')return renderSettings()}

function renderHome(){
  const weak=weakList().length;const ip=STATE.inProgress;
  let h=`<div class="home-top"><div class="brand-tag">登録販売者試験対策</div><div class="brand-title">登録販売者｜学びスプリント</div><p class="brand-sub">令和8年4月手引き準拠・第1章12問の価値検証版</p></div><div class="hero"><p class="hero-title">今日も1問、力に変える。</p></div>`;
  if(ip)h+=`<button class="resume-card" data-action="resume"><span class="resume-ic">▶</span><span class="resume-body"><span class="resume-label">前回の続きから始める</span><span class="resume-name">${esc(ip.title)}</span><span class="resume-meta">${Math.min(ip.idx+1,ip.ids.length)} / ${ip.ids.length}問目</span></span></button>`;
  h+=`<section class="section"><h2>クイック学習</h2>
    <button class="full-btn" data-action="today"><span class="emoji">⚡</span><span><span class="name">今日の12問</span><span class="meta">第1章12問をテンポよく一周・完走 ${completionCount(SESSION_TODAY)} 回</span></span></button>
    <button class="full-btn" data-action="weak"><span class="emoji">🔥</span><span><span class="name">苦手復習</span><span class="meta">${weak?`${weak}問を復習・3連続正解で弱点から解除`:'誤答・「わからない」が自動でここに集まります'}</span></span>${weak?`<span class="count-badge">${weak}問</span>`:''}</button>
  </section>`;
  h+=`<section class="section"><h2>章別で学ぶ</h2><div class="chapter-grid">
    <button class="chapter-card active" data-action="chapter1" style="--ch-accent:var(--ch1);--ch-soft:var(--ch1-soft)">${ring(completionCount(SESSION_CH1))}<span class="chapter-info"><span class="chapter-name">第1章<br>医薬品の基本</span><span class="chapter-meta">12問</span></span></button>
    <div class="chapter-card unavailable" style="--ch-accent:var(--ch2);--ch-soft:var(--ch2-soft)"><span class="chapter-info"><span class="chapter-name">第2章<br>人体と医薬品</span><span class="chapter-meta">本開発で追加</span></span></div>
    <div class="chapter-card unavailable" style="--ch-accent:var(--ch3);--ch-soft:var(--ch3-soft)"><span class="chapter-info"><span class="chapter-name">第3章<br>主な医薬品</span><span class="chapter-meta">本開発で追加</span></span></div>
    <div class="chapter-card unavailable" style="--ch-accent:var(--ch4);--ch-soft:var(--ch4-soft)"><span class="chapter-info"><span class="chapter-name">第4章<br>法規と制度</span><span class="chapter-meta">本開発で追加</span></span></div>
    <div class="chapter-card unavailable" style="--ch-accent:var(--ch5);--ch-soft:var(--ch5-soft)"><span class="chapter-info"><span class="chapter-name">第5章<br>適正使用と安全</span><span class="chapter-meta">本開発で追加</span></span></div>
  </div><p class="section-note">第2〜5章は未監査問題を表示せず、本開発工程で監査完了後に解放します。</p></section>`;
  h+=`<section class="section"><div class="settings-row"><div class="label">この版について</div><div class="settings-note">一般用医薬品の使用判断・診断を行うアプリではありません。学習用の独自問題を、厚生労働省「試験問題の作成に関する手引き」を基準に管理しています。</div></div></section>`;
  h+=tabbar('home');app.innerHTML=h;
  app.querySelector('[data-action="today"]').onclick=()=>startSession(SESSION_TODAY,shuffle(QUESTIONS),'今日の12問');
  app.querySelector('[data-action="chapter1"]').onclick=()=>startSession(SESSION_CH1,QUESTIONS.slice(),'第1章｜医薬品の基本');
  app.querySelector('[data-action="weak"]').onclick=()=>{const qs=weakList();if(!qs.length){alert('現在、弱点登録されている問題はありません。');return}startSession(SESSION_WEAK,shuffle(qs),'苦手復習')};
  const rb=app.querySelector('[data-action="resume"]');if(rb)rb.onclick=resumeSession;bindTabs();
}

function startSession(key,questions,title){if(!questions.length)return;SESSION={key,title,questions,index:0,correct:0,answeredCount:0,answered:false,selected:null,startedAt:Date.now()};saveProgress();go('quiz')}
function saveProgress(){if(!SESSION)return;STATE.inProgress={key:SESSION.key,title:SESSION.title,ids:SESSION.questions.map(q=>q.id),idx:SESSION.index,correct:SESSION.correct,answeredCount:SESSION.answeredCount,answered:SESSION.answered,selected:SESSION.selected,startedAt:SESSION.startedAt};saveState()}
function clearProgress(){STATE.inProgress=null;saveState()}
function resumeSession(){const ip=STATE.inProgress;if(!ip)return;const qs=ip.ids.map(id=>byId[id]);if(qs.some(q=>!q)||ip.idx<0||ip.idx>=qs.length){clearProgress();go('home');alert('前回の学習データを復元できませんでした。');return}SESSION={key:ip.key,title:ip.title,questions:qs,index:ip.idx,correct:ip.correct||0,answeredCount:ip.answeredCount||0,answered:!!ip.answered,selected:Number.isInteger(ip.selected)?ip.selected:null,startedAt:ip.startedAt||Date.now()};go('quiz')}

function renderQuiz(){
  const q=SESSION.questions[SESSION.index],total=SESSION.questions.length;
  let h=`<div class="header"><button class="quit" id="quitBtn">‹ 中断</button><h1>${esc(SESSION.title)}</h1><span class="quiz-counter">${SESSION.index+1} / ${total}</span></div><div class="quiz-wrap"><span class="quiz-tag">${esc(q.chapter)} ・ ${esc(q.topic)}</span><div class="qbar"><div style="width:${Math.round((SESSION.index/total)*100)}%"></div></div><div class="qtext">${esc(q.question)}</div>`;
  q.choices.forEach((c,i)=>{let cls='choice';if(SESSION.answered){if(i===q.answer)cls+=' correct';else if(i===SESSION.selected)cls+=' wrong'}h+=`<button class="${cls}" data-choice="${i}" ${SESSION.answered?'disabled':''}><span class="num">${i+1}</span><span>${esc(c)}</span></button>`});
  if(!SESSION.answered){h+=`<button class="dontknow-btn" id="dontknowBtn">わからない</button>`}else{
    const correct=SESSION.selected===q.answer,dk=SESSION.selected===-1;h+=`<div class="feedback ${correct?'ok':'ng'}"><div class="feedback-title ${correct?'ok':'ng'}">${dk?`正解は ${q.answer+1} でした`:correct?'正解！':`不正解。正解は ${q.answer+1} です`}</div><span class="learn-label">この問題で覚える一文</span><p class="feedback-point">${esc(q.point)}</p><details><summary>詳しい解説を見る</summary><p class="detail-text">${esc(q.detail)}</p></details></div><button class="next-btn" id="nextBtn">${SESSION.index+1<total?'次の問題へ':'結果を見る'}</button>`}
  h+='</div>';app.innerHTML=h;
  document.getElementById('quitBtn').onclick=()=>{saveProgress();go('home')};
  if(!SESSION.answered){app.querySelectorAll('[data-choice]').forEach(b=>b.onclick=()=>answerQuestion(Number(b.dataset.choice)));document.getElementById('dontknowBtn').onclick=()=>answerQuestion(-1)}else document.getElementById('nextBtn').onclick=nextQuestion;
}
function answerQuestion(choice){if(SESSION.answered)return;const q=SESSION.questions[SESSION.index],correct=choice===q.answer;SESSION.selected=choice;SESSION.answered=true;SESSION.answeredCount++;STATE.seenIds[q.id]=true;STATE.stats.totalAnswered++;if(correct){SESSION.correct++;STATE.stats.totalCorrect++;const w=STATE.weak[q.id];if(w){const streak=(w.streak||0)+1;if(streak>=3)delete STATE.weak[q.id];else STATE.weak[q.id]={streak}}}else STATE.weak[q.id]={streak:0};saveProgress();renderQuiz()}
function nextQuestion(){if(!SESSION.answered)return;if(SESSION.index+1<SESSION.questions.length){SESSION.index++;SESSION.answered=false;SESSION.selected=null;saveProgress();renderQuiz();window.scrollTo(0,0)}else finishSession()}
function finishSession(){const total=SESSION.questions.length,duration=Math.max(1,Math.round((Date.now()-SESSION.startedAt)/1000));clearProgress();STATE.sessionCompletions[SESSION.key]=(STATE.sessionCompletions[SESSION.key]||0)+1;STATE.stats.history.unshift({title:SESSION.title,date:new Date().toISOString(),correct:SESSION.correct,total,duration});STATE.stats.history=STATE.stats.history.slice(0,30);saveState();go('result')}

function renderResult(){const total=SESSION.questions.length,rate=Math.round(SESSION.correct/total*100);let h=`<div class="header"><h1>結果</h1></div><div class="result-card"><div class="result-big">${SESSION.correct} / ${total}</div><div class="result-label">${esc(SESSION.title)} 完走！</div><div class="result-detail"><div><div class="n">${rate}%</div><div class="l">正答率</div></div><div><div class="n">${weakList().length}</div><div class="l">現在の弱点数</div></div><div><div class="n">${completionCount(SESSION.key)}</div><div class="l">完走回数</div></div></div></div><div class="result-actions"><button class="next-btn" id="homeBtn">ホームに戻る</button>${weakList().length?'<button class="secondary-btn" id="weakBtn">苦手だけ復習</button>':''}</div>`;h+=tabbar('');app.innerHTML=h;document.getElementById('homeBtn').onclick=()=>go('home');const wb=document.getElementById('weakBtn');if(wb)wb.onclick=()=>startSession(SESSION_WEAK,shuffle(weakList()),'苦手復習');bindTabs()}

function renderRecord(){const rate=STATE.stats.totalAnswered?Math.round(STATE.stats.totalCorrect/STATE.stats.totalAnswered*100):0;let h=`<div class="header"><h1>学習記録</h1></div><section class="section"><div class="stat-row"><div class="stat-box"><div class="num">${STATE.stats.totalAnswered}</div><div class="lbl">総回答数</div></div><div class="stat-box"><div class="num">${STATE.stats.totalCorrect}</div><div class="lbl">総正解数</div></div><div class="stat-box"><div class="num">${rate}%</div><div class="lbl">正答率</div></div></div></section><section class="section"><h2>苦手問題（現在${weakList().length}問）</h2>`;
  if(weakList().length)h+=`<button class="full-btn" data-action="record-weak"><span class="emoji">🔥</span><span><span class="name">苦手復習を開始</span><span class="meta">3連続正解で弱点から解除</span></span><span class="count-badge">${weakList().length}問</span></button>`;else h+=`<div class="empty-note">現在、弱点登録されている問題はありません。</div>`;
  h+=`</section><section class="section"><h2>直近の学習履歴</h2>`;
  if(!STATE.stats.history.length)h+=`<div class="empty-note">まだ学習履歴がありません。</div>`;else STATE.stats.history.forEach(x=>{h+=`<div class="history-item"><span>${esc(x.title)}</span><span class="meta">${formatDate(x.date)} ・ ${x.correct}/${x.total}</span></div>`});
  h+=`</section>${tabbar('record')}`;app.innerHTML=h;const b=app.querySelector('[data-action="record-weak"]');if(b)b.onclick=()=>startSession(SESSION_WEAK,shuffle(weakList()),'苦手復習');bindTabs()}

function renderSettings(){let h=`<div class="header"><h1>設定</h1></div><section class="section"><div class="settings-row"><div class="label">文字サイズ</div><div class="seg">${[['normal','標準'],['large','大'],['xlarge','特大']].map(([k,l])=>`<button data-fs="${k}" class="${STATE.settings.fontSize===k?'active':''}">${l}</button>`).join('')}</div></div><div class="settings-row"><div class="label">教材基準</div><div class="settings-note">厚生労働省「試験問題の作成に関する手引き」令和8年4月一部改訂版を基準に管理しています。現在のSafari価値検証版は監査済み第1章12問のみを収録しています。</div></div><div class="settings-row"><div class="label">データについて</div><div class="settings-note">学習記録・弱点情報はこの端末内にのみ保存します。ログイン、広告、氏名・メールアドレス等の個人情報保存はありません。</div></div><div class="settings-row"><div class="label">学習記録のリセット</div><button class="danger-btn" id="resetBtn">すべての学習記録をリセット</button></div></section>${tabbar('settings')}`;app.innerHTML=h;app.querySelectorAll('[data-fs]').forEach(b=>b.onclick=()=>{STATE.settings.fontSize=b.dataset.fs;saveState();applyFont();renderSettings()});document.getElementById('resetBtn').onclick=()=>{if(confirm('本当にすべての学習記録をリセットしますか？')){try{localStorage.removeItem(LS_KEY);localStorage.removeItem(LEGACY_KEY)}catch(e){}STATE=freshState();applyFont();go('home')}};bindTabs()}

applyFont();render();
})();
