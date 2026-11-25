// Native-only learning state and UI. The public web preview remains separate.
const blankState=()=>({version:1,stats:{},history:[],session:null,settings:{font:'normal',goal:8,examDate:''}});
let study=blankState();
try{const s=window.__touhanStudyState;if(s?.version===1&&s.stats&&Array.isArray(s.history))study={...blankState(),...s,settings:{...blankState().settings,...(s.settings||{})}}}catch(e){}
let sessionScope=null,lastAnswer=null;
function persistStudy(){
  try{if(!window.webkit?.messageHandlers?.studyRecord)throw Error('storage bridge unavailable');
    window.webkit.messageHandlers.studyRecord.postMessage(JSON.stringify(study));
  }catch(e){$('saveWarning').textContent='学習記録を保存できません。';}
}
window.studySaveFailed=()=>{$('saveWarning').textContent='学習記録を保存できません。'};
function setScreen(id){
  for(const n of ['home','setup','quiz','complete','learningRecords','settings'])$(n).classList.toggle('hidden',n!==id);
  for(const [nav,target] of [['navHome','home'],['navStudy','setup'],['navRecords','learningRecords'],['navSettings','settings']])
    $(nav).setAttribute('aria-current',target===id||(nav==='navStudy'&&['quiz','complete'].includes(id))?'page':'false');
  if(id==='setup')renderMockYears();
  if(id==='settings')showSettings();
  window.scrollTo(0,0);
}
function statsFor(rows){let done=0,n=0,c=0;for(const q of rows){const s=study.stats[q.id];if(s?.attempts>0){done++;n+=s.attempts;c+=s.correct}}return {done,n,c,total:rows.length}}
function rate(s){return s.n?Math.round(100*s.c/s.n)+'%':'—'}
function scopeText(s){return (s.year==='all'?'全年度':s.year+'年度')+'・'+(s.chapter==='all'?'全分野':s.chapter)}
function validSession(s){return !!(s&&Array.isArray(s.ids)&&s.ids.length&&Number.isInteger(s.position)&&s.position>=0&&s.position<s.ids.length&&s.ids.every(id=>records.some(q=>q.id===id&&canStudy(q))))}
function todayKey(){const d=new Date();return d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0')}
function todayAttempts(){return (study.history||[]).filter(x=>String(x.at||'').slice(0,10)===todayKey()).length}
function weakQuestions(){return records.filter(q=>{const s=study.stats[q.id];return s&&s.attempts>s.correct})}
function showHome(){
  if(!records.length)return;
  setScreen('home');
  const s=statsFor(records),goal=[4,8,16].includes(Number(study.settings.goal))?Number(study.settings.goal):8,today=todayAttempts();
  $('homeProgress').textContent=s.done+' / '+s.total;$('homeAccuracy').textContent=rate(s);$('homeBar').value=s.done;
  $('resume').disabled=!validSession(study.session);
  $('resumeInfo').textContent=validSession(study.session)?scopeText(study.session.scope)+'：'+(study.session.position+1)+' / '+study.session.ids.length+'問':'中断中の学習はありません';
  $('todayCount').textContent=today+' / '+goal+'問';
  $('todayMessage').textContent=today===0?'まだ今日の学習はありません。まずは1問。':today>=goal?'今日の目標を達成しました。':'あと'+(goal-today)+'問で今日の目標に届きます。';
  $('todayArc').setAttribute('stroke-dashoffset',String((219.91*(1-Math.min(1,today/goal))).toFixed(2)));
  $('weakInfo').textContent='苦手 '+weakQuestions().length+'問';$('weakCount').textContent=weakQuestions().length;
  const grid=$('domainGrid');grid.replaceChildren();
  for(const chapter of [...new Set(records.map(q=>q.chapter))].sort()){
    const rows=records.filter(q=>q.chapter===chapter),available=rows.filter(canStudy).length;
    const b=document.createElement('button');b.className='domain-card';
    const title=document.createElement('b'),meta=document.createElement('small');title.textContent=chapter;meta.textContent=available+'問利用可能／'+rows.length+'問';
    b.append(title,meta);b.onclick=()=>{$('year').value='all';$('chapter').value=chapter;updateCount();beginSetup()};
    grid.append(b);
  }
}
function makeRow(parent,label,s){const row=document.createElement('div');row.className='recordRow';const title=document.createElement('strong');title.textContent=label;const text=document.createElement('span');text.textContent='進捗 '+s.done+' / '+s.total+'問　正答率 '+rate(s)+'（'+s.c+' / '+s.n+'）';const bar=document.createElement('progress');bar.max=s.total||1;bar.value=s.done;row.append(title,text,bar);parent.append(row)}
function renderHeatmap(){const root=$('heatmap');root.replaceChildren();for(let offset=-34;offset<=0;offset++){const d=new Date();d.setHours(12,0,0,0);d.setDate(d.getDate()+offset);const key=d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0');const n=(study.history||[]).filter(x=>String(x.at||'').slice(0,10)===key).length;const cell=document.createElement('span');cell.className='heatcell';cell.title=key+'：'+n+'問';cell.style.background=n===0?'#eee8dc':n<4?'#f5c6b7':n<8?'#e99a83':n<16?'#cf684e':'#a33d22';root.append(cell)}}
function showRecords(){
  if(!records.length)return;const s=statsFor(records);$('recordTotal').replaceChildren();
  for(const [label,value] of [['学習済み',s.done+' / '+s.total],['通算正答率',rate(s)]]){const box=document.createElement('div'),l=document.createElement('span'),v=document.createElement('strong');l.textContent=label;v.textContent=value;box.append(l,v);$('recordTotal').append(box)}
  renderHeatmap();
  for(const [field,id] of [['year','yearRecords'],['chapter','chapterRecords']]){const el=$(id);el.replaceChildren();for(const value of [...new Set(records.map(q=>q[field]))].sort())makeRow(el,field==='year'?value+'年度':value,statsFor(records.filter(q=>q[field]===value)))}
  const el=$('answerHistory');el.replaceChildren();for(const r of study.history.slice(-100).reverse()){const q=records.find(q=>q.id===r.id);if(!q)continue;const row=document.createElement('div');row.className='recordRow';row.textContent=new Date(r.at).toLocaleString('ja-JP')+'　'+q.year+'年度 問'+q.questionNo+' '+q.chapter+'　'+(r.choice===-1?'わからない':r.correct?'正解':'不正解');el.append(row)}
  if(!el.children.length)el.textContent='まだ回答履歴はありません';setScreen('learningRecords');
}
function checkpoint(){study.session={scope:sessionScope,ids:subset.map(q=>q.id),position,correct,denominator,excluded,selected,lastAnswer};persistStudy()}
function storeAnswer(q,i){const s=study.stats[q.id]||{attempts:0,correct:0};if(!q.excludeFromAccuracyDenominator){s.attempts++;if(i===q.answer)s.correct++;study.stats[q.id]=s}study.history.push({id:q.id,choice:i,correct:i===q.answer,at:new Date().toISOString()});study.history=study.history.slice(-1000);lastAnswer=i;checkpoint()}
function resumeStudy(){const s=study.session;if(!validSession(s))return;sessionScope=s.scope;subset=s.ids.map(id=>records.find(q=>q.id===id));position=s.position;correct=s.correct;denominator=s.denominator;excluded=s.excluded;lastAnswer=s.lastAnswer;setScreen('quiz');show();if(s.selected){selected=true;renderAnswer(s.lastAnswer)}}
function beginSetup(){if(!records.length)return;setScreen('setup');updateCount()}
function renderMockYears(){const root=$('mockYears');if(!root)return;root.replaceChildren();for(const year of [2026,2025,2024,2023,2022]){const all=records.filter(q=>q.year===year),free=all.filter(canStudy).length;const b=document.createElement('button');b.className='mockYear';const t=document.createElement('strong'),m=document.createElement('small');t.textContent=year+'年度';m.textContent=premiumUnlocked?all.length+'問':free+'問無料／全'+all.length+'問';b.append(t,m);b.onclick=()=>{$('year').value=String(year);updateCount()};root.append(b)}}
function startDailySprint(){if(!records.length)return;$('year').value='all';$('chapter').value='all';const pool=records.filter(canStudy);if(!pool.length){requestPremium();return}const done=new Set(Object.keys(study.stats||{}));const fresh=pool.filter(q=>!done.has(q.id));const goal=[4,8,16].includes(Number(study.settings.goal))?Number(study.settings.goal):8;subset=(fresh.length?fresh:pool).slice(0,goal);if(!subset.length)return;sessionScope={year:'all',chapter:'all'};position=0;correct=0;denominator=0;excluded=0;selected=false;lastAnswer=null;setScreen('quiz');show();checkpoint()}
function startWeakReview(){const rows=weakQuestions().filter(canStudy);if(!rows.length){if(weakQuestions().length)requestPremium();else alert('現在、苦手として登録された問題はありません。');return}subset=rows;sessionScope={year:'all',chapter:'苦手復習'};position=0;correct=0;denominator=0;excluded=0;selected=false;lastAnswer=null;setScreen('quiz');show();checkpoint()}
function showSettings(){
  const settings=study.settings||{};document.querySelectorAll('[data-font]').forEach(b=>b.classList.toggle('selected',b.dataset.font===(settings.font||'normal')));
  document.querySelectorAll('[data-goal]').forEach(b=>b.classList.toggle('selected',Number(b.dataset.goal)===(settings.goal||8)));
  $('examDate').value=settings.examDate||'';
  $('settingsPremiumStatus').textContent=premiumUnlocked?'Premium利用中：全599問':'無料プラン：50問を利用できます';
}
function applyFont(){document.documentElement.classList.remove('font-large','font-xlarge');if(study.settings.font==='large')document.documentElement.classList.add('font-large');if(study.settings.font==='xlarge')document.documentElement.classList.add('font-xlarge')}
function bindSettings(){
  document.querySelectorAll('[data-font]').forEach(b=>b.onclick=()=>{study.settings.font=b.dataset.font;persistStudy();applyFont();showSettings()});
  document.querySelectorAll('[data-goal]').forEach(b=>b.onclick=()=>{study.settings.goal=Number(b.dataset.goal);persistStudy();showSettings();showHome()});
  $('saveExamDate').onclick=()=>{study.settings.examDate=$('examDate').value||'';persistStudy();alert('試験日を保存しました。')};
  $('exportData').onclick=()=>{const payload=JSON.stringify({app:'touroku-hanbaisha',version:1,exportedAt:new Date().toISOString(),state:study},null,2);const url=URL.createObjectURL(new Blob([payload],{type:'application/json'}));const a=document.createElement('a');a.href=url;a.download='touhan-study-backup.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000)};
  $('importData').onchange=async e=>{const file=e.target.files?.[0];if(!file)return;try{if(file.size>2e6)throw Error('ファイルサイズが大きすぎます');const p=JSON.parse(await file.text());if(p.app!=='touroku-hanbaisha'||p.version!==1||!p.state||p.state.version!==1||!p.state.stats||!Array.isArray(p.state.history))throw Error('このアプリのバックアップではありません');if(!confirm('現在の学習記録をバックアップで置き換えますか？'))return;study={...blankState(),...p.state,settings:{...blankState().settings,...(p.state.settings||{})}};persistStudy();applyFont();showHome();showRecords();alert('学習データを復元しました')}catch(err){alert('読み込み失敗：'+err.message)}finally{e.target.value=''}};
}
function openSettingsPremium(){requestPremium()}
$('homeStart').onclick=beginSetup;$('navStudy').onclick=beginSetup;$('resume').onclick=resumeStudy;$('navHome').onclick=showHome;$('navRecords').onclick=showRecords;$('navSettings').onclick=()=>setScreen('settings');
$('todayStart').onclick=startDailySprint;$('startWeak').onclick=startWeakReview;if($('openRecords'))$('openRecords').onclick=showRecords;$('premiumButton').onclick=requestPremium;$('settingsPremium').onclick=openSettingsPremium;
if($('recordsHome'))$('recordsHome').onclick=showHome;bindSettings();applyFont();
