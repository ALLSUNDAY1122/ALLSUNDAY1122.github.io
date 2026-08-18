const QUESTIONS=window.Q_PARTS||[];
const SUBJECTS=['関係法令','労働衛生','労働生理'];
const EXAMSETS=['令和8年4月','令和7年10月','令和7年4月','5年分相当｜第4回','5年分相当｜第5回','5年分相当｜第6回','5年分相当｜第7回','5年分相当｜第8回','5年分相当｜第9回','5年分相当｜第10回'];
const KEY='sm2_manabi_sprint_v110';
const OLDKEY='sm2-proto-v01';
const VERSION=2;
const LEGAL_DATE='2026-08-18';

const $=s=>document.querySelector(s);
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const shuffle=a=>{a=[...a];for(let i=a.length-1;i>0;i--){let j=Math.floor(Math.random()*(i+1));[a[i],a[j]]=[a[j],a[i]]}return a};
const todayKey=(d=new Date())=>`${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
const clamp=(n,a,b)=>Math.max(a,Math.min(b,n));
const uidMap=()=>Object.fromEntries(QUESTIONS.map(q=>[q.id,q]));
const QMAP=uidMap();

function defaults(){
  return {total:0,correct:0,weak:{},history:[],resume:null,fontSize:'standard',dailyGoal:8,shuffleQuestions:true,shuffleChoices:false,daily:{},mockResults:{},subjectStats:{},examDate:'',seen:{},pairAnswers:{}};
}
function load(){
  let s=defaults();
  try{Object.assign(s,JSON.parse(localStorage.getItem(KEY)||'{}'))}catch(e){}
  if(!localStorage.getItem(KEY)){
    try{
      const o=JSON.parse(localStorage.getItem(OLDKEY)||'{}');
      if(o&&Object.keys(o).length){
        s.total=o.total||0;s.correct=o.correct||0;s.history=o.history||[];
        s.seen=o.seen||{};
        if(o.weak) for(const id of Object.keys(o.weak)) s.weak[id]={streak:0,last:Date.now()};
      }
    }catch(e){}
  }
  s.dailyGoal=[4,8,16].includes(+s.dailyGoal)?+s.dailyGoal:8;
  return s;
}
let S=load(),session=null,idx=0,results=[],score=0,answered=false,currentOrder=[];
function save(){localStorage.setItem(KEY,JSON.stringify(S))}
function applyFont(){document.body.classList.toggle('large',S.fontSize==='large');document.body.classList.toggle('xlarge',S.fontSize==='xlarge')}
function toast(msg){const t=$('#toast');t.textContent=msg;t.classList.add('show');clearTimeout(toast._t);toast._t=setTimeout(()=>t.classList.remove('show'),2200)}
applyFont();

const ICON={
home:`<svg viewBox="0 0 24 24"><path d="M3 11.5 12 4l9 7.5"/><path d="M5.5 10.5V20h13v-9.5"/><path d="M9.5 20v-5.5h5V20"/></svg>`,
mock:`<svg viewBox="0 0 24 24"><path d="M6 3.5h12v17H6z"/><path d="M9 8h6M9 12h6M9 16h3"/></svg>`,
record:`<svg viewBox="0 0 24 24"><path d="M4 19.5V11m5 8.5V6m5 13.5V9m5 10.5V4"/></svg>`,
settings:`<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="3"/><path d="M19 12a7 7 0 0 0-.1-1l2-1.5-2-3.4-2.4 1A8 8 0 0 0 15 6.2L14.7 3h-4L10.4 6.2a8 8 0 0 0-1.5.9l-2.4-1-2 3.4L6.6 11a7 7 0 0 0 0 2l-2.1 1.5 2 3.4 2.4-1a8 8 0 0 0 1.5.9l.3 3.2h4l.3-3.2a8 8 0 0 0 1.5-.9l2.4 1 2-3.4-2-1.5c.1-.3.1-.7.1-1z"/></svg>`,
weak:`<svg viewBox="0 0 24 24"><path d="M12 21s-7-4.3-7-10.2A4.3 4.3 0 0 1 12 7.5a4.3 4.3 0 0 1 7 3.3C19 16.7 12 21 12 21z"/><path d="M12 10v5m0 2.5h.01"/></svg>`
};

function nav(active){
  return `<nav class="nav" aria-label="メインナビ">
  <button class="${active==='home'?'active':''}" onclick="home()">${ICON.home}<span>ホーム</span></button>
  <button class="${active==='mock'?'active':''}" onclick="mockScreen()">${ICON.mock}<span>模試</span></button>
  <button class="${active==='history'?'active':''}" onclick="historyScreen()">${ICON.record}<span>記録</span></button>
  <button class="${active==='settings'?'active':''}" onclick="settingsScreen()">${ICON.settings}<span>設定</span></button>
  </nav>`;
}
function topBlock(brand,title,tagline){
  return `<header class="top"><div class="brand">${esc(brand)}</div><h1 class="title">${esc(title)}</h1><div class="tagline">${esc(tagline)}</div></header>`;
}
function setApp(html,grid=false){const app=$('#app');app.className='app'+(grid?' home-grid':'');app.innerHTML=`<section class="screen">${html}</section>`;window.scrollTo(0,0)}

function dailyNow(){return S.daily[todayKey()]||{a:0,c:0}}
function streakDays(){
  let n=0,d=new Date();
  for(let i=0;i<3650;i++){let k=todayKey(d);if((S.daily[k]?.a||0)>0){n++;d.setDate(d.getDate()-1)}else break}
  return n;
}
function uniqueSeenCount(filter=()=>true){return QUESTIONS.filter(q=>filter(q)&&(S.seen[q.id]||0)>0).length}
function weakCount(filter=()=>true){return Object.keys(S.weak).filter(id=>QMAP[id]&&filter(QMAP[id])).length}
function ringHTML(a,goal){
  const r=35,c=2*Math.PI*r,p=clamp(a/goal,0,1),off=c*(1-p);
  return `<div class="ring"><svg viewBox="0 0 82 82"><circle class="track" cx="41" cy="41" r="${r}"/><circle class="fill" cx="41" cy="41" r="${r}" style="stroke-dasharray:${c};stroke-dashoffset:${off}"/></svg><div class="ringtext"><b>${a}/${goal}</b><small>今日</small></div></div>`;
}
function countdownHTML(){
  if(!S.examDate)return '';
  const target=new Date(S.examDate+'T00:00:00'),now=new Date();now.setHours(0,0,0,0);
  const days=Math.ceil((target-now)/86400000); if(days<0)return '';
  const remain=QUESTIONS.length-uniqueSeenCount();
  const pace=days>0?Math.ceil(remain/days):remain;
  return `<div class="countdown ${days<=14?'urgent':''}"><div class="row"><div><small>試験日まで</small><div class="dnum">${days}日</div></div><div style="text-align:right;font-weight:900">${days===0?'今日が試験日':'1日 '+pace+'問が目安'}</div></div><small>未着手 ${remain}問。焦らせるためではなく、一周に必要な目安です。</small></div>`;
}
function todayMessage(a,c,goal){
  if(a===0)return 'まだ今日の分は解いていません。まずは1問。';
  if(a<goal)return `あと${goal-a}問で今日の目標に届きます。`;
  return `今日の目標は達成。正解${c}問でした。`;
}
function minutes(goal){return goal===4?2:goal===16?6:3}
function subjectCard(s){
  const all=QUESTIONS.filter(q=>q.subject===s),seen=uniqueSeenCount(q=>q.subject===s),weak=weakCount(q=>q.subject===s),pct=Math.round(seen/all.length*100);
  return `<button class="subjectcard" onclick="startSubject('${s}')"><div class="subjecttop"><b>${s}</b><span>${all.length}問</span></div><div class="sbar"><i style="width:${pct}%"></i></div><div class="subjectbottom"><span>解いた ${seen}/${all.length}問</span><span>苦手 ${weak}問</span></div></button>`;
}
