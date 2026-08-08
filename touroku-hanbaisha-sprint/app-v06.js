'use strict';
(function(){
const LS_KEY='manabiSprint.tourokuHanbaisha.v06';
const PREV_KEY='manabiSprint.tourokuHanbaisha.v03';
const SESSION_TODAY='today12';
const SESSION_WEAK='weakreview';
const CHAPTERS=[
  {key:'第1章',title:'医薬品の基本',accent:'var(--ch1)',soft:'var(--ch1-soft)'},
  {key:'第2章',title:'人体と医薬品',accent:'var(--ch2)',soft:'var(--ch2-soft)'},
  {key:'第3章',title:'主な医薬品',accent:'var(--ch3)',soft:'var(--ch3-soft)'},
  {key:'第4章',title:'法規と制度',accent:'var(--ch4)',soft:'var(--ch4-soft)'},
  {key:'第5章',title:'適正使用と安全',accent:'var(--ch5)',soft:'var(--ch5-soft)'}
];
const ROUNDS=[
  {key:'R1',label:'第1回'},
  {key:'R2',label:'第2回'},
  {key:'R3',label:'第3回'}
];
const BASE_QUESTIONS=[...new Map(QUESTIONS.map(q=>[q.id,q])).values()].sort((a,b)=>(parseInt(a.id.split('-').pop(),10)||0)-(parseInt(b.id.split('-').pop(),10)||0));
function sentence1(s){const m=String(s||'').match(/^.*?[。！？]/);return (m?m[0]:String(s||'')).trim()}
function rotateToAnswer(choices,answer,target){const c=choices.slice();const correct=c[answer];c.splice(answer,1);c.splice(target,0,correct);return{choices:c,answer:target}}
function distractorPool(q,field){const same=BASE_QUESTIONS.filter(x=>x.chapter===q.chapter&&x.id!==q.id);const seed=parseInt(q.id.split('-').pop(),10)||1;const out=[];for(let i=0;i<same.length&&out.length<4;i++){const x=same[(seed+i*7)%same.length];let v=field==='point'?x.point:sentence1(x.detail);if(v&&!out.includes(v))out.push(v)}return out}
function buildVariant(q,roundIndex,baseIndex){
  const round=ROUNDS[roundIndex];
  const target=(baseIndex+roundIndex*2)%5;
  if(roundIndex===0){const r=rotateToAnswer(q.choices,q.answer,target);return{...q,id:`${round.key}-${q.id}`,round:round.key,roundLabel:round.label,choices:r.choices,answer:r.answer}}
  const correct=roundIndex===1?q.point:sentence1(q.detail);
  const ds=distractorPool(q,roundIndex===1?'point':'detail');
  const raw=[correct,...ds];
  while(raw.length<5)raw.push(`この設問の論点とは直接関係しない説明 ${raw.length}`);
  const choices=raw.slice(1,5);choices.splice(target,0,correct);
  const question=roundIndex===1?`${q.topic}について、最も適切な要点はどれか。`:`${q.topic}について、説明として最も適切なものはどれか。`;
  return{...q,id:`${round.key}-${q.id}`,round:round.key,roundLabel:round.label,question,choices,answer:target,point:q.point,detail:q.detail};
}
const EXAM_QUESTIONS={};
ROUNDS.forEach((r,ri)=>{EXAM_QUESTIONS[r.key]=BASE_QUESTIONS.map((q,i)=>buildVariant(q,ri,i))});
const ALL_QUESTIONS=ROUNDS.flatMap(r=>EXAM_QUESTIONS[r.key]);
const byId=Object.fromEntries(ALL_QUESTIONS.map(q=>[q.id,q]));
const app=document.getElementById('app');
let SESSION=null;let VIEW='home';
const categoryKey=(round,chapter)=>`exam:${round}:${chapter}`;
const roundKey=round=>`exam:${round}:all`;
function freshState(){return{version:6,weak:{},sessionCompletions:{},stats:{totalAnswered:0,totalCorrect:0,history:[]},settings:{fontSize:'normal'},seenIds:{},inProgress:null}}
function isPlainObject(v){return !!v&&typeof v==='object'&&!Array.isArray(v)}
function migratePrevious(){
  const s=freshState();
  try{
    const old=JSON.parse(localStorage.getItem(PREV_KEY)||'null');
    if(!isPlainObject(old)) return s;
    if(isPlainObject(old.settings)&&['normal','large','xlarge'].includes(old.settings.fontSize)) s.settings.fontSize=old.settings.fontSize;
    if(isPlainObject(old.stats)){
      s.stats.totalAnswered=Number.isFinite(old.stats.totalAnswered)?old.stats.totalAnswered:0;
      s.stats.totalCorrect=Number.isFinite(old.stats.totalCorrect)?Math.min(old.stats.totalCorrect,s.stats.totalAnswered):0;
      s.stats.history=Array.isArray(old.stats.history)?old.stats.history.slice(0,30):[];
    }
    if(isPlainObject(old.weak)) Object.entries(old.weak).forEach(([id,v])=>{const nid=`R1-${id}`;if(byId[nid])s.weak[nid]=v});
    if(isPlainObject(old.seenIds)) Object.keys(old.seenIds).forEach(id=>{const nid=`R1-${id}`;if(byId[nid])s.seenIds[nid]=true});
    if(isPlainObject(old.sessionCompletions)){
      CHAPTERS.forEach(c=>{const n=old.sessionCompletions[`chapter:${c.key}`];if(Number.isFinite(n))s.sessionCompletions[categoryKey('R1',c.key)]=n});
      if(Number.isFinite(old.sessionCompletions.mock120)) s.sessionCompletions[roundKey('R1')]=old.sessionCompletions.mock120;
      if(Number.isFinite(old.sessionCompletions[SESSION_TODAY])) s.sessionCompletions[SESSION_TODAY]=old.sessionCompletions[SESSION_TODAY];
    }
  }catch(e){}
  return s;
}
function loadState(){let s=null;try{s=JSON.parse(localStorage.getItem(LS_KEY)||'null')}catch(e){}if(!isPlainObject(s))s=migratePrevious();if(!isPlainObject(s.weak))s.weak={};if(!isPlainObject(s.sessionCompletions))s.sessionCompletions={};if(!isPlainObject(s.stats))s.stats={totalAnswered:0,totalCorrect:0,history:[]};s.stats.totalAnswered=Number.isFinite(s.stats.totalAnswered)?Math.max(0,s.stats.totalAnswered):0;s.stats.totalCorrect=Number.isFinite(s.stats.totalCorrect)?Math.max(0,Math.min(s.stats.totalCorrect,s.stats.totalAnswered)):0;s.stats.history=Array.isArray(s.stats.history)?s.stats.history.filter(x=>isPlainObject(x)&&typeof x.title==='string'&&typeof x.date==='string').slice(0,30):[];if(!isPlainObject(s.settings))s.settings={fontSize:'normal'};if(!['normal','large','xlarge'].includes(s.settings.fontSize))s.settings.fontSize='normal';if(!isPlainObject(s.seenIds))s.seenIds={};if(!isPlainObject(s.inProgress)||!Array.isArray(s.inProgress.ids)||!s.inProgress.ids.length||!Number.isInteger(s.inProgress.idx)||s.inProgress.idx<0||s.inProgress.idx>=s.inProgress.ids.length||s.inProgress.ids.some(id=>!byId[id]))s.inProgress=null;return s}
function saveState(){try{localStorage.setItem(LS_KEY,JSON.stringify(STATE))}catch(e){}}
let STATE=loadState();
function esc(s){return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')}
function shuffle(arr){const a=arr.slice();for(let i=a.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[a[i],a[j]]=[a[j],a[i]]}return a}
function completionCount(key){return Number(STATE.sessionCompletions[key])||0}
function weakList(){return ALL_QUESTIONS.filter(q=>STATE.weak[q.id]&&STATE.weak[q.id].streak<3)}
function todayQuestions(){const weakIds=new Set(weakList().map(q=>q.id));const categories=[];ROUNDS.forEach(r=>CHAPTERS.forEach(c=>categories.push({r,c})));const buckets=categories.map(({r,c})=>{const qs=EXAM_QUESTIONS[r.key].filter(q=>q.chapter===c.key);return[...shuffle(qs.filter(q=>!STATE.seenIds[q.id])),...shuffle(qs.filter(q=>STATE.seenIds[q.id]&&weakIds.has(q.id))),...shuffle(qs.filter(q=>STATE.seenIds[q.id]&&!weakIds.has(q.id)))]});const out=[];let cursor=0;while(out.length<12&&buckets.some(b=>b.length)){const b=buckets[cursor%buckets.length];if(b.length)out.push(b.shift());cursor++}return out}
function applyFont(){document.documentElement.classList.remove('fs-large','fs-xlarge');if(STATE.settings.fontSize==='large')document.documentElement.classList.add('fs-large');if(STATE.settings.fontSize==='xlarge')document.documentElement.classList.add('fs-xlarge')}
function formatDate(iso){const d=new Date(iso);return `${d.getMonth()+1}/${d.getDate()} ${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}`}
function tabbar(active){return `<nav class="tabbar" aria-label="メインナビゲーション"><button data-tab="home" class="${active==='home'?'active':''}"><span class="ic">⌂</span>ホーム</button><button data-tab="record" class="${active==='record'?'active':''}"><span class="ic">▥</span>学習記録</button><button data-tab="settings" class="${active==='settings'?'active':''}"><span class="ic">⚙</span>設定</button></nav>`}
function bindTabs(){app.querySelectorAll('[data-tab]').forEach(b=>b.onclick=()=>go(b.dataset.tab))}
function go(screen){VIEW=screen;render();window.scrollTo(0,0)}
function render(){if(VIEW==='home')return renderHome();if(VIEW==='quiz')return renderQuiz();if(VIEW==='result')return renderResult();if(VIEW==='record')return renderRecord();if(VIEW==='settings')return renderSettings()}
function renderHome(){const weak=weakList().length,ip=STATE.inProgress;let h=`<div class="home-top"><div class="brand-tag">登録販売者試験対策</div><div class="brand-title">登録販売者｜学びスプリント</div><p class="brand-sub">令和8年4月手引き準拠・模擬試験3回分／全360問</p><span class="version-pill">第1回・第2回・第3回 × 5科目</span></div><div class="hero"><p class="hero-title">今日も1問、力に変える。</p></div>`;
if(ip)h+=`<button class="resume-card" data-action="resume"><span class="resume-ic">▶</span><span class="resume-body"><span class="resume-label">前回の続きから始める</span><span class="resume-name">${esc(ip.title)}</span><span class="resume-meta">${Math.min(ip.idx+1,ip.ids.length)} / ${ip.ids.length}問目</span></span></button>`;
h+=`<section class="section"><h2>クイック学習</h2><button class="full-btn" data-action="today"><span class="emoji">⚡</span><span><span class="name">今日の12問</span><span class="meta">3試験回・5科目から横断出題・完走 ${completionCount(SESSION_TODAY)} 回</span></span></button><button class="full-btn" data-action="weak"><span class="emoji">🔥</span><span><span class="name">苦手復習</span><span class="meta">${weak?`${weak}問を復習・3連続正解で解除`:'誤答・「わからない」が自動で集まります'}</span></span>${weak?`<span class="count-badge">${weak}問</span>`:''}</button></section>`;
h+=`<section class="section"><h2>試験回・科目別</h2>`;
ROUNDS.forEach(r=>{h+=`<div class="exam-group"><div class="exam-heading"><span class="exam-title">${r.label} 模擬試験</span><span class="exam-total">全120問・完答 ${completionCount(roundKey(r.key))}回</span></div><div class="subject-grid">`;CHAPTERS.forEach(c=>{const n=EXAM_QUESTIONS[r.key].filter(q=>q.chapter===c.key).length;h+=`<button class="subject-card" data-round="${r.key}" data-chapter="${c.key}" style="--ch-accent:${c.accent};--ch-soft:${c.soft}"><span><span class="subject-name">${c.key}<br>${c.title}</span><span class="subject-meta">${n}問</span></span><span class="subject-complete">完答 ${completionCount(categoryKey(r.key,c.key))}回</span></button>`});h+=`</div><button class="round-full" data-round-full="${r.key}">${r.label}を120問通しで解く</button></div>`});
h+=`<p class="section-note">問題選択は3試験回 × 5科目＝15分類です。各分類の完答回数を保存します。</p></section><section class="section"><div class="settings-row"><div class="label">問題構成について</div><div class="settings-note">第1回は監査済み120問を使用。第2回・第3回は同じ監査済み論点から、要点選択型・説明選択型へ再構成した独自模擬問題です。地域別の公式過去問そのものを転載したものではありません。</div></div></section>${tabbar('home')}`;app.innerHTML=h;
app.querySelector('[data-action="today"]').onclick=()=>startSession(SESSION_TODAY,todayQuestions(),'今日の12問',false);app.querySelector('[data-action="weak"]').onclick=()=>{const qs=weakList();if(!qs.length){alert('現在、弱点登録されている問題はありません。');return}startSession(SESSION_WEAK,shuffle(qs),'苦手復習',false)};app.querySelectorAll('[data-round][data-chapter]').forEach(b=>b.onclick=()=>{const r=ROUNDS.find(x=>x.key===b.dataset.round),c=CHAPTERS.find(x=>x.key===b.dataset.chapter),qs=EXAM_QUESTIONS[r.key].filter(q=>q.chapter===c.key);startSession(categoryKey(r.key,c.key),qs,`${r.label}｜${c.key} ${c.title}`,false)});app.querySelectorAll('[data-round-full]').forEach(b=>b.onclick=()=>{const r=ROUNDS.find(x=>x.key===b.dataset.round);startSession(roundKey(r.key),EXAM_QUESTIONS[r.key],`${r.label}｜120問通し`,true)});const rb=app.querySelector('[data-action="resume"]');if(rb)rb.onclick=resumeSession;bindTabs()}
function startSession(key,questions,title,examMode){if(!questions.length)return;SESSION={key,title,questions,index:0,correct:0,chapterCorrect:{},answeredCount:0,answered:false,selected:null,startedAt:Date.now(),examMode:!!examMode};saveProgress();go('quiz')}
function saveProgress(){if(!SESSION)return;STATE.inProgress={key:SESSION.key,title:SESSION.title,ids:SESSION.questions.map(q=>q.id),idx:SESSION.index,correct:SESSION.correct,chapterCorrect:SESSION.chapterCorrect||{},answeredCount:SESSION.answeredCount,answered:SESSION.answered,selected:SESSION.selected,startedAt:SESSION.startedAt,examMode:SESSION.examMode};saveState()}
function clearProgress(){STATE.inProgress=null;saveState()}
function resumeSession(){const ip=STATE.inProgress;if(!ip)return;const qs=ip.ids.map(id=>byId[id]);if(qs.some(q=>!q)){clearProgress();go('home');return}SESSION={key:ip.key,title:ip.title,questions:qs,index:ip.idx,correct:ip.correct||0,chapterCorrect:isPlainObject(ip.chapterCorrect)?ip.chapterCorrect:{},answeredCount:ip.answeredCount||0,answered:!!ip.answered,selected:Number.isInteger(ip.selected)?ip.selected:null,startedAt:ip.startedAt||Date.now(),examMode:!!ip.examMode};go('quiz')}
function renderQuiz(){const q=SESSION.questions[SESSION.index],total=SESSION.questions.length;let h=`<div class="header"><button class="quit" id="quitBtn">‹ 中断</button><h1>${esc(SESSION.title)}</h1><span class="quiz-counter">${SESSION.index+1} / ${total}</span></div><div class="quiz-wrap"><span class="quiz-tag">${esc(q.roundLabel||'横断')} ・ ${esc(q.chapter)} ・ ${esc(q.topic)}</span><div class="qbar"><div style="width:${Math.round((SESSION.index/total)*100)}%"></div></div><div class="qtext">${esc(q.question)}</div>`;q.choices.forEach((c,i)=>{let cls='choice';if(!SESSION.examMode&&SESSION.answered){if(i===q.answer)cls+=' correct';else if(i===SESSION.selected)cls+=' wrong'}h+=`<button class="${cls}" data-choice="${i}" ${SESSION.answered&&!SESSION.examMode?'disabled':''}><span class="num">${i+1}</span><span>${esc(c)}</span></button>`});if(!SESSION.answered){h+=`<button class="dontknow-btn" id="dontknowBtn">わからない</button>`}else if(!SESSION.examMode){const correct=SESSION.selected===q.answer,dk=SESSION.selected===-1;h+=`<div class="feedback ${correct?'ok':'ng'}"><div class="feedback-title ${correct?'ok':'ng'}">${dk?`正解は ${q.answer+1} でした`:correct?'正解！':`不正解。正解は ${q.answer+1} です`}</div><span class="learn-label">この問題で覚える一文</span><p class="feedback-point">${esc(q.point)}</p><details><summary>詳しい解説を見る</summary><p class="detail-text">${esc(q.detail)}</p></details></div><button class="next-btn" id="nextBtn">${SESSION.index+1<total?'次の問題へ':'結果を見る'}</button>`}else h+=`<p class="mock-note">本番形式では正誤を途中表示しません。</p>`;h+='</div>';app.innerHTML=h;document.getElementById('quitBtn').onclick=()=>{saveProgress();go('home')};if(!SESSION.answered){app.querySelectorAll('[data-choice]').forEach(b=>b.onclick=()=>answerQuestion(Number(b.dataset.choice)));document.getElementById('dontknowBtn').onclick=()=>answerQuestion(-1)}else if(!SESSION.examMode)document.getElementById('nextBtn').onclick=nextQuestion}
function answerQuestion(choice){if(SESSION.answered)return;const q=SESSION.questions[SESSION.index],correct=choice===q.answer;SESSION.selected=choice;SESSION.answered=true;SESSION.answeredCount++;STATE.seenIds[q.id]=true;STATE.stats.totalAnswered++;if(correct){SESSION.correct++;SESSION.chapterCorrect[q.chapter]=(SESSION.chapterCorrect[q.chapter]||0)+1;STATE.stats.totalCorrect++;const w=STATE.weak[q.id];if(w){const streak=(w.streak||0)+1;if(streak>=3)delete STATE.weak[q.id];else STATE.weak[q.id]={streak}}}else STATE.weak[q.id]={streak:0};saveProgress();if(SESSION.examMode){setTimeout(()=>nextQuestion(),40)}else renderQuiz()}
function nextQuestion(){if(!SESSION.answered)return;if(SESSION.index+1<SESSION.questions.length){SESSION.index++;SESSION.answered=false;SESSION.selected=null;saveProgress();renderQuiz();window.scrollTo(0,0)}else finishSession()}
function finishSession(){const total=SESSION.questions.length,duration=Math.max(1,Math.round((Date.now()-SESSION.startedAt)/1000));clearProgress();STATE.sessionCompletions[SESSION.key]=(STATE.sessionCompletions[SESSION.key]||0)+1;STATE.stats.history.unshift({title:SESSION.title,date:new Date().toISOString(),correct:SESSION.correct,total,duration});STATE.stats.history=STATE.stats.history.slice(0,30);saveState();go('result')}
function renderResult(){const total=SESSION.questions.length,rate=Math.round(SESSION.correct/total*100);let h=`<div class="header"><h1>結果</h1></div><div class="result-card"><div class="result-big">${SESSION.correct} / ${total}</div><div class="result-label">${esc(SESSION.title)} 完走！</div><div class="result-detail"><div><div class="n">${rate}%</div><div class="l">正答率</div></div><div><div class="n">${weakList().length}</div><div class="l">現在の弱点数</div></div><div><div class="n">${completionCount(SESSION.key)}</div><div class="l">完答回数</div></div></div></div>`;if(SESSION.examMode){h+=`<section class="section"><h2>科目別得点</h2><div class="mock-score-grid">${CHAPTERS.map(c=>{const n=SESSION.questions.filter(q=>q.chapter===c.key).length;const got=SESSION.chapterCorrect[c.key]||0;return `<div class="mock-score"><span>${c.key}</span><strong>${got}/${n}</strong></div>`}).join('')}</div></section>`}h+=`<div class="result-actions"><button class="next-btn" id="homeBtn">ホームに戻る</button>${weakList().length?'<button class="secondary-btn" id="weakBtn">苦手だけ復習</button>':''}</div>${tabbar('')}`;app.innerHTML=h;document.getElementById('homeBtn').onclick=()=>go('home');const wb=document.getElementById('weakBtn');if(wb)wb.onclick=()=>startSession(SESSION_WEAK,shuffle(weakList()),'苦手復習',false);bindTabs()}
function renderRecord(){const rate=STATE.stats.totalAnswered?Math.round(STATE.stats.totalCorrect/STATE.stats.totalAnswered*100):0;let h=`<div class="header"><h1>学習記録</h1></div><section class="section"><div class="stat-row"><div class="stat-box"><div class="num">${STATE.stats.totalAnswered}</div><div class="lbl">総回答数</div></div><div class="stat-box"><div class="num">${STATE.stats.totalCorrect}</div><div class="lbl">総正解数</div></div><div class="stat-box"><div class="num">${rate}%</div><div class="lbl">正答率</div></div></div></section><section class="section"><h2>試験回の完答</h2><div class="exam-summary">${ROUNDS.map(r=>`<div class="stat-box"><div class="num">${completionCount(roundKey(r.key))}</div><div class="lbl">${r.label}</div></div>`).join('')}</div></section><section class="section"><h2>苦手問題（現在${weakList().length}問）</h2>`;if(weakList().length)h+=`<button class="full-btn" data-action="record-weak"><span class="emoji">🔥</span><span><span class="name">苦手復習を開始</span><span class="meta">3連続正解で弱点から解除</span></span><span class="count-badge">${weakList().length}問</span></button>`;else h+=`<div class="empty-note">現在、弱点登録されている問題はありません。</div>`;h+=`</section><section class="section"><h2>直近の学習履歴</h2>`;if(!STATE.stats.history.length)h+=`<div class="empty-note">まだ学習履歴がありません。</div>`;else STATE.stats.history.forEach(x=>{h+=`<div class="history-item"><span>${esc(x.title)}</span><span class="meta">${formatDate(x.date)} ・ ${x.correct}/${x.total}</span></div>`});h+=`</section>${tabbar('record')}`;app.innerHTML=h;const b=app.querySelector('[data-action="record-weak"]');if(b)b.onclick=()=>startSession(SESSION_WEAK,shuffle(weakList()),'苦手復習',false);bindTabs()}
function renderSettings(){let h=`<div class="header"><h1>設定</h1></div><section class="section"><div class="settings-row"><div class="label">文字サイズ</div><div class="seg">${[['normal','標準'],['large','大'],['xlarge','特大']].map(([k,l])=>`<button data-fs="${k}" class="${STATE.settings.fontSize===k?'active':''}">${l}</button>`).join('')}</div></div><div class="settings-row"><div class="label">教材基準</div><div class="settings-note">厚生労働省「試験問題の作成に関する手引き」令和8年4月一部改訂版を基準に、3回分の独自模擬試験として構成しています。各回は20・20・40・20・20問です。</div></div><div class="settings-row"><div class="label">データについて</div><div class="settings-note">学習記録・弱点情報は端末内にのみ保存します。</div></div><div class="settings-row"><div class="label">学習記録のリセット</div><button class="danger-btn" id="resetBtn">すべての学習記録をリセット</button></div></section>${tabbar('settings')}`;app.innerHTML=h;app.querySelectorAll('[data-fs]').forEach(b=>b.onclick=()=>{STATE.settings.fontSize=b.dataset.fs;saveState();applyFont();renderSettings()});document.getElementById('resetBtn').onclick=()=>{if(confirm('本当にすべての学習記録をリセットしますか？')){try{localStorage.removeItem(LS_KEY)}catch(e){}STATE=freshState();applyFont();go('home')}};bindTabs()}
applyFont();render();
window.__TOUROKU_V06__={BASE_QUESTIONS,EXAM_QUESTIONS,ALL_QUESTIONS,ROUNDS,CHAPTERS};
})();