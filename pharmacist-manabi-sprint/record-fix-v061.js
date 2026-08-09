(function(){'use strict';
var KEY='pharmacist_manabi_sprint_v060';
function load(){try{return JSON.parse(localStorage.getItem(KEY)||'{}')||{}}catch(e){return{}}}
function dayKey(d){return d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0')}
function activeQuestions(){return (window.PHARM_QUESTIONS||[]).filter(function(q){return q&&q.scored!==false})}
function esc(s){return String(s==null?'':s).replace(/[&<>"']/g,function(c){return{'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]})}
function renderAchievement(){
  var state=load(),qs=activeQuestions(),seen=state.seen||{},fields=state.fields||{};
  var learned=qs.filter(function(q){return !!seen[q.id]}).length,total=qs.length;
  var progress=total?learned/total:0,pct=total?Math.round(progress*100):0;
  var correct=Number(state.totalCorrect)||0,answered=Number(state.totalAnswered)||0,accuracy=answered?Math.round(correct/answered*100):null;
  var dt=document.getElementById('donutText'),df=document.getElementById('donutFill'),at=document.getElementById('achText');
  if(dt)dt.textContent=total?pct+'%':'—';
  if(df)df.style.strokeDashoffset=251.33*(1-progress);
  if(at)at.textContent=learned+' / '+total+'問に着手。'+(accuracy===null?'正答率は回答後に表示されます。':'全体正答率 '+accuracy+'%。');
  var box=document.getElementById('fieldRates');if(!box)return;
  var domains=[];qs.forEach(function(q){if(domains.indexOf(q.s)<0)domains.push(q.s)});box.innerHTML='';
  domains.forEach(function(name){
    var pool=qs.filter(function(q){return q.s===name}),done=pool.filter(function(q){return !!seen[q.id]}).length;
    var p=pool.length?done/pool.length:0,pp=pool.length?Math.round(p*100):0;
    var e=document.createElement('div');e.className='rateRow recordProgressRow';
    e.innerHTML='<span>'+esc(name)+'</span><span class="rateTrack"><i style="width:'+pp+'%"></i></span><b>'+(done?pp+'%':'—')+'</b>';
    box.appendChild(e);
  });
}
function renderHeatmap(){
  var state=load(),daily=state.daily||{},goal=Number(state.goal)||8,x=document.getElementById('heatmap');if(!x)return;
  x.innerHTML='';var today=new Date();today.setHours(12,0,0,0);
  var start=new Date(today);start.setDate(today.getDate()-(today.getDay()+28));
  for(var i=0;i<35;i++){
    var d=new Date(start);d.setDate(start.getDate()+i);var key=dayKey(d),n=Number((daily[key]||{}).a)||0;
    var e=document.createElement('i');e.className='heatCell';e.title=key+' '+n+'問';e.setAttribute('aria-label',key+'、'+n+'問学習');
    if(d>today)e.classList.add('future');
    else if(n>=goal)e.classList.add('lv3');
    else if(n>=4)e.classList.add('lv2');
    else if(n>0)e.classList.add('lv1');
    if(key===dayKey(today))e.classList.add('heatToday');
    x.appendChild(e);
  }
}
function render(){var h=document.getElementById('history');if(!h||!h.classList.contains('active'))return;renderAchievement();renderHeatmap()}
function schedule(){setTimeout(render,0);setTimeout(render,80)}
document.addEventListener('click',function(e){if(e.target.closest&&e.target.closest('.nav button[data-view="history"]'))schedule()},true);
var historyEl=document.getElementById('history');if(historyEl)new MutationObserver(schedule).observe(historyEl,{attributes:true,attributeFilter:['class']});
window.addEventListener('storage',schedule);
document.addEventListener('visibilitychange',function(){if(!document.hidden)schedule()});
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',schedule);else schedule();
})();
