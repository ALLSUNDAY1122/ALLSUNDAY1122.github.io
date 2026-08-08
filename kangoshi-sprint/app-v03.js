(()=>{
'use strict';
const Q=window.KANGOSHI_QUESTIONS||[];
const META=window.KANGOSHI_CONTENT_META||{};
const KEY='kangoshiSprintStateV03';
const app=document.getElementById('app');
if(!app) return;
const esc=s=>String(s??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
const base=()=>({weak:{},history:[],seen:[],resume:null,font:'normal',completed:{}});
let state=load();
let session=null;
let page='home';
let selectedMajor=null;

const GROUPS=[
 ['人体の構造と機能','体','人体の基本構造・生理機能'],
 ['疾病の成り立ちと回復の促進','病','病態・検査・治療・薬理'],
 ['健康支援と社会保障制度','制','公衆衛生・制度・社会保障'],
 ['基礎看護学','基','看護技術・安全・日常生活援助'],
 ['地域・在宅看護論','在','地域・在宅・退院支援'],
 ['成人看護学','成','成人期の主要疾患と看護'],
 ['老年看護学','老','高齢者・老化・認知症'],
 ['小児看護学','小','成長発達・小児疾患・家族支援'],
 ['母性看護学','母','妊娠・分娩・産褥・新生児'],
 ['精神看護学','精','精神疾患・こころの看護'],
 ['看護の統合と実践','統','倫理・災害・管理・横断実践'],
 ['その他・横断','他','複数領域にまたがるテーマ']
];
const EXACT={
 '生命維持':'人体の構造と機能',
 '感染予防':'基礎看護学','安全':'基礎看護学','酸素療法':'基礎看護学','与薬':'基礎看護学','清潔':'基礎看護学','観察':'基礎看護学','褥瘡予防':'基礎看護学','コミュニケーション':'基礎看護学','排泄':'基礎看護学','栄養':'基礎看護学','呼吸':'基礎看護学','循環':'基礎看護学','体温':'基礎看護学','疼痛':'基礎看護学','輸液':'基礎看護学','患者安全':'基礎看護学','安楽':'基礎看護学','記録':'基礎看護学',
 '災害':'看護の統合と実践','倫理':'看護の統合と実践','個人情報':'看護の統合と実践'
};
const RULES=[
 ['小児看護学',/(小児|乳児|幼児|学童|思春期|成長発達)/],
 ['母性看護学',/(母性|妊娠|妊婦|分娩|産褥|胎児|新生児|授乳|産婦)/],
 ['精神看護学',/(精神|統合失調|うつ|躁|不安障害|依存|自殺|こころ)/],
 ['老年看護学',/(老年|高齢|老化|認知症|フレイル|サルコペニア)/],
 ['地域・在宅看護論',/(地域|在宅|訪問|退院支援|在宅療養|介護|地域包括|家族支援)/],
 ['健康支援と社会保障制度',/(社会保障|公衆衛生|保健統計|保健医療|制度|法律|法規|医療保険|介護保険|人口|疫学|労働衛生)/],
 ['看護の統合と実践',/(災害|倫理|個人情報|看護管理|医療安全|チーム|多職種|国際|救急|トリアージ)/],
 ['基礎看護学',/(感染予防|安全|酸素療法|与薬|清潔|観察|褥瘡|コミュニケーション|排泄|栄養|体温|疼痛|輸液|患者安全|安楽|記録|看護技術|バイタル|環境整備)/],
 ['成人看護学',/(循環器|呼吸器|消化器|腎|泌尿|内分泌|代謝|血液|脳神経|神経|運動器|感覚器|周術期|がん|癌|急性期|慢性期|心不全|COPD|糖尿病|脳卒中)/],
 ['疾病の成り立ちと回復の促進',/(疾病|病態|薬理|薬物|感染症|免疫|腫瘍|検査|治療|病理|炎症)/],
 ['人体の構造と機能',/(人体|解剖|生理|生命維持|細胞|組織|恒常性|ホメオスタシス)/]
];
function majorOf(q){
 if(q.majorSubject&&GROUPS.some(g=>g[0]===q.majorSubject))return q.majorSubject;
 const s=String(q.subject||'');
 if(EXACT[s])return EXACT[s];
 for(const [major,re] of RULES)if(re.test(s))return major;
 return 'その他・横断';
}
function load(){try{return {...base(),...JSON.parse(localStorage.getItem(KEY)||'{}')}}catch{return base()}}
function save(){localStorage.setItem(KEY,JSON.stringify(state))}
function applyFont(){document.documentElement.classList.remove('fs-large','fs-xlarge');if(state.font==='large')document.documentElement.classList.add('fs-large');if(state.font==='xlarge')document.documentElement.classList.add('fs-xlarge')}
function shuffle(a){const b=[...a];for(let i=b.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[b[i],b[j]]=[b[j],b[i]]}return b}
function pick(pool,n){const seen=new Set(state.seen||[]);return [...shuffle(pool.filter(x=>!seen.has(x.id))),...shuffle(pool.filter(x=>seen.has(x.id)))].slice(0,Math.min(n,pool.length))}
function header(title,c=''){return `<div class="header"><button data-action="home">ホーム</button><h1>${esc(title)}</h1>${c?`<span class="counter">${esc(c)}</span>`:''}</div>`}
function tabs(active){return `<nav class="tabbar"><button data-tab="home" class="${active==='home'?'active':''}"><span class="ic">⌂</span>ホーム</button><button data-tab="history" class="${active==='history'?'active':''}"><span class="ic">▤</span>学習記録</button><button data-tab="settings" class="${active==='settings'?'active':''}"><span class="ic">⚙</span>設定</button></nav>`}
function current(){return Q.find(x=>x.id===session?.ids?.[session.index])}
function weakPool(){return Object.keys(state.weak||{}).map(id=>Q.find(x=>x.id===id)).filter(Boolean).sort((a,b)=>(state.weak[b.id]?.misses||0)-(state.weak[a.id]?.misses||0))}
function persist(){if(!session)return;state.resume={ids:[...session.ids],index:session.index,correct:session.correct,results:[...session.results],label:session.label,started:session.started};save()}
function start(pool,label,n=12){
 if(!Array.isArray(pool)||!pool.length){alert('この分類にはまだ問題がありません。');return}
 const arr=pick(pool,n);
 session={ids:arr.map(x=>x.id),index:0,correct:0,results:[],label,started:Date.now(),selected:[],answered:false,numericValue:''};
 page='quiz';persist();render();window.scrollTo(0,0);
}
function resumeSession(){const r=state.resume;if(!r?.ids?.length)return;session={...r,selected:[],answered:false,numericValue:''};page='quiz';render();window.scrollTo(0,0)}
function render(){applyFont();if(page==='quiz')return renderQuiz();if(page==='result')return renderResult();if(page==='history')return renderHistory();if(page==='settings')return renderSettings();if(page==='subjects')return renderMajors();if(page==='subject-smalls')return renderSmalls(selectedMajor);if(page==='paywall')return renderPaywall();return renderHome()}
function categoryCard(name,cls){const count=Q.filter(x=>x.category===name).length;return `<button class="category-card ${cls}" data-category="${esc(name)}"><span><strong>${esc(name)}</strong><span>${count}問・完答 ${state.completed[name]||0}回</span></span></button>`}
function renderHome(){
 const wc=Object.keys(state.weak||{}).length;
 const resumeCard=state.resume?`<button class="resume" data-action="resume"><span class="icon">↻</span><span><span class="name">続きから</span><span class="meta">${esc(state.resume.label)}・${state.resume.index+1}/${state.resume.ids.length}問</span></span></button>`:'';
 app.innerHTML=`<section class="home-top"><div class="kicker">学びスプリント</div><div class="app-name">看護師国家試験</div><p class="lead">今日の12問を、合格の1歩に。</p></section>${resumeCard}<section class="section"><button class="full-btn" data-action="daily"><span class="icon">12</span><span><span class="name">今日の12問</span><span class="meta">必修・一般・状況設定を横断</span></span></button><button class="full-btn" data-action="required"><span class="icon">必</span><span><span class="name">必修12問</span><span class="meta">基本事項を集中反復</span></span></button><button class="full-btn" data-action="weak" ${wc?'':'disabled'}><span class="icon">↺</span><span><span class="name">苦手復習</span><span class="meta">3連続正解で自動解除</span></span><span class="badge">${wc}問</span></button></section><section class="section"><h2>出題区分から学ぶ</h2><div class="category-grid">${categoryCard('必修','required')}${categoryCard('一般','general')}${categoryCard('状況設定','scenario')}</div></section><section class="section"><button class="full-btn" data-action="subjects"><span class="icon">科</span><span><span class="name">科目・領域から学ぶ</span><span class="meta">大分類 → 小分類の順に選択</span></span></button><button class="full-btn" data-action="mock"><span class="icon">試</span><span><span class="name">本番形式</span><span class="meta">製品版で午前120問＋午後120問</span></span></button></section>${tabs('home')}`;
}
function buildHierarchy(){
 const seen=new Set(state.seen||[]),weak=state.weak||{},byMajor=new Map(GROUPS.map(g=>[g[0],new Map()]));
 Q.forEach(q=>{const major=majorOf(q);if(!byMajor.has(major))byMajor.set(major,new Map());const small=String(q.subject||'未分類'),m=byMajor.get(major);if(!m.has(small))m.set(small,{questions:[],seen:0,weak:0});const row=m.get(small);row.questions.push(q);if(seen.has(q.id))row.seen++;if(weak[q.id])row.weak++});
 return byMajor;
}
function renderMajors(){
 const byMajor=buildHierarchy();
 const cards=GROUPS.map(([name,icon,desc])=>{const smalls=byMajor.get(name)||new Map(),vals=[...smalls.values()],qCount=vals.reduce((n,v)=>n+v.questions.length,0);if(!qCount)return'';const seen=vals.reduce((n,v)=>n+v.seen,0),weak=vals.reduce((n,v)=>n+v.weak,0);return `<button class="major-card" data-major="${esc(name)}"><span class="major-icon">${esc(icon)}</span><span class="major-body"><strong>${esc(name)}</strong><span class="major-desc">${esc(desc)}</span><span class="major-meta">小分類 ${smalls.size} ・ ${qCount}問 ・ ${seen}問解答${weak?` ・ 苦手${weak}`:''}</span></span><span class="major-arrow">›</span></button>`}).join('');
 app.innerHTML=`${header('科目・領域から学ぶ')}<section class="section hierarchy-section"><div class="hierarchy-guide"><b>大分類を選ぶ</b><span>選択すると、その中の小分類だけを表示します。</span></div><div class="major-list">${cards}</div></section>${tabs('home')}`;
}
function renderSmalls(major){
 const byMajor=buildHierarchy(),smalls=byMajor.get(major)||new Map(),group=GROUPS.find(g=>g[0]===major);
 const rows=[...smalls.entries()].sort((a,b)=>a[0].localeCompare(b[0],'ja')).map(([name,v])=>{const pct=v.questions.length?Math.round(v.seen/v.questions.length*100):0;return `<button class="small-subject-card" data-subject="${esc(name)}"><span class="small-subject-main"><strong>${esc(name)}</strong><span>${v.questions.length}問 ・ ${v.seen}問解答${v.weak?` ・ 苦手${v.weak}`:''}</span></span><span class="small-progress"><i style="width:${pct}%"></i></span><span class="small-arrow">›</span></button>`}).join('');
 app.innerHTML=`${header('科目・領域から学ぶ')}<section class="section hierarchy-section"><button class="hierarchy-back" data-action="majors">‹ 大分類に戻る</button><div class="selected-major"><span class="major-icon">${esc(group?.[1]||'科')}</span><span><span class="crumb">大分類</span><strong>${esc(major)}</strong><small>${esc(group?.[2]||'')}</small></span></div><div class="hierarchy-guide small-guide"><b>小分類を選ぶ</b><span>この大分類に含まれる項目だけを表示しています。</span></div><div class="small-subject-list">${rows}</div></section>${tabs('home')}`;
}
function scenarioBlock(q){if(!q.scenario)return'';const idx=Number(q.scenarioIndex||0),total=Number(q.scenarioTotal||1);return `<div class="scenario-box"><div class="scenario-label">状況設定 ${idx+1}/${total}</div>${idx===0?`<div class="scenario-text">${esc(q.scenario)}</div>`:`<details><summary>状況をもう一度見る</summary><div class="scenario-text">${esc(q.scenario)}</div></details>`}</div>`}
function renderQuiz(){
 const q=current();if(!q){finish();return}
 const n=session.index+1,total=session.ids.length,done=session.answered,last=session.results.at(-1);let answerHtml='';
 if(q.answerType==='numeric'){
  answerHtml=done?`<div class="numeric-answer">あなたの回答：<b>${esc(last.response)} ${esc(q.unit||'')}</b><br>正答：<b>${esc(q.answer)} ${esc(q.unit||'')}</b></div>`:`<div class="numeric-wrap"><label class="numeric-label" for="numericAnswer">数値を入力</label><div class="numeric-line"><input id="numericAnswer" class="numeric-input" inputmode="decimal" type="number" step="any" value="${esc(session.numericValue)}"><span class="numeric-unit">${esc(q.unit||'')}</span></div></div><button class="grade" data-action="numeric-grade">採点する</button><button class="dontknow" data-action="unknown">わからない</button>`;
 }else{
  const multi=q.answerType==='multiChoice';
  const choices=(q.choices||[]).map((c,i)=>{let cls=session.selected.includes(i)?'selected':'';if(done){const ans=Array.isArray(q.answer)?q.answer:[q.answer];if(ans.includes(i))cls='correct';else if(session.selected.includes(i))cls='wrong'}return `<button class="choice ${cls}" data-choice="${i}" ${done?'disabled':''}><span class="num">${i+1}</span><span>${esc(c)}</span></button>`}).join('');
  if(done)answerHtml=choices;else if(multi)answerHtml=`<div class="select-state">${session.selected.length} / ${q.selectCount} 選択中</div>${choices}<button class="grade" data-action="multi-grade" ${session.selected.length===q.selectCount?'':'disabled'}>採点する</button><button class="dontknow" data-action="unknown">わからない</button>`;else answerHtml=`${choices}<button class="dontknow" data-action="unknown">わからない</button>`;
 }
 const feedback=done?`<div class="feedback ${last.correct?'ok':'ng'}"><div class="feedback-title">${last.correct?'正解':'不正解'}</div><span class="learn-label">この問題で覚える一文</span><p class="feedback-point">${esc(q.point)}</p><details><summary>詳しい解説を見る</summary><p class="detail">${esc(q.detail)}</p></details></div><button class="next" data-action="next">${n===total?'結果を見る':'次の問題へ'}</button>`:'';
 const type=q.answerType==='multiChoice'?`<span class="tag multi">${q.selectCount}つ選択</span>`:q.answerType==='numeric'?`<span class="tag multi">数値計算</span>`:'';
 app.innerHTML=`${header(session.label,`${n} / ${total}`)}<section class="quiz"><div class="progress"><div style="width:${Math.round((session.index/total)*100)}%"></div></div><div class="tags"><span class="tag">${esc(q.category)}</span><span class="tag nurse">${esc(q.subject)}</span>${type}</div>${scenarioBlock(q)}<div class="qtext">${esc(q.question)}</div>${answerHtml}${feedback}</section>`;
}
function isCorrect(q,response,unknown){if(unknown)return false;if(q.answerType==='numeric'){const v=Number(response);return Number.isFinite(v)&&Math.abs(v-Number(q.answer))<=Number(q.tolerance||0)}const ans=(Array.isArray(q.answer)?[...q.answer]:[q.answer]).sort((a,b)=>a-b),got=[...response].sort((a,b)=>a-b);return ans.length===got.length&&ans.every((v,i)=>v===got[i])}
function grade(response,unknown=false){const q=current();if(!q||session.answered)return;const ok=isCorrect(q,response,unknown);session.answered=true;if(ok)session.correct++;const w=state.weak[q.id];if(ok&&w){w.streak=(w.streak||0)+1;if(w.streak>=3)delete state.weak[q.id]}else if(!ok){state.weak[q.id]={streak:0,misses:(w?.misses||0)+1,lastMiss:Date.now()}}if(!state.seen.includes(q.id))state.seen.push(q.id);session.results.push({id:q.id,correct:ok,unknown,category:q.category,subject:q.subject,response:q.answerType==='numeric'?response:[...response]});persist();render()}
function nextQuestion(){if(session.index>=session.ids.length-1){finish();return}session.index++;session.selected=[];session.answered=false;session.numericValue='';persist();render();window.scrollTo(0,0)}
function finish(){if(!session)return;const r={label:session.label,correct:session.correct,total:session.ids.length,elapsed:Math.max(1,Math.round((Date.now()-session.started)/1000)),at:Date.now(),results:session.results};state.history.unshift(r);state.history=state.history.slice(0,30);const cats=[...new Set(r.results.map(x=>x.category))];if(cats.length===1&&r.results.length===session.ids.length)state.completed[cats[0]]=(state.completed[cats[0]]||0)+1;state.resume=null;save();session.final=r;page='result';render()}
function renderResult(){const r=session?.final||state.history[0];if(!r){page='home';render();return}const rate=Math.round(r.correct/r.total*100),wc=Object.keys(state.weak||{}).length;app.innerHTML=`${header('結果')}<div class="result"><div class="result-big">${r.correct} / ${r.total}</div><div class="result-sub">正答率 ${rate}%</div><div class="result-grid"><div class="metric"><b>${rate}%</b><span>正答率</span></div><div class="metric"><b>${Math.floor(r.elapsed/60)}:${String(r.elapsed%60).padStart(2,'0')}</b><span>所要時間</span></div><div class="metric"><b>${wc}</b><span>苦手</span></div></div></div><div class="result-actions"><button class="next" data-action="daily">もう12問</button><button class="secondary" data-action="weak" ${wc?'':'disabled'}>間違えた問題を復習</button><button class="secondary" data-action="home">ホームへ</button></div>`}
function renderHistory(){const a=state.history.reduce((s,x)=>s+x.total,0),c=state.history.reduce((s,x)=>s+x.correct,0);app.innerHTML=`${header('学習記録')}<section class="stats"><div class="stat-row"><div class="stat"><b>${a}</b><span>累計解答</span></div><div class="stat"><b>${a?Math.round(c/a*100):0}%</b><span>正答率</span></div><div class="stat"><b>${Object.keys(state.weak||{}).length}</b><span>苦手</span></div></div><div class="history">${state.history.length?state.history.map(x=>`<div class="history-item"><span>${esc(x.label)} ${x.correct}/${x.total}</span><span>${new Date(x.at).toLocaleDateString('ja-JP')}</span></div>`).join(''):`<div class="empty">まだ学習記録はありません。</div>`}</div></section>${tabs('history')}`}
function renderSettings(){app.innerHTML=`${header('設定')}<section class="settings"><div class="setting-card"><h3>文字サイズ</h3><div class="seg"><button data-font="normal" class="${state.font==='normal'?'active':''}">標準</button><button data-font="large" class="${state.font==='large'?'active':''}">大</button><button data-font="xlarge" class="${state.font==='xlarge'?'active':''}">特大</button></div></div><div class="setting-card"><h3>問題データ</h3><p>${esc(META.version||'MVP')}・${Q.length}問</p></div><div class="setting-card"><h3>課金</h3><button class="secondary" data-action="paywall">課金画面を確認</button></div><div class="setting-card"><h3>学習データ</h3><button class="danger" data-action="reset">学習データをリセット</button></div></section>${tabs('settings')}`}
function renderPaywall(){app.innerHTML=`${header('プレミアム')}<section class="paywall"><div class="paycard"><h2>看護師国試 プレミアム</h2><p>Safari版では購入処理を行いません。</p><div class="plans"><div class="plan"><b>月額</b><span>7日無料候補</span></div><div class="plan"><b>買い切り</b><span>長期利用向け</span></div></div></div></section>`}

app.addEventListener('input',e=>{if(e.target.id==='numericAnswer'&&session)session.numericValue=e.target.value});
app.addEventListener('click',e=>{
 const choice=e.target.closest('[data-choice]');
 if(choice&&page==='quiz'&&!session.answered){const q=current(),i=Number(choice.dataset.choice);if(q.answerType==='singleChoice'){grade([i]);return}const p=session.selected.indexOf(i);if(p>=0)session.selected.splice(p,1);else if(session.selected.length<q.selectCount)session.selected.push(i);render();return}
 const el=e.target.closest('[data-action],[data-tab],[data-category],[data-major],[data-subject],[data-font]');if(!el)return;
 if(el.dataset.action){const a=el.dataset.action;if(a==='home'){page='home';selectedMajor=null;render();return}if(a==='daily'){start(Q,'今日の12問');return}if(a==='required'){start(Q.filter(x=>x.category==='必修'),'必修12問');return}if(a==='weak'){const w=weakPool();if(w.length)start(w,'苦手復習',Math.min(12,w.length));return}if(a==='resume'){resumeSession();return}if(a==='subjects'){page='subjects';render();return}if(a==='majors'){page='subjects';selectedMajor=null;render();return}if(a==='multi-grade'){grade(session.selected);return}if(a==='numeric-grade'){grade(session.numericValue);return}if(a==='unknown'){grade(current().answerType==='numeric'?'':[],true);return}if(a==='next'){nextQuestion();return}if(a==='mock'||a==='paywall'){page='paywall';render();return}if(a==='reset'){if(confirm('学習データを削除しますか？')){state=base();save();page='home';render()}return}}
 if(el.dataset.tab){page=el.dataset.tab;selectedMajor=null;render();return}
 if(el.dataset.category){const c=el.dataset.category;start(Q.filter(x=>x.category===c),`${c}12問`);return}
 if(el.dataset.major){selectedMajor=el.dataset.major;page='subject-smalls';render();return}
 if(el.dataset.subject){const s=el.dataset.subject;start(Q.filter(x=>x.subject===s),s);return}
 if(el.dataset.font){state.font=el.dataset.font;save();render();return}
});
applyFont();render();
})();
