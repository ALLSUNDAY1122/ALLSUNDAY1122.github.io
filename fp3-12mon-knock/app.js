'use strict';
let QUESTIONS=[];
const QUESTIONS_GZ_B64=window.QDATA||'';
async function loadQuestions(){if(typeof DecompressionStream==='undefined')throw new Error('このブラウザはデータ展開に対応していません。Safariを最新版に更新してください。');const bytes=Uint8Array.from(atob(QUESTIONS_GZ_B64),c=>c.charCodeAt(0));const stream=new Blob([bytes]).stream().pipeThrough(new DecompressionStream('gzip'));return JSON.parse(await new Response(stream).text())}
const STORE_KEY='fp3_12mon_knock_v010';
let FIELDS=[];
const FIELD_SHORT={'ライフプラン':'ライフ','リスク管理':'リスク','金融資産運用':'金融','タックス':'税金','不動産':'不動産','相続・事業承継':'相続'};
const $=id=>document.getElementById(id);
const defaultState=()=>({version:1,questionState:{},totalAnswered:0,totalCorrect:0,sessions:0,studyDates:[],examDate:'',fontSize:'16',activeSession:null});
let state=loadState();
let session=null;
let pendingModalAction=null;

function safeStorage(){try{const t='__fp3_test__';localStorage.setItem(t,'1');localStorage.removeItem(t);return localStorage}catch(e){return null}}
const storage=safeStorage();
function loadState(){try{if(!storage)return defaultState();const raw=storage.getItem(STORE_KEY);return raw?Object.assign(defaultState(),JSON.parse(raw)):defaultState()}catch(e){return defaultState()}}
function saveState(){try{if(storage)storage.setItem(STORE_KEY,JSON.stringify(state))}catch(e){}}
function today(){return new Date().toLocaleDateString('sv-SE')}
function shuffle(items){const a=[...items];for(let i=a.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[a[i],a[j]]=[a[j],a[i]]}return a}
function qState(id){return state.questionState[id]||{status:'new',attempts:0,correct:0}}
function priority(q){const s=qState(q.id).status;return s==='weak'?0:s==='unsure'?1:s==='new'?2:3}
function pickBalancedDaily(){const out=[];for(const field of FIELDS){const pool=shuffle(QUESTIONS.filter(q=>q.field===field)).sort((a,b)=>priority(a)-priority(b));out.push(...pool.slice(0,2))}return shuffle(out)}
function pickReview(){const pool=shuffle(QUESTIONS.filter(q=>['weak','unsure'].includes(qState(q.id).status))).sort((a,b)=>priority(a)-priority(b));if(pool.length>=12)return pool.slice(0,12);const fill=shuffle(QUESTIONS.filter(q=>!pool.some(p=>p.id===q.id))).sort((a,b)=>priority(a)-priority(b));return [...pool,...fill.slice(0,12-pool.length)]}
function pickField(field){return shuffle(QUESTIONS.filter(q=>q.field===field)).sort((a,b)=>priority(a)-priority(b)).slice(0,8)}
function startSession(mode,field){let queue=mode==='daily'?pickBalancedDaily():mode==='review'?pickReview():pickField(field);session={mode,field:field||'',queue:queue.map(q=>q.id),index:0,correct:0,wrong:0,unknown:0,markedUnsure:0,answered:false,lastChoice:null};state.activeSession=session;saveState();showView('quiz');renderQuestion()}
function restoreSession(){if(!state.activeSession)return;session=state.activeSession;showView('quiz');renderQuestion()}
function currentQuestion(){return QUESTIONS.find(q=>q.id===session.queue[session.index])}
function renderQuestion(){const q=currentQuestion();session.answered=false;session.lastChoice=null;state.activeSession=session;saveState();$('fieldChip').textContent=q.field;$('topicChip').textContent=q.topic;$('questionText').textContent=q.text;$('quizCounter').textContent=`${session.index+1} / ${session.queue.length}`;$('progressBar').style.width=`${(session.index/session.queue.length)*100}%`;$('feedbackBox').className='feedback';$('uncertainMark').hidden=true;$('uncertainMark').classList.remove('on');document.querySelectorAll('.answer').forEach(b=>b.disabled=false);$('nextQuestion').textContent=session.index===session.queue.length-1?'結果を見る':'次の問題';window.scrollTo({top:0,behavior:'instant'})}
function answer(choice){if(session.answered)return;session.answered=true;session.lastChoice=choice;document.querySelectorAll('.answer').forEach(b=>b.disabled=true);const q=currentQuestion();const qs=qState(q.id);qs.attempts=(qs.attempts||0)+1;state.totalAnswered++;let kind,title;
  if(choice==='unknown'){session.unknown++;qs.status='unsure';kind='hold';title=`保留｜正解は ${q.answer?'○':'×'}`}
  else{const correct=(choice==='true')===q.answer;if(correct){session.correct++;state.totalCorrect++;qs.correct=(qs.correct||0)+1;qs.status='ok';kind='good';title='正解';$('uncertainMark').hidden=false}else{session.wrong++;qs.status='weak';kind='bad';title=`不正解｜正解は ${q.answer?'○':'×'}`}}
  state.questionState[q.id]=qs;session._currentStatus=qs.status;state.activeSession=session;saveState();$('feedbackBox').className=`feedback show ${kind}`;$('feedbackTitle').textContent=title;$('explanation').textContent=q.explanation;
}
function toggleUncertain(){if(!session||!session.answered||session.lastChoice==='unknown')return;const q=currentQuestion();const qs=qState(q.id);const on=$('uncertainMark').classList.toggle('on');if(on){qs.status='unsure';session.markedUnsure++;$('uncertainMark').textContent='迷いとして保存済み'}else{qs.status='ok';session.markedUnsure=Math.max(0,session.markedUnsure-1);$('uncertainMark').textContent='正解したけど迷った'}state.questionState[q.id]=qs;state.activeSession=session;saveState()}
function nextQuestion(){if(!session.answered)return;if(session.index<session.queue.length-1){session.index++;renderQuestion()}else{finishSession()}}
function finishSession(){state.sessions++;if(!state.studyDates.includes(today()))state.studyDates.push(today());state.activeSession=null;saveState();$('resultCorrect').textContent=session.correct;$('resultWrong').textContent=session.wrong;$('resultUnknown').textContent=session.unknown;const unresolved=session.wrong+session.unknown+session.markedUnsure;$('resultSub').textContent=`${session.queue.length}問中 ${session.correct}問正解`;$('resultMessage').innerHTML=unresolved?`<b>${unresolved}問</b>を復習待ちに残しました。正解数だけでなく、迷いを減らすことを優先します。`:'全問を迷わず回答できました。次回は未回答問題を中心に出題します。';$('resultReview').hidden=countReview()===0;showView('result');session=null;renderHome();renderRecord()}
function countReview(){return QUESTIONS.filter(q=>['weak','unsure'].includes(qState(q.id).status)).length}
function streak(){const dates=[...new Set(state.studyDates)].sort();if(!dates.length)return 0;let d=new Date(today()+'T00:00:00');const set=new Set(dates);if(!set.has(today())){d.setDate(d.getDate()-1)}let n=0;while(set.has(d.toLocaleDateString('sv-SE'))){n++;d.setDate(d.getDate()-1)}return n}
function renderHome(){$('streakMetric').textContent=`${streak()}日`;$('reviewMetric').textContent=`${countReview()}問`;const seen=Object.keys(state.questionState).length;$('seenMetric').textContent=`${Math.round(seen/QUESTIONS.length*100)}%`;$('reviewDescription').textContent=countReview()?`${countReview()}問が復習待ち`:'復習待ちはありません';$('resumeBtn').hidden=!state.activeSession;renderExamPill()}
function renderFields(){const counts=Object.fromEntries(FIELDS.map(f=>[f,QUESTIONS.filter(q=>q.field===f).length]));$('fieldButtons').innerHTML=FIELDS.map(f=>`<button class="field-btn" data-field="${escapeHtml(f)}"><b>${escapeHtml(FIELD_SHORT[f]||f)}</b><span>${counts[f]}問から優先8問</span></button>`).join('')}
function renderRecord(){$('totalAnswered').textContent=state.totalAnswered;$('overallAccuracy').textContent=state.totalAnswered?`${Math.round(state.totalCorrect/state.totalAnswered*100)}%`:'0%';$('totalSessions').textContent=state.sessions;$('fieldBars').innerHTML=FIELDS.map(f=>{const qs=QUESTIONS.filter(q=>q.field===f);const ok=qs.filter(q=>qState(q.id).status==='ok').length;const pct=Math.round(ok/qs.length*100);return `<div class="bar-row"><span>${escapeHtml(FIELD_SHORT[f]||f)}</span><div class="bar-bg"><div class="bar-fill" style="width:${pct}%"></div></div><b>${pct}%</b></div>`}).join('')}
function renderSettings(){$('examDate').value=state.examDate||'';$('fontSize').value=state.fontSize||'16';document.documentElement.style.setProperty('--font',`${state.fontSize||16}px`)}
function renderExamPill(){if(!state.examDate){$('examPill').textContent='受検日 未設定';return}const now=new Date(today()+'T00:00:00');const exam=new Date(state.examDate+'T00:00:00');const diff=Math.ceil((exam-now)/86400000);$('examPill').textContent=diff>=0?`受検まで ${diff}日`:'受検日経過'}
function showView(name){const map={home:'homeView',quiz:'quizView',result:'resultView',record:'recordView',settings:'settingsView'};document.querySelectorAll('.view').forEach(v=>v.classList.remove('active'));$(map[name]).classList.add('active');const showNav=!['quiz','result'].includes(name);$('bottomNav').style.display=showNav?'grid':'none';$('topBar').style.display=name==='quiz'?'none':'flex';document.querySelectorAll('.nav button').forEach(b=>b.classList.toggle('active',b.dataset.view===name));if(name==='home')renderHome();if(name==='record')renderRecord();if(name==='settings')renderSettings();window.scrollTo({top:0,behavior:'instant'})}
function openModal(title,text,action){$('modalTitle').textContent=title;$('modalText').textContent=text;pendingModalAction=action;$('modalBack').classList.add('show')}
function closeModal(){$('modalBack').classList.remove('show');pendingModalAction=null}
function escapeHtml(s){return String(s).replace(/[&<>'"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]))}

$('dailyStart').addEventListener('click',()=>startSession('daily'));
$('resumeBtn').addEventListener('click',restoreSession);
$('reviewStart').addEventListener('click',()=>startSession('review'));
$('fieldButtons').addEventListener('click',e=>{const b=e.target.closest('[data-field]');if(b)startSession('field',b.dataset.field)});
$('answerGrid').addEventListener('click',e=>{const b=e.target.closest('[data-answer]');if(b)answer(b.dataset.answer)});
$('uncertainMark').addEventListener('click',toggleUncertain);
$('nextQuestion').addEventListener('click',nextQuestion);
$('quitQuiz').addEventListener('click',()=>openModal('学習を中断しますか？','進捗は保存され、ホームから再開できます。',()=>showView('home')));
$('resultReview').addEventListener('click',()=>startSession('review'));
$('resultHome').addEventListener('click',()=>showView('home'));
$('bottomNav').addEventListener('click',e=>{const b=e.target.closest('[data-view]');if(b)showView(b.dataset.view)});
$('examDate').addEventListener('change',e=>{state.examDate=e.target.value;saveState();renderExamPill()});
$('fontSize').addEventListener('change',e=>{state.fontSize=e.target.value;saveState();renderSettings()});
$('resetData').addEventListener('click',()=>openModal('学習記録を消しますか？','回答履歴、弱点、連続学習、設定がすべて削除されます。',()=>{state=defaultState();saveState();renderSettings();renderHome();renderRecord();showView('home')}));
$('modalCancel').addEventListener('click',closeModal);
$('modalBack').addEventListener('click',e=>{if(e.target===$('modalBack'))closeModal()});
$('modalConfirm').addEventListener('click',()=>{const action=pendingModalAction;closeModal();if(action)action()});

async function boot(){try{QUESTIONS=await loadQuestions();FIELDS=[...new Set(QUESTIONS.map(q=>q.field))];renderFields();renderHome();renderRecord();renderSettings();window.__FP3_TEST__={questionCount:QUESTIONS.length,getState:()=>state,getSession:()=>session,startSession,showView}}catch(e){console.error(e);document.body.innerHTML='<main style="padding:24px;font-family:-apple-system,sans-serif"><h1>読み込みに失敗しました</h1><p>'+escapeHtml(e.message||String(e))+'</p><p>Safariを最新版に更新して、ページを再読み込みしてください。</p></main>'}}boot();
