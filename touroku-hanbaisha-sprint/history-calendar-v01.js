'use strict';
(function(){
  const LS_KEY='manabiSprint.tourokuHanbaisha.v07';
  const app=document.getElementById('app');
  if(!app)return;

  let visibleMonth=null;

  function loadHistory(){
    try{
      const state=JSON.parse(localStorage.getItem(LS_KEY)||'null');
      return Array.isArray(state?.stats?.history)?state.stats.history:[];
    }catch(e){return []}
  }

  function keyForDate(d){
    return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
  }

  function activityByDay(history){
    const map={};
    history.forEach(item=>{
      const d=new Date(item.date);
      if(Number.isNaN(d.getTime()))return;
      const key=keyForDate(d);
      if(!map[key])map[key]={sessions:0,correct:0,total:0};
      map[key].sessions++;
      map[key].correct+=Number(item.correct)||0;
      map[key].total+=Number(item.total)||0;
    });
    return map;
  }

  function monthLabel(d){return `${d.getFullYear()}年${d.getMonth()+1}月`}

  function buildCalendar(month,history){
    const activity=activityByDay(history);
    const year=month.getFullYear(),mon=month.getMonth();
    const first=new Date(year,mon,1);
    const days=new Date(year,mon+1,0).getDate();
    const today=new Date();
    const cells=[];
    for(let i=0;i<first.getDay();i++)cells.push('<div class="history-cal-cell empty" aria-hidden="true"></div>');
    for(let day=1;day<=days;day++){
      const d=new Date(year,mon,day);
      const key=keyForDate(d);
      const a=activity[key];
      const isToday=key===keyForDate(today);
      const rate=a&&a.total?Math.round(a.correct/a.total*100):null;
      const label=a?`${day}日、${a.sessions}回学習、正答率${rate}%`:`${day}日、学習なし`;
      cells.push(`<div class="history-cal-cell${a?' active':''}${isToday?' today':''}" aria-label="${label}"><span class="history-cal-day">${day}</span>${a?`<span class="history-cal-dot"></span><span class="history-cal-rate">${rate}%</span>`:''}</div>`);
    }
    return `<section class="section history-calendar" data-history-calendar>
      <div class="history-cal-head">
        <h2>履歴カレンダー</h2>
        <div class="history-cal-nav">
          <button type="button" data-cal-prev aria-label="前の月">‹</button>
          <strong>${monthLabel(month)}</strong>
          <button type="button" data-cal-next aria-label="次の月">›</button>
        </div>
      </div>
      <div class="history-cal-week"><span>日</span><span>月</span><span>火</span><span>水</span><span>木</span><span>金</span><span>土</span></div>
      <div class="history-cal-grid">${cells.join('')}</div>
      <p class="history-cal-note">● 学習した日。数字はその日の正答率です。</p>
    </section>`;
  }

  function inject(){
    const title=app.querySelector('.brand-title');
    if(!title||title.textContent.trim()!=='学習記録')return;
    if(app.querySelector('[data-history-calendar]'))return;
    const sections=app.querySelectorAll(':scope > .section');
    if(!sections.length)return;
    const history=loadHistory();
    if(!visibleMonth)visibleMonth=new Date();
    const holder=document.createElement('div');
    holder.innerHTML=buildCalendar(visibleMonth,history).trim();
    const calendar=holder.firstElementChild;
    sections[0].after(calendar);
    calendar.querySelector('[data-cal-prev]').onclick=()=>{
      visibleMonth=new Date(visibleMonth.getFullYear(),visibleMonth.getMonth()-1,1);
      calendar.outerHTML=buildCalendar(visibleMonth,loadHistory());
      bindCurrent();
    };
    calendar.querySelector('[data-cal-next]').onclick=()=>{
      visibleMonth=new Date(visibleMonth.getFullYear(),visibleMonth.getMonth()+1,1);
      calendar.outerHTML=buildCalendar(visibleMonth,loadHistory());
      bindCurrent();
    };
  }

  function bindCurrent(){
    const calendar=app.querySelector('[data-history-calendar]');
    if(!calendar)return;
    calendar.querySelector('[data-cal-prev]').onclick=()=>{
      visibleMonth=new Date(visibleMonth.getFullYear(),visibleMonth.getMonth()-1,1);
      calendar.outerHTML=buildCalendar(visibleMonth,loadHistory());
      bindCurrent();
    };
    calendar.querySelector('[data-cal-next]').onclick=()=>{
      visibleMonth=new Date(visibleMonth.getFullYear(),visibleMonth.getMonth()+1,1);
      calendar.outerHTML=buildCalendar(visibleMonth,loadHistory());
      bindCurrent();
    };
  }

  new MutationObserver(()=>requestAnimationFrame(inject)).observe(app,{childList:true,subtree:true});
  inject();
})();
