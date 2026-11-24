// Native-only study state; the web legacy page is not modified.
const blankState=()=>({version:1,stats:{},history:[],session:null});
let study=blankState();
try{const s=window.__touhanStudyState;if(s?.version===1&&s.stats&&Array.isArray(s.history))study=s}catch(e){}
let sessionScope=null,lastAnswer=null;
function persistStudy(){
  try{if(!window.webkit?.messageHandlers?.studyRecord)throw Error('storage bridge unavailable');
    window.webkit.messageHandlers.studyRecord.postMessage(JSON.stringify(study));
  }catch(e){$('saveWarning').textContent='学習記録を保存できません。';}
}
window.studySaveFailed=()=>{$('saveWarning').textContent='学習記録を保存できません。'};
function setScreen(id){for(const n of ['home','setup','quiz','complete','learningRecords'])$(n).classList.toggle('hidden',n!==id);for(const [nav,target] of [['navHome','home'],['navStudy','setup'],['navRecords','learningRecords']])$(nav).setAttribute('aria-current',target===id||(nav==='navStudy'&&['quiz','complete'].includes(id))?'page':'false');window.scrollTo(0,0)}
function statsFor(rows){let done=0,n=0,c=0;for(const q of rows){const s=study.stats[q.id];if(s?.attempts>0){done++;n+=s.attempts;c+=s.correct}}return {done,n,c,total:rows.length}}
function rate(s){return s.n?Math.round(100*s.c/s.n)+'%':'—'}
function scopeText(s){return (s.year==='all'?'全年度':s.year+'年度')+'・'+(s.chapter==='all'?'全分野':s.chapter)}
function validSession(s){return !!(s&&Array.isArray(s.ids)&&s.ids.length&&Number.isInteger(s.position)&&s.position>=0&&s.position<s.ids.length&&s.ids.every(id=>records.some(q=>q.id===id)))}
function showHome(){if(!records.length)return;const s=statsFor(records);$('homeProgress').textContent=s.done+' / '+s.total;$('homeAccuracy').textContent=rate(s);$('homeBar').value=s.done;$('resume').disabled=!validSession(study.session);$('resumeInfo').textContent=validSession(study.session)?scopeText(study.session.scope)+'：'+(study.session.position+1)+' / '+study.session.ids.length+'問':'中断中の学習はありません';setScreen('home')}
function makeRow(parent,label,s){let row=document.createElement('div');row.className='recordRow';let title=document.createElement('strong');title.textContent=label;let text=document.createElement('span');text.textContent='進捗 '+s.done+' / '+s.total+'問　正答率 '+rate(s)+'（'+s.c+' / '+s.n+'）';let bar=document.createElement('progress');bar.max=s.total||1;bar.value=s.done;row.append(title,text,bar);parent.append(row)}
function showRecords(){if(!records.length)return;const s=statsFor(records);$('recordTotal').textContent='';for(const [label,value] of [['学習済み',s.done+' / '+s.total],['通算正答率',rate(s)]]){let box=document.createElement('div'),l=document.createElement('span'),v=document.createElement('strong');l.textContent=label;v.textContent=value;box.append(l,v);$('recordTotal').append(box)}for(const [field,id] of [['year','yearRecords'],['chapter','chapterRecords']]){let el=$(id);el.replaceChildren();for(const value of [...new Set(records.map(q=>q[field]))].sort())makeRow(el,field==='year'?value+'年度':value,statsFor(records.filter(q=>q[field]===value)))}let el=$('answerHistory');el.replaceChildren();for(const r of study.history.slice(-100).reverse()){const q=records.find(q=>q.id===r.id);if(!q)continue;let row=document.createElement('div');row.className='recordRow';row.textContent=new Date(r.at).toLocaleString('ja-JP')+'　'+q.year+'年度 問'+q.questionNo+' '+q.chapter+'　'+(r.choice===-1?'わからない':r.correct?'正解':'不正解');el.append(row)}if(!el.children.length)el.textContent='まだ回答履歴はありません';setScreen('learningRecords')}
function checkpoint(){study.session={scope:sessionScope,ids:subset.map(q=>q.id),position,correct,denominator,excluded,selected,lastAnswer};persistStudy()}
function storeAnswer(q,i){const s=study.stats[q.id]||{attempts:0,correct:0};if(!q.excludeFromAccuracyDenominator){s.attempts++;if(i===q.answer)s.correct++;study.stats[q.id]=s}study.history.push({id:q.id,choice:i,correct:i===q.answer,at:new Date().toISOString()});study.history=study.history.slice(-1000);lastAnswer=i;checkpoint()}
function resumeStudy(){const s=study.session;if(!validSession(s))return;sessionScope=s.scope;subset=s.ids.map(id=>records.find(q=>q.id===id));position=s.position;correct=s.correct;denominator=s.denominator;excluded=s.excluded;lastAnswer=s.lastAnswer;setScreen('quiz');show();if(s.selected){selected=true;renderAnswer(s.lastAnswer)}}
function beginSetup(){if(!records.length)return;setScreen('setup')}
$('homeStart').onclick=beginSetup;$('navStudy').onclick=beginSetup;$('resume').onclick=resumeStudy;$('navHome').onclick=showHome;$('recordsHome').onclick=showHome;$('openRecords').onclick=showRecords;$('navRecords').onclick=showRecords;
