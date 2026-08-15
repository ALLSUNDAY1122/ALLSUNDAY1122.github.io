'use strict';
(async function(){
const app=document.getElementById('app');
const LS_KEY='manabiSprint.tourokuHanbaisha.v07';
const PREV_KEY='manabiSprint.tourokuHanbaisha.v06';
const SESSION_TODAY='today12';
const SESSION_WEAK='weakreview';
const CHAPTERS=[
 {key:'第1章',title:'医薬品の基本',accent:'var(--ch1)',soft:'var(--ch1-soft)'},
 {key:'第2章',title:'人体と医薬品',accent:'var(--ch2)',soft:'var(--ch2-soft)'},
 {key:'第3章',title:'主な医薬品',accent:'var(--ch3)',soft:'var(--ch3-soft)'},
 {key:'第4章',title:'法規と制度',accent:'var(--ch4)',soft:'var(--ch4-soft)'},
 {key:'第5章',title:'適正使用と安全',accent:'var(--ch5)',soft:'var(--ch5-soft)'}
];
const ROUNDS=[{key:'R1',label:'第1回'},{key:'R2',label:'第2回'},{key:'R3',label:'第3回'}];
const expected={'第1章':20,'第2章':20,'第3章':40,'第4章':20,'第5章':20};
const esc=s=>String(s??'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
const shuffle=arr=>{const a=arr.slice();for(let i=a.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[a[i],a[j]]=[a[j],a[i]]}return a};
function loading(message='問題データを読み込んでいます…'){app.innerHTML=`<div class="home-top"><div class="brand-tag">登録販売者試験対策</div><div class="brand-title">登録販売者｜学びスプリント</div><p class="brand-sub">${esc(message)}</p></div>`}
loading();

async function loadRound(round){
 const files=[1,2,3,4,5].map(n=>`questions/exam-${round}/chapter-${n}.json`);
 const parts=await Promise.all(files.map(async f=>{const r=await fetch(f,{cache:'no-store'});if(!r.ok)throw new Error(`${f}: HTTP ${r.status}`);return r.json()}));
 return parts.flat();
}
function normalizeR1(q){return{id:`R1-${q.id}`,round:'R1',roundLabel:'第1回',chapter:q.chapter,topic:q.topic,question:q.question,choices:q.choices.slice(),answer:q.answer,point:q.point,detail:q.detail,source_url:q.source_url||''}}
function normalizeCanonical(q,r){return{id:q.id,round:`R${r}`,roundLabel:`第${r}回`,chapter:q.chapter,topic:q.topic,question:q.question,choices:q.choices.slice(),answer:q.correct_index,point:q.explanation,detail:q.explanation,source_url:q.source_url||''}}
function validateRound(list,r){
 if(list.length!==120)throw new Error(`第${r}回の問題数が${list.length}問です`);
 const ids=new Set(),counts={};
 for(const q of list){
  if(!q.id||ids.has(q.id))throw new Error(`第${r}回 ID重複: ${q.id}`);ids.add(q.id);
  counts[q.chapter]=(counts[q.chapter]||0)+1;
  if(!Array.isArray(q.choices)||q.choices.length!==5||new Set(q.choices).size!==5)throw new Error(`${q.id}: 5択構造エラー`);
  if(!Number.isInteger(q.answer)||q.answer<0||q.answer>4)throw new Error(`${q.id}: 正解位置エラー`);
  if(!q.question||!q.point||!q.topic)throw new Error(`${q.id}: 必須データ欠損`);
 }
 for(const [ch,n] of Object.entries(expected))if(counts[ch]!==n)throw new Error(`第${r}回 ${ch}: ${counts[ch]||0}/${n}`);
}

let r2raw,r3raw;
try{[r2raw,r3raw]=await Promise.all([loadRound(2),loadRound(3)])}catch(e){app.innerHTML=`<div class="home-top"><div class="brand-title">問題データを読み込めませんでした</div><p class="brand-sub">通信状態を確認して再読み込みしてください。<br>${esc(e.message)}</p><button class="secondary-btn" onclick="location.reload()">再読み込み</button></div>`;return}
const r1=[...new Map((window.QUESTIONS||[]).map(q=>[q.id,q])).values()].sort((a,b)=>(parseInt(a.id.split('-').pop(),10)||0)-(parseInt(b.id.split('-').pop(),10)||0)).map(normalizeR1);
const r2=r2raw.map(q=>normalizeCanonical(q,2));
const r3=r3raw.map(q=>normalizeCanonical(q,3));
try{validateRound(r1,1);validateRound(r2,2);validateRound(r3,3)}catch(e){app.innerHTML=`<div class="home-top"><div class="brand-title">問題データ監査エラー</div><p class="brand-sub">${esc(e.message)}</p></div>`;return}
const EXAM_QUESTIONS={R1:r1,R2:r2,R3:r3};
const ALL_QUESTIONS=[...r1,...r2,...r3];
const byId=Object.fromEntries(ALL_QUESTIONS.map(q=>[q.id,q]));

function freshState(){return{version:7,weak:{},sessionCompletions:{},stats:{totalAnswered:0,totalCorrect:0,history:[]},settings:{fontSize:'normal'},seenIds:{},inProgress:null}}
function migrate(){const s=freshState();try{const old=JSON.parse(localStorage.getItem(PREV_KEY)||'null');if(!old||typeof old!=='object')return s;if(old.settings&&['normal','large','xlarge'].includes(old.settings.fontSize))s.settings.fontSize=old.settings.fontSize;if(old.stats){s.stats.totalAnswered=Number(old.stats.totalAnswered)||0;s.stats.totalCorrect=Math.min(Number(old.stats.totalCorrect)||0,s.stats.totalAnswered);s.stats.history=Array.isArray(old.stats.history)?old.stats.history.slice(0,30):[]}if(old.sessionCompletions&&typeof old.sessionCompletions==='object')s.sessionCompletions={...old.sessionCompletions};if(old.seenIds&&typeof old.seenIds==='object')Object.keys(old.seenIds).filter(id=>id.startsWith('R1-')&&byId[id]).forEach(id=>s.seenIds[id]=true);if(old.weak&&typeof old.weak==='object')Object.entries(old.weak).filter(([id])=>id.startsWith('R1-')&&byId[id]).forEach(([id,v])=>s.weak[id]=v)}catch(e){}return s}
function loadState(){let s;try{s=JSON.parse(localStorage.getItem(LS_KEY)||'null')}catch(e){}if(!s||typeof s!=='object')s=migrate();s.weak=s.weak&&typeof s.weak==='object'?s.weak:{};s.sessionCompletions=s.sessionCompletions&&typeof s.sessionCompletions==='object'?s.sessionCompletions:{};s.seenIds=s.seenIds&&typeof s.seenIds==='object'?s.seenIds:{};s.settings=s.settings&&typeof s.settings==='object'?s.settings:{fontSize:'normal'};if(!['normal','large','xlarge'].includes(s.settings.fontSize))s.settings.fontSize='normal';s.stats=s.stats&&typeof s.stats==='object'?s.stats:{totalAnswered:0,totalCorrect:0,history:[]};s.stats.history=Array.isArray(s.stats.history)?s.stats.history.slice(0,30):[];if(s.inProgress&&(!Array.isArray(s.inProgress.ids)||s.inProgress.ids.some(id=>!byId[id])))s.inProgress=null;return s}
let STATE=loadState(),SESSION=null,VIEW='home';
function save(){try{localStorage.setItem(LS_KEY,JSON.stringify(STATE))}catch(e){}}
function applyFont(){document.documentElement.classList.remove('fs-large','fs-xlarge');if(STATE.settings.fontSize==='large')document.documentElement.classList.add('fs-large');if(STATE.settings.fontSize==='xlarge')document.documentElement.classList.add('fs-xlarge')}
applyFont();
const categoryKey=(r,c)=>`exam:${r}:${c}`;
const roundKey=r=>`exam:${r}:all`;
const completionCount=k=>Number(STATE.sessionCompletions[k])||0;
const weakList=()=>ALL_QUESTIONS.filter(q=>STATE.weak[q.id]&&Number(STATE.weak[q.id].streak)<3);
function todayQuestions(){const cats=[];ROUNDS.forEach(r=>CHAPTERS.forEach(c=>cats.push(EXAM_QUESTIONS[r.key].filter(q=>q.chapter===c.key))));const buckets=cats.map(qs=>[...shuffle(qs.filter(q=>!STATE.seenIds[q.id])),...shuffle(qs.filter(q=>STATE.seenIds[q.id]))]);const out=[];let i=0;while(out.length<12&&buckets.some(b=>b.length)){const b=buckets[i%buckets.length];if(b.length)out.push(b.shift());i++}return out}
function tabbar(active){return `<nav class="tabbar"><button data-tab="home" class="${active==='home'?'active':''}"><span class="ic">⌂</span>ホーム</button><button data-tab="record" class="${active==='record'?'active':''}"><span class="ic">▥</span>学習記録</button><button data-tab="settings" class="${active==='settings'?'active':''}"><span class="ic">⚙</span>設定</button></nav>`}
function bindTabs(){app.querySelectorAll('[data-tab]').forEach(b=>b.onclick=()=>go(b.dataset.tab))}
function go(v){VIEW=v;render();window.scrollTo(0,0)}
function render(){if(VIEW==='home')renderHome();else if(VIEW==='quiz')renderQuiz();else if(VIEW==='result')renderResult();else if(VIEW==='record')renderRecord();else renderSettings()}
function renderHome(){const weak=weakList().length,ip=STATE.inProgress;let h=`<div class="home-top"><div class="brand-tag">登録販売者試験対策</div><div class="brand-title">登録販売者｜学びスプリント</div><p class="brand-sub">令和8年4月手引き準拠・独立模擬試験3回分／全360問</p><span class="version-pill">v0.7 canonical 360</span></div><div class="hero"><p class="hero-title">今日も1問、力に変える。</p></div>`;
 if(ip)h+=`<button class="resume-card" data-action="resume"><span class="resume-ic">▶</span><span class="resume-body"><span class="resume-label">前回の続きから始める</span><span class="resume-name">${esc(ip.title)}</span><span class="resume-meta">${Math.min(ip.idx+1,ip.ids.length)} / ${ip.ids.length}問目</span></span></button>`;
 h+=`<section class="section"><h2>クイック学習</h2><button class="full-btn" data-action="today"><span class="emoji">⚡</span><span><span class="name">今日の12問</span><span class="meta">3試験回・5科目から横断出題・完走 ${completionCount(SESSION_TODAY)}回</span></span></button><button class="full-btn" data-action="weak"><span class="emoji">🔥</span><span><span class="name">苦手復習</span><span class="meta">${weak?`${weak}問・3連続正解で解除`:'誤答・わからないが自動で集まります'}</span></span>${weak?`<span class="count-badge">${weak}問</span>`:''}</button></section><section class="section"><h2>試験回・科目別</h2>`;
 ROUNDS.forEach(r=>{h+=`<div class="exam-group"><div class="exam-heading"><span class="exam-title">${r.label} 模擬試験</span><span class="exam-total">全120問・完答 ${completionCount(roundKey(r.key))}回</span></div><div class="subject-grid">`;CHAPTERS.forEach(c=>{const n=EXAM_QUESTIONS[r.key].filter(q=>q.chapter===c.key).length;h+=`<button class="subject-card" data-round="${r.key}" data-chapter="${c.key}" style="--ch-accent:${c.accent};--ch-soft:${c.soft}"><span><span class="subject-name">${c.key}<br>${c.title}</span><span class="subject-meta">${n}問</span></span><span class="subject-complete">完答 ${completionCount(categoryKey(r.key,c.key))}回</span></button>`});h+=`</div><button class="round-full" data-round-full="${r.key}">${r.label}を120問通しで解く</button></div>`});
 h+=`<p class="section-note">3試験回 × 5科目＝15分類。第2回・第3回も第1回の解説文からの自動生成ではなく、独立した問題データを使用します。</p></section>${tabbar('home')}`;app.innerHTML=h;
 app.querySelector('[data-action="today"]').onclick=()=>startSession(SESSION_TODAY,todayQuestions(),'今日の12問',false);
 app.querySelector('[data-action="weak"]').onclick=()=>{const qs=shuffle(weakList());if(!qs.length)return alert('現在、苦手問題はありません。');startSession(SESSION_WEAK,qs,'苦手復習',false)};
 const rb=app.querySelector('[data-action="resume"]');if(rb)rb.onclick=resumeSession;
 app.querySelectorAll('[data-round][data-chapter]').forEach(b=>b.onclick=()=>{const r=ROUNDS.find(x=>x.key===b.dataset.round),c=CHAPTERS.find(x=>x.key===b.dataset.chapter);startSession(categoryKey(r.key,c.key),EXAM_QUESTIONS[r.key].filter(q=>q.chapter===c.key),`${r.label}｜${c.key} ${c.title}`,false)});
 app.querySelectorAll('[data-round-full]').forEach(b=>b.onclick=()=>{const r=ROUNDS.find(x=>x.key===b.dataset.round);startSession(roundKey(r.key),EXAM_QUESTIONS[r.key],`${r.label}｜120問通し`,true)});bindTabs();
}
function startSession(key,questions,title,examMode){SESSION={key,title,questions:questions.slice(),index:0,correct:0,chapterCorrect:{},chapterAnswered:{},answered:false,selected:null,startedAt:Date.now(),examMode:!!examMode};saveProgress();go('quiz')}
function saveProgress(){if(!SESSION)return;STATE.inProgress={key:SESSION.key,title:SESSION.title,ids:SESSION.questions.map(q=>q.id),idx:SESSION.index,correct:SESSION.correct,chapterCorrect:SESSION.chapterCorrect,chapterAnswered:SESSION.chapterAnswered,answered:SESSION.answered,selected:SESSION.selected,startedAt:SESSION.startedAt,examMode:SESSION.examMode};save()}
function resumeSession(){const p=STATE.inProgress;if(!p)return;const qs=p.ids.map(id=>byId[id]).filter(Boolean);if(qs.length!==p.ids.length){STATE.inProgress=null;save();return renderHome()}SESSION={key:p.key,title:p.title,questions:qs,index:p.idx||0,correct:p.correct||0,chapterCorrect:p.chapterCorrect||{},chapterAnswered:p.chapterAnswered||{},answered:!!p.answered,selected:p.selected??null,startedAt:p.startedAt||Date.now(),examMode:!!p.examMode};go('quiz')}
function markWeak(q,correct,unknown){const cur=STATE.weak[q.id];if(!correct||unknown){STATE.weak[q.id]={streak:0,last:Date.now()};return}if(cur){const streak=(Number(cur.streak)||0)+1;if(streak>=3)delete STATE.weak[q.id];else STATE.weak[q.id]={...cur,streak,last:Date.now()}}}
function answerQuestion(idx,unknown=false){if(!SESSION||SESSION.answered)return;const q=SESSION.questions[SESSION.index],correct=!unknown&&idx===q.answer;SESSION.answered=true;SESSION.selected=unknown?-1:idx;SESSION.chapterAnswered[q.chapter]=(SESSION.chapterAnswered[q.chapter]||0)+1;if(correct){SESSION.correct++;SESSION.chapterCorrect[q.chapter]=(SESSION.chapterCorrect[q.chapter]||0)+1}STATE.stats.totalAnswered=(Number(STATE.stats.totalAnswered)||0)+1;if(correct)STATE.stats.totalCorrect=(Number(STATE.stats.totalCorrect)||0)+1;STATE.seenIds[q.id]=true;markWeak(q,correct,unknown);saveProgress();if(SESSION.examMode){setTimeout(nextQuestion,180)}else renderQuiz()}
function nextQuestion(){if(!SESSION)return;if(SESSION.index+1>=SESSION.questions.length)return finishSession();SESSION.index++;SESSION.answered=false;SESSION.selected=null;saveProgress();renderQuiz();window.scrollTo(0,0)}
function finishSession(){const total=SESSION.questions.length;STATE.sessionCompletions[SESSION.key]=completionCount(SESSION.key)+1;STATE.stats.history=[{title:SESSION.title,date:new Date().toISOString(),correct:SESSION.correct,total,examMode:SESSION.examMode},...(STATE.stats.history||[])].slice(0,30);STATE.inProgress=null;save();VIEW='result';renderResult()}
function renderQuiz(){const q=SESSION.questions[SESSION.index],n=SESSION.index+1,total=SESSION.questions.length,pct=Math.round(n/total*100);let h=`<div class="header"><button class="quit" data-quit>中断</button><h1>${esc(SESSION.title)}</h1><span class="quiz-counter">${n}/${total}</span></div><div class="quiz-wrap"><span class="quiz-tag">${esc(q.roundLabel)}・${esc(q.chapter)}・${esc(q.topic)}</span>${SESSION.examMode?'<div class="mock-note">通し模試では正誤・解説を途中表示しません</div>':''}<div class="qbar"><div style="width:${pct}%"></div></div><div class="qtext">${esc(q.question)}</div>`;
 q.choices.forEach((c,i)=>{let cls='choice';if(SESSION.answered&&!SESSION.examMode){if(i===q.answer)cls+=' correct';else if(i===SESSION.selected)cls+=' wrong'}h+=`<button class="${cls}" data-choice="${i}" ${SESSION.answered?'disabled':''}><span class="num">${i+1}</span><span>${esc(c)}</span></button>`});
 h+=`<button class="dontknow-btn" data-dk ${SESSION.answered?'disabled':''}>わからない</button>`;
 if(SESSION.answered&&!SESSION.examMode){const ok=SESSION.selected===q.answer;h+=`<div class="feedback ${ok?'ok':'ng'}"><div class="feedback-title ${ok?'ok':'ng'}">${ok?'正解':'ここを確認'}</div><div class="learn-label">ここだけ覚える</div><p class="feedback-point">${esc(q.point)}</p>${q.detail&&q.detail!==q.point?`<details><summary>詳しい解説</summary><p class="detail-text">${esc(q.detail)}</p></details>`:''}</div><button class="next-btn" data-next>${n===total?'結果を見る':'次の問題'}</button>`}
 h+='</div>';app.innerHTML=h;app.querySelector('[data-quit]').onclick=()=>{saveProgress();go('home')};app.querySelectorAll('[data-choice]').forEach(b=>b.onclick=()=>answerQuestion(Number(b.dataset.choice)));const dk=app.querySelector('[data-dk]');if(dk)dk.onclick=()=>answerQuestion(-1,true);const nx=app.querySelector('[data-next]');if(nx)nx.onclick=nextQuestion;
}
function renderResult(){if(!SESSION)return go('home');const total=SESSION.questions.length,rate=Math.round(SESSION.correct/total*100);let h=`<div class="header"><h1>${esc(SESSION.title)}</h1></div><div class="result-card"><div class="result-big">${SESSION.correct}/${total}</div><div class="result-label">正答率 ${rate}%</div><div class="result-detail"><div><div class="n">${total-SESSION.correct}</div><div class="l">要復習</div></div><div><div class="n">${weakList().length}</div><div class="l">現在の苦手</div></div></div></div>`;
 if(SESSION.examMode){h+='<div class="exam-summary">';CHAPTERS.forEach(c=>{const a=SESSION.chapterAnswered[c.key]||0,cc=SESSION.chapterCorrect[c.key]||0;h+=`<div class="stat-box"><div class="num">${cc}/${a}</div><div class="lbl">${c.key}</div></div>`});h+='</div>'}
 h+=`<div class="result-actions"><button class="next-btn" data-home>ホームへ</button><button class="secondary-btn" data-again>同じ範囲をもう一度</button></div>${tabbar('home')}`;app.innerHTML=h;const prev={key:SESSION.key,title:SESSION.title,questions:SESSION.questions.slice(),examMode:SESSION.examMode};app.querySelector('[data-home]').onclick=()=>{SESSION=null;go('home')};app.querySelector('[data-again]').onclick=()=>startSession(prev.key,prev.questions,prev.title,prev.examMode);bindTabs();
}
function renderRecord(){const a=Number(STATE.stats.totalAnswered)||0,c=Number(STATE.stats.totalCorrect)||0,rate=a?Math.round(c/a*100):0;let h=`<div class="home-top"><div class="brand-title">学習記録</div></div><section class="section"><div class="stat-row"><div class="stat-box"><div class="num">${a}</div><div class="lbl">総回答</div></div><div class="stat-box"><div class="num">${rate}%</div><div class="lbl">正答率</div></div><div class="stat-box"><div class="num">${weakList().length}</div><div class="lbl">苦手</div></div></div></section><section class="section"><h2>最近の学習</h2>`;const hist=STATE.stats.history||[];h+=hist.length?hist.map(x=>`<div class="history-item"><span>${esc(x.title)}<br><strong>${x.correct}/${x.total}</strong></span><span class="meta">${new Date(x.date).toLocaleDateString('ja-JP')}</span></div>`).join(''):'<div class="empty-note">まだ学習記録がありません。</div>';h+=`</section>${tabbar('record')}`;app.innerHTML=h;bindTabs()}
function renderSettings(){let h=`<div class="home-top"><div class="brand-title">設定</div></div><section class="section"><div class="settings-row"><div class="label">文字サイズ</div><div class="seg">${[['normal','標準'],['large','大'],['xlarge','特大']].map(([v,l])=>`<button data-font="${v}" class="${STATE.settings.fontSize===v?'active':''}">${l}</button>`).join('')}</div></div><div class="settings-row"><div class="label">問題データ</div><div class="settings-note">全360問。第1回120問、第2回120問、第3回120問。各回20・20・40・20・20問。第2回・第3回はcanonical JSONを直接読み込みます。</div></div><button class="danger-btn" data-reset>学習記録をリセット</button></section>${tabbar('settings')}`;app.innerHTML=h;app.querySelectorAll('[data-font]').forEach(b=>b.onclick=()=>{STATE.settings.fontSize=b.dataset.font;save();applyFont();renderSettings()});app.querySelector('[data-reset]').onclick=()=>{if(confirm('学習記録をすべてリセットしますか？')){STATE=freshState();save();applyFont();renderSettings()}};bindTabs()}
render();
})();