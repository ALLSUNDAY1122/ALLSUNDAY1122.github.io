const Q=window.Q_PARTS||[];const LEGAL={checked:'2026-08-08',status:'現行法監査済',copyright:'公表問題は出題論点・傾向の確認に限定し、問題文・選択肢・解説は独自作成',future:[
'2027年4月1日：一般健康診断に血清クレアチニン検査追加・喀痰検査廃止',
'2028年4月1日：労働者50人未満の事業場にもストレスチェック義務化'
]};const KEY='sm2-proto-v01';const app=document.getElementById('app');let go=null,unk=null,fb=null;let S=load(),session=[],idx=0,score=0,mode='',selected=0,locked=false,results=[];
function init(){return{seen:{},weak:{},streak:{},history:[],resume:null,total:0,correct:0,reasonByQuestion:{},reasonCounts:{}}}function load(){try{return Object.assign(init(),JSON.parse(localStorage.getItem(KEY)||'{}'))}catch(e){return init()}}function save(){localStorage.setItem(KEY,JSON.stringify(S))}
function e(s){return String(s??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]))}function sh(a){return[...a].sort(()=>Math.random()-.5)}
function head(t){return`<div class="header"><h1>${e(t)}</h1><button onclick="settings()">設定</button></div>`}
function quizHead(t){return`<div class="header"><button onclick="quizHome()">⌂ ホーム</button><h1>${e(t)}</h1><span class="autosave">自動保存</span></div>`}
function quizHome(){remember(locked?Math.min(idx+1,session.length):idx);save();home()}function tabs(a){return`<div class="tab"><button class="${a==='home'?'active':''}" onclick="home()">⌂<br>ホーム</button><button class="${a==='study'?'active':''}" onclick="study()">▣<br>学習</button><button class="${a==='hist'?'active':''}" onclick="hist()">◷<br>履歴</button><button class="${a==='set'?'active':''}" onclick="settings()">⚙<br>設定</button></div>`}
function pairCount(set,subject){return Q.filter(x=>x.examSet===set&&x.subject===subject).length}
function pairAnswerCount(set,subject){
  return Q.filter(x=>x.examSet===set&&x.subject===subject)
    .reduce((sum,q)=>sum+(S.seen[q.id]||0),0)
}
function pairLatestResult(set,subject){
  let key=set+'｜'+subject;
  let h=[...(S.history||[])].reverse().find(x=>x.mode===key&&x.total===10);
  return h ? {score:h.score,total:h.total} : null
}
function pairCard(set,subject){
  let n=pairCount(set,subject),ready=n===10,answered=pairAnswerCount(set,subject),latest=pairLatestResult(set,subject);
  let latestClass=latest?(latest.score>=8?'strong':latest.score>=6?'steady':'review'):'';
  let latestHtml=latest?`<span class="pair-score ${latestClass}">直近 ${latest.score}/${latest.total}</span>`:'';
  let statusHtml=ready?'':`<span class="pair-wait">準備中</span>`;
  return `<button class="card pair-card ${ready?'':'pair-disabled'}" ${ready?`onclick="examSubject('${set}','${subject}')"`:'disabled'}>
    ${latestHtml}${statusHtml}
    <strong>${subject}</strong>
    <small>解答 ${answered}回</small>
  </button>`
}
function examGroup(set,label){
  return `<div class="exam-group"><div class="exam-label">${label}</div><div class="grid">
    ${pairCard(set,'関係法令')}
    ${pairCard(set,'労働衛生')}
    ${pairCard(set,'労働生理')}
  </div></div>`
}
