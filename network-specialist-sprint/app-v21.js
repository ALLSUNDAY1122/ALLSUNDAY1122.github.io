'use strict';
(function(){
const KEY='manabiSprint.networkSpecialist.v010',SCHEMA=1;
const app=document.getElementById('app');
const OCC=(window.NW_EXAM_OCCURRENCES||[]);
const UNIQUE_IDS=new Set(window.NW_UNIQUE_IDS||[]);
const BANK=OCC.filter(q=>UNIQUE_IDS.has(q.id));
const BY_ID=Object.fromEntries(OCC.map(q=>[q.id,q]));
const BANK_BY_ID=Object.fromEntries(BANK.map(q=>[q.id,q]));
const YEARS=[2025,2024,2023];
let VIEW='home',SESSION=null;

const todayKey=()=>{const d=new Date();return`${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`};
function fresh(){return{
  schemaVersion:SCHEMA,contentVersion:window.NW_CONTENT_VERSION||'nw-a2-v1',
  weak:{},seenIds:{},sessionCompletions:{},stats:{totalAnswered:0,totalCorrect:0,history:[]},
  answerLog:[],settings:{fontSize:'normal',dailyGoal:8,examDate:''},inProgress:null
}}
function load(){
  let s=null;try{s=JSON.parse(localStorage.getItem(KEY)||'null')}catch(e){}
  const f=fresh();if(!s||typeof s!=='object')s=f;
  s={...f,...s,settings:{...f.settings,...(s.settings||{})},stats:{...f.stats,...(s.stats||{})}};
  s.answerLog=Array.isArray(s.answerLog)?s.answerLog.slice(-4000):[];
  s.stats.history=Array.isArray(s.stats.history)?s.stats.history.slice(0,100):[];
  if(![4,8,16].includes(Number(s.settings.dailyGoal)))s.settings.dailyGoal=8;
  if(!['normal','large','xlarge'].includes(s.settings.fontSize))s.settings.fontSize='normal';
  if(!s.weak||typeof s.weak!=='object')s.weak={};
  if(!s.seenIds||typeof s.seenIds!=='object')s.seenIds={};
  if(!s.sessionCompletions||typeof s.sessionCompletions!=='object')s.sessionCompletions={};
  if(s.inProgress&&(!Array.isArray(s.inProgress.ids)||s.inProgress.ids.some(id=>!BY_ID[id]&&!BANK_BY_ID[id])))s.inProgress=null;
  return s
}
let STATE=load();
function save(){try{localStorage.setItem(KEY,JSON.stringify(STATE))}catch(e){}}
function esc(v){return String(v??'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;')}
function shuffle(a){a=a.slice();for(let i=a.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[a[i],a[j]]=[a[j],a[i]]}return a}
function applyFont(){document.documentElement.dataset.font=STATE.settings.fontSize}
function canonicalId(q){return q.canonicalConceptId||q.id}
function canonicalQuestion(q){return BANK_BY_ID[canonicalId(q)]||q}
function icon(name){const p={
 home:'M3 10.5 12 3l9 7.5V21h-6v-6H9v6H3z',
 mock:'M5 3h14v18H5z M8 7h8 M8 11h8 M8 15h5',
 history:'M4 19V9h4v10H4zm6 0V5h4v14h-4zm6 0v-7h4v7h-4z',
 settings:'M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8zm8.5 4a6.7 6.7 0 0 0-.1-1l2-1.6-2-3.4-2.5 1a8 8 0 0 0-1.8-1L15.7 3h-4l-.4 3a8 8 0 0 0-1.8 1L7 6 5 9.4 7 11a7 7 0 0 0 0 2l-2 1.6L7 18l2.5-1a8 8 0 0 0 1.8 1l.4 3h4l.4-3a8 8 0 0 0 1.8-1l2.5 1 2-3.4-2-1.6c.1-.3.1-.7.1-1z',
 bolt:'M13 2 4 14h7l-1 8 9-12h-7z',repeat:'M17 1l4 4-4 4V6H7a4 4 0 0 0-4 4H1a6 6 0 0 1 6-6h10V1z M7 23l-4-4 4-4v3h10a4 4 0 0 0 4-4h2a6 6 0 0 1-6 6H7v3z',
 arrow:'M5 12h14 M13 6l6 6-6 6'
};return`<svg class="svg-ic" viewBox="0 0 24 24" aria-hidden="true"><path d="${p[name]||p.arrow}"/></svg>`}
function tabbar(active){return`<nav class="nav" aria-label="メインナビゲーション">${[['home','ホーム'],['mock','模試'],['history','記録'],['settings','設定']].map(([k,l])=>`<button data-tab="${k}" class="${active===k?'active':''}">${icon(k)}<span>${l}</span></button>`).join('')}</nav>`}
function bindTabs(){app.querySelectorAll('[data-tab]').forEach(b=>b.onclick=()=>go(b.dataset.tab))}
function go(v){VIEW=v;render();scrollTo(0,0)}
function domains(){return [...new Set(BANK.map(q=>q.uiDomain||q.domain))].sort((a,b)=>a.localeCompare(b,'ja'))}
function domainQuestions(d){return BANK.filter(q=>(q.uiDomain||q.domain)===d)}
function weakList(){return BANK.filter(q=>STATE.weak[q.id]&&Number(STATE.weak[q.id].streak||0)<3)}
function completion(k){return Number(STATE.sessionCompletions[k]||0)}
function todayAnswered(){const k=todayKey();return STATE.answerLog.filter(x=>x.day===k).length}
function todayCorrect(){const k=todayKey();return STATE.answerLog.filter(x=>x.day===k&&x.correct).length}
function seenCount(){return Object.keys(STATE.seenIds).filter(id=>STATE.seenIds[id]).length}
function examInfo(){const s=STATE.settings.examDate;if(!s)return null;const end=new Date(`${s}T00:00:00`),now=new Date();const days=Math.ceil((end-new Date(now.getFullYear(),now.getMonth(),now.getDate()))/86400000);if(!Number.isFinite(days))return null;const unseen=Math.max(0,BANK.length-seenCount());return{days,pace:days>0?Math.max(1,Math.ceil(unseen/days)):0}}
function todayQuestions(){
  const n=Number(STATE.settings.dailyGoal)||8;
  const unseen=shuffle(BANK.filter(q=>!STATE.seenIds[q.id]));
  const weak=shuffle(weakList());
  const seen=shuffle(BANK.filter(q=>STATE.seenIds[q.id]&&!STATE.weak[q.id]));
  const out=[],ids=new Set();
  for(const pool of [unseen,weak,seen])for(const q of pool){if(out.length>=n)break;if(!ids.has(q.id)){ids.add(q.id);out.push(q)}}
  return out
}
function yearQuestions(y){return OCC.filter(q=>q.examYear===y).sort((a,b)=>a.questionNo-b.questionNo)}
function render(){applyFont();if(VIEW==='home')renderHome();else if(VIEW==='mock')renderMock();else if(VIEW==='history')renderHistory();else if(VIEW==='settings')renderSettings();else if(VIEW==='quiz')renderQuiz();else if(VIEW==='result')renderResult()}
function renderHome(){
 const done=todayAnswered(),goal=Number(STATE.settings.dailyGoal)||8,pct=Math.min(100,Math.round(done/goal*100)),weak=weakList().length,exam=examInfo(),ip=STATE.inProgress,total=STATE.stats.totalAnswered||0,acc=total?Math.round((STATE.stats.totalCorrect||0)/total*100):0;
 let h=`<div class="paper-grid"></div><header class="mast"><div class="eyebrow">学びスプリント</div><h1 class="title">ネットワークスペシャリスト</h1><p>科目A-2（旧午前II）を、短く深く。</p></header>`;
 if(exam)h+=`<section class="countdown"><div><span>試験まで</span><b class="dnum">${exam.days>=0?exam.days:'—'}</b><span>日</span></div><p>${exam.days>0?`未学習を進める目安：1日 ${exam.pace}問`:'試験日を迎えました'}</p></section>`;
 h+=`<section class="today-card"><div class="today-ring" style="--p:${pct*3.6}deg"><div><b>${done}</b><span>/ ${goal}</span></div></div><div class="today-copy"><span class="sig">今日の学習</span><strong>${done>=goal?'今日の目標を達成':'あと'+Math.max(0,goal-done)+'問'}</strong><small>正解 ${todayCorrect()}問・ユニーク ${BANK.length}問</small></div></section>`;
 if(ip)h+=`<button class="resume" data-resume><span>${icon('repeat')}</span><span><small>続きから再開</small><b>${esc(ip.title||'学習中')}</b><em>${Math.min((ip.index||0)+1,(ip.ids||[]).length)} / ${(ip.ids||[]).length}</em></span>${icon('arrow')}</button>`;
 h+=`<main class="home-main"><button class="primary-cta" data-start-today><span class="cta-ic">${icon('bolt')}</span><span><small>今日のスプリント</small><b>${goal}問を解く</b></span>${icon('arrow')}</button>
 <button class="weak-cta" data-weak><span>${icon('repeat')}</span><span><small>苦手をつぶす</small><b>${weak?weak+'問あります':'現在の苦手はありません'}</b></span><span class="weak-count">${weak}</span></button>
 <button class="mock-link" data-open-mock><span>${icon('mock')}</span><span><small>模擬試験</small><b>2025・2024・2023 各25問</b></span>${icon('arrow')}</button>
 <section class="block"><div class="section-head"><h2>分野から解く</h2><span>完答回数</span></div><div class="field-list">${domains().map(d=>`<button data-domain="${esc(d)}"><span><b>${esc(d)}</b><small>${domainQuestions(d).length}問</small></span><em>${completion('domain:'+d)}回</em>${icon('arrow')}</button>`).join('')}</div></section>
 <section class="block"><div class="section-head"><h2>これまで</h2></div><div class="three-stats"><div><b>${total}</b><span>回答</span></div><div><b>${acc}%</b><span>正答率</span></div><div><b>${weak}</b><span>苦手</span></div></div></section></main>${tabbar('home')}`;
 app.innerHTML=h;
 app.querySelector('[data-start-today]').onclick=()=>startSession('today',todayQuestions(),'今日のスプリント','practice');
 app.querySelector('[data-open-mock]').onclick=()=>go('mock');
 app.querySelector('[data-weak]').onclick=()=>{const q=weakList();if(q.length)startSession('weak',shuffle(q),'苦手をつぶす','practice')};
 app.querySelectorAll('[data-domain]').forEach(b=>b.onclick=()=>{const d=b.dataset.domain;startSession('domain:'+d,shuffle(domainQuestions(d)).slice(0,Number(STATE.settings.dailyGoal)||8),d,'practice')});
 const r=app.querySelector('[data-resume]');if(r)r.onclick=resume;bindTabs()
}
function renderMock(){
 let h=`<div class="paper-grid"></div><header class="subhead"><span>学びスプリント</span><h1>模擬試験</h1><p>IPA公開問題を基に改変した3回分。各25問を試験回単位で再現します。</p></header><main class="page-pad"><div class="notice">通常スプリントは重複を除いた68問。模試は実際の出題枠を再現するため、歴史的な再出題・類題を含む75出題枠を保持しています。</div>`;
 for(const y of YEARS){const qs=yearQuestions(y),key='exam:'+y;const hist=STATE.stats.history.find(x=>x.key===key);h+=`<section class="mock-round"><div class="mocktitle"><b>${y}年度 春期</b><span>午前II・25問</span></div><button class="mock-card" data-year="${y}"><span><b>${y}年度を解く</b><small>完答 ${completion(key)}回${hist?`・直近 ${hist.correct}/${hist.total}`:''}</small></span>${icon('arrow')}</button></section>`}
 h+=`</main>${tabbar('mock')}`;app.innerHTML=h;
 app.querySelectorAll('[data-year]').forEach(b=>{b.onclick=()=>{const y=Number(b.dataset.year);startSession('exam:'+y,yearQuestions(y),`${y}年度 春期 午前II`,'mock')}});
 bindTabs()
}
function answerStatsForDomain(d){const logs=STATE.answerLog.filter(x=>x.domain===d);const c=logs.filter(x=>x.correct).length;return{n:logs.length,p:logs.length?Math.round(c/logs.length*100):0}}
function renderHistory(){
 const total=STATE.stats.totalAnswered||0,correct=STATE.stats.totalCorrect||0,acc=total?Math.round(correct/total*100):0,seen=seenCount(),weak=weakList();
 const drows=domains().map(d=>{const s=answerStatsForDomain(d);return`<div class="bar-row"><div><b>${esc(d)}</b><span>${s.n?s.p+'%':'未回答'}</span></div><div class="bar"><i style="width:${s.p}%"></i></div></div>`}).join('');
 const days=[];for(let i=34;i>=0;i--){const d=new Date();d.setDate(d.getDate()-i);const k=`${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;const n=STATE.answerLog.filter(x=>x.day===k).length;days.push(n)}
 const heat=days.map(n=>`<i class="${n>=16?'lv4':n>=8?'lv3':n>=4?'lv2':n>=1?'lv1':''}" title="${n}問"></i>`).join('');
 let h=`<div class="paper-grid"></div><header class="subhead"><span>学びスプリント</span><h1>記録</h1><p>反復量と弱点の変化を、短く確認します。</p></header><main class="page-pad"><section class="record-top"><div class="donut" style="--p:${acc*3.6}deg"><div><b>${acc}%</b><span>正答率</span></div></div><div class="record-summary"><div><b>${total}</b><span>回答</span></div><div><b>${seen}</b><span>既習</span></div><div><b>${weak.length}</b><span>苦手</span></div></div></section>
 <section class="record-card"><h2>分野別</h2>${drows||'<div class="empty">まだ回答がありません</div>'}</section>
 <section class="record-card"><h2>5週間</h2><div class="heatmap">${heat}</div><div class="heat-legend"><span>少</span><i></i><i class="lv1"></i><i class="lv2"></i><i class="lv3"></i><i class="lv4"></i><span>多</span></div></section>
 <section class="record-card"><h2>苦手</h2>${weak.length?weak.slice(0,12).map(q=>`<button class="weak-row" data-w="${q.id}"><span><b>${esc(q.topic)}</b><small>${esc(q.uiDomain||q.domain)}・連続正解 ${STATE.weak[q.id]?.streak||0}/3</small></span>${icon('arrow')}</button>`).join(''):'<div class="empty">現在の苦手はありません</div>'}</section></main>${tabbar('history')}`;
 app.innerHTML=h;app.querySelectorAll('[data-w]').forEach(b=>b.onclick=()=>startSession('weak-one',[BANK_BY_ID[b.dataset.w]],'苦手を1問復習','practice'));bindTabs()
}
function renderSettings(){
 let h=`<div class="paper-grid"></div><header class="subhead"><span>学びスプリント</span><h1>設定</h1><p>学習量・試験日・表示・バックアップを調整します。</p></header><main class="page-pad">
 <section class="setting-card"><label>1回の問題数</label><div class="seg">${[4,8,16].map(n=>`<button data-goal="${n}" class="${STATE.settings.dailyGoal===n?'active':''}">${n}問</button>`).join('')}</div><small>標準は8問。変更後の次セッションから反映します。</small></section>
 <section class="setting-card"><label>文字サイズ</label><div class="seg">${[['normal','標準'],['large','大'],['xlarge','特大']].map(([v,l])=>`<button data-font="${v}" class="${STATE.settings.fontSize===v?'active':''}">${l}</button>`).join('')}</div></section>
 <section class="setting-card"><label for="examDate">試験日</label><input id="examDate" class="date-input" type="date" value="${esc(STATE.settings.examDate||'')}"><small>設定するとホームに残日数と未学習ペースを表示します。</small></section>
 <section class="setting-card"><label>データ</label><div class="stack"><button class="sub-btn" data-export>JSONを書き出す</button><label class="file-btn">JSONを読み込む<input type="file" accept="application/json" data-import></label></div><small>端末内保存です。バックアップは個人情報を含みません。</small></section>
 <section class="setting-card"><label>問題データ</label><p>通常学習：重複除外済み <b>${BANK.length}問</b><br>模試出題枠：3回×25問＝<b>${OCC.length}枠</b><br>監査基準日：2026-08-09</p></section>
 <section class="setting-card"><label>試験制度・出典</label><p>本アプリはIPA公式アプリではありません。2026年度までの現行ネットワークスペシャリスト試験の科目A-2（旧午前II）学習を対象とします。IPA公開問題を基に改変した問題には出典・改変情報を表示します。2027年度の制度変更時は、正式情報を確認して再監査が完了するまで「新制度対応」と表示しません。</p></section>
 <section class="setting-card danger"><button data-reset>学習記録を初期化</button></section></main>${tabbar('settings')}`;
 app.innerHTML=h;
 app.querySelectorAll('[data-goal]').forEach(b=>b.onclick=()=>{STATE.settings.dailyGoal=Number(b.dataset.goal);save();renderSettings()});
 app.querySelectorAll('[data-font]').forEach(b=>b.onclick=()=>{STATE.settings.fontSize=b.dataset.font;applyFont();save();renderSettings()});
 app.querySelector('#examDate').onchange=e=>{STATE.settings.examDate=e.target.value;save()};
 app.querySelector('[data-export]').onclick=exportJson;
 app.querySelector('[data-import]').onchange=importJson;
 app.querySelector('[data-reset]').onclick=()=>{if(confirm('学習記録を初期化しますか？')){STATE=fresh();save();renderSettings()}};
 bindTabs()
}
function startSession(key,questions,title,mode='practice'){
 if(!questions||!questions.length)return;
 SESSION={key,title,mode,ids:questions.map(q=>q.id),index:0,answers:{},correct:0,startedAt:Date.now(),judged:false,selected:null};
 STATE.inProgress={key,title,mode,ids:SESSION.ids,index:0,answers:{},correct:0,startedAt:SESSION.startedAt,judged:false,selected:null};save();VIEW='quiz';render()
}
function resume(){
 const p=STATE.inProgress;if(!p||!p.ids?.length)return;
 SESSION={key:p.key,title:p.title,mode:p.mode||'practice',ids:p.ids,index:p.index||0,answers:p.answers||{},correct:p.correct||0,startedAt:p.startedAt||Date.now(),judged:!!p.judged,selected:p.selected??null};
 VIEW='quiz';render()
}
function currentQ(){if(!SESSION)return null;const id=SESSION.ids[SESSION.index];return BY_ID[id]||BANK_BY_ID[id]||null}
function persistSession(){if(!SESSION)return;STATE.inProgress={key:SESSION.key,title:SESSION.title,mode:SESSION.mode,ids:SESSION.ids,index:SESSION.index,answers:SESSION.answers,correct:SESSION.correct,startedAt:SESSION.startedAt,judged:SESSION.judged,selected:SESSION.selected};save()}
function renderQuiz(){
 const q=currentQ();if(!q){go('home');return}const i=SESSION.index,total=SESSION.ids.length,selected=SESSION.selected;
 let h=`<header class="quiz-head"><button data-quit>ホーム</button><div><small>${esc(SESSION.title)}</small><b>${i+1} / ${total}</b></div></header><main class="quiz-page"><div class="qprogress"><i style="width:${((i+1)/total)*100}%"></i></div>`;
 if(SESSION.mode==='mock')h+=`<p class="mock-mode-note">模試モード：正誤と解説は終了後まで表示しません。</p>`;
 h+=`<section class="question-card"><div class="qno">${q.examYear}年度 春期・午前II 問${q.questionNo}・${esc(q.uiDomain||q.domain)}</div><div class="qtext">${esc(q.question)}</div>${SESSION.judged&&SESSION.mode==='practice'?`<div class="judge-mark ${SESSION.answers[q.id]?.correct?'':'ng'}">${SESSION.answers[q.id]?.correct?'○':'×'}</div>`:''}</section><div class="answers">${q.choices.map((c,idx)=>{
   let cls='choice';if(selected===idx)cls+=' selected';if(SESSION.judged&&SESSION.mode==='practice'){if(idx===q.answerIndex)cls+=' correct';else if(selected===idx)cls+=' wrong'}
   return`<button class="${cls}" data-choice="${idx}" ${SESSION.judged?'disabled':''}><span>${['ア','イ','ウ','エ'][idx]}</span><b>${esc(c)}</b></button>`
 }).join('')}</div>`;
 if(!SESSION.judged)h+=`<button class="dontknow" data-dk>わからない</button>`;
 if(SESSION.judged&&SESSION.mode==='practice'){
  const a=SESSION.answers[q.id],cq=canonicalQuestion(q);
  h+=`<section class="feedback"><div class="judge-text ${a.correct?'ok':''}">${a.correct?'正解':'不正解'}</div><div class="memory"><span>ここだけ覚える</span><p>${esc(cq.memoryLine)}</p></div><p class="short-ex">${esc(cq.shortExplanation)}</p><details><summary>詳しい解説</summary><p>${esc(cq.detailExplanation)}</p></details><details class="source"><summary>出典・改変情報</summary><p>出典：${q.examYear}年度 春期 ネットワークスペシャリスト試験 午前II 問${q.questionNo}（IPA公開問題を基に改変）\n問題冊子：${esc((window.NW_SOURCE_URLS||{})[q.examYear]||'')}\n公式解答：${esc((window.NW_ANSWER_URLS||{})[q.examYear]||'')}\n監査：2026-08-09</p></details><button class="next" data-next>${i+1<total?'次の問題へ':'結果を見る'} ${icon('arrow')}</button></section>`;
 }else if(SESSION.judged&&SESSION.mode==='mock'){
  h+=`<div class="mock-selected">回答を記録しました。${i+1<total?'次の問題へ進みます。':'25問終了です。'}</div><button class="next" data-next>${i+1<total?'次の問題へ':'採点する'} ${icon('arrow')}</button>`;
 }
 h+=`</main>`;app.innerHTML=h;
 app.querySelector('[data-quit]').onclick=()=>{persistSession();VIEW='home';render()};
 app.querySelectorAll('[data-choice]').forEach(b=>b.onclick=()=>choose(Number(b.dataset.choice)));
 const dk=app.querySelector('[data-dk]');if(dk)dk.onclick=()=>choose(null);
 const nx=app.querySelector('[data-next]');if(nx)nx.onclick=nextQuestion
}
function choose(idx){
 if(SESSION.judged)return;const q=currentQ(),correct=idx===q.answerIndex;
 SESSION.selected=idx;SESSION.judged=true;SESSION.answers[q.id]={selected:idx,correct};
 if(correct)SESSION.correct++;
 if(SESSION.mode==='practice')recordAnswer(q,correct,idx);
 persistSession();renderQuiz()
}
function recordAnswer(q,correct,selected){
 const cid=canonicalId(q),cq=canonicalQuestion(q),day=todayKey();
 STATE.seenIds[cid]=true;STATE.stats.totalAnswered++;if(correct)STATE.stats.totalCorrect++;
 STATE.answerLog.push({day,id:cid,occurrenceId:q.id,domain:(cq.uiDomain||cq.domain),topic:cq.topic,correct,selected});
 if(!correct){STATE.weak[cid]={streak:0,lastWrong:Date.now(),wrongCount:Number(STATE.weak[cid]?.wrongCount||0)+1}}
 else if(STATE.weak[cid]){STATE.weak[cid].streak=Number(STATE.weak[cid].streak||0)+1;if(STATE.weak[cid].streak>=3)delete STATE.weak[cid]}
}
function nextQuestion(){
 if(!SESSION.judged)return;if(SESSION.index+1<SESSION.ids.length){SESSION.index++;SESSION.selected=null;SESSION.judged=false;persistSession();renderQuiz();scrollTo(0,0);return}finishSession()
}
function finishSession(){
 const elapsed=Math.max(1,Math.round((Date.now()-SESSION.startedAt)/1000)),total=SESSION.ids.length;
 if(SESSION.mode==='mock'){
  SESSION.ids.forEach(id=>{const q=BY_ID[id],a=SESSION.answers[id];if(q&&a)recordAnswer(q,a.correct,a.selected)})
 }
 STATE.sessionCompletions[SESSION.key]=completion(SESSION.key)+1;
 const rec={key:SESSION.key,title:SESSION.title,mode:SESSION.mode,total,correct:SESSION.correct,elapsed,at:Date.now()};
 STATE.stats.history.unshift(rec);STATE.stats.history=STATE.stats.history.slice(0,100);
 STATE.inProgress=null;save();VIEW='result';render()
}
function renderResult(){
 const r=STATE.stats.history[0];if(!r){go('home');return}const pct=Math.round(r.correct/r.total*100),wrong=r.total-r.correct;
 const answers=SESSION?.answers||{},qs=(SESSION?.ids||[]).map(id=>BY_ID[id]||BANK_BY_ID[id]).filter(Boolean);
 const domainMap={};qs.forEach(q=>{const d=q.uiDomain||q.domain;domainMap[d]??={n:0,c:0};domainMap[d].n++;if(answers[q.id]?.correct)domainMap[d].c++});
 let h=`<main class="result-page"><div class="result-seal">学習結果</div><h1 class="rmsg">${r.mode==='mock'?'模擬試験、おつかれさまでした。':'今日の反復を記録しました。'}</h1><div class="score"><b>${r.correct}</b><span>/ ${r.total}</span></div><div class="result-metrics"><div><b>${pct}%</b><span>正答率</span></div><div><b>${Math.floor(r.elapsed/60)}:${String(r.elapsed%60).padStart(2,'0')}</b><span>所要時間</span></div><div><b>${wrong}</b><span>誤答</span></div></div>`;
 if(Object.keys(domainMap).length)h+=`<div class="breakdown">${Object.entries(domainMap).map(([d,s])=>`<div><b>${esc(d)}</b><span>${s.c} / ${s.n}</span></div>`).join('')}</div>`;
 h+=`<div class="result-actions"><button class="primary" data-again>もう${r.mode==='mock'?r.total:(STATE.settings.dailyGoal||8)}問</button>${weakList().length?'<button class="outline" data-review>間違えた問題を復習</button>':''}<button class="text-home" data-home>ホームへ</button></div></main>`;
 app.innerHTML=h;
 app.querySelector('[data-again]').onclick=()=>{if(r.mode==='mock'){const y=Number((r.key.match(/\d{4}/)||[])[0]);if(y)startSession(r.key,yearQuestions(y),r.title,'mock');else go('mock')}else startSession('today',todayQuestions(),'今日のスプリント','practice')};
 const rev=app.querySelector('[data-review]');if(rev)rev.onclick=()=>startSession('weak',shuffle(weakList()),'間違えた問題を復習','practice');
 app.querySelector('[data-home]').onclick=()=>{SESSION=null;go('home')}
}
function exportJson(){
 const blob=new Blob([JSON.stringify({app:'network-specialist-sprint',schemaVersion:SCHEMA,exportedAt:new Date().toISOString(),state:STATE},null,2)],{type:'application/json'});
 const a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download=`network-specialist-sprint-${todayKey()}.json`;a.click();setTimeout(()=>URL.revokeObjectURL(a.href),1000)
}
function importJson(e){
 const f=e.target.files?.[0];if(!f)return;const r=new FileReader();r.onload=()=>{try{const x=JSON.parse(r.result);const s=x.state||x;if(!s||typeof s!=='object')throw new Error();STATE={...fresh(),...s,settings:{...fresh().settings,...(s.settings||{})},stats:{...fresh().stats,...(s.stats||{})}};save();renderSettings();alert('読み込みました')}catch(_){alert('読み込めないJSONです')}};r.readAsText(f,'utf-8')
}
window.addEventListener('beforeunload',()=>{if(SESSION&&VIEW==='quiz')persistSession()});
render();
})();
